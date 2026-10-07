"""Usage: python tests/test_ahc041.py EXE [OFFICIAL_TOOLS_DIRECTORY]"""
from pathlib import Path
import random
import re
import subprocess
import sys
import tempfile
import time


def parse(data):
    tokens = iter(map(int, data.split()))
    n, m, height = next(tokens), next(tokens), next(tokens)
    beauty = [next(tokens) for _ in range(n)]
    edges = [(next(tokens), next(tokens)) for _ in range(m)]
    return n, height, beauty, edges


def validate(data, output):
    n, height, beauty, edges = parse(data)
    parents = list(map(int, output.split()))
    assert len(parents) == n
    edge_set = {tuple(sorted(edge)) for edge in edges}
    for v, p in enumerate(parents):
        assert -1 <= p < n and p != v
        if p >= 0:
            assert tuple(sorted((v, p))) in edge_set
    depths = []
    for v in range(n):
        seen = {v}
        depth = 0
        while parents[v] >= 0:
            v = parents[v]
            assert v not in seen, "cycle"
            seen.add(v)
            depth += 1
            assert depth <= height
        depths.append(depth)
    return 1 + sum((d + 1) * a for d, a in zip(depths, beauty))


def exhaustive(data):
    # サンプルと同じ追加順で親を全列挙。小規模入力の正確な比較用。
    n, height, beauty, edges = parse(data)
    graph = [[] for _ in range(n)]
    for u, v in edges:
        graph[u].append(v)
        graph[v].append(u)
    for row in graph:
        row.sort(key=lambda v: (beauty[v], v))
    order, visited = [], set()

    def visit(v):
        visited.add(v)
        order.append(v)
        for u in graph[v]:
            if u not in visited:
                visit(u)

    for v in sorted(range(n), key=lambda v: (beauty[v], v)):
        if v not in visited:
            visit(v)
    depth = [-1] * n

    def search(turn):
        if turn == n:
            return 1 + sum((depth[v] + 1) * beauty[v] for v in range(n))
        v = order[turn]
        choices = {0} | {depth[u] + 1 for u in graph[v] if 0 <= depth[u] < height}
        best = 0
        for d in choices:
            depth[v] = d
            best = max(best, search(turn + 1))
        depth[v] = -1
        return best

    return search(0)


def check(exe, data, label, exact=False, official=None, input_path=None):
    start = time.perf_counter()
    run = subprocess.run([exe], input=data, text=True, capture_output=True,
                         timeout=10, check=True)
    elapsed = time.perf_counter() - start
    score = validate(data, run.stdout)
    assert run.stderr.strip() == f"score: {score}"
    if exact:
        assert score == exhaustive(data), label
    if official:
        with tempfile.TemporaryDirectory(prefix="ahc041-") as directory:
            output_path = Path(directory) / "out.txt"
            output_path.write_text(run.stdout, encoding="utf-8")
            oracle = subprocess.run([str(official / "vis.exe"), str(input_path), str(output_path)],
                                    cwd=directory, text=True, capture_output=True, check=True)
            match = re.search(r"Score\s*=\s*(\d+)", oracle.stdout + oracle.stderr)
            assert match and int(match[1]) == score, oracle.stdout + oracle.stderr
    print(f"{label}: score={score}, {elapsed:.3f}s")


if __name__ == "__main__":
    exe = str(Path(sys.argv[1]).resolve())
    for seed in range(20):
        rng = random.Random(seed)
        n = 1 + seed % 5
        height = seed % 4
        edges = [(u, v) for u in range(n) for v in range(u + 1, n) if rng.randrange(2)]
        data = f"{n} {len(edges)} {height}\n"
        data += " ".join(str(rng.randint(1, 100)) for _ in range(n)) + "\n"
        data += "".join(f"{u} {v}\n" for u, v in edges)
        data += "".join(f"{v} 0\n" for v in range(n))
        check(exe, data, f"tiny seed={seed}", exact=True)
    if len(sys.argv) > 2:
        official = Path(sys.argv[2]).resolve()
        for seed in range(10):
            path = official / "in" / f"{seed:04d}.txt"
            check(exe, path.read_text(encoding="utf-8"), f"official {seed:04d}",
                  official=official, input_path=path)
