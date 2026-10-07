include ../../lib/collections/sorted_containers

# 重複なしの集合。常に昇順、添字・順位は0始まり。
var s = initSqrtSet[int]()
for x in [30, 10, 20, 20]:
    s.incl(x)
echo toSeq(s.items)       # @[10, 20, 30]
echo s.len               # 3
echo 20 in s             # true
echo s.incl(20)          # false（既に存在）

# 順位から値を取得。空でないことを確認する。
if s.len > 0:
    echo s[0]              # 10（最小値）
    echo s[s.len - 1]      # 30（最大値）
echo s[1]                # 20（小さい方から2番目）

# lowerBound: x以上の最初の順位、upperBound: xより大きい最初の順位。
# 該当なしはlen。返り値は値そのものではない。
echo s.lowerBound(20)    # 1
echo s.upperBound(20)    # 2
let pos = s.lowerBound(25)
if pos < s.len:
    echo s[pos]            # 30（25以上の最小値）
if pos > 0:
    echo s[pos - 1]        # 20（25未満の最大値）
doAssert s.lowerBound(100) == s.len

echo s.excl(20)          # true（削除できた）
echo s.excl(20)          # false（存在しない）
doAssert toSeq(s.items) == @[10, 30]
s.clear()
doAssert s.len == 0
