"""Client ARTEMIS dùng chung cho cả bộ test.

ARTEMIS chạy như một máy chủ cục bộ (xem e2e_test/README.md); test gọi nó bằng `artemis_client`.
Cấu hình bằng biến môi trường (không commit khoá hay tài khoản):

  ARTEMIS_BASE_URL       mặc định http://127.0.0.1:8000
  ARTEMIS_DEVICE_SERIAL  số seri thiết bị (`adb devices`); bắt buộc
  ARTEMIS_PROFILE        flash (hồi quy, mặc định) hoặc pro (phiên khám phá)
  TEST_GOOGLE_ACCOUNT    tài khoản Google dành riêng cho test (chỉ dùng cho bước chọn tài khoản)
  Khoá API mô hình nằm trong .env của máy chủ ARTEMIS, không nằm trong repo này.
"""
import os

import pytest
import pytest_asyncio
from artemis_client import ArtemisClient

BASE_URL = os.environ.get("ARTEMIS_BASE_URL", "http://127.0.0.1:8000")
PROFILE = os.environ.get("ARTEMIS_PROFILE", "flash")


class Artemis:
    """Bọc ArtemisClient: gắn thiết bị và hồ sơ, luôn yêu cầu kết quả có cấu trúc."""

    def __init__(self, client: ArtemisClient, serial: str):
        self._client = client
        self._serial = serial

    async def run(self, instruction: str, *, expected_output: str | None = None, profile: str | None = None):
        """Chạy một chỉ dẫn. `expected_output` mô tả giá trị agent phải báo lại
        (ví dụ "JSON với khoá item_count là số nguyên") để test so sánh với kết quả mong đợi."""
        return await self._client.run(
            instruction,
            profile=profile or PROFILE,
            device_serial=self._serial,
            expected_output=expected_output,
            enable_outputter=expected_output is not None,
        )


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
