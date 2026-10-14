# nimble install bigints
# Pure Nimの多倍長整数。パッケージ名はbigints、型名はBigInt。
import bigints
import std/options

let a = initBigInt("123456789012345678901234567890")
let b = initBigInt("98765432109876543210")
echo "sum = ", a + b
echo "product = ", a * b
echo "2^100 = ", initBigInt(2).pow(100)
echo "gcd = ", gcd(initBigInt(48), initBigInt(18))
echo "powmod = ", powmod(initBigInt(2), initBigInt(100), initBigInt(1000000007))

# 負数の除算は床方向。Nim組み込みintのdiv/modとは異なる。
let (q, r) = divmod(initBigInt(-7), initBigInt(3))
echo "-7 div 3 = ", q, ", mod = ", r
doAssert q == initBigInt(-3) and r == initBigInt(2)

# 通常整数への変換はOption。範囲外の値をgetしない。
let small = toInt[int](initBigInt(42))
doAssert small.isSome and small.get == 42
doAssert toInt[int](a).isNone

var factorial = initBigInt(1)
for i in 1..30:
    factorial = factorial * initBigInt(i)
echo "30! = ", factorial
doAssert $factorial == "265252859812191058636308480000000"
