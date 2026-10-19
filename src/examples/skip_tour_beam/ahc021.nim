include ../../lib/header
# AHC021 A - Pyramid Sorting（skipBeamと同じ遷移・評価を使う世代スキップ例）
# https://atcoder.jp/contests/ahc021/tasks/ahc021_a
import ../../lib/search/skip_tour_beam_core

const
    N = 30
    M = N * (N + 1) div 2
    targetCoefficient = 600
    horizontalCost = 10
    AhcBeamWidth {.intdefine.} = 1024

type
    HashType = int
    CostType = int
    Action = int # 6座標を8bitずつ格納（64bit環境用）
    Stack[T] = object
        len: int
        data: array[3000, T]
    State = object
        isFinished: bool
        targetBall, potential: int
        hash: HashType
        b: array[N, array[N, int]]
        pos: array[M, (int, int)]
        targetBallHistory: Stack[int]
        hashHistory: Stack[HashType]
    Frontier = SkipTourBeamFrontier[Action, CostType, HashType]

static: doAssert sizeof(int) == 8
proc add[T](s: var Stack[T], value: T) =
    s.data[s.len] = value
    inc s.len
proc pop[T](s: var Stack[T]): T =
    dec s.len
    s.data[s.len]

template getPyramidIndex(y, x: int): int =
    (y * (y+1) div 2 + x)
const hashMask = ((1 shl 23)-1) shl 9
template updateTargetPosition(hash: HashType, y, x: int): HashType =
    ((hash and hashMask) or getPyramidIndex(y, x))
proc updateSortedPosition(hash: HashType, y, x: int): HashType =
    var zobristHash = getPyramidIndex(y, x)
    zobristHash = zobristHash or 0x200    # 512 (10bit)
    zobristHash *= zobristHash
    zobristHash *= zobristHash
    return hash xor (zobristHash and hashMask)

template initAction(y1, x1, y2, x2, y3, x3: int): Action =
    ( y1 or (x1 shl 8) or
    (y2 shl 16) or (x2 shl 24) or
    (y3 shl 32) or (x3 shl 40))

template decode(self: Action) =
    y1 = self and 0xFF
    x1 = (self shr 8) and 0xFF
    y2 = (self shr 16) and 0xFF
    x2 = (self shr 24) and 0xFF
    y3 = (self shr 32) and 0xFF
    x3 = (self shr 40) and 0xFF

template canMoveLeft(self: State, y, x: int): bool =
    ((x > 0) and (self.b[y-1][x-1] > self.b[y][x]))

template canMoveRight(self: State, y, x: int): bool =
    ((x < y) and (self.b[y-1][x] > self.b[y][x]))

proc updateTargetBall(self:var State, targetBall: int, h: HashType): (int, HashType) =
    var hash = h
    var ball = targetBall
    while ball < M:
        let (y, x) = self.pos[ball]
        if self.canMoveLeft(y, x) or self.canMoveRight(y, x):
            hash = updateTargetPosition(hash, y, x)
            return (ball, hash)
        hash = updateSortedPosition(hash, y, x)
        ball += 1
    return (M, hash)

proc swapBalls(self:var State, y1, x1, y2, x2: int) =
    let b1 = self.b[y1][x1]
    let b2 = self.b[y2][x2]
    swap(self.b[y1][x1], self.b[y2][x2])
    swap(self.pos[b1], self.pos[b2])

# 初期状態の定義
proc initState(values: openArray[int]): State =
    var self = State()

    for y in 0..<N:
        for x in 0..y:
            self.b[y][x] = values[y * (y + 1) div 2 + x]
            self.pos[values[y * (y + 1) div 2 + x]] = (y, x)

    let (ball, hash) = self.updateTargetBall(0, 0)
    self.targetBall = ball
    self.isFinished = ball == M

    return self

# 盤面評価関数
template evaluate(self:var State): CostType =
    (self.potential - targetCoefficient*self.targetBall)

# actionを実行して次の状態に遷移する
proc moveForward(self:var State, action: Action) =
    self.hashHistory.add(self.hash)
    self.targetBallHistory.add(self.targetBall)

    var y1, x1, y2, x2, y3, x3: int
    action.decode()

    if y1!=y2:
        self.potential += self.b[y1][x1] - self.b[y2][x2]
    else:
        self.potential -= horizontalCost

    self.swapBalls(y1, x1, y2, x2)
    if x3 < N:
        self.potential += self.b[y3][x3] - self.b[y1][x1]
        self.swapBalls(y1, x1, y3, x3)

    (self.targetBall, self.hash) = self.updateTargetBall(
        self.targetBall, self.hash)
    self.isFinished = self.targetBall == M

# actionを実行する前の状態に遷移する
# 今の状態は、親からactionを実行して遷移した状態である
proc moveBackward(self:var State, action: Action) =
    var y1, x1, y2, x2, y3, x3: int
    action.decode()

    if x3 < N:
        self.swapBalls(y1, x1, y3, x3)
        self.potential -= self.b[y3][x3] - self.b[y1][x1]
    self.swapBalls(y1, x1, y2, x2)
    if y1!=y2:
        self.potential -= self.b[y1][x1] - self.b[y2][x2]
    else:
        self.potential += horizontalCost

    self.hash = self.hashHistory.pop()
    self.targetBall = self.targetBallHistory.pop()
    self.isFinished = self.targetBall == M

# 盤面と終了状態だけを適用し、評価値・Hashの更新を省く。
proc moveBoardForward(self: var State, action: Action) =
    self.targetBallHistory.add(self.targetBall)
    var y1,x1,y2,x2,y3,x3: int
    action.decode()
    self.swapBalls(y1,x1,y2,x2)
    if x3 < N: self.swapBalls(y1,x1,y3,x3)
    var ball = self.targetBall
    while ball < M:
        let (y,x) = self.pos[ball]
        if self.canMoveLeft(y,x) or self.canMoveRight(y,x): break
        inc ball
    self.targetBall = ball
    self.isFinished = ball == M

# 盤面と終了状態だけを巻き戻す。
proc moveBoardBackward(self: var State, action: Action) =
    var y1,x1,y2,x2,y3,x3: int
    action.decode()
    if x3 < N: self.swapBalls(y1,x1,y3,x3)
    self.swapBalls(y1,x1,y2,x2)
    self.targetBall = self.targetBallHistory.pop()
    self.isFinished = self.targetBall == M

# 保存済みの評価値・Hashを展開直前に復元する。
template loadLeaf(self: var State, score: int, key: int) =
    self.potential = score + targetCoefficient*self.targetBall
    self.hash = key


# 次の状態候補を全てselectorに追加する。
proc expand(self:var State, parent: int, multiSelector:var Frontier) =
    proc push2(self:var State, parent: int, multiSelector:var Frontier,
        y1, x1, y2, x2: int) =
        var action = initAction(y1, x1, y2, x2, N, N)

        self.moveForward(action)
        var hash = self.hash
        var cost = self.evaluate()
        var finished = (self.targetBall == M)
        self.moveBackward(action)

        multiSelector.push(action, cost, hash, finished = finished, step = 1)

    proc push3(self:var State, parent: int, multiSelector:var Frontier,
        y1, x1, y2, x2, y3, x3: int) =
        var action = initAction(y1, x1, y2, x2, y3, x3)

        self.moveForward(action)
        var hash = self.hash
        var cost = self.evaluate()
        var finished = (self.targetBall == M)
        self.moveBackward(action)

        multiSelector.push(action, cost, hash, finished = finished, step = 2)

    var (y, x) = self.pos[self.targetBall]
    if self.canMoveLeft(y, x):
        self.push2(parent, multiSelector, y, x, y-1, x-1)
        if self.canMoveLeft(y-1, x-1):
            self.push3(parent, multiSelector, y-1, x-1, y-2, x-2, y, x)
        if self.canMoveRight(y-1, x-1):
            self.push3(parent, multiSelector, y-1, x-1, y-2, x-1, y, x)
        if x-1 > 0 and self.b[y-1][x-1]<self.b[y-1][x-2]:   # 真左
            self.push3(parent, multiSelector, y-1, x-1, y-1, x-2, y, x)
        if y-1 > x-1 and self.b[y-1][x-1]<self.b[y-1][x]:   # 真右
            self.push3(parent, multiSelector, y-1, x-1, y-1, x, y, x)

    if self.canMoveRight(y, x):
        self.push2(parent, multiSelector, y, x, y-1, x)
        if self.canMoveLeft(y-1, x):
            self.push3(parent, multiSelector, y-1, x, y-2, x-1, y, x)
        if self.canMoveRight(y-1, x):
            self.push3(parent, multiSelector, y-1, x, y-2, x, y, x)
        if x > 0 and self.b[y-1][x]<self.b[y-1][x-1]:   # 真左
            self.push3(parent, multiSelector, y-1, x, y-1, x-1, y, x)
        if y-1 > x and self.b[y-1][x]<self.b[y-1][x+1]:   # 真右
            self.push3(parent, multiSelector, y-1, x, y-1, x+1, y, x)

    if x > 0 and self.b[y][x]<self.b[y][x-1]:   # 真左
        self.push2(parent, multiSelector, y, x, y, x-1)
    if y > x and self.b[y][x]<self.b[y][x+1]:   # 真右
        self.push2(parent, multiSelector, y, x, y, x+1)


proc getHash(s: State): HashType = s.hash

template expand(s: var State, f: var Frontier) = expand(s, 0, f)

defineSkipTourBeam(skipTourBeam, State, Action, CostType, HashType)

proc solve(initial: State, beamWidth = AhcBeamWidth): SkipTourBeamResult[Action, CostType] =
    skipTourBeam(initial, beamWidth, maxTurns = 2000)

proc output(initial: State, actions: openArray[Action]) =
    var count = actions.len
    for action in actions:
        if ((action shr 40) and 0xFF) < N: inc count
    echo count
    var replay = initial
    for action in actions:
        var y1, x1, y2, x2, y3, x3: int
        action.decode()
        echo y1, " ", x1, " ", y2, " ", x2
        replay.swapBalls(y1, x1, y2, x2)
        if x3 < N:
            echo y1, " ", x1, " ", y3, " ", x3
            replay.swapBalls(y1, x1, y3, x3)
    var errors = 0
    for y in 0..<N-1:
        for x in 0..y:
            for dx in 0..1:
                if replay.b[y][x] > replay.b[y+1][x+dx]: inc errors
    let score = if errors == 0: 100000 - 5 * count else: 50000 - 50 * errors
    stderr.writeLine("score: ", score)

when isMainModule:
    let values = input(int, M)
    let initial = initState(values)
    let answer = solve(initial)
    output(initial, answer.actions)
