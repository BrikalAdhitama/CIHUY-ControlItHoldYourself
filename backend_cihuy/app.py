import os
from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
import traceback

from google import genai  # <-- SDK BARU (google-genai)

load_dotenv()
app = Flask(__name__)
CORS(app)

# ===================== CONFIG =====================

API_KEY = os.getenv("GEMINI_API_KEY")
MODEL_NAME = "gemini-2.5-pro"  # bisa diganti "gemini-2.5-flash" kalau mau lebih murah

if not API_KEY:
    print("[ERROR] GEMINI_API_KEY tidak ditemukan di .env")
    # jangan exit, biar kelihatan errornya di route
else:
    print("[INFO] API key terbaca")

client = genai.Client(api_key=API_KEY)

SYSTEM_INSTRUCTION = (
    "Kamu adalah CiHuy, chatbot pendamping untuk orang yang ingin berhenti merokok dan vape. "
    "Gunakan bahasa santai, empatik, dan supportive seperti teman dekat. "
    "Jawaban tidak harus pendek, bisa panjang jika diperlukan, tetapi tetap jelas dan tidak bertele-tele. "
    "Fokus percakapan pada: kesehatan, coping craving, alasan berhenti, motivasi, kebiasaan pengganti, manajemen stres, dan edukasi tentang dampak rokok/vape. "
    "Berikan langkah konkret, bukan hanya teori umum. "
    "Boleh bercerita, jelasin konsep, kasih strategi bertahap, atau validasi emosi pengguna. "
    "JANGAN keluar topik selain seputar rokok, vape, kesehatan, dan proses berhenti kecanduan. "
    "Jika user keluar topik, alihkan balik dengan halus. "
    "Tidak memberikan diagnosis medis atau saran medis hardcore; arahkan ke tenaga profesional jika topik sudah serius."
)

# ===================== ROUTES =====================

@app.route("/", methods=["GET"])
def home():
    return "Server AI CIHUY! Siap Melayani (SDK baru).", 200


@app.route("/chat", methods=["POST"])
def chat():
    if not API_KEY:
        return jsonify({"success": False, "error": "GEMINI_API_KEY kosong"}), 500

    try:
        data = request.get_json() or {}
        user_msg = (data.get("message") or "").strip()
        history = data.get("history", [])

        if not user_msg:
            return jsonify({"success": False, "reply": "Pesan kosong."}), 400

        contents = []

        # Tambah system instruction di awal
        contents.append(SYSTEM_INSTRUCTION)

        # Tambah history (kalau dikirim dari Flutter)
        if isinstance(history, list):
            for item in history:
                sender = item.get("sender", "user")
                text = (item.get("text") or "").strip()
                if not text:
                    continue

                role = "model" if sender == "bot" else "user"
                contents.append({
                    "role": role,
                    "parts": [{"text": text}]
                })

        # Tambah pesan user sekarang
        contents.append({
            "role": "user",
            "parts": [{"text": user_msg}]
        })

        # Panggil Gemini 2.5
        response = client.models.generate_content(
            model=MODEL_NAME,
            contents=contents,
        )

        reply_text = (response.text or "").strip() if hasattr(response, "text") else ""

        if not reply_text:
            reply_text = "CIHuy lagi bingung jawab, coba tanya dengan cara lain ya 🙂"

        return jsonify({"success": True, "reply": reply_text}), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"success": False, "error": str(e)}), 500


if __name__ == "__main__":
    print("[SERVER] CIHUY AI (google-genai) berjalan di port 5000...")
    app.run(debug=True, host="0.0.0.0", port=5000)
