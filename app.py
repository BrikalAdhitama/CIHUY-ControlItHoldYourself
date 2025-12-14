import os
import time
import random
import atexit
import pytz

from flask import Flask, request, jsonify
from flask_cors import CORS
from apscheduler.schedulers.background import BackgroundScheduler
from dotenv import load_dotenv

# ================= LOAD ENV =================
load_dotenv()

# ================= IMPORT MODUL SENDIRI =================
from fcm import send_fcm, send_fcm_broadcast

# ================= SUPABASE =================
from supabase import create_client, Client

# ================= GEMINI SDK =================
import google.generativeai as genai


# ================= APP INIT =================
app = Flask(__name__)
CORS(app)


# ================= CONFIG SUPABASE =================
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

supabase: Client | None = None
try:
    if SUPABASE_URL and SUPABASE_KEY:
        supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
        print("[DB] Supabase Connected ⚡")
    else:
        print("[DB] Supabase ENV missing ❌")
except Exception as e:
    print("[DB ERROR]", e)
    supabase = None


# ================= SYSTEM INSTRUCTION =================
SYSTEM_INSTRUCTION = (
    "Kamu adalah CiHuy, chatbot pendamping untuk orang yang ingin berhenti merokok dan vape. "
    "Gunakan bahasa santai, empatik, dan supportive seperti teman dekat. "
    "Jawaban boleh panjang jika diperlukan, jangan satu kalimat pendek. "
    "Jika user menyebut gejala (batuk, pusing, gelisah), jelaskan apakah normal dan apa yang bisa dilakukan. "
    "Berikan langkah konkret dan reassurance. "
    "Fokus hanya pada rokok, vape, kesehatan, dan proses berhenti kecanduan."
)

# ================= CONFIG GEMINI =================
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
model = None

if GEMINI_API_KEY:
    try:
        genai.configure(api_key=GEMINI_API_KEY)
        model = genai.GenerativeModel(
            model_name="gemini-1.5-flash",
            system_instruction=SYSTEM_INSTRUCTION
        )
        print("[AI] Gemini Ready 🧠")
    except Exception as e:
        print("[AI ERROR]", e)
else:
    print("[AI] GEMINI_API_KEY not found ❌")


# ================= HELPERS =================
def make_fallback_reply():
    return random.choice([
        "Tarik napas dulu ya. Kamu nggak sendirian.",
        "Kalau lagi berat, coba jeda 10 menit. Biasanya dorongan itu turun.",
        "Minum air dan gerak dikit bisa bantu banget.",
        "Kamu sudah berani berhenti — itu langkah besar."
    ])


def extract_gemini_text(response):
    """
    FIX UTAMA:
    Ambil text dari Gemini SDK dengan aman
    """
    # Cara 1 (kalau tersedia)
    if hasattr(response, "text") and response.text:
        return response.text.strip()

    # Cara 2 (SDK resmi – paling sering dipakai)
    if hasattr(response, "candidates") and response.candidates:
        try:
            return response.candidates[0].content.parts[0].text.strip()
        except Exception:
            return None

    return None


# ================= DB HELPERS =================
def get_users_by_zona(zona: str):
    if not supabase:
        return []

    try:
        res = (
            supabase
            .table("users")
            .select("token")
            .eq("zona", zona)
            .execute()
        )
        return list({item["token"] for item in res.data})
    except Exception as e:
        print("[DB ERROR] get_users_by_zona:", e)
        return []


# ================= SCHEDULER JOB =================
def job_kirim_per_zona(sesi: str, zona: str):
    tokens = get_users_by_zona(zona)
    if not tokens:
        return

    pesan = {
        "pagi": "Pagi, Pejuang! Awali harimu dengan napas yang segar 🌱",
        "siang": "Masih bertahan? Kamu keren banget 💪",
        "malam": "Hari ini berat? Terima kasih sudah bertahan 🤍"
    }

    send_fcm_broadcast(
        tokens,
        "Hai Sobat CIHUY!",
        pesan.get(sesi, "Semangat Cihuy!")
    )


# ================= SCHEDULER =================
jakarta_tz = pytz.timezone("Asia/Jakarta")
scheduler = BackgroundScheduler(timezone=jakarta_tz)

scheduler.add_job(job_kirim_per_zona, "cron", hour=6, minute=0, args=["pagi", "WIB"])
scheduler.add_job(job_kirim_per_zona, "cron", hour=12, minute=0, args=["siang", "WIB"])
scheduler.add_job(job_kirim_per_zona, "cron", hour=19, minute=0, args=["malam", "WIB"])

scheduler.start()
atexit.register(lambda: scheduler.shutdown())


# ================= ROUTES =================
@app.route("/", methods=["GET"])
def home():
    return jsonify({
        "status": "Cihuy Backend Online 🚀"
    })


@app.route("/chat", methods=["POST"])
def chat():
    if not model:
        return jsonify({"success": False, "reply": "AI belum siap"}), 500

    data = request.get_json() or {}
    message = (data.get("message") or "").strip()

    if not message:
        return jsonify({"success": False, "reply": "Pesan kosong"}), 400

    try:
        prompt = f"""
User sedang berhenti merokok dan curhat ke CiHuy.

ATURAN:
- Jawab empatik
- Jelaskan dengan bahasa manusia
- Jangan jawab singkat
- Beri reassurance + langkah konkret

Pesan user:
{message}

Jawaban CiHuy:
"""

        response = model.generate_content(
            prompt,
            generation_config={
                "temperature": 0.75,
                "max_output_tokens": 400
            }
        )

        reply = extract_gemini_text(response)

        if not reply:
            reply = make_fallback_reply()

    except Exception as e:
        print("[AI ERROR]", e)
        reply = make_fallback_reply()

    return jsonify({"success": True, "reply": reply})


# ================= MAIN =================
if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=int(os.getenv("PORT", 8080)),
        debug=False
    )