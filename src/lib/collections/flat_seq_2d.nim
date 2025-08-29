
include ../header

# 2 次元配列を 1 次元のシーケンスで内部的に保持
when not declared FlatSeq2DModule:  # 2次元配列を1次元で管理する
    type FlatSeq2D[T] = object
        data: seq[T]
        row, col: int   # 行数, 列数
    proc initFlatSeq2D[T](row, col: Natural): FlatSeq2D[T] =
        result.data.setLen(row*col)
        result.col = col
        result.row = row
    proc initFlatSeq2D[T](v: seq[T], row: Natural): FlatSeq2D[T] =
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