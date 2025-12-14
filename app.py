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

# ================= GEMINI (SDK BARU & BENAR) =================
import google.generativeai as genai


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
    print(f"[DB ERROR] {e}")
    supabase = None


# ================= CONFIG GEMINI =================
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
model = None

if GEMINI_API_KEY:
    try:
        genai.configure(api_key=GEMINI_API_KEY)
        model = genai.GenerativeModel("gemini-1.5-flash")
        print("[AI] Gemini Ready 🧠")
    except Exception as e:
        print("[AI ERROR] Gemini init failed:", e)
else:
    print("[AI] GEMINI_API_KEY not found ❌")


SYSTEM_INSTRUCTION = (
    "Kamu adalah CiHuy, chatbot pendamping untuk orang yang ingin berhenti merokok dan vape. "
    "Gunakan bahasa santai, empatik, dan supportive seperti teman dekat. "
    "Jawaban tidak harus pendek, bisa panjang jika diperlukan, tetapi tetap jelas dan tidak bertele-tele. "
    "Fokus percakapan pada: kesehatan, coping craving, alasan berhenti, motivasi, kebiasaan pengganti, manajemen stres, dan edukasi tentang dampak rokok/vape. "
    "Berikan langkah konkret, bukan hanya teori umum. "
    "Boleh bercerita, jelasin konsep, kasih strategi bertahap, atau validasi emosi pengguna. "
    "JANGAN keluar topik selain seputar rokok, vape, kesehatan, dan proses berhenti kecanduan. "
    "Jika user keluar topik, alihkan balik dengan halus. "
    "Tidak memberikan diagnosis medis atau saran medis hardcore; arahkan ke tenaga profesional jika topik sudah serius."
)

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


# ================= DB HELPERS =================
def get_users_by_zona(zona: str):
    if not supabase:
        return []

    try:
        response = (
            supabase
            .table("users")
            .select("token")
            .eq("zona", zona)
            .execute()
        )

        tokens = [item["token"] for item in response.data]
        return list(set(tokens))
    except Exception as e:
        print(f"[DB ERROR] get_users_by_zona: {e}")
        return []


# ================= SCHEDULER JOB =================
def job_kirim_per_zona(sesi, target_zona):
    print(
        f"[SCHEDULER] {time.strftime('%H:%M')} "
        f"Kirim {sesi} ke {target_zona}"
    )

    tokens = get_users_by_zona(target_zona)
    if not tokens:
        print("[SCHEDULER] Token kosong, skip")
        return

    pesan = {
        "pagi": "Pagi, Pejuang! Awali harimu dengan napas yang segar ya.",
        "siang": "Semangat siang! Ayo, kamu pasti bisa!",
        "malam": "Sudah malam nih. Terima kasih sudah bertahan hari ini."
    }

    send_fcm_broadcast(
        tokens,
        "Hai Sobat CIHUY!",
        pesan.get(sesi, "Semangat Cihuy!")
    )


# ================= SCHEDULER =================
jakarta_tz = pytz.timezone("Asia/Jakarta")
scheduler = BackgroundScheduler(timezone=jakarta_tz)

# PAGI
scheduler.add_job(job_kirim_per_zona, "cron", hour=6,  minute=0, args=["pagi", "WIT"])
scheduler.add_job(job_kirim_per_zona, "cron", hour=7,  minute=0, args=["pagi", "WITA"])
scheduler.add_job(job_kirim_per_zona, "cron", hour=8,  minute=0, args=["pagi", "WIB"])

# SIANG
scheduler.add_job(job_kirim_per_zona, "cron", hour=10, minute=0, args=["siang", "WIT"])
scheduler.add_job(job_kirim_per_zona, "cron", hour=11, minute=0, args=["siang", "WITA"])
scheduler.add_job(job_kirim_per_zona, "cron", hour=12, minute=0, args=["siang", "WIB"])

# MALAM
scheduler.add_job(job_kirim_per_zona, "cron", hour=17, minute=0, args=["malam", "WIT"])
scheduler.add_job(job_kirim_per_zona, "cron", hour=18, minute=0, args=["malam", "WITA"])
scheduler.add_job(job_kirim_per_zona, "cron", hour=19, minute=0, args=["malam", "WIB"])

scheduler.start()
atexit.register(lambda: scheduler.shutdown())


# ================= ROUTES =================
@app.route("/", methods=["GET"])
def home():
    total_users = "Offline"

    if supabase:
        try:
            res = supabase.table("users").select("*", count="exact", head=True).execute()
            total_users = res.count
        except:
            total_users = "Error DB"

    return jsonify({
        "status": "Cihuy Backend Online 🚀",
        "database": "Connected" if supabase else "Offline",
        "users_connected": total_users
    })


@app.route("/save-token", methods=["POST"])
def save_token():
    data = request.get_json() or {}
    token = data.get("token")
    zona = data.get("zona", "WIB")

    if not token:
        return jsonify({"error": "Token wajib ada"}), 400

    try:
        supabase.table("users").upsert({
            "token": token,
            "zona": zona
        }).execute()

        return jsonify({"message": "Token tersimpan"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/send-notification", methods=["POST"])
def send_notification():
    data = request.get_json() or {}
    token = data.get("token")

    if not token:
        return jsonify({"error": "Token wajib ada"}), 400

    success, result = send_fcm(
        token,
        data.get("title", "Ingat Cihuy!"),
        data.get("body", "Waktunya cek progress kamu.")
    )

    if success:
        return jsonify({"message": "Terkirim", "id": result}), 200
    return jsonify({"error": result}), 500


@app.route("/chat", methods=["POST"])
def chat():
    if not model:
        return jsonify({"success": False, "reply": "AI belum siap"}), 500

    data = request.get_json() or {}
    message = (data.get("message") or "").strip()

    if not message:
        return jsonify({"success": False, "reply": "Pesan kosong"}), 400

    try:
        response = model.generate_content(
            message,
            generation_config={"temperature": 0.7}
        )
        reply = response.text or make_fallback_reply()
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
