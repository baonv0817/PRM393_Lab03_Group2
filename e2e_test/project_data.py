"""Đọc và ghi dữ liệu của dự án thật cho các test cần chuẩn bị hoặc dọn dữ liệu (TC-30, TC-32 … TC-34, TC-42, TC-43).

Lệnh đi qua API REST của Firestore với quyền của thành viên dự án (Security Rules không áp dụng cho quyền này): test
chỉ dùng nó để làm phần của người khác trong luồng (quầy, quản trị) hoặc để đặt điều kiện đầu và dọn sau test, đúng
các trường mà ứng dụng tự ghi. Phía ứng dụng vẫn do ARTEMIS điều khiển trên điện thoại.

Token: đặt CROSS_ROLE_ACCESS_TOKEN, hoặc đã `firebase login` trên máy chạy test (token lấy từ cấu hình của Firebase
CLI). Không có khoá hay token nào nằm trong repo.
"""
import datetime as dt
import json
import os
import pathlib
import subprocess
import urllib.request

PROJECT = "breakbite-1315b"
ROOT = f"projects/{PROJECT}/databases/(default)/documents"
DOCS = f"https://firestore.googleapis.com/v1/{ROOT}"


def access_token() -> str:
    token = os.environ.get("CROSS_ROLE_ACCESS_TOKEN")
    if token:
        return token
    # `firebase projects:list` refreshes the CLI's token, which is then read from its config file.
    subprocess.run("firebase projects:list", shell=True, capture_output=True, check=False)
    config = pathlib.Path.home() / ".config" / "configstore" / "firebase-tools.json"
    return json.loads(config.read_text(encoding="utf-8"))["tokens"]["access_token"]


def call(method: str, url: str, body: dict | None = None) -> dict:
    request = urllib.request.Request(
        url,
        data=None if body is None else json.dumps(body).encode(),
        method=method,
        headers={
            "Authorization": f"Bearer {access_token()}",
            "x-goog-user-project": PROJECT,
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read() or b"{}")


def ts(value: dict) -> dt.datetime:
    return dt.datetime.fromisoformat(value["timestampValue"].replace("Z", "+00:00"))


def iso(moment: dt.datetime) -> str:
    return moment.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def get(path: str) -> dict | None:
    """The document at `path` (for example "carts/<uid>"), or None when it does not exist."""
    try:
        return call("GET", f"{DOCS}/{path}")
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return None
        raise


def query(collection: str, filters: list[tuple[str, str, dict]], *, parent: str = "") -> list[dict]:
    """Documents of `collection` (under `parent`, a document path, if given) matching every (field, op, value)."""
    where = [{"fieldFilter": {"field": {"fieldPath": f}, "op": op, "value": v}} for f, op, v in filters]
    body = {
        "structuredQuery": {
            "from": [{"collectionId": collection}],
            "where": where[0] if len(where) == 1 else {"compositeFilter": {"op": "AND", "filters": where}},
        }
    }
    url = f"{DOCS}/{parent}:runQuery" if parent else f"{DOCS}:runQuery"
    return [row["document"] for row in call("POST", url, body) if "document" in row]


def update(name: str, fields: dict, *, delete: tuple[str, ...] = (), stamps: tuple[str, ...] = ("updatedAt",)) -> None:
    """Sets `fields` (Firestore REST values) on the existing document `name`, removes `delete`, and sets every field
    in `stamps` to the server time, as the app's `Stamp.updated()` does."""
    write = {
        "update": {"name": name if name.startswith("projects/") else f"{ROOT}/{name}", "fields": fields},
        "updateMask": {"fieldPaths": [*fields, *delete]},
        "updateTransforms": [{"fieldPath": f, "setToServerValue": "REQUEST_TIME"} for f in stamps],
        "currentDocument": {"exists": True},
    }
    call("POST", f"{DOCS}:commit", {"writes": [write]})


def remove(path: str) -> None:
    """Deletes the document at `path` if it exists."""
    call("POST", f"{DOCS}:commit", {"writes": [{"delete": f"{ROOT}/{path}"}]})
