
include ../header



# 0..<maの範囲の順列
# iterator permutations(ma, r: int): seq[int] =
#     var indices = (0..<ma).toSeq()
#     var cycles = (0..<r).toSeq().mapIt(ma-it)
#     var res = (0..<r).toSeq()
#     while true:
#         yield res
#         var i = r - 1
#         while i >= 0:
#             cycles[i].dec
#             if cycles[i] == 0:
#                 let first = indices[i]
#                 for j in i..<ma-1:
#                     indices[j] = indices[j+1]
#                 indices[ma-1] = first
#                 cycles[i] = ma - i
#                 i.dec
#             else:
#                 let j = ma - cycles[i]
#                 swap(indices[i], indices[j])
#                 for k in 0..<r:
#                     res[k] = indices[k]
#                 break
#         if i < 0: break


# 0..<ma から r 個取り出した「順列」（重複なし、長さ r）
iterator permutations(ma, r: int): seq[int] =
    var comb = (0..<r).toSeq()
    var cur  = comb
    while true:
        yield cur
        while nextPermutation(cur):
            yield cur
        var i = r - 1
        while i >= 0 and comb[i] == i+ma-r: 
            dec i
        if i < 0: break
        inc comb[i]
        for j in i+1 ..< r: 
            comb[j] = comb[j-1] + 1
        cur = comb                      # 新しい組合せで順列を回す

