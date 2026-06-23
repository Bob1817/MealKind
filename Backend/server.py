#!/usr/bin/env python3
from __future__ import annotations

import base64
import binascii
import json
import os
import secrets
import sys
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlparse


ROOT = Path(__file__).resolve().parent
PUBLIC_DIR = ROOT / "public"
STORE_PATH = ROOT / "data" / "store.json"
UPLOAD_DIR = ROOT / "data" / "uploads"
SESSIONS: set[str] = set()
CLIENT_SESSIONS: dict[str, str] = {}

CLIENT_COLLECTIONS = {
    "settings",
    "habits",
    "dailyTasks",
    "mealRecords",
    "workoutRecords",
    "sleepRecords",
    "waterRecords",
    "weightRecords",
    "supplementRecords",
    "measurementRecords",
    "dailyStrategies",
    "weeklyReviews",
    "trainingCycles",
}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def load_store() -> dict:
    with STORE_PATH.open("r", encoding="utf-8") as handle:
        return ensure_store_shape(json.load(handle))


def save_store(store: dict) -> None:
    store = ensure_store_shape(store)
    tmp_path = STORE_PATH.with_suffix(".tmp")
    with tmp_path.open("w", encoding="utf-8") as handle:
        json.dump(store, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    tmp_path.replace(STORE_PATH)


def json_bytes(payload: object) -> bytes:
    return json.dumps(payload, ensure_ascii=False).encode("utf-8")


def ensure_store_shape(store: dict) -> dict:
    store.setdefault("users", [])
    store.setdefault("plans", [])
    store.setdefault("subscriptions", [])
    store.setdefault("aiModels", [])
    store.setdefault("settings", {})
    store.setdefault("analysisLogs", [])
    store.setdefault("systemLogs", [])
    store.setdefault("issues", [])
    store.setdefault("notifications", [])
    store.setdefault("clientTokens", {})
    store.setdefault("clientData", {})
    for user in store["users"]:
        user.setdefault("updatedAt", user.get("createdAt"))
        user.setdefault("lastSeenAt", None)
    return store


def public_url(path: Path) -> str:
    relative = path.relative_to(ROOT)
    return "/" + relative.as_posix()


def plan_name(plan_payload: dict | None, locale: str) -> str:
    if not plan_payload:
        return "Scanned meal"
    if locale == "zh-Hans":
        return {
            "Lifestyle Cut": "生活化减脂",
            "531 Carb Step-down": "531 碳水渐降",
            "High Protein": "高蛋白控热量",
        }.get(plan_payload.get("name", ""), "当前方案")
    return plan_payload.get("name", "Current plan")


def mock_food_analysis(body: dict) -> dict:
    locale = body.get("locale", "en")
    image_base64 = body.get("imageBase64") or ""
    remaining = int(body.get("remainingCalories") or 0)
    plan = body.get("plan") or {}
    image_size = len(image_base64)
    calories = 420 + min(max(image_size // 18000, 0), 260)
    protein = max(18, round(calories * 0.20 / 4))
    carbs = max(32, round(calories * 0.42 / 4))
    fat = max(10, round(calories * 0.28 / 9))
    fits = remaining >= calories

    if locale == "zh-Hans":
        food_name = "AI 识别餐食" if image_base64 else "手动餐食"
        summary = "这餐可以纳入今日计划。" if fits else "可以吃，但建议缩小主食或留一部分。"
        portion = ["优先吃蛋白质", "主食按实际分量记录"]
        next_meal = "下一餐保持清淡一点" if not fits else "下一餐正常吃，不需要补偿"
    else:
        food_name = "AI scanned meal" if image_base64 else "Manual meal"
        summary = "This meal can fit today." if fits else "You can eat it, but keep starch smaller or save some."
        portion = ["Protein first", "Record the actual portion"]
        next_meal = "Keep the next meal lighter" if not fits else "Eat normally next; no compensation needed"

    return {
        "foods": [
            {
                "name": food_name,
                "portion": "1 serving",
                "estimatedCalories": calories,
                "protein": protein,
                "carbs": carbs,
                "fat": fat,
                "confidence": 0.72 if image_base64 else 0.55,
            }
        ],
        "totalCalories": calories,
        "planFit": "fits" if fits else "adjust",
        "recommendedAction": {
            "summary": summary,
            "portionStrategy": portion,
            "nextMealAdjustment": next_meal,
            "wasteAvoidance": "Save leftovers if full",
        },
        "safetyFlags": [],
        "recordDraft": {
            "mealType": "unknown",
            "calories": calories,
            "protein": protein,
            "carbs": carbs,
            "fat": fat,
        },
        "meta": {
            "provider": "mock-json",
            "planName": plan_name(plan, locale),
            "createdAt": utc_now(),
        },
    }


class MealKindHandler(BaseHTTPRequestHandler):
    server_version = "MealKindBackend/0.1"

    def do_OPTIONS(self) -> None:
        self.send_response(HTTPStatus.NO_CONTENT)
        self.add_common_headers()
        self.end_headers()

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path == "/health":
            return self.send_json({"ok": True, "service": "MealKind Backend", "time": utc_now()})
        if path == "/" or path.startswith("/admin"):
            return self.serve_file(PUBLIC_DIR / "admin.html")
        if path.startswith("/assets/"):
            return self.serve_file(PUBLIC_DIR / path.removeprefix("/assets/"))
        if path.startswith("/data/uploads/"):
            return self.serve_file(ROOT / unquote(path.removeprefix("/")))
        if path == "/api/client/me":
            return self.with_client(lambda user_id: self.client_me(user_id))
        if path == "/api/client/export":
            return self.with_client(lambda user_id: self.client_export(user_id))
        if path.startswith("/api/client/records/"):
            collection = path.rsplit("/", 1)[-1]
            return self.with_client(lambda user_id: self.list_client_records(user_id, collection))
        if path == "/api/admin/overview":
            return self.with_admin(lambda: self.send_json(self.admin_overview()))
        if path == "/api/admin/users":
            return self.with_admin(lambda: self.send_json(load_store()["users"]))
        if path == "/api/admin/plans":
            return self.with_admin(lambda: self.send_json(load_store()["plans"]))
        if path == "/api/admin/subscriptions":
            return self.with_admin(lambda: self.send_json(load_store()["subscriptions"]))
        if path == "/api/admin/ai-models":
            return self.with_admin(lambda: self.send_json(load_store()["aiModels"]))
        if path == "/api/admin/settings":
            return self.with_admin(lambda: self.send_json(load_store()["settings"]))
        if path == "/api/admin/analysis-logs":
            return self.with_admin(lambda: self.send_json(list(reversed(load_store()["analysisLogs"][-80:]))))
        if path == "/api/admin/system-logs":
            return self.with_admin(lambda: self.send_json(list(reversed(load_store()["systemLogs"][-120:]))))
        if path == "/api/admin/issues":
            return self.with_admin(lambda: self.send_json(load_store()["issues"]))
        if path == "/api/admin/notifications":
            return self.with_admin(lambda: self.send_json(load_store()["notifications"]))
        return self.send_error_json(HTTPStatus.NOT_FOUND, "Not found")

    def do_POST(self) -> None:
        path = urlparse(self.path).path
        body = self.read_json()
        if path == "/api/auth/login":
            return self.login(body)
        if path == "/api/client/session":
            return self.client_session(body)
        if path == "/api/client/sync":
            return self.with_client(lambda user_id: self.client_sync(user_id, body))
        if path == "/api/client/clear":
            return self.with_client(lambda user_id: self.client_clear(user_id))
        if path == "/api/client/delete-account":
            return self.with_client(lambda user_id: self.client_delete_account(user_id, body))
        if path.startswith("/api/client/records/"):
            collection = path.rsplit("/", 1)[-1]
            return self.with_client(lambda user_id: self.upsert_client_record(user_id, collection, body))
        if path == "/api/ai/food-analysis":
            return self.food_analysis(body)
        if path == "/api/ai/smart-scan":
            return self.smart_scan(body)
        if path == "/api/admin/users":
            return self.with_admin(lambda: self.create_user(body))
        if path == "/api/admin/plans":
            return self.with_admin(lambda: self.replace_collection("plans", body))
        if path == "/api/admin/subscriptions":
            return self.with_admin(lambda: self.replace_collection("subscriptions", body))
        if path == "/api/admin/ai-models":
            return self.with_admin(lambda: self.replace_collection("aiModels", body))
        if path == "/api/admin/settings":
            return self.with_admin(lambda: self.replace_settings(body))
        if path == "/api/admin/issues":
            return self.with_admin(lambda: self.create_record("issues", body, "iss"))
        if path == "/api/admin/notifications":
            return self.with_admin(lambda: self.create_record("notifications", body, "ntf"))
        return self.send_error_json(HTTPStatus.NOT_FOUND, "Not found")

    def do_PATCH(self) -> None:
        path = urlparse(self.path).path
        body = self.read_json()
        if path.startswith("/api/admin/users/"):
            user_id = path.rsplit("/", 1)[-1]
            return self.with_admin(lambda: self.patch_user(user_id, body))
        if path.startswith("/api/client/records/"):
            parts = path.split("/")
            if len(parts) >= 6:
                collection = parts[-2]
                record_id = parts[-1]
                return self.with_client(lambda user_id: self.patch_client_record(user_id, collection, record_id, body))
        if path.startswith("/api/admin/issues/"):
            issue_id = path.rsplit("/", 1)[-1]
            return self.with_admin(lambda: self.patch_record("issues", issue_id, body))
        if path.startswith("/api/admin/notifications/"):
            notification_id = path.rsplit("/", 1)[-1]
            return self.with_admin(lambda: self.patch_record("notifications", notification_id, body))
        return self.send_error_json(HTTPStatus.NOT_FOUND, "Not found")

    def do_DELETE(self) -> None:
        path = urlparse(self.path).path
        if path.startswith("/api/admin/users/"):
            user_id = path.rsplit("/", 1)[-1]
            return self.with_admin(lambda: self.delete_user(user_id))
        if path.startswith("/api/client/records/"):
            parts = path.split("/")
            if len(parts) >= 6:
                collection = parts[-2]
                record_id = parts[-1]
                return self.with_client(lambda user_id: self.delete_client_record(user_id, collection, record_id))
        if path.startswith("/api/admin/issues/"):
            issue_id = path.rsplit("/", 1)[-1]
            return self.with_admin(lambda: self.delete_record("issues", issue_id))
        if path.startswith("/api/admin/notifications/"):
            notification_id = path.rsplit("/", 1)[-1]
            return self.with_admin(lambda: self.delete_record("notifications", notification_id))
        return self.send_error_json(HTTPStatus.NOT_FOUND, "Not found")

    def log_message(self, fmt: str, *args: object) -> None:
        sys.stderr.write("[%s] %s\n" % (utc_now(), fmt % args))

    def add_common_headers(self, content_type: str = "application/json; charset=utf-8") -> None:
        self.send_header("Content-Type", content_type)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,PATCH,DELETE,OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type,Authorization")
        self.send_header("Cache-Control", "no-store")

    def send_json(self, payload: object, status: HTTPStatus = HTTPStatus.OK) -> None:
        data = json_bytes(payload)
        self.send_response(status)
        self.add_common_headers()
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def send_error_json(self, status: HTTPStatus, message: str) -> None:
        self.send_json({"error": message}, status)

    def read_json(self) -> dict:
        length = int(self.headers.get("Content-Length", "0") or 0)
        if length == 0:
            return {}
        raw = self.rfile.read(length)
        try:
            return json.loads(raw.decode("utf-8"))
        except json.JSONDecodeError:
            return {}

    def bearer_token(self) -> str:
        header = self.headers.get("Authorization", "")
        if header.startswith("Bearer "):
            return header.removeprefix("Bearer ").strip()
        return ""

    def with_admin(self, callback) -> None:
        if self.bearer_token() not in SESSIONS:
            return self.send_error_json(HTTPStatus.UNAUTHORIZED, "Admin login required")
        return callback()

    def with_client(self, callback) -> None:
        token = self.bearer_token()
        store = load_store()
        user_id = CLIENT_SESSIONS.get(token) or store.get("clientTokens", {}).get(token)
        if not user_id:
            return self.send_error_json(HTTPStatus.UNAUTHORIZED, "Client session required")
        if not any(user.get("id") == user_id and user.get("status") == "active" for user in store["users"]):
            return self.send_error_json(HTTPStatus.UNAUTHORIZED, "User is not active")
        CLIENT_SESSIONS[token] = user_id
        return callback(user_id)

    def login(self, body: dict) -> None:
        username = body.get("username", "")
        password = body.get("password", "")
        expected_user = os.environ.get("MEALKIND_ADMIN_USER", "admin")
        expected_password = os.environ.get("MEALKIND_ADMIN_PASSWORD", "mealkind-admin")
        if username != expected_user or password != expected_password:
            return self.send_error_json(HTTPStatus.UNAUTHORIZED, "Invalid credentials")
        token = secrets.token_urlsafe(32)
        SESSIONS.add(token)
        self.send_json({"token": token, "role": "super_admin", "user": username})

    def client_session(self, body: dict) -> None:
        store = load_store()
        settings = store.get("settings", {})
        if not settings.get("registrationEnabled", True):
            return self.send_error_json(HTTPStatus.FORBIDDEN, "Registration is disabled")

        install_id = str(body.get("installId") or "").strip()
        email = str(body.get("email") or "").strip().lower()
        locale = body.get("locale") or settings.get("defaultLocale", "zh-Hans")
        now = utc_now()

        user = None
        for candidate in store["users"]:
            if email and candidate.get("email") == email and candidate.get("status") != "deleted":
                user = candidate
                break
            if install_id and candidate.get("installId") == install_id and candidate.get("status") != "deleted":
                user = candidate
                break

        if user is None:
            user = {
                "id": "usr_" + secrets.token_hex(8),
                "name": body.get("name") or (email.split("@")[0] if email else "Guest"),
                "email": email or f"guest-{secrets.token_hex(4)}@local.mealkind",
                "installId": install_id or "install_" + secrets.token_hex(8),
                "locale": locale,
                "plan": body.get("plan", "Lifestyle Cut"),
                "mode": body.get("mode", "lifestyle"),
                "status": "active",
                "subscription": body.get("subscription", "free"),
                "registeredAt": now,
                "deletedAt": None,
                "deleteReason": None,
                "createdAt": now,
                "updatedAt": now,
                "lastSeenAt": now,
            }
            store["users"].append(user)
            store["clientData"].setdefault(user["id"], self.empty_client_data())
            self.append_system_log(store, "info", "client", f"Created client user {user['id']}")
        else:
            user["lastSeenAt"] = now
            user["locale"] = locale
            user["updatedAt"] = now

        token = secrets.token_urlsafe(32)
        store["clientTokens"][token] = user["id"]
        CLIENT_SESSIONS[token] = user["id"]
        save_store(store)
        self.send_json({"token": token, "user": self.safe_user(user), "createdAt": now})

    def client_me(self, user_id: str) -> None:
        store = load_store()
        user = self.user_by_id(store, user_id)
        if not user:
            return self.send_error_json(HTTPStatus.NOT_FOUND, "User not found")
        self.send_json({"user": self.safe_user(user)})

    def client_export(self, user_id: str) -> None:
        store = load_store()
        self.send_json({
            "user": self.safe_user(self.user_by_id(store, user_id) or {}),
            "data": store["clientData"].setdefault(user_id, self.empty_client_data()),
            "exportedAt": utc_now(),
        })

    def client_sync(self, user_id: str, body: dict) -> None:
        records = body.get("records")
        if not isinstance(records, list):
            return self.send_error_json(HTTPStatus.BAD_REQUEST, "Expected records array")

        store = load_store()
        client_data = store["clientData"].setdefault(user_id, self.empty_client_data())
        upserted = 0
        deleted = 0

        if body.get("replaceAll") is True:
            client_data.clear()
            client_data.update(self.empty_client_data())

        for item in records:
            if not isinstance(item, dict):
                continue
            collection = item.get("collection")
            if collection not in CLIENT_COLLECTIONS:
                continue
            payload = item.get("payload")
            if not isinstance(payload, dict):
                continue
            record_id = str(item.get("id") or payload.get("id") or secrets.token_hex(8))
            payload["id"] = record_id
            if item.get("deleted") is True:
                deleted += self.remove_client_record(client_data, collection, record_id)
                continue
            self.normalize_client_payload(user_id, collection, payload)
            payload["updatedAt"] = item.get("updatedAt") or payload.get("updatedAt") or utc_now()
            client_data.setdefault(collection, [])
            existing = next((record for record in client_data[collection] if record.get("id") == record_id), None)
            if existing:
                existing.update(payload)
            else:
                payload["createdAt"] = payload.get("createdAt") or utc_now()
                client_data[collection].append(payload)
            upserted += 1

        if user := self.user_by_id(store, user_id):
            user["lastSeenAt"] = utc_now()
            user["updatedAt"] = user["lastSeenAt"]
        self.append_system_log(store, "info", "client", f"Synced {upserted} records for {user_id}")
        save_store(store)
        self.send_json({
            "ok": True,
            "upserted": upserted,
            "deleted": deleted,
            "serverTime": utc_now(),
            "dataVersion": "client-sync.v1",
        })

    def client_clear(self, user_id: str) -> None:
        store = load_store()
        store["clientData"][user_id] = self.empty_client_data()
        self.remove_user_uploads(user_id)
        if user := self.user_by_id(store, user_id):
            user["updatedAt"] = utc_now()
            user["lastSeenAt"] = user["updatedAt"]
        self.append_system_log(store, "warning", "client", f"Cleared client data for {user_id}")
        save_store(store)
        self.send_json({"ok": True, "cleared": user_id, "serverTime": utc_now()})

    def client_delete_account(self, user_id: str, body: dict) -> None:
        store = load_store()
        if not store.get("settings", {}).get("accountDeletionEnabled", True):
            return self.send_error_json(HTTPStatus.FORBIDDEN, "Account deletion is disabled")
        user = self.user_by_id(store, user_id)
        if not user:
            return self.send_error_json(HTTPStatus.NOT_FOUND, "User not found")
        now = utc_now()
        user["status"] = "deleted"
        user["deletedAt"] = now
        user["updatedAt"] = now
        user["deleteReason"] = body.get("reason") or "client_request"
        store["clientData"].pop(user_id, None)
        store["clientTokens"] = {
            token: owner for token, owner in store.get("clientTokens", {}).items()
            if owner != user_id
        }
        for token, owner in list(CLIENT_SESSIONS.items()):
            if owner == user_id:
                CLIENT_SESSIONS.pop(token, None)
        self.remove_user_uploads(user_id)
        self.append_system_log(store, "warning", "client", f"Deleted account {user_id}")
        save_store(store)
        self.send_json({"ok": True, "deleted": user_id, "serverTime": now})

    def list_client_records(self, user_id: str, collection: str) -> None:
        if collection not in CLIENT_COLLECTIONS:
            return self.send_error_json(HTTPStatus.NOT_FOUND, "Unknown collection")
        store = load_store()
        data = store["clientData"].setdefault(user_id, self.empty_client_data())
        self.send_json({"collection": collection, "records": data.get(collection, [])})

    def upsert_client_record(self, user_id: str, collection: str, body: dict) -> None:
        if collection not in CLIENT_COLLECTIONS:
            return self.send_error_json(HTTPStatus.NOT_FOUND, "Unknown collection")
        payload = body.get("payload") if isinstance(body.get("payload"), dict) else dict(body)
        record_id = str(payload.get("id") or body.get("id") or secrets.token_hex(8))
        payload["id"] = record_id
        payload["updatedAt"] = utc_now()
        self.normalize_client_payload(user_id, collection, payload)

        store = load_store()
        data = store["clientData"].setdefault(user_id, self.empty_client_data())
        records = data.setdefault(collection, [])
        existing = next((record for record in records if record.get("id") == record_id), None)
        if existing:
            existing.update(payload)
            status = HTTPStatus.OK
        else:
            payload["createdAt"] = payload.get("createdAt") or utc_now()
            records.append(payload)
            status = HTTPStatus.CREATED
        save_store(store)
        self.send_json(payload, status)

    def patch_client_record(self, user_id: str, collection: str, record_id: str, body: dict) -> None:
        if collection not in CLIENT_COLLECTIONS:
            return self.send_error_json(HTTPStatus.NOT_FOUND, "Unknown collection")
        store = load_store()
        records = store["clientData"].setdefault(user_id, self.empty_client_data()).setdefault(collection, [])
        for record in records:
            if record.get("id") == record_id:
                record.update(body)
                record["updatedAt"] = utc_now()
                self.normalize_client_payload(user_id, collection, record)
                save_store(store)
                return self.send_json(record)
        return self.send_error_json(HTTPStatus.NOT_FOUND, "Record not found")

    def delete_client_record(self, user_id: str, collection: str, record_id: str) -> None:
        if collection not in CLIENT_COLLECTIONS:
            return self.send_error_json(HTTPStatus.NOT_FOUND, "Unknown collection")
        store = load_store()
        data = store["clientData"].setdefault(user_id, self.empty_client_data())
        deleted = self.remove_client_record(data, collection, record_id)
        if not deleted:
            return self.send_error_json(HTTPStatus.NOT_FOUND, "Record not found")
        save_store(store)
        self.send_json({"ok": True, "deleted": record_id})

    def normalize_client_payload(self, user_id: str, collection: str, payload: dict) -> None:
        payload["userId"] = user_id
        payload["collection"] = collection
        for key in ("imageBase64", "imageData"):
            image_base64 = payload.pop(key, None)
            if isinstance(image_base64, str) and image_base64:
                saved = self.save_image_payload(user_id, collection, str(payload.get("id")), image_base64)
                if saved:
                    payload["imageUrl"] = saved
                break

    def save_image_payload(self, user_id: str, collection: str, record_id: str, image_base64: str) -> str | None:
        try:
            image_data = base64.b64decode(image_base64, validate=False)
        except (binascii.Error, ValueError):
            return None
        max_bytes = int(load_store().get("settings", {}).get("maxImageBytes", 5_242_880))
        if not image_data or len(image_data) > max_bytes:
            return None
        user_dir = UPLOAD_DIR / user_id / collection
        user_dir.mkdir(parents=True, exist_ok=True)
        path = user_dir / f"{record_id}.jpg"
        path.write_bytes(image_data)
        return public_url(path)

    def remove_client_record(self, client_data: dict, collection: str, record_id: str) -> int:
        records = client_data.setdefault(collection, [])
        before = len(records)
        client_data[collection] = [record for record in records if record.get("id") != record_id]
        return before - len(client_data[collection])

    def remove_user_uploads(self, user_id: str) -> None:
        user_dir = UPLOAD_DIR / user_id
        if not user_dir.exists():
            return
        for path in sorted(user_dir.rglob("*"), reverse=True):
            if path.is_file():
                path.unlink(missing_ok=True)
            elif path.is_dir():
                path.rmdir()
        user_dir.rmdir()

    def empty_client_data(self) -> dict:
        return {collection: [] for collection in sorted(CLIENT_COLLECTIONS)}

    def user_by_id(self, store: dict, user_id: str) -> dict | None:
        return next((user for user in store["users"] if user.get("id") == user_id), None)

    def safe_user(self, user: dict) -> dict:
        allowed = ("id", "name", "email", "locale", "plan", "mode", "status", "subscription", "registeredAt", "createdAt", "updatedAt", "lastSeenAt")
        return {key: user.get(key) for key in allowed if key in user}

    def food_analysis(self, body: dict) -> None:
        response = mock_food_analysis(body)
        store = load_store()
        store["analysisLogs"].append({
            "id": "log_" + secrets.token_hex(6),
            "createdAt": utc_now(),
            "type": "food-analysis",
            "locale": body.get("locale", "en"),
            "remainingCalories": body.get("remainingCalories"),
            "plan": (body.get("plan") or {}).get("name"),
            "estimatedCalories": response["totalCalories"],
            "confidence": response["foods"][0]["confidence"],
        })
        save_store(store)
        self.send_json(response)

    def smart_scan(self, body: dict) -> None:
        image_base64 = body.get("imageBase64") or ""
        try:
            size = len(base64.b64decode(image_base64, validate=False)) if image_base64 else 0
        except Exception:
            size = 0
        kind = "unknown"
        if size > 2_000:
            kind = "food" if size % 5 else "workout"
        self.send_json({"kind": kind, "confidence": 0.68 if kind != "unknown" else 0.25, "createdAt": utc_now()})

    def admin_overview(self) -> dict:
        store = load_store()
        logs = store["analysisLogs"]
        calories = [item.get("estimatedCalories", 0) for item in logs]
        subscriptions = store.get("subscriptions", [])
        pro_users = [u for u in store["users"] if str(u.get("subscription", "")).startswith("pro")]
        open_issues = [issue for issue in store.get("issues", []) if issue.get("status") != "closed"]
        return {
            "users": len(store["users"]),
            "activeUsers": len([u for u in store["users"] if u.get("status") == "active"]),
            "plans": len([p for p in store["plans"] if p.get("enabled")]),
            "subscriptionPlans": len([s for s in subscriptions if s.get("enabled")]),
            "proUsers": len(pro_users),
            "aiModels": len([m for m in store.get("aiModels", []) if m.get("enabled")]),
            "analysisCount": len(logs),
            "averageCalories": round(sum(calories) / len(calories)) if calories else 0,
            "openIssues": len(open_issues),
            "notifications": len(store.get("notifications", [])),
            "maintenanceMode": bool(store["settings"].get("maintenanceMode")),
        }

    def replace_collection(self, key: str, body: dict) -> None:
        items = body.get(key)
        if not isinstance(items, list):
            return self.send_error_json(HTTPStatus.BAD_REQUEST, f"Expected {key} array")
        store = load_store()
        store[key] = items
        self.append_system_log(store, "info", "admin", f"Replaced {key} configuration")
        save_store(store)
        self.send_json(store[key])

    def replace_settings(self, body: dict) -> None:
        settings = body.get("settings")
        if not isinstance(settings, dict):
            return self.send_error_json(HTTPStatus.BAD_REQUEST, "Expected settings object")
        store = load_store()
        store["settings"] = settings
        self.append_system_log(store, "info", "admin", "Updated system settings")
        save_store(store)
        self.send_json(store["settings"])

    def create_user(self, body: dict) -> None:
        email = body.get("email", "").strip()
        if not email:
            return self.send_error_json(HTTPStatus.BAD_REQUEST, "email is required")
        store = load_store()
        if any(user.get("email") == email and user.get("status") != "deleted" for user in store["users"]):
            return self.send_error_json(HTTPStatus.CONFLICT, "email already exists")
        user = {
            "id": "usr_" + secrets.token_hex(6),
            "name": body.get("name") or email.split("@")[0],
            "email": email,
            "locale": body.get("locale", store["settings"].get("defaultLocale", "zh-Hans")),
            "plan": body.get("plan", "Lifestyle Cut"),
            "mode": body.get("mode", "lifestyle"),
            "status": "active",
            "subscription": body.get("subscription", "free"),
            "registeredAt": utc_now(),
            "deletedAt": None,
            "deleteReason": None,
            "createdAt": utc_now(),
            "lastSeenAt": None,
        }
        store["users"].append(user)
        self.append_system_log(store, "info", "admin", f"Created user {email}")
        save_store(store)
        self.send_json(user, HTTPStatus.CREATED)

    def delete_user(self, user_id: str) -> None:
        store = load_store()
        for user in store["users"]:
            if user.get("id") == user_id:
                user["status"] = "deleted"
                user["deletedAt"] = utc_now()
                user["deleteReason"] = "admin_action"
                self.append_system_log(store, "warning", "admin", f"Deleted user {user.get('email')}")
                save_store(store)
                return self.send_json(user)
        return self.send_error_json(HTTPStatus.NOT_FOUND, "User not found")

    def patch_user(self, user_id: str, body: dict) -> None:
        store = load_store()
        for user in store["users"]:
            if user.get("id") == user_id:
                for key in ("name", "email", "locale", "plan", "mode", "status", "subscription"):
                    if key in body:
                        user[key] = body[key]
                user["updatedAt"] = utc_now()
                self.append_system_log(store, "info", "admin", f"Updated user {user.get('email')}")
                save_store(store)
                return self.send_json(user)
        return self.send_error_json(HTTPStatus.NOT_FOUND, "User not found")

    def create_record(self, key: str, body: dict, prefix: str) -> None:
        store = load_store()
        record = dict(body)
        record["id"] = record.get("id") or f"{prefix}_" + secrets.token_hex(6)
        record["createdAt"] = record.get("createdAt") or utc_now()
        record["updatedAt"] = record.get("updatedAt") or record["createdAt"]
        store[key].append(record)
        self.append_system_log(store, "info", "admin", f"Created {key} record {record['id']}")
        save_store(store)
        self.send_json(record, HTTPStatus.CREATED)

    def patch_record(self, key: str, record_id: str, body: dict) -> None:
        store = load_store()
        for record in store[key]:
            if record.get("id") == record_id:
                record.update(body)
                record["updatedAt"] = utc_now()
                self.append_system_log(store, "info", "admin", f"Updated {key} record {record_id}")
                save_store(store)
                return self.send_json(record)
        return self.send_error_json(HTTPStatus.NOT_FOUND, "Record not found")

    def delete_record(self, key: str, record_id: str) -> None:
        store = load_store()
        before = len(store[key])
        store[key] = [record for record in store[key] if record.get("id") != record_id]
        if len(store[key]) == before:
            return self.send_error_json(HTTPStatus.NOT_FOUND, "Record not found")
        self.append_system_log(store, "warning", "admin", f"Deleted {key} record {record_id}")
        save_store(store)
        self.send_json({"ok": True, "deleted": record_id})

    def append_system_log(self, store: dict, level: str, source: str, message: str) -> None:
        store.setdefault("systemLogs", []).append({
            "id": "evt_" + secrets.token_hex(6),
            "level": level,
            "source": source,
            "message": message,
            "createdAt": utc_now(),
        })

    def serve_file(self, path: Path) -> None:
        if not path.exists() or not path.is_file():
            return self.send_error_json(HTTPStatus.NOT_FOUND, "File not found")
        content_type = "text/html; charset=utf-8"
        if path.suffix == ".css":
            content_type = "text/css; charset=utf-8"
        elif path.suffix == ".js":
            content_type = "application/javascript; charset=utf-8"
        data = path.read_bytes()
        self.send_response(HTTPStatus.OK)
        self.add_common_headers(content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


def main() -> None:
    host = os.environ.get("MEALKIND_HOST", "127.0.0.1")
    port = int(os.environ.get("MEALKIND_PORT", "8787"))
    server = ThreadingHTTPServer((host, port), MealKindHandler)
    print(f"MealKind backend running at http://{host}:{port}/admin")
    print("Default super admin: admin / mealkind-admin")
    server.serve_forever()


if __name__ == "__main__":
    main()
