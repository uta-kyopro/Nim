include ../header

# 計算量（L = 文字列長、A = 各ノードの最大分岐数）: 検索・prefix検索・挿入は平均 O(L)。
# 最小・最大文字列取得は O(L * A)。
when not declared TableTrieModule:
    const TableTrieModule = true

    type TableTrieNode = ref object
        children: Table[char, TableTrieNode]
        isEndWord: bool
        value: int
        maxLength: int
        minLength: int
        count: int

    type TableTrie = object
        root: TableTrieNode
        totalCount: int
        nodeCount: int

    proc initTableTrieNode(): TableTrieNode =
        result = new TableTrieNode
        result.minLength = int.high

    proc initTableTrie(): TableTrie =
        result.root = initTableTrieNode()

    proc search(self: TableTrie, word: string): bool =
        var node = self.root
        for ch in word:
            if ch notin node.children:
                return false
            node = node.children[ch]
        node.isEndWord

    proc startsWith(self: TableTrie, prefix: string): bool =
        var node = self.root
        for ch in prefix:
            if ch notin node.children:
                return false
            node = node.children[ch]
        true

    proc insert(self: var TableTrie, word: string, duplicate: bool = true,
        value: int = 0): bool {.discardable.} =
        if not duplicate and self.search(word):
            return false
        var node = self.root
        self.totalCount.inc
        for ch in word:
            if ch notin node.children:
                node.children[ch] = initTableTrieNode()
                self.nodeCount.inc
            node = node.children[ch]
            node.count.inc
            node.maxLength.max = word.len
            node.minLength.min = word.len
        node.value = value
        node.isEndWord = true
        true

    proc getMinString(self: TableTrie): string =
        when defined(debug):
            assert self.totalCount > 0, "cannot get a word from an empty TableTrie"
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

    proc getMaxString(self: TableTrie): string =
        when defined(debug):
            assert self.totalCount > 0, "cannot get a word from an empty TableTrie"
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
