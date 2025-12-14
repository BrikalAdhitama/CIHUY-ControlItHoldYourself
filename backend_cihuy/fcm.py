import firebase_admin
from firebase_admin import credentials, messaging
import os

# Setup Path Credential (Biar gak error "File not found")
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
KEY_PATH = os.path.join(BASE_DIR, "service_account.json")

# Inisialisasi Firebase (Cuma sekali seumur hidup server nyala)
if not firebase_admin._apps:
    try:
        cred = credentials.Certificate(KEY_PATH)
        firebase_admin.initialize_app(cred)
        print("[FCM] Firebase Connected ✅")
    except Exception as e:
        print(f"[FCM FATAL] Gagal connect Firebase: {e}")

# --- 1. Kirim ke SATU Orang (Manual/Personal) ---
def send_fcm(token: str, title: str, body: str, data: dict = None):
    try:
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data=data or {},
            token=token,
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    channel_id='cihuy_reminder_channel',
                    sound='default'
                )
            ),
        )
        response = messaging.send(message)
        return True, response
    except Exception as e:
        print(f"[FCM ERROR] {e}")
        return False, str(e)

# --- 2. Kirim ke BANYAK Orang (Broadcast/Scheduler) ---
def send_fcm_broadcast(tokens: list, title: str, body: str, data: dict = None):
    if not tokens:
        return False, "List token kosong"

    try:
        message = messaging.MulticastMessage(
            notification=messaging.Notification(title=title, body=body),
            data=data or {},
            tokens=tokens, 
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    channel_id='cihuy_reminder_channel',
                    sound='default'
                )
            ),
        )
        
        response = messaging.send_each_for_multicast(message)
        
        if response.failure_count > 0:
            print(f"[FCM BROADCAST] {response.success_count} Sukses, {response.failure_count} Gagal.")
            # Di sini bisa tambah logic hapus token basi kalau mau
            
        return True, "Broadcast Sukses"
        
    except Exception as e:
        print(f"[FCM BROADCAST ERROR] {e}")
        return False, str(e)