# nim cpp -r --outdir:build/tests tests/test_range_query.nim
include ../src/examples/lazysegtree/affine_sum_min_max
include ../src/lib/tree/kd_tree

# AOJのクエリ形式をそのまま再生し、添字変換・初期値も確認する。
proc replay(kind: char, n: int, queries: string): seq[int] =
    let initial = if kind in {'A', 'D', 'F'}: 2147483647 else: 0
    let offset = if kind in {'B', 'E', 'G'}: 1 else: 0
    var sg = AffineSumMinMaxSeg.init(newSeqWith(n, leaf(initial)))
    for line in queries.splitLines():
        let q = line.splitWhitespace().mapIt(parseInt(it))
        let l = q[1] - offset
        if q[0] == 0:
            case kind
            of 'A': sg.set(l, leaf(q[2]))
            of 'B': sg.apply(l, (a: 1, b: q[2]))
            else:
                let r = q[2] - offset + 1
                let a = if kind in {'D', 'F', 'I'}: 0 else: 1
                sg.apply(l..<r, (a: a, b: q[3]))
        elif kind in {'D', 'E'}:
            result.add(sg.get(l).sum)
        else:
            let node = sg.prod(l..<(q[2] - offset + 1))
            result.add(if kind in {'A', 'F', 'H'}: node.mn else: node.sum)

doAssert replay('A', 3, "0 0 1\n0 1 2\n0 2 3\n1 0 2\n1 1 2") == @[1, 2]
doAssert replay('A', 1, "1 0 0\n0 0 5\n1 0 0") == @[2147483647, 5]
doAssert replay('B', 3, "0 1 1\n0 2 2\n0 3 3\n1 1 2\n1 2 2") == @[3, 2]
doAssert replay('D', 3, "0 0 1 1\n0 1 2 3\n0 2 2 2\n1 0\n1 1") == @[1, 3]
doAssert replay('D', 1, "1 0\n0 0 0 5\n1 0") == @[2147483647, 5]
doAssert replay('E', 3, "0 1 2 1\n0 2 3 2\n0 3 3 3\n1 2\n1 3") == @[3, 5]
doAssert replay('E', 4, "1 2\n0 1 4 1\n1 2") == @[0, 1]
doAssert replay('F', 3, "0 0 1 1\n0 1 2 3\n0 2 2 2\n1 0 2\n1 1 2") == @[1, 2]
doAssert replay('F', 1, "1 0 0\n0 0 0 5\n1 0 0") == @[2147483647, 5]
doAssert replay('G', 3, "0 1 2 1\n0 2 3 2\n0 3 3 3\n1 1 2\n1 2 3") == @[4, 8]
doAssert replay('G', 4, "1 1 4\n0 1 4 1\n1 1 4") == @[0, 4]
let hiQueries = "0 1 3 1\n0 2 4 -2\n1 0 5\n1 0 1\n0 3 5 3\n1 3 4\n1 0 5"
doAssert replay('H', 6, hiQueries) == @[-2, 0, 1, -1]
doAssert replay('I', 6, hiQueries) == @[-5, 1, 6, 8]
let sampleTree = initKdTree(@[[2, 1], [2, 2], [4, 2], [6, 2], [3, 3], [5, 4]])
doAssert sampleTree.rangeSearch([2, 0], [4, 4]) == @[0, 1, 2, 4]
doAssert sampleTree.rangeSearch([4, 2], [10, 5]) == @[2, 3, 5]
echo "DSL_2_A-I: all 14 sample cases passed"

var rng = initRand(20260924)
for n in [1, 2, 5, 31]:
    var values = newSeq[int](n)
    var sg = AffineSumMinMaxSeg.init(values.mapIt(leaf(it)))
    for step in 0..<5000:
        let l = rng.rand(n)
        let r = rng.rand(l..n)
        let value = rng.rand(-100..100)
        case rng.rand(4)
        of 0:
            sg.apply(l..<r, (a: 1, b: value))
            for i in l..<r: values[i] += value
        of 1:
            sg.apply(l..<r, (a: 0, b: value))
            for i in l..<r: values[i] = value
        of 2:
            sg.apply(l..<r, (a: -1, b: value))
            for i in l..<r: values[i] = -values[i] + value
        of 3:
            let i = rng.rand(n-1)
            sg.set(i, leaf(value))
            values[i] = value
        else: discard
        let node = sg.prod(l..<r)
        doAssert node.len == r-l
        if l == r: doAssert node == e()
        else:
            doAssert node.sum == values[l..<r].foldl(a+b, 0)
            doAssert node.mn == min(values[l..<r])
            doAssert node.mx == max(values[l..<r])
        let i = rng.rand(n-1)
        doAssert sg.get(i) == leaf(values[i])
    sg.apply(0..<n, (a: 0, b: 2147483647))
    doAssert sg.allProd().sum == n * 2147483647
echo "1D: 20000 mixed operations passed"

for n in [0, 1, 5, 100]:
    var points = newSeq[array[2, int]](n)
    for p in points.mitems:
        p = [rng.rand(-5..5), rng.rand(-5..5)]
    let tree = initKdTree(points)
    for _ in 0..<1000:
        let lo = [rng.rand(-6..6), rng.rand(-6..6)]
        let hi = [rng.rand(lo[0]..6), rng.rand(lo[1]..6)]
        var expected: seq[int]
        for i, p in points:
            if p[0] in lo[0]..hi[0] and p[1] in lo[1]..hi[1]: expected.add(i)
        doAssert tree.rangeSearch(lo, hi) == expected
echo "2D: 4000 rectangles passed (empty sets, duplicates, boundaries)"
