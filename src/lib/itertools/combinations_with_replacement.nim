
include ../header



# 0..<maの範囲の重複あり組み合わせ
when not declared CombinationsWithReplacementModule:
    const CombinationsWithReplacementModule = true
    iterator combinations_with_replacement(ma, r: int): seq[int] =
        if r == 0 and ma >= 0:
            yield @[]
        elif ma > 0 and r > 0:
            var idx = newSeq[int](r)
            while true:
                yield idx
                var i = r - 1
                while i >= 0 and idx[i] == ma - 1:
                    dec i
                if i < 0:
                    break
                let v = idx[i] + 1
                for j in i ..< r:
                    idx[j] = v
