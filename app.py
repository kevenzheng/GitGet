import os
import io
import tempfile
from pathlib import Path
from flask import Flask, request, jsonify
from flask_cors import CORS
from markitdown import MarkItDown

# PDF Rendering & OCR Libraries
from pdf2image import convert_from_path
from PIL import Image
import pytesseract

app = Flask(__name__)
CORS(app)  # Enable cross-origin requests for n8n webhooks

# Configure Tesseract OCR binary path for Windows environments if applicable
if os.name == 'nt':
    pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'


def ocr_pdf_pages(pdf_path):
    """
    Converts PDF pages into high-resolution images and runs Tesseract OCR 
    to extract text from scanned or image-based slides.
    """
    ocr_text = ""
    try:
        # Convert PDF pages to PIL images (requires poppler installed)
        images = convert_from_path(pdf_path)
        for i, img in enumerate(images):
            # Upscale slightly for better text recognition clarity
            img = img.resize((img.width * 2, img.height * 2), Image.Resampling.LANCZOS)
            page_text = pytesseract.image_to_string(img, config=r'--psm 6')
            if page_text.strip():
                ocr_text += f"\n--- PAGE {i+1} ---\n" + page_text
    except Exception as err:
        print(f"[PDF OCR Error]: {err}")
    return ocr_text


@app.route('/convert-slides', methods=['POST'])
def convert_slides():
    """API Endpoint restricted strictly to PDF processing and OCR."""
    if 'file' not in request.files:
        return jsonify({'success': False, 'error': 'No file uploaded'}), 400

    uploaded_file = request.files['file']
    if uploaded_file.filename == '':
        return jsonify({'success': False, 'error': 'Empty filename'}), 400

    file_extension = Path(uploaded_file.filename).suffix.lower()
    if file_extension != '.pdf':
        return jsonify({'success': False, 'error': 'Only .pdf files are supported'}), 400

    temp_file_path = None
    try:
        # Save uploaded binary file to temporary disk location
        with tempfile.NamedTemporaryFile(delete=False, suffix='.pdf') as tmp:
            uploaded_file.save(tmp.name)
            temp_file_path = tmp.name

        # 1. Try primary text extraction via MarkItDown
        md = MarkItDown()
        parsed_result = md.convert(temp_file_path)
        extracted_text = parsed_result.text_content if parsed_result and parsed_result.text_content else ""

        # 2. If MarkItDown yields little to no text (common with scanned PDFs), fallback to full OCR
        if len(extracted_text.strip()) < 50:
            print("[Info]: Low native text detected. Running full PDF OCR fallback...")
            extracted_text = ocr_pdf_pages(temp_file_path)

        # Cleanup temporary disk file
        if temp_file_path and os.path.exists(temp_file_path):
            os.unlink(temp_file_path)

        return jsonify({
            'success': True,
            'text_content': extracted_text
        })

    except Exception as e:
        if temp_file_path and os.path.exists(temp_file_path):
            try:
                os.unlink(temp_file_path)
            except Exception:
                pass
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'healthy', 'service': 'study-diary-pdf-extractor'})


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)