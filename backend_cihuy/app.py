import os
from datetime import datetime
from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_bcrypt import Bcrypt
from flask_cors import CORS
import google.generativeai as genai
from dotenv import load_dotenv
import traceback # <-- Tambahkan ini untuk error detail

# =========================================
# 1. KONFIGURASI SERVER & DATABASE
# =========================================

# Muat API Key dari file .env
load_dotenv()

app = Flask(__name__)
CORS(app)  # Penting agar bisa diakses dari HP/Emulator

# Konfigurasi Database SQLite
basedir = os.path.abspath(os.path.dirname(__file__))
db_path = os.path.join(basedir, 'cihuy.db')
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + db_path
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)
bcrypt = Bcrypt(app)

# =========================================
# 2. KONFIGURASI AI (GOOGLE GEMINI)
# =========================================
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

if GEMINI_API_KEY:
    try:
        genai.configure(api_key=GEMINI_API_KEY)
        gemini_model = genai.GenerativeModel('gemini-1.0-pro')
        print("[INFO] AI Gemini siap digunakan!")
    except Exception as e:
        print(f"[ERROR] Gagal konfigurasi Gemini: {e}")
        gemini_model = None
else:
    print("[WARNING] GEMINI_API_KEY belum diatur di file .env")
    gemini_model = None

# =========================================
# 3. MODEL DATABASE (TABEL USER)
# =========================================
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), unique=True, nullable=False)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(128), nullable=False)
    quit_date = db.Column(db.DateTime, nullable=True) # Waktu mulai berhenti

    def __init__(self, email, username, password):
        self.email = email
        self.username = username
        self.password_hash = bcrypt.generate_password_hash(password).decode('utf-8')

    def check_password(self, password):
        return bcrypt.check_password_hash(self.password_hash, password)
    
class DailyRecord(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    date = db.Column(db.Date, nullable=False) # Hanya tanggal (YYYY-MM-DD)
    status = db.Column(db.String(20), nullable=False) # 'success' atau 'relapse' (kambuh)

    # Agar satu user hanya punya satu catatan per hari
    __table_args__ = (db.UniqueConstraint('user_id', 'date', name='_user_date_uc'),)

# Buat tabel otomatis saat server nyala
with app.app_context():
    db.create_all()
    # Opsional: Buat akun test jika belum ada
    if not User.query.filter_by(username='test').first():
        db.session.add(User('test@cihuy.com', 'test', '123'))
        db.session.commit()
        print("[INFO] Akun dummy 'test' / '123' dibuat.")

# =========================================
# 4. API ENDPOINTS (JALUR KOMUNIKASI)
# =========================================

@app.route('/', methods=['GET'])
def home():
    return "Server CIHUY! Berjalan Normal.", 200

# --- AUTH (Login & Register) ---
@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    if not data or not all(k in data for k in ('email', 'username', 'password')):
        return jsonify({'message': 'Data tidak lengkap!'}), 400

    if User.query.filter_by(username=data['username']).first():
        return jsonify({'message': 'Username sudah terpakai'}), 409

    try:
        new_user = User(email=data['email'], username=data['username'], password=data['password'])
        db.session.add(new_user)
        db.session.commit()
        return jsonify({'message': 'Registrasi berhasil! Silakan login.'}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({'message': f'Server Error: {str(e)}'}), 500

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    user = User.query.filter_by(username=data.get('username')).first()

    if user and user.check_password(data.get('password')):
        return jsonify({
            'success': True,
            'message': 'Login berhasil',
            'username': user.username
        }), 200
    return jsonify({'success': False, 'message': 'Username atau password salah'}), 401

# --- FITUR UTAMA (Timer & Chat) ---

# [POST] Reset / Mulai Timer
@app.route('/set_quit_date', methods=['POST'])
def set_quit_date():
    data = request.get_json()
    username = data.get('username')
    
    user = User.query.filter_by(username=username).first()
    if user:
        # Set waktu berhenti ke WAKTU SEKARANG (UTC)
        user.quit_date = datetime.utcnow()
        db.session.commit()
        print(f"[TIMER] {username} mereset waktunya ke {user.quit_date}")
        return jsonify({
            'success': True,
            'message': 'Timer berhasil di-reset!',
            'quit_date': user.quit_date.isoformat()
        }), 200
    return jsonify({'success': False, 'message': 'User tidak ditemukan'}), 404

# [GET] Ambil Data Timer
@app.route('/get_progress/<username>', methods=['GET'])
def get_progress(username):
    user = User.query.filter_by(username=username).first()
    if not user:
        return jsonify({'success': False, 'message': 'User tidak ditemukan'}), 404

    if user.quit_date:
        # Hitung selisih waktu sekarang dengan waktu berhenti
        now = datetime.utcnow()
        duration = now - user.quit_date
        total_seconds = int(duration.total_seconds())

        # Pastikan tidak negatif (jika jam server tidak sinkron sedikit)
        if total_seconds < 0: total_seconds = 0

        return jsonify({
            'success': True,
            'quit_date': user.quit_date.isoformat(),
            'total_seconds': total_seconds
        }), 200
    else:
        return jsonify({'success': False, 'message': 'Belum mulai berhenti'}), 200

# [POST] Chatbot AI
@app.route('/chat', methods=['POST'])
def chat():
    if not gemini_model:
        return jsonify({'reply': 'Maaf, otak AI saya belum dipasang (API Key error).'}), 503

    data = request.get_json()
    user_msg = data.get('message', '')
    if not user_msg: return jsonify({'error': 'Pesan kosong'}), 400

    # Instruksi agar AI berperan sebagai terapis
    persona = (
        "Kamu adalah 'CiHuy', teman virtual yang suportif untuk membantu orang berhenti merokok. "
        "Jawab dengan singkat, ramah, dan memotivasi. Bahasa Indonesia gaul tapi sopan."
    )
    
    try:
        # --- BLOK DEBUG BARU ---
        print(f"[CHAT DEBUG] Menerima pesan: {user_msg}")
        full_prompt = f"{persona}\nUser: {user_msg}\nCiHuy:"
        
        print("[CHAT DEBUG] Mengirim permintaan ke Google Gemini...")
        response = gemini_model.generate_content(full_prompt)
        
        print("[CHAT DEBUG] Menerima balasan dari Gemini.")
        return jsonify({'reply': response.text})
    except Exception as e:
        # --- BLOK ERROR DETAIL BARU ---
        print("\n" + "="*30)
        print("[CHAT ERROR] Terjadi kesalahan fatal saat menghubungi Gemini!")
        print(f"Error: {str(e)}")
        traceback.print_exc() # Mencetak error lengkap ke terminal
        print("="*30 + "\n")
        return jsonify({'reply': f'Duh, lagi pusing nih. (Error: {str(e)})'}), 500

# =========================================
# 5. JALANKAN SERVER
# =========================================
if __name__ == '__main__':
    # host='0.0.0.0' WAJIB agar bisa diakses Ngrok/Emulator
    print("[SERVER] CIHUY! siap meluncur di port 5000...")
    app.run(debug=True, host='0.0.0.0', port=5000)