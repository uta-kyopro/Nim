
include ../header



# Miller-Rabin法による素数判定
when not declared MillerRabinTestModule:
    # a * b % mod (128bit)
    proc mul128(a, b, m:int):int {.importcpp: "(__int128)(#) * (#) % (#)", nodecl.}
    proc pow128(a, b, m:int):int =
        var (a, b) = (a, b)
        result = 1
        while b != 0:
            if (b & 1) != 0: 
                result = mul128(result, a, m)
            a = mul128(a, a, m)
            b >>= 1

    const WitnessNumbers = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37]

    proc isPrime(n: int): bool =
        if n < 2: return false      # 0,1,負数は素数でない
        for p in WitnessNumbers:    # 小さい素数での試し割り
            if n == p: return true
            if (n % p) == 0: return false

        var d = n - 1
        var s = 0
        while (d & 1) == 0:     # n−1 を偶数因子と奇数因子に分解
            d >>= 1
            s += 1

        for a0 in WitnessNumbers:
            let a = a0 % n
            var x = pow128(a, d, n)   # x = a^d mod n
            if x == 1 or x == n - 1:
                continue
            block ok:
                for _ in 1..<s:
                    x = mul128(x, x, n)     # x = x^2 mod n
                    if x == n - 1:
                        break ok
                return false
        return true
    