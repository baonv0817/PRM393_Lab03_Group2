"""Client ARTEMIS dùng chung cho cả bộ test.

ARTEMIS chạy như một máy chủ cục bộ (xem e2e_test/README.md); test gọi nó bằng `artemis_client`.
Cấu hình bằng biến môi trường (không commit khoá hay tài khoản):

  ARTEMIS_BASE_URL       mặc định http://127.0.0.1:8000
  ARTEMIS_DEVICE_SERIAL  số seri thiết bị (`adb devices`); bắt buộc
  ARTEMIS_PROFILE        flash (hồi quy, mặc định) hoặc pro (phiên khám phá)
  ARTEMIS_TRACES_DIR     thư mục `traces` của máy chủ ARTEMIS (cùng máy), ví dụ C:/src/artemis/traces; nơi test đọc
                         giá trị agent báo lại (xem `_final_report`)
  TEST_GOOGLE_ACCOUNT    tài khoản Google dành riêng cho test (chỉ dùng cho bước chọn tài khoản)
  Khoá API mô hình nằm trong .env của máy chủ ARTEMIS, không nằm trong repo này.
"""
import ast
import json
import os
import pathlib
import re

import pytest
import pytest_asyncio
from artemis_client import ArtemisClient

BASE_URL = os.environ.get("ARTEMIS_BASE_URL", "http://127.0.0.1:8000")
PROFILE = os.environ.get("ARTEMIS_PROFILE", "flash")


TRACES_DIR = os.environ.get("ARTEMIS_TRACES_DIR")


def _final_report(task_id: str) -> str | None:
    """Lời báo cuối của agent (`explanation` của `report_task_status`) đọc từ nhật ký phiên của máy chủ ARTEMIS.

    Ở bản ARTEMIS đã ghim, API của phiên không trả kết quả có cấu trúc (hồ sơ flash không chạy bước Outputter,
    và hồ sơ pro cũng không đưa nó vào `/api/sessions/{id}`), nên `result.output` luôn rỗng. Máy chủ ghi mọi
    lệnh agent gọi vào `traces/<mã phiên>/stdout.log`, trong đó có lời báo cuối ở dạng từ điển Python.
    """
    if not TRACES_DIR:
        return None
    log = pathlib.Path(TRACES_DIR) / task_id / "stdout.log"
    if not log.exists():
        return None
    text = log.read_text(encoding="utf-8", errors="replace")
    start = text.rfind("report_task_status(")
    if start == -1:
        return None
    match = re.search(r"report_task_status\((\{.*?\})\)\s*\n", text[start:], re.S)
    if not match:
        return None
    try:
        return str(ast.literal_eval(match.group(1)).get("explanation", ""))
    except (ValueError, SyntaxError):
        return None


def _as_json(report: str) -> dict | str:
    """Phần JSON trong lời báo (bỏ rào ```), hoặc nguyên văn lời báo nếu không phải JSON hợp lệ."""
    first, last = report.find("{"), report.rfind("}")
    if first != -1 and last > first:
        try:
            return json.loads(report[first : last + 1])
        except json.JSONDecodeError:
            pass
    return report


class Artemis:
    """Bọc ArtemisClient: gắn thiết bị và hồ sơ, và lấy lại giá trị agent báo (xem `_final_report`)."""

    def __init__(self, client: ArtemisClient, serial: str):
        self._client = client
        self._serial = serial

    async def run(self, instruction: str, *, expected_output: str | None = None, profile: str | None = None):
        """Chạy một chỉ dẫn. `expected_output` mô tả giá trị agent phải báo lại
        (ví dụ "JSON với khoá item_count là số nguyên"); nó được gắn vào chỉ dẫn để agent ghi đúng một đối tượng
        JSON trong lời báo cuối, và `result.output` là đối tượng đó (hoặc nguyên văn lời báo nếu không đọc được)."""
        goal = instruction
        if expected_output is not None:
            goal += (
                "\n\nKhi báo hoàn thành (report_task_status), phần explanation chỉ gồm MỘT đối tượng JSON hợp lệ, "
                f"không thêm chữ nào khác, theo mô tả: {expected_output}"
            )
        result = await self._client.run(
            goal,
            profile=profile or PROFILE,
            device_serial=self._serial,
            expected_output=expected_output,
            enable_outputter=expected_output is not None,
        )
        if expected_output is not None and result.output is None:
            report = _final_report(result.task_id)
            if report is not None:
                try:
                    result.output = _as_json(report)
                except AttributeError:  # TaskResult bất biến: dựng lại bản có `output`
                    import dataclasses

                    result = dataclasses.replace(result, output=_as_json(report))
        return result


@pytest_asyncio.fixture
async def artemis():
    serial = os.environ.get("ARTEMIS_DEVICE_SERIAL")
    if not serial:
        pytest.skip("Chưa đặt ARTEMIS_DEVICE_SERIAL (chạy `adb devices`)")
    client = ArtemisClient(BASE_URL, token=os.environ.get("ARTEMIS_TOKEN"), device_serial=serial, default_profile=PROFILE)
    try:
        await client.health()
    except Exception as exc:  # máy chủ ARTEMIS chưa chạy
        pytest.skip(f"Không kết nối được máy chủ ARTEMIS tại {BASE_URL}: {exc}")
    return Artemis(client, serial)
