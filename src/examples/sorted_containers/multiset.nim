include ../../lib/collections/sorted_containers

# 重複ありの集合。len・添字・順位には重複分も含まれる。
var s = initSqrtMultiSet[int]()
for x in [30, 10, 20, 20, 20]:
    s.add(x)
echo toSeq(s.items)       # @[10, 20, 20, 20, 30]
echo s.len               # 5
echo 20 in s             # true
echo s.count(20)         # 3
echo s[2]                # 20（小さい方から3番目）
if s.len > 0:
    echo s[0]              # 10
    echo s[s.len - 1]      # 30

echo s.lowerBound(20)    # 1（20未満の個数）
echo s.upperBound(20)    # 4（20以下の個数）
# 値の範囲[lo, hi)に入る要素数。
let lo = 15
let hi = 30
echo s.lowerBound(hi) - s.lowerBound(lo) # 3

echo s.remove(20)        # true（1個だけ削除）
doAssert s.count(20) == 2
echo s.removeAll(20)     # 2（すべて削除し、削除数を返す）
echo s.remove(20)        # false（存在しない）
doAssert toSeq(s.items) == @[10, 30]
s.clear()
doAssert s.len == 0
