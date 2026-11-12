"""Phiên kiểm thử khám phá (exploratory) bằng ARTEMIS hồ sơ Pro, mục 4 của docs/test-plan.md.

Không có kịch bản: agent nhận một charter (vùng cần khám phá và cách "phá"), tự đi trong app và báo lại các vấn đề
thấy được. Chạy các charter nối tiếp nhau cho tới khi đủ thời lượng tối thiểu (mặc định 15 phút), mỗi charter tối đa
`--per-charter` phút. Kết quả (thời gian, mã phiên, danh sách vấn đề) ghi vào evidence/artemis/exploratory-<ngày>.json.

  uv run python exploratory.py                 # tối thiểu 15 phút
  uv run python exploratory.py --minutes 20

Cần các biến môi trường như conftest.py (ARTEMIS_DEVICE_SERIAL, ARTEMIS_TRACES_DIR); app đã đăng nhập bằng tài khoản
khách test, đang ở Trang chủ.
"""
import argparse
import ast
import asyncio
import datetime as dt
import json
import os
import pathlib
import re
import sqlite3
import sys
import time

from artemis_client import ArtemisClient
from artemis_client.errors import TaskTimeoutError

from conftest import BASE_URL, _as_json, _final_report

OUT = pathlib.Path(__file__).resolve().parent.parent / "evidence" / "artemis"
PACKAGE = "vn.edu.fpt.breakbite"

REPORT = (
    "\n\nKhi xong (report_task_status), phần explanation chỉ gồm MỘT đối tượng JSON hợp lệ: "
    '{"areas_tried": [các màn/chức năng đã thử], "issues": [{"screen": tên màn, "what": điều đã làm, '
    '"problem": điều sai hoặc khó dùng thấy được, "severity": "high" | "medium" | "low"}]}. '
    "Chỉ ghi vấn đề thật sự nhìn thấy trên màn hình; nếu không thấy vấn đề nào thì issues là danh sách rỗng."
)

CHARTERS = [
    "Bạn là sinh viên lần đầu dùng BreakBite (app đặt đồ ăn tại kiosk trong trường), app đã đăng nhập và đang ở "
    "Trang chủ. Khám phá TỰ DO trong khoảng 10 phút, không theo kịch bản, để tìm lỗi hoặc chỗ khó dùng: duyệt Thực "
    "đơn và các danh mục, mở chi tiết vài món và đổi tuỳ chọn, thêm/bớt món nhiều lần liên tiếp, mở giỏ hàng và "
    "thử mã giảm giá, tìm kiếm với từ lạ (dấu, ký tự đặc biệt, chuỗi rất dài), mở thông báo, đổi kiosk rồi đổi lại "
    "Kiosk Q9 · Tầng 2. Dùng nút Back của hệ thống ở nhiều màn khác nhau. KHÔNG đặt đơn và KHÔNG đăng xuất.",
    "Bạn là sinh viên đã đặt vài đơn với BreakBite, app đã đăng nhập và đang ở Trang chủ. Khám phá TỰ DO trong "
    "khoảng 10 phút, không theo kịch bản, các màn còn lại: tab Đơn hàng (đang xử lý và lịch sử, mở chi tiết vài đơn, "
    "xem mã QR nhận món, xuất biên nhận), tab Cá nhân (hồ sơ sinh viên với dữ liệu sai rồi đúng, phương thức thanh "
    "toán, khu demo Firebase, tệp của tôi, cài đặt). Thử nhập dữ liệu sai, chạm nhanh nhiều lần, quay lại giữa chừng. "
    "KHÔNG huỷ đơn của người khác, KHÔNG đăng xuất.",
]


def session_log(task_id: str) -> dict:
    """What the Pro agent did and wrote down: its step summaries (traces/data_engine.db) and its last saved notes.

    The Pro profile ends through its planner and checker instead of `report_task_status`, so there is often no
    final JSON; the steps and notes are the record of the session.
    """
    traces = os.environ.get("ARTEMIS_TRACES_DIR")
    if not traces:
        return {}
    root = pathlib.Path(traces)
    steps: list[str] = []
    try:
        db = sqlite3.connect(f"file:{root / 'data_engine.db'}?mode=ro", uri=True)
        rows = db.execute("select step_number, summary from steps where session_id = ? order by step_number", (task_id,))
        steps = [f"{n}. {(s or '').strip()}" for n, s in rows]
        db.close()
    except sqlite3.Error:
        pass
    notes: dict[str, str] = {}
    log = root / task_id / "stdout.log"
    if log.exists():
        text = log.read_text(encoding="utf-8", errors="replace")
        for raw in re.findall(r"save_note with args: (\{.*?\})\n", text):
            try:
                note = ast.literal_eval(raw)
                notes[note["key"]] = note["content"]
            except (ValueError, SyntaxError, KeyError):
                continue
    return {"steps": steps, "notes": notes}


async def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--minutes", type=float, default=15, help="thời lượng tối thiểu của cả phiên")
    parser.add_argument("--per-charter", type=float, default=15, help="thời gian tối đa cho mỗi charter (phút)")
    args = parser.parse_args()
    serial = os.environ["ARTEMIS_DEVICE_SERIAL"]
    client = ArtemisClient(BASE_URL, token=os.environ.get("ARTEMIS_TOKEN"), device_serial=serial, default_profile="pro")
    started = time.monotonic()
    session = {"date": dt.datetime.now().isoformat(timespec="seconds"), "profile": "pro", "charters": []}
    for index, charter in enumerate(CHARTERS * 2):
        if index >= len(CHARTERS) and (time.monotonic() - started) / 60 >= args.minutes:
            break
        t0 = time.monotonic()
        handle = await client.submit(charter + REPORT, profile="pro", device_serial=serial, locked_app_package=PACKAGE)
        try:
            result = await client.wait_for_task(handle.task_id, timeout=args.per_charter * 60)
            status = result.status
        except TaskTimeoutError:
            await client.stop(handle.task_id)  # time box reached: stop the agent, keep what it logged
            result, status = None, "timeboxed"
        report = (result.output if result else None) or _final_report(handle.task_id)
        entry = {
            "charter": index % len(CHARTERS) + 1,
            "task_id": handle.task_id,
            "status": status,
            "minutes": round((time.monotonic() - t0) / 60, 1),
            "report": _as_json(report) if isinstance(report, str) else report,
            **session_log(handle.task_id),
        }
        session["charters"].append(entry)
        print(json.dumps(entry, ensure_ascii=False, indent=1), flush=True)
    session["total_minutes"] = round((time.monotonic() - started) / 60, 1)
    out = OUT / f"exploratory-{dt.date.today().isoformat()}.json"
    out.write_text(json.dumps(session, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"total {session['total_minutes']} min -> {out}")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    asyncio.run(main())
