"""Run external-package examples and compare arbitrary-precision arithmetic.

Build products live in a temporary directory and are removed on completion.
No packages are installed or modified. Requires Nim and the packages below.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import random
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
VERSIONS = {"bigints": "1.1.0", "bignum": "1.0.6", "gmp": "0.2.7",
            "regex": "0.26.3", "sat": "0.1.0"}
REGRESSION = (6277101735386680763835789123314955362437298222279840143829,
              1461501637330902918203684832716283019655932313743)


def run(command, data=None):
    result = subprocess.run(command, input=data, text=True, capture_output=True,
                            cwd=ROOT, timeout=60)
    return {"returncode": result.returncode, "stdout": result.stdout.strip(),
            "stderr": result.stderr.strip()}


def package(name, version):
    home = Path(os.environ.get("NIMBLE_DIR", Path.home() / ".nimble"))
    for directory in (home / "pkgs2", home / "pkgs"):
        matches = sorted(directory.glob(f"{name}-{version}*"))
        if matches:
            return matches[-1]
    raise RuntimeError(f"Install {name}@{version} before running this check")


def expected(a, b, backend):
    if backend == "bigints":
        q = a // b
    else:
        q = abs(a) // abs(b)
        if (a < 0) != (b < 0):
            q = -q
    return [a + b, a - b, a * b, q, a - q * b, math.gcd(a, b)]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--gmp-dll", type=Path,
                        help="Windows GMP DLL to copy as libgmp.dll for this run")
    parser.add_argument("--report", type=Path,
                        help="Optional local diagnostic JSON; save under ignored build/")
    args = parser.parse_args()
    packages = {name: package(name, version) for name, version in VERSIONS.items()}
    report = {"nim": run(["nim", "--version"])["stdout"], "platform": platform.platform(),
              "packages": {},
              "seed": 20261015, "results": []}
    if args.gmp_dll:
        report["gmp_dll_sha256"] = hashlib.sha256(args.gmp_dll.read_bytes()).hexdigest()
    for name, directory in packages.items():
        metadata = json.loads((directory / "nimblemeta.json").read_text())
        sources = sorted(directory.rglob("*.nim"))
        digest = hashlib.sha256()
        for source in sources:
            digest.update(source.relative_to(directory).as_posix().encode())
            digest.update(source.read_bytes())
        report["packages"][name] = {"version": VERSIONS[name],
            "revision": metadata["metaData"]["vcsRevision"],
            "source_sha256": digest.hexdigest()}
    rng = random.Random(report["seed"])
    cases = [(a, b) for a in [-17, -7, 0, 7, 17] for b in [-5, -3, 3, 5]]
    for _ in range(100):
        a = rng.getrandbits(rng.randint(1, 512)) * rng.choice([-1, 1])
        b = (rng.getrandbits(rng.randint(1, 256)) or 1) * rng.choice([-1, 1])
        cases.append((a, b))
    failed = False
    build_root = (ROOT / "build" / "external_examples").resolve()
    if not build_root.is_relative_to(ROOT.resolve()):
        raise RuntimeError("Build directory must remain inside the repository")
    build_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="run-", dir=build_root) as work:
        work = Path(work)
        if args.gmp_dll:
            shutil.copyfile(args.gmp_dll, work / "libgmp.dll")
        for mode in ("debug", "release"):
            def compile_source(source, name, defines=()):
                binary = work / (name + (".exe" if os.name == "nt" else ""))
                command = ["nim", "cpp", f"-d:{mode}", "--hints:off", "--warnings:off",
                           f"--nimcache:{work / (name + '_cache')}", f"--out:{binary}"]
                if os.name == "nt":
                    command.append("--passL:-static")
                command += [f"--path:{directory}" for directory in packages.values()]
                command += [f"-d:{define}" for define in defines]
                command.append(str(source))
                result = run(command)
                if result["returncode"]:
                    raise RuntimeError(f"Compilation failed: {name}\n{result['stderr']}")
                return binary

            for example in ("bigints_basic", "bignum_basic", "regex_basic", "sat_basic"):
                binary = compile_source(ROOT / f"src/examples/external/{example}.nim",
                                        example + "_" + mode)
                result = run([str(binary)])
                report["results"].append({"mode": mode, "example": example, **result})
                failed |= result["returncode"] != 0
                print(mode, example, "PASS" if not result["returncode"] else "FAIL", flush=True)
            for backend in ("bigints", "bignum"):
                binary = compile_source(ROOT / "tests/external_integer_probe.nim",
                    backend + "_probe_" + mode, ("useBignum",) if backend == "bignum" else ())
                result = run([str(binary)], "".join(f"{a} {b}\n" for a, b in cases))
                lines = result["stdout"].splitlines()
                mismatches = []
                for index, (a, b) in enumerate(cases):
                    want = " ".join(map(str, expected(a, b, backend)))
                    got = lines[index] if index < len(lines) else "<missing>"
                    if got != want:
                        mismatches.append({"a": str(a), "b": str(b),
                                           "expected": want, "actual": got})
                ok = result["returncode"] == 0 and not mismatches and len(lines) == len(cases)
                failed |= not ok
                report["results"].append({"mode": mode, "backend": backend,
                    "check": "python differential", "cases": len(cases), "passed": ok,
                    "returncode": result["returncode"], "stderr": result["stderr"],
                    "mismatches": mismatches[:5]})
                print(mode, backend, "arithmetic", "PASS" if ok else "FAIL", flush=True)
                a, b = REGRESSION
                result = run([str(binary)], f"{a} {b}\n")
                want = " ".join(map(str, expected(a, b, backend)))
                ok = result["returncode"] == 0 and result["stdout"] == want
                report["results"].append({"mode": mode, "backend": backend,
                    "check": "bigints issue 123", "passed": ok, **result})
                failed |= not ok
                print(mode, backend, "issue123", "PASS" if ok else "FAIL", flush=True)
                # Run each native-integer conversion separately: a defect must not
                # prevent subsequent diagnostic inputs from being checked.
                native = []
                for value in [0, -7, 2**31, 2**32, 2**40, -(2**40), 2**63 - 1, -(2**63)]:
                    result = run([str(binary)], f"native {value}\n")
                    native.append({"input": str(value),
                        "passed": result["returncode"] == 0 and result["stdout"] == str(value),
                        **result})
                report["results"].append({"mode": mode, "backend": backend,
                    "check": "native integer conversion", "cases": native})
                failed |= any(not case["passed"] for case in native)
                print(mode, backend, "native", sum(case["passed"] for case in native),
                      "/", len(native), flush=True)
    if args.report:
        args.report.write_text(json.dumps(report, indent=4, ensure_ascii=False) + "\n",
                               encoding="utf-8")
    raise SystemExit(1 if failed else 0)


if __name__ == "__main__":
    main()
