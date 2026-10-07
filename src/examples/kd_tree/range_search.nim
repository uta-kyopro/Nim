include ../../lib/tree/kd_tree

# DSL_2_C: 静的な2次元点集合から閉長方形内の点の入力番号を昇順に取得。
when isMainModule:
    let points = @[[2, 1], [2, 2], [4, 2], [6, 2], [3, 3], [5, 4]]
    let tree = initKdTree(points)
    # sx <= x <= tx かつ sy <= y <= ty
    let indices = tree.rangeSearch([2, 0], [4, 4])
    doAssert indices == @[0, 1, 2, 4]
    for i in indices:
        echo i
    echo "" # AOJでは各クエリの最後に空行（該当点なしでも必要）
    doAssert tree.rangeSearch([4, 2], [10, 5]) == @[2, 3, 5]
