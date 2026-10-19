include ../../lib/header
import ../../lib/search/regacy/beam_search_core
include ./ahc073_problem

type Frontier = BeamSearchFrontier[State, int, uint64, uint8]

proc expand(s: var State, frontier: var Frontier) =
    for id, order in orders:
        let route = makeRoute(s, order)
        var next = s
        next.circles = route.after
        next.cost += int(route.cost)
        inc next.turn
        next.pushCandidate(frontier, uint8(id))

defineBeamSearch(beamSearch, State, int, uint64, uint8)


# Stateコピー型の結果を、共通の再生・出力処理へ渡す。
proc runSearch(initial: State, width, turns: int): Ahc073Answer =
    let answer = beamSearch(initial, width, maxTurns = turns)
    Ahc073Answer(state: answer.state, actions: answer.actions, turns: answer.turns,
        selectedCandidates: answer.selectedCandidates)

# 入力を読み、共通の逆順区間再生で提出形式を出力する。
proc solve*() = solveWith(runSearch)

when isMainModule and not defined(beamTests): solve()
