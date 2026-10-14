# nimble install sat
# (x or y) and not x は充足可能。x and not x は充足不能。
import sat/[sat, satvars]

proc formula(text: string): Formular =
    var builder: Builder
    let consumed = parseFormular(text, 0, builder)
    doAssert consumed == text.len
    builder.toForm()

let possible = formula("(& (| v0 v1) (~ v0))")
var solution = createSolution(possible)
doAssert satisfiable(possible, solution)
doAssert possible.eval(solution)
doAssert not solution.isTrue(VarId(0))
doAssert solution.isTrue(VarId(1))
echo "x = ", solution.isTrue(VarId(0)), ", y = ", solution.isTrue(VarId(1))

let impossible = formula("(& v0 (~ v0))")
var noSolution = createSolution(impossible)
doAssert not satisfiable(impossible, noSolution)
echo "x and not x: unsatisfiable"
