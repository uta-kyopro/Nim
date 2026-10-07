const Ahc026Testing = true
include ../src/examples/thunder_beam/ahc026
import std/[unittest, random]

proc snapshot(s: State): seq[int] =
    result = @[s.target, s.cost]
    var key = 0'u64
    for stack in 0..<m:
        result.add(s.size[stack])
        for i in 0..<s.size[stack]:
            let box = s.boxes[stack][i]
            result.add(box)
            doAssert s.location[box] == stack and s.position[box] == i
            doAssert s.minimum[stack][i] == (if i == 0: box
                else: min(box, s.minimum[stack][i - 1]))
            key = key xor edgeHash[box][if i == 0: n + 1 + stack else: s.boxes[stack][i - 1]]
    doAssert key == s.key

suite "AHC026 Python-style macro transitions":
    test "replay and nested undo restore boxes, positions, costs and hashes":
        n = 200
        m = 10
        prepareHash()
        var rng = initRand(26)
        for seed in 0..<5:
            var values: seq[int]
            for box in 1..n: values.add(box)
            rng.shuffle(values)
            var s = State(target: 1)
            for i, box in values: s.append(i div (n div m), box)
            s.drain()
            let original = s.snapshot()
            let originalOps = s.operations
            for column in 0..<m:
                for variant in 1..4:
                    let action = Action(column: column, seed: uint64(variant))
                    s.moveForward(action)
                    let after = s.snapshot()
                    let afterOps = s.operations
                    let inner = Action(column: column, seed: uint64(variant + 4))
                    s.moveForward(inner)
                    discard s.snapshot()
                    s.moveBackward(inner)
                    check s.snapshot() == after
                    s.moveBackward(action)
                    check s.snapshot() == original
                    check s.operations == originalOps and s.frames.len == 0
                    s.moveForward(action)
                    check s.snapshot() == after and s.operations == afterOps
                    s.moveBackward(action)

    test "gather exposed runs, leave sorted towers and near-needed boxes":
        n = 12
        m = 4
        prepareHash()
        var s = State(target: 1)
        for box in [12]: s.append(0, box)
        for box in [3, 10, 8]: s.append(1, box)
        for box in [11, 7, 4]: s.append(2, box)
        for box in [1, 9, 6, 5, 2]: s.append(3, box)
        s.gather(0)
        check s.size[0] == 3
        check s.boxes[0][0..2] == [12, 10, 8]
        check s.size[1] == 1 and s.top(1) == 3
        check s.size[2] == 3 and s.top(2) == 4
        check s.top(3) == 2
        discard s.snapshot()

    test "sweep retains a compatible sorted base":
        n = 12
        m = 4
        prepareHash()
        var s = State(target: 1)
        for box in [12, 1, 10]: s.append(0, box)
        for box in [11, 7, 3]: s.append(1, box)
        for box in [8, 9, 2]: s.append(2, box)
        for box in [6, 5, 4]: s.append(3, box)
        var rng = 1'u64
        s.sweep(0, rng)
        check s.size[0] == 1 and s.top(0) == 12 and s.sortedTower(0)
        discard s.snapshot()

    test "finish handles sorted and empty columns":
        n = 6
        m = 3
        prepareHash()
        var s = State(target: 1)
        for box in [1, 6, 3, 5, 2, 4]: s.append(0, box)
        s.finish()
        check s.target == n + 1 and s.operations.len <= 2 * n
        discard s.snapshot()
