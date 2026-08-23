include ../header

when not declared TrieModule:
    const TrieModule = true

    type TrieNode = ref object
        children: Table[char, TrieNode]
        isEndWord: bool
        value: int
        maxLength: int
        minLength: int
        count: int

    type Trie = object
        root: TrieNode
        totalCount: int
        nodeCount: int

    proc initTrieNode(): TrieNode =
        result = new TrieNode
        result.minLength = int.high

    proc initTrie(): Trie =
        result.root = initTrieNode()

    proc search(self: Trie, word: string): bool =
        var node = self.root
        for ch in word:
            if ch notin node.children:
                return false
            node = node.children[ch]
        node.isEndWord

    proc startsWith(self: Trie, prefix: string): bool =
        var node = self.root
        for ch in prefix:
            if ch notin node.children:
                return false
            node = node.children[ch]
        true

    proc insert(self: var Trie, word: string, duplicate: bool = true,
            value: int = 0): bool {.discardable.} =
        if not duplicate and self.search(word):
            return false
        var node = self.root
        self.totalCount.inc
        for ch in word:
            if ch notin node.children:
                node.children[ch] = initTrieNode()
                self.nodeCount.inc
            node = node.children[ch]
            node.count.inc
            node.maxLength.max = word.len
            node.minLength.min = word.len
        node.value = value
        node.isEndWord = true
        true

    proc getMinString(self: Trie): string =
        when defined(debug):
            assert self.totalCount > 0, "cannot get a word from an empty Trie"
        var node = self.root
        while not node.isEndWord:
            var found = false
            var nextChar: char
            for ch in node.children.keys:
                if not found or ch < nextChar:
                    found = true
                    nextChar = ch
            if not found:
                return
            result.add(nextChar)
            node = node.children[nextChar]

    proc getMaxString(self: Trie): string =
        when defined(debug):
            assert self.totalCount > 0, "cannot get a word from an empty Trie"
        var node = self.root
        while node.children.len > 0:
            var found = false
            var nextChar: char
            for ch in node.children.keys:
                if not found or ch > nextChar:
                    found = true
                    nextChar = ch
            result.add(nextChar)
            node = node.children[nextChar]
