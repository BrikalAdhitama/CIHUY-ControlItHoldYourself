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
from fcm import send_fcm_broadcast
from supabase import create_client, Client

# ================= GEMINI SDK =================
import google.generativeai as genai

# ================= KONSTANTA =================
MIN_RESPONSE_DELAY = 2

# ================= APP INIT =================
app = Flask(__name__)
CORS(app)

# ================= SUPABASE =================
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

supabase: Client | None = None
if SUPABASE_URL and SUPABASE_KEY:
    try:
        supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
        print("[DB] Supabase Connected ⚡")
    except Exception as e:
        print("[DB ERROR]", e)

# ================= GEMINI CONFIG =================
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
model = None

if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)
    try:
        model = genai.GenerativeModel("gemini-1.5-flash")
        print("[AI] Gemini-1.5-Flash Ready 🧠")
    except Exception as e:
        print("[AI SETUP ERROR]", e)

# ================= HELPERS =================
def make_fallback_reply():
    return random.choice([
        "Bentar ya, gue nangkepin dulu ceritamu.",
        "Kayaknya tadi kepotong. Coba ceritain lagi dikit.",
        "Gue masih di sini kok, lanjut aja ceritanya."
    ])

def extract_gemini_text(response):
    try:
        if hasattr(response, "text") and response.text:
            return response.text.strip()
        if hasattr(response, "candidates"):
            for c in response.candidates:
                for p in c.content.parts:
                    if hasattr(p, "text"):
                        return p.text.strip()
    except:
        pass
    return None

# ================= DB HELPERS =================
def get_users_by_zona(zona: str):
    if not supabase:
        return []
    try:
        res = supabase.table("users").select("token").eq("zona", zona).execute()
        return list({r["token"] for r in res.data})
    except:
        return []

# ================= SCHEDULER JOB =================
def job_kirim_per_zona(sesi: str, zona: str):
    tokens = get_users_by_zona(zona)
    if not tokens:
        return

    pesan = {
        "pagi": "Pagi! Tarik napas dulu. Hari baru 🌱",
        "siang": "Masih bertahan? Itu keren 💪",
        "malam": "Hari ini berat? Makasih udah bertahan 🤍"
    }

    send_fcm_broadcast(tokens, "CIHUY", pesan.get(sesi, "Semangat ya"))

# ================= SCHEDULER =================
jakarta_tz = pytz.timezone("Asia/Jakarta")
scheduler = BackgroundScheduler(timezone=jakarta_tz)

scheduler.add_job(job_kirim_per_zona, "cron", hour=8, args=["pagi", "WIB"])
scheduler.add_job(job_kirim_per_zona, "cron", hour=7, args=["pagi", "WITA"])
scheduler.add_job(job_kirim_per_zona, "cron", hour=6, args=["pagi", "WIT"])

scheduler.add_job(job_kirim_per_zona, "cron", hour=12, args=["siang", "WIB"])
scheduler.add_job(job_kirim_per_zona, "cron", hour=11, args=["siang", "WITA"])
scheduler.add_job(job_kirim_per_zona, "cron", hour=10, args=["siang", "WIT"])

scheduler.add_job(job_kirim_per_zona, "cron", hour=19, args=["malam", "WIB"])
scheduler.add_job(job_kirim_per_zona, "cron", hour=18, args=["malam", "WITA"])
scheduler.add_job(job_kirim_per_zona, "cron", hour=17, args=["malam", "WIT"])

scheduler.start()
atexit.register(lambda: scheduler.shutdown())

# ================= ROUTES =================
@app.route("/chat", methods=["POST"])
def chat():
    start = time.time()
    data = request.get_json() or {}
    message = (data.get("message") or "").strip()

    if not message:
        return jsonify({"success": False, "reply": "Pesan kosong"}), 400

    prompt = f"""
Kamu adalah CiHuy, teman curhat dan pendamping untuk orang yang ingin berhenti merokok dan vape.

Gaya bicara:
- Seperti manusia, hangat, santai, empatik
- Jangan jawab singkat
- Jangan template
- Jangan menggurui

Aturan penting:
- Jawaban minimal 3 paragraf
- Setiap paragraf 2–3 kalimat
- Langsung kasih langkah konkret
- Jangan memotong jawaban
- Jangan tanya balik kecuali perlu

Pesan user:
{message}

Jawaban CiHuy:
"""

    reply = None

    if model:
        try:
            response = model.generate_content(
                prompt,
                generation_config={
                    "temperature": 0.85,
                    "max_output_tokens": 3000,
                }
            )
            reply = extract_gemini_text(response)
        except Exception as e:
            print("[AI ERROR]", e)

    if not reply:
        reply = make_fallback_reply()

    elapsed = time.time() - start
    if elapsed < MIN_RESPONSE_DELAY:
        time.sleep(MIN_RESPONSE_DELAY - elapsed)

    return jsonify({"success": True, "reply": reply})

# ================= MAIN =================
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", 8080)))
