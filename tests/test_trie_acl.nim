# Run with and without -d:aclFirst to check both include orders.
when defined(aclFirst):
    include atcoder/extra/structure/trie
include ../src/lib/collections/trie
when not defined(aclFirst):
    include atcoder/extra/structure/trie
import std/unittest
{.checks: on, assertions: on.}

suite "trie ACL coexistence":
    test "table trie coexists with ACL array trie":
        var own: TableTrie = initTableTrie()
        var acl: Trie[26, ord('a')] = initTrie[26, ord('a')]()
        for word in ["app", "apple", "banana"]:
            own.insert(word)
            acl.add(word)
        check own.search("app") and own.search("apple")
        check not own.search("ap")
        check own.startsWith("ap") and not own.startsWith("z")
        check own.getMinString() == "app"
        check own.getMaxString() == "banana"
        check not own.insert("app", duplicate = false)
        check acl.count == 3
        own.insert("")
        check own.getMinString() == ""
