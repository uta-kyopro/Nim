"""Compare the C++-backed 128bit integers against Python's integers.

Only signed operations whose mathematical result fits Int128 are tested.
Build products are created below build/int128_validation and removed afterward.
"""
import os
from pathlib import Path
import random
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MASK = (1 << 128) - 1


def main():
    rng = random.Random(20261015)
    cases = []
    for _ in range(200):
        a = rng.getrandbits(62) * rng.choice([-1, 1])
        b = (rng.getrandbits(62) or 1) * rng.choice([-1, 1])
        cases.append(("s", a, b, rng.randrange(64)))
        cases.append(("u", rng.getrandbits(128), rng.getrandbits(128) or 1, rng.randrange(128)))
    cases += [("s", 0, 1, 0), ("u", 0, MASK, 127), ("u", MASK, MASK, 127)]
    expected = []
    for kind, a, b, shift in cases:
        q = abs(a) // abs(b)
        if (a < 0) != (b < 0):
            q = -q
        values = [a + b, a - b, a * b, q, a - q*b,
                  a & b, a | b, a ^ b, ~a, a << shift, a >> shift]
        if kind == "u":
            values = [value & MASK for value in values]
        values.append((a > b) - (a < b))
        expected.append(" ".join(map(str, values)))
    build_root = (ROOT / "build" / "int128_validation").resolve()
    if not build_root.is_relative_to(ROOT.resolve()):
        raise RuntimeError("Build directory must stay inside the repository")
    build_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="differential-", dir=build_root) as work:
        work = Path(work)
        for mode in ("debug", "release"):
            binary = work / (mode + (".exe" if os.name == "nt" else ""))
            command = ["nim", "cpp", f"-d:{mode}", "--hints:off", "--warnings:off",
                       f"--nimcache:{work / (mode + '_cache')}", f"--out:{binary}",
                       str(ROOT / "tests/int128_probe.nim")]
            if os.name == "nt":
                command.insert(2, "--passL:-static")
            subprocess.run(command, cwd=ROOT, check=True, timeout=60)
            data = "".join(f"{kind} {a} {b} {shift}\n" for kind, a, b, shift in cases)
            result = subprocess.run([str(binary)], input=data, text=True, capture_output=True,
                                    check=True, timeout=30)
            actual = result.stdout.splitlines()
            if actual != expected:
                for case, got, want in zip(cases, actual, expected):
                    if got != want:
                        raise AssertionError(f"{mode}: {case}\nactual: {got}\nexpected: {want}")
                raise AssertionError(f"{mode}: unexpected output row count")
            print(f"{mode}: {len(cases)} arithmetic/bitwise/shift/comparison cases PASS", flush=True)
            for example in ("input_output", "header_input"):
                command[-1] = str(ROOT / f"src/examples/int128/{example}.nim")
                subprocess.run(command, cwd=ROOT, check=True, timeout=60)
                data = "-170141183460469231731687303715884105728 340282366920938463463374607431768211455\n"
                result = subprocess.run([str(binary)], input=data, text=True, capture_output=True,
                                        check=True, timeout=30)
                assert result.stdout.splitlines() == data.split()
                print(f"{mode}: {example} stdin/stdout PASS", flush=True)


if __name__ == "__main__":
    main()
