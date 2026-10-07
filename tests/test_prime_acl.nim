# Run with and without -d:aclFirst to check both include orders.
when defined(aclFirst):
    include atcoder/extra/math/factorization
include ../src/lib/math/miller_rabin
when not defined(aclFirst):
    include atcoder/extra/math/factorization
import std/unittest
{.checks: on, assertions: on.}

suite "prime ACL coexistence":
    test "Miller Rabin coexists with ACL factorization":
        for n in -10..10000:
            var expected = n >= 2
            var divisor = 2
            while divisor * divisor <= n:
                if n mod divisor == 0: expected = false
                inc divisor
            check isPrimeMillerRabin(n) == expected
            if n >= 2: check isPrime(n) == expected
        check isPrimeMillerRabin(2305843009213693951)
        check not isPrimeMillerRabin(341550071728321)
        check not isPrimeMillerRabin(int.high)
