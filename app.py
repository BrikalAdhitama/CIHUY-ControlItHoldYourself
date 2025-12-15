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
try:
    from fcm import send_fcm, send_fcm_broadcast
except ImportError:
    # Fallback biar app gak crash kalau fcm.py error
    def send_fcm_broadcast(*args, **kwargs): pass
    def send_fcm(*args, **kwargs): pass

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

# ================= SYSTEM INSTRUCTION =================
SYSTEM_INSTRUCTION = (
    "Kamu adalah CiHuy, teman curhat dan pendamping untuk orang yang ingin berhenti merokok dan vape. "
    "Jawab sebagai manusia yang hangat, santai, dan empatik seperti teman dekat. "
    "Fokus utama: proses berhenti, craving, motivasi, dan manajemen stres. "
    "Berikan langkah konkret dan praktis. "
    "Jangan menghakimi. Jangan memberikan diagnosis medis berat."
)

# ================= GEMINI CONFIG =================
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
model = None

if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)
    try:
        # [REKOMENDASI TERBAIK] Pakai Flash biar cepet & support token banyak
        model = genai.GenerativeModel(
            model_name="gemini-1.5-flash", 
            system_instruction=SYSTEM_INSTRUCTION
        )
        print("[AI] Gemini-1.5-Flash Ready 🧠")
    except Exception as e:
        print(f"[AI SETUP ERROR] {e}")

# ================= HELPERS =================
def make_fallback_reply():
    return random.choice([
        "Waduh, koneksi gue agak gangguan nih. Coba tanya lagi ya.",
        "Bentar, sinyal otak gue putus nyambung. Coba ulangi pertanyaannya.",
        "Sori banget, tadi kepotong. Mau nanya apa tadi?"
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

# [BAGIAN INI YANG HILANG DI KODEMU TADI]
# Tanpa route ini, token user gak bakal masuk database!
@app.route("/register", methods=["POST"])
def register_user():
    data = request.get_json() or {}
    token = data.get("token")
    zona = data.get("zona", "WIB")

    if not token:
        return jsonify({"success": False, "message": "Token wajib ada"}), 400

    try:
        # Logic: Cek dulu, kalau ada update, kalau gak ada insert
        if supabase:
            existing = supabase.table("users").select("token").eq("token", token).execute()
            
            if existing.data:
                # Update zonanya aja
                supabase.table("users").update({"zona": zona}).eq("token", token).execute()
                print(f"[REGISTER] User Updated: {token[:10]}...")
            else:
                # Insert user baru
                supabase.table("users").insert({"token": token, "zona": zona}).execute()
                print(f"[REGISTER] New User Saved: {token[:10]}...")
             
        return jsonify({"success": True, "message": "Berhasil disimpan"})

    except Exception as e:
        print(f"[DB REGISTER ERROR] {e}")
        return jsonify({"success": False, "message": str(e)}), 500


@app.route("/chat", methods=["POST"])
def chat():
    start = time.time()
    data = request.get_json() or {}
    message = (data.get("message") or "").strip()

    if not message:
        return jsonify({"success": False, "reply": "Pesan kosong"}), 400

    prompt = f"""
Situasi: User ingin berhenti merokok.
Pesan user: {message}

Instruksi:
Jawab sebagai CiHuy (teman santai & supportif).
Berikan jawaban UTUH, JELAS, dan SOLUTIF.
JANGAN MEMOTONG KALIMAT.
"""

    reply = None
    
    if model:
        try:
            # SAFETY SETTINGS WAJIB ADA (Biar topik rokok ga diblokir)
            safe_list = [
                {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
                {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"},
                {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"},
                {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"}
            ]

            response = model.generate_content(
                prompt,
                generation_config={
                    "temperature": 0.85,
                    "max_output_tokens": 4000, 
                },
                safety_settings=safe_list
            )

            reply = extract_gemini_text(response)
            
            if not reply:
                print(f"[DEBUG AI] Response Feedback: {response.prompt_feedback}")
        
        except Exception as e:
            print(f"[AI ERROR FATAL] {e}")
            reply = None

    if not reply:
        reply = make_fallback_reply()

    elapsed = time.time() - start
    if elapsed < MIN_RESPONSE_DELAY:
        time.sleep(MIN_RESPONSE_DELAY - elapsed)

    return jsonify({"success": True, "reply": reply})

# ================= MAIN =================
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", 8080)))