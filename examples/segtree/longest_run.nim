
include ../../src/lib/header
import atcoder/segtree


# 同じ文字が連続する最長区間
# ---------- longest consecutive same character ----------

type LongestRunNode = tuple
    length: int      # 区間長
    left: char       # 左端の文字
    right: char      # 右端の文字
    prefix: int      # 左端から続く同一文字の長さ
    suffix: int      # 右端から続く同一文字の長さ
    best: int        # 区間内の最長連続長

proc longestRunE(): LongestRunNode =
    (
        length: 0,
        left: '\0',
        right: '\0',
        prefix: 0,
        suffix: 0,
        best: 0
    )
proc longestRunOp(a, b: LongestRunNode): LongestRunNode =
    if a.length == 0:
        return b
    if b.length == 0:
        return a

    result.length = a.length + b.length
    result.left = a.left
    result.right = b.right

    result.prefix = a.prefix
    if a.prefix == a.length and a.right == b.left:
        result.prefix += b.prefix

    result.suffix = b.suffix
    if b.suffix == b.length and a.right == b.left:
        result.suffix += a.suffix

    result.best = max(a.best, b.best)

    if a.right == b.left:
        result.best = max(result.best, a.suffix + b.prefix)


type LongestRunSeg =
    SegTreeType[LongestRunNode](longestRunOp, longestRunE)


# 1文字からNodeを作る
proc makeLongestRunNode(c: char): LongestRunNode =
    (
        length: 1,
        left: c,
        right: c,
        prefix: 1,
        suffix: 1,
        best: 1
    )


# 使用例
var S = "aabbbacca"

var base = S.mapIt(makeLongestRunNode(it))
var sgLongestRun =
    initSegTree(base, longestRunOp, longestRunE)

echo sgLongestRun.prod(0..<S.len).best
# 3

echo sgLongestRun.prod(0..<5).best
# "aabbb" -> 3


# 1文字更新
sgLongestRun.set(2, makeLongestRunNode('a'))

