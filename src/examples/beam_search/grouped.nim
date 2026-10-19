include ../../lib/header
import ../../lib/search/beam_search_core

type
    State = object
        value: int
    Action = int

# 13との差を最小化する。
template evaluate(s: State): int = abs(13-s.value)
# 同じ位置を同一状態として扱う。
template getHash(s: State): int = s.value
# 固定5ターンで最良を選ぶ。
template isFinished(s: State): bool = false
# 移動先の値を3グループに分けて候補を登録する。
proc expand(s: var State,f: var BeamSearchFrontier[State,int,int,Action]) =
    for action in [1,2,3]:
        var next = State(value:s.value+action)
        next.pushCandidate(f,action,group=next.value mod 3)

defineBeamSearch(beamSearch,State,int,int,Action)

when isMainModule:
    # 各グループ2候補、最大6候補。groupLimit > 0ならbeamWidthの全体上限は使わない。
    let answer = beamSearch(State(),beamWidth=1,maxTurns=5,groupLimit=2,groupCount=3)
    echo answer.state.value
    echo answer.score
    echo answer.actions
    doAssert answer.state.value == 13 and answer.score == 0
    doAssert answer.actions.foldl(a+b,0) == answer.state.value
