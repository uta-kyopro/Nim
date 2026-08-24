
include ../header

# 2 次元配列を 1 次元のシーケンスで内部的に保持
# 計算量: 初期化・fill・全走査は O(row * col)、添字アクセスは O(1)。
# 行走査は O(col)、列走査は O(row)。
when not declared FlatSeq2DModule:  # 2次元配列を1次元で管理する
    const FlatSeq2DModule = true
    type FlatSeq2D[T] = object
        data: seq[T]
        row, col: int   # 行数, 列数
    proc initFlatSeq2D[T](row, col: Natural): FlatSeq2D[T] =
        result.data.setLen(row*col)
        result.col = col
        result.row = row
    proc initFlatSeq2D[T](v: seq[T], row: Natural): FlatSeq2D[T] =
        when defined(debug):
            assert row > 0, "FlatSeq2D row count must be positive"
            assert v.len mod row == 0,
                "FlatSeq2D data length must be divisible by its row count"
        result.data = v
        result.row = row
        result.col = result.data.len div row
    proc len(self: FlatSeq2D): int = self.data.len
    proc fill[T](self: var FlatSeq2D[T], v: T) = self.data.fill(v)
    proc `[]`[T](self: FlatSeq2D[T], i, j: Natural): lent T = 
        self.data[i*self.col + j]
    proc `[]=`[T](self:var FlatSeq2D[T], i, j: Natural, v: T) = 
        self.data[i*self.col + j] = v
    iterator items[T](self:FlatSeq2D[T]): lent T =
        for i in 0..<self.data.len:
            yield self.data[i]
    # 指定の1行をiteratorで取得
    iterator getRow[T](self:FlatSeq2D[T], i: Natural): lent T =
        let base = i*self.col
        for k in 0..<self.col:
            yield self.data[base + k]
    # 指定の1列をiteratorで取得
    iterator getCol[T](self:FlatSeq2D[T], j: Natural): lent T =
        for k in 0..<self.row:
            yield self.data[k*self.col + j]
