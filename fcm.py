import os
import json
import firebase_admin
from firebase_admin import credentials, messaging

# ================= INIT FIREBASE =================
def init_firebase():
    if firebase_admin._apps:
        return

    service_account_json = os.getenv("FIREBASE_SERVICE_ACCOUNT")

    if not service_account_json:
        raise RuntimeError("FIREBASE_SERVICE_ACCOUNT env not found")

    try:
        cred_dict = json.loads(service_account_json)
        cred = credentials.Certificate(cred_dict)
        firebase_admin.initialize_app(cred)
        print("[FCM] Firebase Connected via ENV ✅")
    except Exception as e:
        raise RuntimeError(f"Firebase init failed: {e}")


# Init sekali saat module load
try:
    init_firebase()
except Exception as e:
    print("[FCM ERROR]", e)


# ================= SEND SINGLE =================
def send_fcm(token: str, title: str, body: str, data: dict | None = None):
    try:
        message = messaging.Message(
            token=token,
            notification=messaging.Notification(
                title=title,
                body=body
            ),
            data=data or {},
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="cihuy_reminder_channel",
                    sound="default"
                )
            )
        )

        response = messaging.send(message)
        return True, response

    except Exception as e:
        print("[FCM ERROR]", e)
        return False, str(e)


# ================= SEND BROADCAST =================
def send_fcm_broadcast(tokens: list[str], title: str, body: str, data: dict | None = None):
    if not tokens:
        return False, "Token list kosong"

    try:
        message = messaging.MulticastMessage(
            tokens=tokens,
            notification=messaging.Notification(
                title=title,
                body=body
            ),
            data=data or {},
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="cihuy_reminder_channel",
                    sound="default"
                )
            )
        )

        response = messaging.send_each_for_multicast(message)

        print(
            f"[FCM BROADCAST] "
            f"{response.success_count} sukses, "
            f"{response.failure_count} gagal"
        )

        return True, {
            "success": response.success_count,
            "failure": response.failure_count
        }

    except Exception as e:
        print("[FCM BROADCAST ERROR]", e)
        return False, str(e)
