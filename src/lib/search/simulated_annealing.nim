include ../header

# コピーして問題ごとに編集する焼きなましの枠組み。
when not declared SimulatedAnnealingModule:
    const SimulatedAnnealingModule* = true

    type
        CostType* = int
        Action* = object # TODO: 変更内容と巻き戻しに必要な情報を入れる。
        State* = object # TODO: 盤面・差分計算用の情報を追加する。
            score*: CostType # TODO: 初期化し、適用・巻き戻しで更新する。
        AnnealingResult* = object
            state*: State # 最良状態。最後に訪れた状態とは限らない。
            score*: CostType
            iterations*, accepted*: int

    # 保持している評価値を返す。必要なら評価式へ書き換える。
    template evaluate*(self: State): CostType = self.score

    # TODO: rngを使って合法な近傍を1つ作る。Stateは変更せず、遷移不能ならfalseを返す。
    proc propose*(self: var State, rng: var Rand, action: var Action): bool =
        raise newException(ValueError, "implement propose")

    # TODO: actionを適用し、scoreと差分計算用の情報を更新する。
    proc moveForward*(self: var State, action: Action) =
        raise newException(ValueError, "implement moveForward")

    # TODO: 対応するmoveForwardの変更を、scoreやキャッシュも含めて完全に戻す。
    proc moveBackward*(self: var State, action: Action) =
        raise newException(ValueError, "implement moveBackward")

    # 最良状態を保存する。TODO: ref/ptrなどを持つ場合は独立した複製へ書き換える。
    template copyState*(self: State): State = self

    # 仮適用型の探索ループ。TODO: 差分を先に評価できる問題では受理後だけ適用する形へ編集する。
    proc simulatedAnnealing*(initial: State, timeLimitSec = 1.0,
        startTemperature = 1.0, endTemperature = 0.01,
        seed: int64 = 0, minimize = true,
        temperatureUpdateInterval = 256): AnnealingResult =
        if timeLimitSec < 0 or
            startTemperature < 0 or endTemperature < 0:
            raise newException(ValueError, "invalid annealing parameters")
        if temperatureUpdateInterval <= 0 or
            (temperatureUpdateInterval and (temperatureUpdateInterval-1)) != 0:
            raise newException(ValueError, "temperature update interval must be a positive power of two")

        var state = initial.copyState()
        var score = state.evaluate()
        result.state = state.copyState()
        result.score = score
        if timeLimitSec == 0: return
        var rng = initRand(seed)
        let started = getMonoTime()
        let temperatureUpdateMask = temperatureUpdateInterval-1
        var temperature = startTemperature

        while true:
            if (result.iterations and temperatureUpdateMask) == 0:
                let elapsed = float(getMonoTime().ticks - started.ticks) / 1e9
                if elapsed >= timeLimitSec: break
                let progress = elapsed / timeLimitSec
                # TODO: 必要なら指数冷却などへ変更する（既定は線形冷却）。
                temperature = startTemperature * (1.0 - progress) + endTemperature * progress
            inc result.iterations
            var action: Action
            if not state.propose(rng, action): continue
            state.moveForward(action)
            let nextScore = state.evaluate()
            let loss = if minimize: float(nextScore) - float(score)
                else: float(score) - float(nextScore)
            if loss <= 0 or (temperature > 0 and rng.rand(1.0) < exp(-loss / temperature)):
                score = nextScore
                inc result.accepted
                if (if minimize: score < result.score else: score > result.score):
                    result.state = state.copyState()
                    result.score = score
            else:
                state.moveBackward(action)

# let answer = simulatedAnnealing(initialState, timeLimitSec = 1.9,
#     startTemperature = 10.0, endTemperature = 0.1)
