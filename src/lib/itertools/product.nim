
include ../header



# 0..<maの範囲の直積
# 計算量: 1個の生成は O(repeat)、全列挙は O(ma^repeat * repeat)、作業領域は O(repeat)。
when not declared ProductModule:
    const ProductModule = true
    iterator product(ma, repeat: int): seq[int]=
        if repeat == 0:
            yield @[]
        elif ma > 0 and repeat > 0:
            var res = newSeq[int](max(repeat, 0))
            while true:
                yield res
                var i = 0
                while i < repeat and res[i] == ma-1:
                    res[i] = 0
                    i.inc
                if i == repeat:
                    break
                res[i].inc
