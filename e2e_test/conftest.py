"""Tạo client ARTEMIS cho cả bộ test.

Cấu hình qua biến môi trường (không commit khoá hay tài khoản):
  ARTEMIS_DEVICE_SERIAL  số seri thiết bị (adb devices)
  ARTEMIS_PROFILE        flash (hồi quy) hoặc pro (khám phá)
  Khoá API mô hình theo hướng dẫn của ARTEMIS (biến môi trường).
  TEST_GOOGLE_ACCOUNT    tài khoản Google dành riêng cho test

TODO: cập nhật import và cách khởi tạo theo đúng commit ARTEMIS đã ghim trong README.
"""
import os

import pytest


@pytest.fixture
def artemis():
    # from artemis import ArtemisClient   # TODO: đường dẫn import theo commit đã ghim
    serial = os.environ.get("ARTEMIS_DEVICE_SERIAL")
    profile = os.environ.get("ARTEMIS_PROFILE", "flash")
    if not serial:
        pytest.skip("Chưa đặt ARTEMIS_DEVICE_SERIAL")
    raise NotImplementedError("Khởi tạo ArtemisClient(device=serial, profile=profile) khi đã cài ARTEMIS")
