# nimble install regex
# std/reとは別のPure Nim正規表現ライブラリ。
import regex

doAssert "ABC-123".match(re2"[A-Z]+-[0-9]+")
doAssert not "ABC".match(re2"[A-Z]+-[0-9]+")
let text = "item=12 cost=345"
var values: seq[string]
for m in text.findAll(re2"([0-9]+)"):
    values.add(text[m.group(0)])
echo values
doAssert values == @["12", "345"]
