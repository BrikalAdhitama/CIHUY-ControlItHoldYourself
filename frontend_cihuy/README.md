CIHUY!

CIHUY! - "Control It, Hold Yourself"

CIHUY! adalah aplikasi mobile pendamping untuk membantu pengguna berhenti merokok dan vape. Aplikasi ini menyediakan pelacakan progres waktu nyata, dukungan chatbot AI, dan fitur motivasi harian.

Fitur Utama

Pelacak Waktu (Quit Timer): Menghitung durasi (hari, jam, menit, detik) sejak pengguna terakhir merokok/vape.

Chatbot AI (CiHuy): Asisten virtual berbasis Google Gemini AI untuk curhat dan mendapatkan tips instan saat craving.

Tombol Darurat (Panic Button): Tombol "Saya Kambuh" untuk me-reset timer dengan konfirmasi, membantu pengguna jujur pada progres mereka.

Riwayat Harian: (Segera Hadir) Pelacakan visual keberhasilan harian pengguna dalam kalender.

Edukasi: (Segera Hadir) Kumpulan artikel dan info bahaya merokok/vape.

Teknologi yang Digunakan

Frontend: Flutter (Dart)

Backend: Python (Flask)

Database: SQLite (via SQLAlchemy)

AI Engine: Google Gemini API (gemini-1.0-pro)

Cara Menjalankan (Local Development)

Proyek ini terdiri dari dua bagian yang harus dijalankan bersamaan: Backend dan Frontend.

Prasyarat

Flutter SDK terinstal.

Python 3.x terinstal.

(Opsional) Ngrok untuk testing di HP fisik.

1. Menjalankan Backend (Server)

Masuk ke folder backend:

cd backend_cihuy


Buat virtual environment (opsional tapi disarankan):

python -m venv .venv
# Windows:
.venv\Scripts\activate
# macOS/Linux:
source .venv/bin/activate


Instal dependensi:

pip install -r requirements.txt


Buat file .env dan isi dengan API Key Gemini Anda:

GEMINI_API_KEY=AIzaSyYourSecretKeyHere


Jalankan server:

python app.py


Server akan berjalan di http://0.0.0.0:5000.

2. Menjalankan Frontend (Aplikasi Mobile)

Masuk ke folder frontend:

cd frontend_cihuy


PENTING: Update URL server di lib/services/auth_service.dart:

Jika pakai Android Emulator: Gunakan http://10.0.2.2:5000.

Jika pakai HP Fisik: Gunakan Ngrok (lihat panduan di bawah) atau IP LAN laptop Anda (misal http://192.168.1.x:5000).

Jalankan aplikasi:

flutter run


Catatan Penting untuk Testing di HP Fisik

Jika menggunakan HP fisik dan mengalami error koneksi, gunakan Ngrok untuk mengekspos server lokal ke internet:

Jalankan Ngrok: ngrok http 5000

Salin URL HTTPS yang diberikan Ngrok.

Tempel URL tersebut ke variabel _baseUrl di file frontend_cihuy/lib/services/auth_service.dart.

Struktur Proyek

proyek_cihuy/
├── backend_cihuy/       # Server Flask & Database
│   ├── app.py           # Logika utama server
│   ├── cihuy.db         # File database SQLite
│   └── .env             # (RAHASIA) API Key disimpan di sini
│
└── frontend_cihuy/      # Aplikasi Flutter
    ├── lib/
    │   ├── screens/     # Halaman (Login, Register, Home, Chat)
    │   ├── services/    # Komunikasi ke Backend (API Calls)
    │   └── widgets/     # Komponen UI yang bisa dipakai ulang
    └── pubspec.yaml     # Daftar library Flutter
