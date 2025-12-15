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


# ================= KONSTANTA =================
MAX_RESPONSE_TIME = 30   # batas logging (detik)
MIN_RESPONSE_DELAY = 2   # delay biar human-like


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


# ================= SYSTEM INSTRUCTION (SATU-SATUNYA) =================
SYSTEM_INSTRUCTION = """
Kamu adalah CiHuy, teman curhat untuk orang yang sedang atau ingin berhenti merokok dan vape.

Gaya bicara:
- Jawab seperti manusia, bukan bot
- Bahasa santai, empatik, hangat
- Jangan pakai jawaban template
- Jangan jawab satu kalimat pendek

Aturan:
- Kalau user bercanda atau ngawur, tanggapi santai
- Kalau user serius, tanggapi empatik
- Jangan menghakimi
- Beri penjelasan + langkah konkret

Fokus topik:
- Berhenti merokok/vape
- Craving, gejala awal, emosi naik turun
- Motivasi & coping
- Edukasi ringan kesehatan

Larangan:
- Jangan diagnosis medis
- Jangan keluar topik
"""


# ================= CONFIG GEMINI =================
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
model = None

if GEMINI_API_KEY:
    try:
        genai.configure(api_key=GEMINI_API_KEY)
        model = genai.GenerativeModel("gemini-2.5-flash")
        print("[AI] Gemini Ready 🧠")
    except Exception as e:
        print("[AI ERROR]", e)
else:
    print("[AI] GEMINI_API_KEY not found ❌")


# ================= HELPERS =================
def make_fallback_reply():
    return random.choice([
        "Gue masih di sini kok. Coba ceritain pelan-pelan lagi.",
        "Sebentar ya, gue nangkep dulu ceritamu.",
        "Kayaknya koneksi gue sempat kejedot 😅. Ulangi dikit ya."
    ])


def extract_gemini_text(response):
    try:
        if hasattr(response, "text") and response.text:
            return response.text.strip()

        if hasattr(response, "candidates"):
            for cand in response.candidates:
                if hasattr(cand, "content"):
                    for part in cand.content.parts:
                        if hasattr(part, "text") and part.text:
                            return part.text.strip()
    except Exception as e:
        print("[AI PARSE ERROR]", e)

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
        tokens = [item["token"] for item in res.data]
        return list(set(tokens))
    except Exception as e:
        print("[DB ERROR] get_users_by_zona:", e)
        return []


# ================= SCHEDULER JOB =================
def job_kirim_per_zona(sesi: str, zona: str):
    print(f"[SCHEDULER] {time.strftime('%H:%M')} | {sesi.upper()} → {zona}")

    tokens = get_users_by_zona(zona)
    if not tokens:
        print("[SCHEDULER] Token kosong, skip")
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

# PAGI (08 lokal)
scheduler.add_job(job_kirim_per_zona, "cron", hour=8, minute=0, args=["pagi", "WIB"])
scheduler.add_job(job_kirim_per_zona, "cron", hour=7, minute=0, args=["pagi", "WITA"])
scheduler.add_job(job_kirim_per_zona, "cron", hour=6, minute=0, args=["pagi", "WIT"])

# SIANG (12 lokal)
scheduler.add_job(job_kirim_per_zona, "cron", hour=12, minute=0, args=["siang", "WIB"])
scheduler.add_job(job_kirim_per_zona, "cron", hour=11, minute=0, args=["siang", "WITA"])
scheduler.add_job(job_kirim_per_zona, "cron", hour=10, minute=0, args=["siang", "WIT"])

# MALAM (19 lokal)
scheduler.add_job(job_kirim_per_zona, "cron", hour=19, minute=0, args=["malam", "WIB"])
scheduler.add_job(job_kirim_per_zona, "cron", hour=18, minute=0, args=["malam", "WITA"])
scheduler.add_job(job_kirim_per_zona, "cron", hour=17, minute=0, args=["malam", "WIT"])

scheduler.start()
atexit.register(lambda: scheduler.shutdown())


# ================= ROUTES =================
@app.route("/", methods=["GET"])
def home():
    return jsonify({"status": "Cihuy Backend Online 🚀"})


@app.route("/save-token", methods=["POST"])
def save_token():
    if not supabase:
        return jsonify({"error": "DB offline"}), 500

    data = request.get_json() or {}
    token = data.get("token")
    zona = data.get("zona", "WIB")

    if not token:
        return jsonify({"error": "Token wajib ada"}), 400

    supabase.table("users").upsert({
        "token": token,
        "zona": zona
    }).execute()

    return jsonify({"message": "Token tersimpan"}), 200


@app.route("/chat", methods=["POST"])
def chat():
    if not model:
        return jsonify({"success": False, "reply": "AI belum siap"}), 500

    start_time = time.time()

    data = request.get_json() or {}
    message = (data.get("message") or "").strip()

    if not message:
        return jsonify({"success": False, "reply": "Pesan kosong"}), 400

    if len(message) < 3:
        return jsonify({
            "success": True,
            "reply": "Hehe gue denger kok 😄 Mau cerita apa hari ini?"
        })

    prompt = f"""
{SYSTEM_INSTRUCTION}

Pesan user:
{message}

Jawaban CiHuy:
"""

    try:
        response = model.generate_content(
            prompt,
            generation_config={
                "temperature": 0.8,
                "max_output_tokens": 600
            }
        )

        reply = extract_gemini_text(response)
        if not reply:
            reply = make_fallback_reply()

        elapsed = time.time() - start_time

        # delay minimal biar human-like
        if elapsed < MIN_RESPONSE_DELAY:
            time.sleep(MIN_RESPONSE_DELAY - elapsed)

        # logging jika terlalu lama
        if elapsed > MAX_RESPONSE_TIME:
            print(f"[AI WARNING] Response time {elapsed:.2f}s exceeded limit")

    except Exception as e:
        print("[AI ERROR]", e)
        reply = make_fallback_reply()

    return jsonify({
        "success": True,
        "reply": reply
    })


# ================= MAIN =================
if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=int(os.getenv("PORT", 8080)),
        debug=False
    )
