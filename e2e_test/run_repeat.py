"""Chạy bộ test ARTEMIS nhiều lần và in bảng tỉ lệ pass cho mục 3 của docs/test-plan.md.

  uv run python run_repeat.py              # 3 lần, mọi test
  uv run python run_repeat.py -n 5 -k tc03 # 5 lần, chỉ các test khớp "tc03"
  uv run python run_repeat.py -k tc05 --start 6   # ghi run-6…run-8, giữ nguyên các run cũ

Mỗi lần chạy ghi một báo cáo JUnit vào evidence/artemis/run-<n>.xml; bảng Markdown được in ra màn hình và
ghi vào evidence/artemis/pass-rate.md. Test bị bỏ qua (skip) không tính vào tỉ lệ. Script từ chối ghi đè
một run-<n>.xml đã có; dùng --start để chọn số tiếp theo.
"""
import argparse
import collections
import os
import pathlib
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE.parent / "evidence" / "artemis"
PACKAGE = "vn.edu.fpt.breakbite"


def restart_app() -> None:
    """Tắt và mở lại app để lượt chạy bắt đầu ở Trang chủ (hoặc màn đăng nhập), không ở màn lượt trước để lại."""
    serial = os.environ["ARTEMIS_DEVICE_SERIAL"]
    adb = ["adb", "-s", serial, "shell"]
    subprocess.run([*adb, "am", "force-stop", PACKAGE], check=False)
    subprocess.run([*adb, "monkey", "-p", PACKAGE, "-c", "android.intent.category.LAUNCHER", "1"],
                   check=False, capture_output=True)
    time.sleep(5)


def run_once(index: int, keyword: str | None) -> pathlib.Path:
    report = OUT / f"run-{index}.xml"
    cmd = [sys.executable, "-m", "pytest", "-q", f"--junitxml={report}"]
    if keyword:
        cmd += ["-k", keyword]
    subprocess.run(cmd, cwd=HERE, check=False)
    return report


def collect(reports: list[pathlib.Path]) -> dict[str, dict]:
    stats: dict[str, dict] = collections.defaultdict(lambda: {"pass": 0, "fail": 0, "skip": 0, "time": 0.0})
    for report in reports:
        if not report.exists():
            continue
        for case in ET.parse(report).getroot().iter("testcase"):
            row = stats[case.get("name", "?")]
            if case.find("skipped") is not None:
                row["skip"] += 1
                continue
            row["time"] += float(case.get("time", 0))
            failed = case.find("failure") is not None or case.find("error") is not None
            row["fail" if failed else "pass"] += 1
    return stats


def table(stats: dict[str, dict]) -> str:
    lines = ["| Test | Runs | Pass rate | Average time | Notes |", "|---|---|---|---|---|"]
    for name in sorted(stats):
        row = stats[name]
        runs = row["pass"] + row["fail"]
        if runs == 0:
            lines.append(f"| {name} | 0 | - | - | skipped {row['skip']}x |")
            continue
        rate = f"{row['pass']}/{runs} ({100 * row['pass'] // runs}%)"
        note = "flaky: find the cause" if 0 < row["pass"] < runs else ("fails" if row["pass"] == 0 else "")
        lines.append(f"| {name} | {runs} | {rate} | {row['time'] / runs:.0f} s | {note} |")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("-n", "--runs", type=int, default=3)
    parser.add_argument("-k", "--keyword")
    parser.add_argument("--start", type=int, default=1, help="số của run đầu tiên (run-<start>.xml)")
    parser.add_argument("--restart-app", action="store_true", help="tắt và mở lại app trước mỗi lượt")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    indices = range(args.start, args.start + args.runs)
    taken = [f"run-{i}.xml" for i in indices if (OUT / f"run-{i}.xml").exists()]
    if taken:
        sys.exit(f"Đã có {', '.join(taken)} trong {OUT}; chọn --start khác để không ghi đè bằng chứng cũ.")
    reports = []
    for i in indices:
        if args.restart_app:
            restart_app()
        reports.append(run_once(i, args.keyword))
    result = table(collect(reports))
    (OUT / "pass-rate.md").write_text(result + "\n", encoding="utf-8")
    print(result)


if __name__ == "__main__":
    main()
