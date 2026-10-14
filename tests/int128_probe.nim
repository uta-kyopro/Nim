import ../src/lib/math/int128
import std/strutils

var line: string
while stdin.readLine(line):
    let fields = line.splitWhitespace()
    let shift = parseInt(fields[3])
    if fields[0] == "s":
        let a = parseInt128(fields[1])
        let b = parseInt128(fields[2])
        echo a + b, " ", a - b, " ", a * b, " ", a div b, " ", a mod b,
            " ", a and b, " ", a or b, " ", a xor b, " ", not a,
            " ", a shl shift, " ", a shr shift, " ", cmp(a, b)
    else:
        let a = parseUInt128(fields[1])
        let b = parseUInt128(fields[2])
        echo a + b, " ", a - b, " ", a * b, " ", a div b, " ", a mod b,
            " ", a and b, " ", a or b, " ", a xor b, " ", not a,
            " ", a shl shift, " ", a shr shift, " ", cmp(a, b)
