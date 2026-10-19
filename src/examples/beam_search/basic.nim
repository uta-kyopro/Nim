include ../../lib/header
import ../../lib/search/regacy/beam_search_core

type
    State = object
        position: int
        isFinished: bool
    Frontier = BeamSearchFrontier[State, int, int, int]

proc evaluate(s: State): int = abs(10-s.position)
proc getHash(s: State): int = s.position
proc expand(s: var State, frontier: var Frontier) =
    for action in [1,2]:
        if s.position+action > 10: continue
        var next = s
        next.position += action
        next.isFinished = next.position == 10
        next.pushCandidate(frontier, action)

defineBeamSearch(beamSearch, State, int, int, int)

when isMainModule:
    let initial = State()
    let answer = beamSearch(initial,beamWidth = 8,maxTurns = 10)
    echo answer.score
    echo answer.actions
    echo answer.turns
    echo answer.status
    var position = 0
    for action in answer.actions: position += action
    doAssert position == 10 and answer.score == 0 and answer.turns == 5
    doAssert initial.position == 0
