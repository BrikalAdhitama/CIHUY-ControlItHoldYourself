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
# Pastikan file fcm.py ada di folder yang sama
from fcm import send_fcm, send_fcm_broadcast

# ================= SUPABASE =================
from supabase import create_client, Client

# ================= GEMINI SDK =================
import google.generativeai as genai

# ================= KONSTANTA =================
MIN_RESPONSE_DELAY = 2
MAX_RESPONSE_TIME = 30

# ================= APP INIT =================
app = Flask(__name__)
CORS(app)

# ================= SUPABASE =================
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

supabase: Client | None = None
try:
    if SUPABASE_URL and SUPABASE_KEY:
        supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
        print("[DB] Supabase Connected ⚡")
except Exception as e:
    print("[DB ERROR]", e)
    supabase = None

# ================= SYSTEM INSTRUCTION (FINAL) =================
SYSTEM_INSTRUCTION = (
    "Kamu adalah CiHuy, teman curhat dan pendamping untuk orang yang ingin berhenti merokok dan vape. "
    "Jawab sebagai manusia yang hangat, santai, dan empatik seperti teman dekat, bukan seperti bot atau konselor formal. "

    "Jawaban boleh panjang jika memang dibutuhkan, tapi harus jelas, relevan, dan tidak bertele-tele. "
    "Hindari basa-basi yang tidak perlu, pujian berlebihan, atau kalimat pembuka yang diulang-ulang. "

    "Fokus utama percakapan adalah: proses berhenti merokok/vape, craving, gejala awal berhenti, emosi yang naik turun, "
    "motivasi, kebiasaan pengganti, manajemen stres, serta edukasi ringan tentang dampak rokok dan vape. "

    "Selalu berikan langkah konkret dan praktis yang bisa langsung dicoba, bukan hanya teori umum. "
    "Jika user bertanya 'ada saran' atau mengulang pertanyaan, langsung jawab inti tanpa mengulang empati yang sama. "

    "Boleh memvalidasi emosi pengguna, tapi cukup singkat dan jangan berulang. "
    "Jika user bercanda atau jawab singkat, tanggapi santai tanpa menggurui. "
    "Jika user serius atau sedang struggle, tanggapi dengan empati yang tenang dan solutif. "

    "Jangan menghakimi, jangan menyalahkan, dan jangan membuat pengguna merasa gagal. "
    "Jangan memberikan diagnosis medis atau saran medis berat; jika topik sudah serius, arahkan secara halus ke tenaga profesional. "

    "Jika percakapan mulai keluar topik, arahkan kembali secara natural ke proses berhenti merokok atau kesehatan."
)

# ================= GEMINI CONFIG =================
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
model = None

if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)
    # [FIX 1] Gunakan model yang stabil (1.5-flash) agar output konsisten
    model = genai.GenerativeModel(
        model_name="gemini-1.5-flash",
        system_instruction=SYSTEM_INSTRUCTION
    )
    print("[AI] Gemini Ready 🧠")

# ================= HELPERS =================
def make_fallback_reply():
    return random.choice([
        "Gue masih di sini. Coba ceritain lagi dikit, gue dengerin.",
        "Sebentar ya, kayaknya tadi kepotong. Lanjutin aja.",
        "Santai, gue nangkep kok. Ulangin pelan-pelan."
    ])

def extract_gemini_text(response):
    try:
        if hasattr(response, "text") and response.text:
            return response.text.strip()

        if hasattr(response, "candidates"):
            for cand in response.candidates:
                for part in cand.content.parts:
                    if hasattr(part, "text") and part.text:
                        return part.text.strip()
    except:
        pass
    return None

# ================= DB HELPERS =================
def get_users_by_zona(zona: str):
    if not supabase:
        return []
    try:
        res = supabase.table("users").select("token").eq("zona", zona).execute()
        return list({row["token"] for row in res.data})
    except Exception as e:
        print(f"[DB ERROR get_users] {e}")
        return []

# ================= SCHEDULER JOB =================
def job_kirim_per_zona(sesi: str, zona: str):
    tokens = get_users_by_zona(zona)
    if not tokens:
        return

    pesan = {
        "pagi": "Pagi! Tarik napas dulu. Hari baru, kesempatan baru 🌱",
        "siang": "Masih bertahan? Itu keren banget 💪",
        "malam": "Hari ini berat? Terima kasih udah bertahan 🤍"
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

    if len(message) < 3:
        return jsonify({
            "success": True,
            "reply": "Hehe, gue denger kok 😄 Mau lanjut cerita apa?"
        })

    # [FIX 2] Tambahkan instruksi agar jawaban lengkap
    prompt = f"""
Situasi:
User sedang berjuang berhenti merokok/vape.

Aturan:
- Jangan muter empati
- Jangan tanya balik kalau user minta saran
- Langsung kasih solusi praktis
- Jawab santai & manusiawi
- PASTIKAN JAWABANMU LENGKAP DAN TIDAK TERPOTONG.

Pesan user:
{message}

Jawaban CiHuy:
"""

    try:
        response = model.generate_content(
            prompt,
            generation_config={
                "temperature": 0.85,
                # [FIX 3] NAIKKAN TOKEN OUTPUT BIAR GAK KEPOTONG
                "max_output_tokens": 4000 
            }
        )

        reply = extract_gemini_text(response)
        if not reply:
            reply = make_fallback_reply()

    except Exception as e:
        print("[AI ERROR]", e)
        reply = make_fallback_reply()

    elapsed = time.time() - start
    if elapsed < MIN_RESPONSE_DELAY:
        time.sleep(MIN_RESPONSE_DELAY - elapsed)

    return jsonify({"success": True, "reply": reply})

# ================= MAIN =================
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", 8080)))