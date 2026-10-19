include ../../lib/header

# simulated_annealing.nimを編集した例。N=100、入力は1..100の順列（N自体は入力しない）。
const N = 100
const SortingTimeLimitMs {.intdefine.} = 1000

type
    ActionKind = enum
        swapMove, insertMove
    State = object
        values: array[N, int]
        score: int
    Action = object
        kind: ActionKind
        source, destination: int
    AnnealingResult = object
        state: State
        score, iterations, accepted: int

# 各要素の前後の違反を数えるため、降順になった隣接ペアは両端から1回ずつ数える。
template edgeCost(left, right: int): int = (if left > right: 2 else: 0)

# 隣接関係だけで評価値を計算する。0なら全体が昇順になっている。
proc fullScore(self: State): int =
    for i in 0..<N-1:
        result += edgeCost(self.values[i], self.values[i+1])

# 保存している評価値を参照する。
template evaluate(self: State): int = self.score

# swapと挿入を半々で選び、元と先の異なる2点は一様に選ぶ。
proc propose(self: var State, rng: var Rand, action: var Action): bool =
    action.kind = ActionKind(rng.rand(1))
    action.source = rng.rand(N-1)
    action.destination = rng.rand(N-2)
    if action.destination >= action.source: inc action.destination
    true

# 指定した境界だけのコストを、重複する境界を除いて計算する。
proc boundaryScore(self: State, boundaries: openArray[int]): int =
    for k, i in boundaries:
        if i < 0 or i >= N-1: continue
        var duplicate = false
        for j in 0..<k:
            if boundaries[j] == i: duplicate = true
        if not duplicate: result += edgeCost(self.values[i], self.values[i+1])

# 要素を取り除いて指定位置へ挿入し、変化する境界だけで評価値を更新する。
proc moveInsert(self: var State, a, b: int) =
    self.score -= self.boundaryScore([a-1, a, if b < a: b-1 else: b])
    let value = self.values[a]
    if a < b:
        for i in a..<b: self.values[i] = self.values[i+1]
    else:
        for i in countdown(a, b+1): self.values[i] = self.values[i-1]
    self.values[b] = value
    self.score += self.boundaryScore([b-1, b, if a < b: a-1 else: a])

# 選ばれたswapまたは挿入を適用し、評価値を差分更新する。
proc moveForward(self: var State, action: Action) =
    let a = action.source
    let b = action.destination
    if action.kind == insertMove:
        self.moveInsert(a, b)
        return
    let boundaries = [a-1, a, b-1, b]
    self.score -= self.boundaryScore(boundaries)
    swap(self.values[a], self.values[b])
    self.score += self.boundaryScore(boundaries)

# swapは同じ2点、挿入は逆方向へ移動して、配列と評価値を復元する。
proc moveBackward(self: var State, action: Action) =
    if action.kind == insertMove:
        self.moveInsert(action.destination, action.source)
    else:
        self.moveForward(action)

# 時間制限・指数冷却で探索し、評価値0へ到達したら最良状態を返す。
proc simulatedAnnealing(initial: State, timeLimitSec = float(SortingTimeLimitMs)/1000.0,
    startTemperature = 0.5, endTemperature = 0.01, seed: int64 = 42,
    temperatureUpdateInterval = 256): AnnealingResult =
    if startTemperature <= 0 or endTemperature <= 0 or timeLimitSec < 0:
        raise newException(ValueError, "expected positive temperatures and a nonnegative time limit")
    if temperatureUpdateInterval <= 0 or
        (temperatureUpdateInterval and (temperatureUpdateInterval-1)) != 0:
        raise newException(ValueError, "temperature update interval must be a positive power of two")
    var state = initial
    var score = state.evaluate()
    result.state = state
    result.score = score
    if timeLimitSec == 0 or result.score == 0: return
    var rng = initRand(seed)
    let started = getMonoTime()
    let logTemperatureRatio = ln(endTemperature / startTemperature)
    let temperatureUpdateMask = temperatureUpdateInterval-1
    var temperature = startTemperature
    while true:
        if (result.iterations and temperatureUpdateMask) == 0:
            let elapsed = float(getMonoTime().ticks - started.ticks) / 1e9
            if elapsed >= timeLimitSec: break
            let progress = elapsed/timeLimitSec
            temperature = startTemperature * exp(logTemperatureRatio * progress)
        inc result.iterations
        var action: Action
        if not state.propose(rng, action): continue
        state.moveForward(action)
        let nextScore = state.evaluate()
        let loss = nextScore-score
        if loss <= 0 or (temperature > 0 and rng.rand(1.0) < exp(-float(loss)/temperature)):
            score = nextScore
            inc result.accepted
            if score < result.score:
                result.state = state
                result.score = score
                if result.score == 0: break
        else:
            state.moveBackward(action)

when isMainModule:
    var initial: State
    var seen: array[N+1, bool]
    for i in 0..<N:
        let value = input(int)
        if value < 1 or value > N or seen[value]:
            raise newException(ValueError, "expected a permutation of 1..100")
        seen[value] = true
        initial.values[i] = value
    initial.score = initial.fullScore()
    let answer = simulatedAnnealing(initial)
    echo answer.state.values.join(" ")
    stderr.writeLine("score=", answer.score, " iterations=", answer.iterations,
        " accepted=", answer.accepted)
