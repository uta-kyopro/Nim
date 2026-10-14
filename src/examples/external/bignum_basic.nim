# nimble install bignum
# GMPのヘッダ・ライブラリも必要。Windowsの大きなintは文字列から構築する。
import bignum

let a = newInt("123456789012345678901234567890")
let b = newInt("98765432109876543210")
echo "sum = ", a + b
echo "product = ", a * b
echo "gcd = ", gcd(newInt(48), newInt(18))

# 負数の除算はゼロ方向。bigintsの床方向とは異なる。
echo "-7 div 3 = ", newInt(-7) div newInt(3)
echo "-7 mod 3 = ", newInt(-7) mod newInt(3)
doAssert $(newInt(-7) div newInt(3)) == "-2"
doAssert $(newInt(-7) mod newInt(3)) == "-1"

# Intはref型。代入では参照を共有し、独立した数が必要ならcloneする。
let original = newInt("100")
let shared = original
let independent = original.clone()
shared *= 2
doAssert $original == "200"
doAssert $independent == "100"

var factorial = newInt(1)
for i in 1..30:
    factorial *= i
echo "30! = ", factorial
doAssert $factorial == "265252859812191058636308480000000"

# Ratなら分数を正確に計算できる。floatを経由しない。
let fraction = newRat(newInt(1), newInt(3)) + newRat(newInt(1), newInt(6))
echo "1/3 + 1/6 = ", fraction
doAssert $fraction == "1/2"
doAssert newInt(42).fitsInt
doAssert newInt(42).toInt == 42
