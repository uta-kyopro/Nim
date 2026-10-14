# Pythonの任意精度整数との比較用。ライブラリの違いはコンパイル時に指定。
import std/[strutils, math]
when defined(useBignum):
    import bignum
    template number(s: string): untyped = newInt(s)
else:
    import bigints
    template number(s: string): untyped = initBigInt(s)

var line: string
while stdin.readLine(line):
    let parts = line.splitWhitespace()
    if parts[0] == "native":
        when defined(useBignum):
            echo newInt(parseInt(parts[1]))
        else:
            echo initBigInt(parseBiggestInt(parts[1]))
        continue
    let a = number(parts[0])
    let b = number(parts[1])
    echo a + b, " ", a - b, " ", a * b, " ", a div b, " ", a mod b, " ", gcd(a, b)
