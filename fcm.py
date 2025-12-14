import os
import json
import firebase_admin
from firebase_admin import credentials, messaging

# ================= FIREBASE INIT (ENV BASED) =================
if not firebase_admin._apps:
    try:
        service_account_json = os.getenv("FIREBASE_SERVICE_ACCOUNT")

        if not service_account_json:
            raise Exception("ENV FIREBASE_SERVICE_ACCOUNT belum diset")

        cred_dict = json.loads(service_account_json)
        cred = credentials.Certificate(cred_dict)
        firebase_admin.initialize_app(cred)

        print("[FCM] Firebase Connected via ENV ✅")

    except Exception as e:
        print(f"[FCM FATAL] Gagal connect Firebase: {e}")

# ================= SEND SINGLE =================
def send_fcm(token: str, title: str, body: str, data: dict = None):
    try:
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data=data or {},
            token=token,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="cihuy_reminder_channel",
                    sound="default"
                )
            ),
        )
        response = messaging.send(message)
        return True, response

    except Exception as e:
        print(f"[FCM ERROR] {e}")
        return False, str(e)

# ================= SEND BROADCAST =================
def send_fcm_broadcast(tokens: list, title: str, body: str, data: dict = None):
    if not tokens:
        return False, "Token list kosong"

    try:
        message = messaging.MulticastMessage(
            notification=messaging.Notification(title=title, body=body),
            data=data or {},
            tokens=tokens,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="cihuy_reminder_channel",
                    sound="default"
                )
            ),
        )

        response = messaging.send_each_for_multicast(message)

        print(
            f"[FCM BROADCAST] {response.success_count} sukses, "
            f"{response.failure_count} gagal"
        )

        return True, "Broadcast selesai"

    except Exception as e:
        print(f"[FCM BROADCAST ERROR] {e}")
        return False, str(e)
