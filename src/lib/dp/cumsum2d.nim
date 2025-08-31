
include ../header



# 2次元累積和
when not declared CumulativeSum2DModule:
    # 1-indexで構成された2次元配列を累積和へ変換
    proc cumsum(data:var seq[seq[int]]) =
        for i in 1..<data.len:
            for j in 1..<data[0].len:
                data[i][j] += data[i-1][j]+data[i][j-1]-data[i-1][j-1]

    # (y1, x1), (y2, x2)の矩形範囲和を返す
    proc getRangeSum(data:seq[seq[int]], yx1, yx2: (int, int)): int =
        var (y1, x1) = yx1
        var (y2, x2) = yx2
        if y1>y2: swap(y1, y2)
        if x1>x2: swap(x1, x2)
        return data[y2][x2]-data[y1][x2]-data[y2][x1]+data[y1][x1]
