
include ../header



# 0..<maの範囲の直積
iterator product(ma, repeat: int): seq[int]=
    var res: seq[int] = newSeq[int](repeat)
    var i: int = 0
    block loop:
        while i<repeat:
            yield res
            i = 0
            while res[i]>=ma-1:
                res[i] = 0
                i.inc
                if i>=repeat: 
                    break loop
            res[i].inc
