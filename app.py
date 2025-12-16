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

# ================= IMPORT MODUL FUNGSI NOTIFIKASI =================
# Pastikan file fcm.py ada di folder yang sama dengan app.py
try:
    from fcm import send_fcm, send_fcm_broadcast
except ImportError:
    # Fallback biar app gak crash kalau fcm.py belum ada/error
    print("[WARNING] fcm.py tidak ditemukan. Fitur notif mungkin tidak jalan.")
    def send_fcm_broadcast(*args, **kwargs): pass
    def send_fcm(*args, **kwargs): pass

# ================= SUPABASE =================
from supabase import create_client, Client

# ================= GEMINI SDK =================
import google.generativeai as genai

# ================= KONSTANTA =================
MIN_RESPONSE_DELAY = 2  # Biar kesannya mikir dulu (manusiawi)
MAX_RESPONSE_TIME = 30

# ================= APP INIT =================
app = Flask(__name__)
CORS(app)

# ================= KONEKSI DATABASE (SUPABASE) =================
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

supabase: Client | None = None
try:
    if SUPABASE_URL and SUPABASE_KEY:
        supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
        print("[DB] Supabase Connected ⚡")
    else:
        print("[DB WARNING] URL atau KEY Supabase belum diset di .env")
except Exception as e:
    print(f"[DB ERROR] Gagal connect Supabase: {e}")
    supabase = None

# ================= KONFIGURASI AI (GEMINI) =================
SYSTEM_INSTRUCTION = (
    "Kamu adalah Cia, teman curhat dan pendamping untuk orang yang ingin berhenti merokok dan vape. "
    "Jawab sebagai manusia yang hangat, santai, dan empatik seperti teman dekat (gunakan bahasa aku/kamu yang akrab). "
    "Fokus utama: proses berhenti, craving, motivasi, dan manajemen stres. "
    "\n\n"
    "ATURAN PENTING: "
    "1. Jika pengguna bertanya tentang **bahaya/risiko/dampak** rokok atau vape, KAMU WAJIB MENJAWAB PERTANYAAN ITU DULU. Jelaskan fakta bahaya kesehatannya secara konkret tapi dengan bahasa yang mudah dimengerti (jangan terlalu medis kaku). "
    "2. Setelah menjelaskan bahayanya, barulah kamu arahkan pembicaraan untuk mengajak mereka berhenti atau menawarkan strategi berhenti. "
    "3. Berikan langkah konkret dan praktis. "
    "4. Jangan menghakimi. Jangan memberikan diagnosis medis berat selayaknya dokter, tapi berikan fakta umum."
)

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
model = None

if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)
    try:
        # Menggunakan model Flash agar respons cepat dan token output panjang
        model = genai.GenerativeModel(
            model_name="gemini-2.5-flash", 
            system_instruction=SYSTEM_INSTRUCTION
        )
        print("[AI] Gemini-2.5-Flash Ready 🧠")
    except Exception as e:
        print(f"[AI SETUP ERROR] {e}")
else:
    print("[AI WARNING] GEMINI_API_KEY belum diset.")

# ================= HELPERS (Fungsi Bantuan) =================
def make_fallback_reply():
    """Jawaban cadangan kalau AI error/timeout"""
    return random.choice([
        "Waduh, koneksi gue agak gangguan nih. Coba tanya lagi ya.",
        "Bentar, sinyal otak gue putus nyambung. Coba ulangi pertanyaannya.",
        "Sori banget, tadi kepotong. Mau nanya apa tadi?"
    ])

def extract_gemini_text(response):
    """Mengambil teks bersih dari respon Gemini"""
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
    """Mengambil semua token user berdasarkan zona waktu (WIB/WITA/WIT)"""
    if not supabase:
        return []
    try:
        # Select token where zona = zona
        res = supabase.table("users").select("token").eq("zona", zona).execute()
        # Pakai set() biar token unik (tidak double kirim ke orang yang sama)
        return list({row["token"] for row in res.data})
    except Exception as e:
        print(f"[DB ERROR get_users] {e}")
        return []

# ================= SCHEDULER JOB (Tugas Otomatis) =================
def job_kirim_per_zona(sesi: str, zona: str):
    """Fungsi yang dipanggil Scheduler untuk kirim notifikasi massal"""
    print(f"[JOB START] Mengirim pesan {sesi} untuk zona {zona}...")
    tokens = get_users_by_zona(zona)
    
    if not tokens:
        print(f"[JOB INFO] Tidak ada user di zona {zona}.")
        return

    # Kata-kata semangat random biar ga bosen
    pesan_dict = {
        "pagi": [
            "Pagi! Tarik napas dulu. Hari baru, kesempatan baru 🌱",
            "Selamat pagi! Ingat targetmu hari ini ya, kamu pasti bisa! ☀️",
            "Awali hari tanpa asap, rasakan segarnya paru-parumu! 🍃"
        ],
        "siang": [
            "Masih bertahan? Itu keren banget 💪",
            "Siang! Kalau craving datang, coba minum air putih dingin 💧",
            "Tetap semangat! Setengah hari sudah terlewati dengan hebat 🔥"
        ],
        "malam": [
            "Hari ini berat? Terima kasih udah bertahan 🤍",
            "Selamat istirahat. Bangga banget kamu bisa lewati hari ini 🌙",
            "Tutup hari ini dengan senyuman. Besok kita berjuang lagi! 🛌"
        ]
    }
    
    # Pilih satu pesan random
    pesan_isi = random.choice(pesan_dict.get(sesi, ["Tetap semangat!"]))
    
    # Panggil fungsi dari fcm.py
    send_fcm_broadcast(tokens, "CiHuy Sapa Kamu 👋", pesan_isi)
    print(f"[JOB DONE] Terkirim ke {len(tokens)} device.")

# ================= CONFIG SCHEDULER =================
# Mengatur jadwal kirim sesuai jam Jakarta
jakarta_tz = pytz.timezone("Asia/Jakarta")
scheduler = BackgroundScheduler(timezone=jakarta_tz)

# --- PAGI (Jam 08:00 waktu setempat) ---
scheduler.add_job(job_kirim_per_zona, "cron", hour=8, args=["pagi", "WIB"])   # 08.00 WIB
scheduler.add_job(job_kirim_per_zona, "cron", hour=7, args=["pagi", "WITA"])  # 08.00 WITA (07.00 WIB)
scheduler.add_job(job_kirim_per_zona, "cron", hour=6, args=["pagi", "WIT"])   # 08.00 WIT  (06.00 WIB)

# --- SIANG (Jam 12:00 waktu setempat) ---
scheduler.add_job(job_kirim_per_zona, "cron", hour=12, args=["siang", "WIB"])
scheduler.add_job(job_kirim_per_zona, "cron", hour=11, args=["siang", "WITA"])
scheduler.add_job(job_kirim_per_zona, "cron", hour=10, args=["siang", "WIT"])

# --- MALAM (Jam 19:00 waktu setempat) ---
scheduler.add_job(job_kirim_per_zona, "cron", hour=19, args=["malam", "WIB"])
scheduler.add_job(job_kirim_per_zona, "cron", hour=18, args=["malam", "WITA"])
scheduler.add_job(job_kirim_per_zona, "cron", hour=17, args=["malam", "WIT"])

# Jalankan Scheduler
scheduler.start()
atexit.register(lambda: scheduler.shutdown())

# ================= ROUTES (API ENDPOINTS) =================

# 1. HOME ROUTE (Pintu Depan) - Biar gak Not Found di browser
@app.route("/", methods=["GET"])
def home():
    return """
    <div style="text-align: center; padding-top: 50px; font-family: sans-serif;">
        <h1>🚀 Server CiHuy is Running!</h1>
        <p>Backend API siap melayani Aplikasi Flutter.</p>
        <p>Status: <strong>Active</strong></p>
    </div>
    """

# 2. REGISTER USER (Pintu Samping) - Buat nyatet Token HP & Zona Waktu
@app.route("/register", methods=["POST"])
def register_user():
    data = request.get_json() or {}
    token = data.get("token")
    zona = data.get("zona", "WIB") # Default WIB kalau null

    if not token:
        return jsonify({"success": False, "message": "Token wajib ada"}), 400

    try:
        if supabase:
            # Cek apakah token ini sudah pernah daftar?
            existing = supabase.table("users").select("token").eq("token", token).execute()
            
            if existing.data:
                # Kalau sudah ada, UPDATE zonanya (siapa tau pindah kota)
                supabase.table("users").update({"zona": zona}).eq("token", token).execute()
                print(f"[REGISTER] User Updated: {token[:15]}... ({zona})")
            else:
                # Kalau belum ada, INSERT baru
                supabase.table("users").insert({"token": token, "zona": zona}).execute()
                print(f"[REGISTER] New User Saved: {token[:15]}... ({zona})")
             
        return jsonify({"success": True, "message": "Data berhasil disimpan"})

    except Exception as e:
        print(f"[DB REGISTER ERROR] {e}")
        return jsonify({"success": False, "message": str(e)}), 500


# 3. CHAT ROUTE (Pintu Belakang) - Otak AI Gemini
@app.route("/chat", methods=["POST"])
def chat():
    start = time.time()
    data = request.get_json() or {}
    message = (data.get("message") or "").strip()

    # Validasi input kosong
    if not message:
        return jsonify({"success": False, "reply": "Pesan kosong, ngomong apa nih?"}), 400

    # Prompt Engineering
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
            # SAFETY SETTINGS: BLOCK_NONE (Wajib biar topik rokok/kesehatan mental gak diblokir)
            safe_list = [
                {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
                {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"},
                {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"},
                {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"}
            ]

            # Generate jawaban
            response = model.generate_content(
                prompt,
                generation_config={
                    "temperature": 0.85,    # Kreatifitas sedang
                    "max_output_tokens": 4000, # Cukup panjang buat tips
                },
                safety_settings=safe_list
            )

            reply = extract_gemini_text(response)
            
            # Debugging kalau AI nolak jawab
            if not reply:
                print(f"[DEBUG AI] Empty Response. Feedback: {response.prompt_feedback}")
        
        except Exception as e:
            print(f"[AI ERROR FATAL] {e}")
            reply = None

    # Fallback kalau AI mati/error
    if not reply:
        reply = make_fallback_reply()

    # Simulasi delay manusia (biar gak terlalu robot)
    elapsed = time.time() - start
    if elapsed < MIN_RESPONSE_DELAY:
        time.sleep(MIN_RESPONSE_DELAY - elapsed)

    return jsonify({"success": True, "reply": reply})

# ================= RUN APP =================
if __name__ == "__main__":
    # Mengambil PORT dari environment (Wajib buat Railway)
    port = int(os.getenv("PORT", 8080))
    app.run(host="0.0.0.0", port=port)