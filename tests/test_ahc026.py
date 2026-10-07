"""Usage: python tests/test_ahc026.py EXE [OFFICIAL_TOOLS_DIRECTORY] [--partial]"""
from pathlib import Path
import random
import re
import subprocess
import sys
import tempfile
import time


def parse(data):
    values = list(map(int, data.split()))
    n, m = values[:2]
    stacks = [values[2 + i * (n // m):2 + (i + 1) * (n // m)] for i in range(m)]
    assert sorted(sum(stacks, [])) == list(range(1, n + 1))
    return n, m, stacks


def validate(data, output):
    n, m, stacks = parse(data)
    operations = output.splitlines()
    assert len(operations) <= 5000
    target, cost = 1, 0
    for line in operations:
        box, destination = map(int, line.split())
        assert target <= box <= n and 0 <= destination <= m
        source = next((i for i, row in enumerate(stacks) if box in row), None)
        assert source is not None
        if destination == 0:
            assert box == target and stacks[source][-1] == box
            stacks[source].pop()
            target += 1
        else:
            cut = stacks[source].index(box)
            block = stacks[source][cut:]
            del stacks[source][cut:]
            stacks[destination - 1].extend(block)
            cost += len(block) + 1
    assert target == n + 1 and not any(stacks)
    return max(1, 10000 - cost)


def check(exe, data, label, official=None, input_path=None):
    start = time.perf_counter()
    run = subprocess.run([exe], input=data, text=True, capture_output=True,
        timeout=10, check=True)
    elapsed = time.perf_counter() - start
    score = validate(data, run.stdout)
    assert run.stderr.strip() == f"score: {score}"
    if official:
        with tempfile.TemporaryDirectory(prefix="ahc026-") as directory:
            output_path = Path(directory) / "out.txt"
            output_path.write_text(run.stdout, encoding="utf-8")
            oracle = subprocess.run([str(official / "vis.exe"), str(input_path), str(output_path)],
                cwd=directory, text=True, capture_output=True, check=True)
            match = re.search(r"Score\s*=\s*(\d+)", oracle.stdout + oracle.stderr)
            assert match and int(match[1]) == score, oracle.stdout + oracle.stderr
    print(f"{label}: operations={len(run.stdout.splitlines())}, score={score}, {elapsed:.3f}s")


if __name__ == "__main__":
    exe = str(Path(sys.argv[1]).resolve())
    # 搬出のみ、長い移動、空の山、ランダムな配置を含む小規模テスト。
    for seed in range(20):
        values = list(range(1, 7))
        random.Random(seed).shuffle(values)
        data = "6 3\n" + "\n".join(" ".join(map(str, values[i:i + 2]))
            for i in range(0, 6, 2)) + "\n"
        check(exe, data, f"tiny seed={seed}")
    check(exe, "6 3\n2 1\n4 3\n6 5\n", "removal only")
    check(exe, "9 3\n1 2 3\n4 5 6\n7 8 9\n", "long transfer")
    if len(sys.argv) > 2 and sys.argv[2] != "--partial":
        official = Path(sys.argv[2]).resolve()
        for seed in range(10):
            path = official / "in" / f"{seed:04d}.txt"
            check(exe, path.read_text(encoding="utf-8"), f"official {seed:04d}",
                official=official, input_path=path)
