# ビット盤面のBFS

長方形盤面を1つの整数に格納し、frontierを上下左右へシフトする4近傍・複数始点BFS。

| 版 | 最大セル数 | 使用例 | バックエンド |
|---|---|---|---|
| `uint64` | 64 | [u64.nim](../src/examples/bitboard_bfs/u64.nim) | `nim c` / `nim cpp` |
| `UInt128` | 128 | [bitboard_bfs.nim](../src/examples/int128/bitboard_bfs.nim) | `nim cpp`、128bit対応コンパイラ |

どちらも`bitboardBfs(height, width, walkable, starts)`を呼ぶ。`walkable`は通行可能セル、`starts`はその中にある始点のbit集合。bit位置は`row * width + col`。

戻り値の`reachable`は到達可能セルのbit集合、`distances`は各セルの最短距離。壁・到達不能セルは-1。始点が空なら到達セルも空。複数始点なら最も近い始点からの距離になる。

```nim
import ../src/examples/bitboard_bfs/u64
import std/bitops

let answer = bitboardBfs(8, 8, high(uint64), 1'u64)
echo answer.reachable.popCount() # 64
echo answer.distances[63]        # 14
```

左右端のマスクで行の回り込みを防ぎ、有効盤面マスクで盤面外のbitを除外する。全64/128セルや1行の盤面は、型の幅と同じシフト数を使わないよう別扱いする。盤面サイズ・盤面外の通行可能bit・壁上の始点の検査はdebug時のみ。

uint64版は`std/bitops.countTrailingZeroBits`でfrontierのセルを列挙する。非ゼロを確認してから呼び出し、`bits and (bits - 1)`で最下位の立っているbitを消す。128bit版は`getSetBits`を使用する。[128bit整数の説明](int128.md)

```sh
nim c -r -d:release --outdir:build/examples src/examples/bitboard_bfs/u64.nim
nim c -r -d:debug --outdir:build/tests tests/test_uint64_bfs.nim
nim cpp -r -d:release --outdir:build/tests tests/test_uint64_bfs.nim
```

uint64版は1×64・64×1・8×8・最高位bit・左右端・空のfrontier・到達不能領域、および固定seedのランダム300盤面で、全セルの距離と到達集合を独立した座標・キューBFSと比較する。速度の優位性は測定していない。
