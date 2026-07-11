
include ../header



# 0..<maの範囲の重複なし組み合わせ
when not declared CombinationsModule:
    const CombinationsModule = true
    iterator combinations(ma, r: int): seq[int] =
        if r == 0 and ma >= 0:
            yield @[]
        elif ma >= 0 and r > 0 and r <= ma:
            var res = (0..<r).toSeq()
            while true:
                yield res
                var i = r - 1
                while i >= 0 and (res[i] == ma - r + i):
                    i.dec
                if i < 0: break
                res[i].inc
                for j in i+1 ..< r:
                    res[j] = res[j - 1] + 1
