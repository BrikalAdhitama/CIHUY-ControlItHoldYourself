import os
import time
import random
import atexit
import pytz 
from flask import Flask, request, jsonify
from flask_cors import CORS
from apscheduler.schedulers.background import BackgroundScheduler
from dotenv import load_dotenv

# --- IMPORT MODUL SENDIRI ---
# Pastikan file fcm.py ada di satu folder
from fcm import send_fcm, send_fcm_broadcast 

# --- IMPORT SUPABASE & GOOGLE GEMINI ---
from supabase import create_client, Client
from google import genai
from google.genai import types

load_dotenv()

# ================= CONFIG SUPABASE =================
# ⚠️ PASTE URL & KEY SUPABASE KAMU DI SINI ⚠️
SUPABASE_URL = "https://jqfqscorljutadkxwzwm.supabase.co"
SUPABASE_KEY = "sb_publishable_Y0sFgFsWECdM92wd_ChpGA_wGm3Pm2x"

# Init Supabase
try:
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    print("[DB] Supabase Connected ⚡")
except Exception as e:
    print(f"[DB ERROR] Gagal connect Supabase: {e}")
    supabase = None

# ================= CONFIG GEMINI =================
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "").strip()
MODEL_NAME = os.getenv("GEMINI_MODEL", "gemini-2.0-flash")

# ================= APP INIT =================
app = Flask(__name__)
CORS(app) 

# ================= HELPERS =================
def make_fallback_reply():
    tips = [
        "Tarik napas dulu ya. Kamu nggak sendirian.",
        "Minum air sebentar, craving itu datang dan pergi.",
        "Fokus 10 menit aja. Biasanya lewat.",
        "Kamu sudah sejauh ini, itu nggak kecil."
    ]
    return random.choice(tips)

# ================= GEMINI SETUP =================
_client = None
if GEMINI_API_KEY:
    try:
        _client = genai.Client(api_key=GEMINI_API_KEY)
        print("[AI] Gemini Ready 🧠")
    except Exception as e:
        print("[AI ERROR] GenAI init failed:", e)

SYSTEM_INSTRUCTION = (
    "Kamu adalah CiHuy, chatbot pendamping untuk orang yang ingin berhenti merokok dan vape. "
    "Gunakan bahasa santai, empatik, dan supportive. "
    "JANGAN keluar topik selain seputar rokok, vape, kesehatan."
)

# ================= 🧠 LOGIKA JADWAL & DB MANAGEMENT =================

def get_users_by_zona(zona):
    # [SUPABASE] Ambil token dari tabel 'users' berdasarkan zona
    try:
        if not supabase: return []
        
        # Ambil kolom 'token' saja biar hemat bandwidth
        response = supabase.table("users").select("token").eq("zona", zona).execute()
        
        # Hasilnya list of dict: [{'token': 'abc'}, {'token': 'xyz'}]
        tokens = [item['token'] for item in response.data]
        return list(set(tokens)) # Hapus duplikat
    except Exception as e:
        print(f"[DB ERROR] Gagal ambil user zona {zona}: {e}")
        return []

def job_kirim_per_zona(sesi, target_zona):
    print(f"\n[SCHEDULER] 🚀 Server WIB jam {time.strftime('%H:%M')} -> Mengirim ke User {target_zona} ({sesi})...")
    
    tokens = get_users_by_zona(target_zona)
    
    if not tokens:
        print(f"[SCHEDULER] User zona {target_zona} kosong atau DB Error. Skip.")
        return

    pesan_dict = {
        "pagi": "Pagi, Pejuang! Awali harimu dengan napas yang segar ya.",
        "siang": "Semangat siang! Ayo, kamu pasti bisa!",
        "malam": "Sudah malam nih. Terima kasih sudah bertahan hari ini."
    }
    body = pesan_dict.get(sesi, "Semangat Cihuy!")
    
    # Kirim Broadcast via FCM
    send_fcm_broadcast(tokens, "Hai Sobat CIHUY!", body)

# ================= SETUP SCHEDULER =================
jakarta_tz = pytz.timezone('Asia/Jakarta')
scheduler = BackgroundScheduler(timezone=jakarta_tz)

# JADWAL RUTIN (WIB Server Time)
# Pagi (Target Local 08:00)
scheduler.add_job(job_kirim_per_zona, 'cron', hour=6, minute=0, args=["pagi", "WIT"])   # 06 WIB -> 08 WIT
scheduler.add_job(job_kirim_per_zona, 'cron', hour=7, minute=0, args=["pagi", "WITA"])  # 07 WIB -> 08 WITA
scheduler.add_job(job_kirim_per_zona, 'cron', hour=8, minute=0, args=["pagi", "WIB"])   # 08 WIB -> 08 WIB

# Siang (Target Local 12:00)
scheduler.add_job(job_kirim_per_zona, 'cron', hour=10, minute=0, args=["siang", "WIT"])  # 10 WIB -> 12 WIT
scheduler.add_job(job_kirim_per_zona, 'cron', hour=11, minute=0, args=["siang", "WITA"]) # 11 WIB -> 12 WITA
scheduler.add_job(job_kirim_per_zona, 'cron', hour=12, minute=0, args=["siang", "WIB"])  # 12 WIB -> 12 WIB

# Malam (Target Local 19:00)
scheduler.add_job(job_kirim_per_zona, 'cron', hour=17, minute=0, args=["malam", "WIT"])  # 17 WIB -> 19 WIT
scheduler.add_job(job_kirim_per_zona, 'cron', hour=18, minute=0, args=["malam", "WITA"]) # 18 WIB -> 19 WITA
scheduler.add_job(job_kirim_per_zona, 'cron', hour=19, minute=0, args=["malam", "WIB"])  # 19 WIB -> 19 WIB

scheduler.start()
atexit.register(lambda: scheduler.shutdown())

# ================= ROUTES =================
@app.route("/", methods=["GET"])
def home():
    # Cek status koneksi DB
    total_users = "Offline"
    if supabase:
        try:
            res = supabase.table("users").select("*", count="exact", head=True).execute()
            total_users = res.count
        except:
            total_users = "Error DB"

    return jsonify({
        "status": "Cihuy Backend Online 🚀",
        "database": "Supabase Connected ✅" if supabase else "Offline ❌",
        "users_connected": total_users
    }), 200

# INI DIA ENDPOINT UTAMA BUAT NANGKEP TOKEN
@app.route("/save-token", methods=["POST"])
def save_token():
    data = request.json
    token = data.get('token')
    zona = data.get('zona', 'WIB') 

    if not token:
        return jsonify({"error": "Token wajib ada!"}), 400

    # Simpan ke Supabase (Upsert)
    try:
        user_data = {"token": token, "zona": zona}
        # Upsert: Token baru -> Insert. Token lama -> Update zonanya.
        supabase.table("users").upsert(user_data).execute()
        
        print(f"[INFO] User Saved: {zona} | Token: {token[:10]}...")
        return jsonify({"message": "Token berhasil disimpan ke Cloud!"}), 200
        
    except Exception as e:
        print(f"[DB ERROR] Gagal save token: {e}")
        return jsonify({"error": str(e)}), 500

# Endpoint Tes Manual (Buat ngetes notif masuk atau nggak)
@app.route("/send-notification", methods=["POST"])
def trigger_notification():
    data = request.json
    token = data.get('token')
    title = data.get('title', 'Ingat Cihuy!')
    body = data.get('body', 'Waktunya cek progress kamu.')
    
    if not token: return jsonify({"error": "Token wajib ada!"}), 400
    
    success, result = send_fcm(token, title, body)
    return (jsonify({"message": "Terkirim!", "id": result}), 200) if success else (jsonify({"error": "Gagal", "detail": result}), 500)

# Endpoint Chat AI
@app.route("/chat", methods=["POST"])
def chat():
    if not _client: return jsonify({"success": False, "reply": "AI belum siap."}), 500
    data = request.get_json() or {}
    message = (data.get("message") or "").strip()
    if not message: return jsonify({"success": False, "reply": "Pesan kosong."}), 400
    contents = [types.Content(role="user", parts=[types.Part.from_text(text=message)])]
    try:
        response = _client.models.generate_content(
            model=MODEL_NAME, contents=contents,
            config=types.GenerateContentConfig(system_instruction=SYSTEM_INSTRUCTION, temperature=0.7)
        )
        reply = response.text if response.text else make_fallback_reply()
    except Exception as e:
        print(f"Gemini Error: {e}")
        reply = make_fallback_reply()
    return jsonify({"success": True, "reply": reply}), 200

if __name__ == "__main__":
    print("Cihuy backend module loaded (Gunicorn mode)")