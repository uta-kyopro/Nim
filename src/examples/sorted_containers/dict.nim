include ../../lib/collections/sorted_containers

# キーの昇順を保つ辞書。[]は順位ではなくキーによるアクセス。
var d = initSqrtDict[int, string]()
d[30] = "thirty"
d[10] = "ten"
d[20] = "twenty"
d[20] = "TWENTY"          # 既存キーの値を更新
echo d.len                # 3
echo d.hasKey(20)         # true
echo d[20]                # TWENTY
echo d.getOrDefault(99, "missing") # missing（挿入はしない）

for key, value in d.pairs:
    echo key, ": ", value  # 10: ten / 20: TWENTY / 30: thirty
echo toSeq(d.keys)        # @[10, 20, 30]

# keyAtは0始まりの順位からキーを取得する。
echo d.keyAt(1)           # 20
echo d[d.keyAt(1)]        # TWENTY
echo d.lowerBound(20)     # 1（20以上の最初のキーの順位）
echo d.upperBound(20)     # 2（20より大きい最初のキーの順位）
let pos = d.lowerBound(25)
if pos < d.len:           # 該当なしはlen
    let key = d.keyAt(pos)
    echo key, ": ", d[key] # 30: thirty

# 存在しないキーを[]で読むとエラー。hasKeyかgetOrDefaultを使う。
echo d.del(20)            # true
echo d.del(20)            # false
doAssert toSeq(d.keys) == @[10, 30]
doAssert not d.hasKey(99)
d.clear()
doAssert d.len == 0
