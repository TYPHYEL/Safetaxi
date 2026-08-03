import os
import firebase_admin
from firebase_admin import credentials, messaging

_initialized = False


def init_firebase():
    global _initialized
    if _initialized:
        return
    cred_path = os.getenv('FIREBASE_CREDENTIALS')
    if cred_path and os.path.exists(cred_path):
        cred = credentials.Certificate(cred_path)
        try:
            firebase_admin.initialize_app(cred)
            _initialized = True
        except Exception as e:
            print('Failed to initialize Firebase:', e)
    else:
        print('FIREBASE_CREDENTIALS not set or file missing; Firebase not initialized')


def send_multicast(tokens, title, body, data=None):
    """Send a multicast notification to a list of FCM tokens.

    Returns dict with success and failure counts.
    """
    init_firebase()
    try:
        if not firebase_admin._apps:
            print('Firebase app not initialized; skipping send')
            return {'success': 0, 'failure': len(tokens)}
    except Exception:
        return {'success': 0, 'failure': len(tokens)}

    if not tokens:
        return {'success': 0, 'failure': 0}

    message = messaging.MulticastMessage(
        notification=messaging.Notification(title=title, body=body),
        data=data or {},
        tokens=list(tokens),
    )
    response = messaging.send_each_for_multicast(message)
    return {'success': response.success_count, 'failure': response.failure_count}
