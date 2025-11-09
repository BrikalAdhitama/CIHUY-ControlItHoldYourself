from app import app, db, User

# Menggunakan konteks aplikasi agar bisa akses database
with app.app_context():
    print("Sedang mengecek database...")

    # 1. Cek apakah user 'test' sudah ada
    existing_user = User.query.filter_by(username='test').first()

    if existing_user:
        print("\nℹ️ [INFO] Akun 'test' SUDAH ADA. Tidak perlu dibuat lagi.")
    else:
        # 2. Jika belum ada, buat baru
        dummy_user = User(
            email='test@cihuy.com',
            username='test',
            password='123'  # Password simpel
        )
        db.session.add(dummy_user)
        db.session.commit()
        print("\n✅ [SUKSES] Akun dummy berhasil dibuat!")

    print("-" * 30)
    print("Username : test")
    print("Password : 123")
    print("-" * 30)