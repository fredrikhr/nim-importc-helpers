import .. / src / importc_helpers

type DistinctInt = distinct int
implementDistinctEnum(DistinctInt):
  const zero = 0.DistinctInt
  const one = 1.DistinctInt

#[
  Generates:
proc `==`*(a, b: DistinctInt): bool =
a.int == b.int

proc `$`*(v: DistinctInt): string =
if v == zero: "ZERO" elif v == one: "ONE" else: $ v.int

proc parseDistinctInt*(s: string): DistinctInt {.raises: [ValueError].} =
if cmpRunesIgnoreCase(s, "zero") == 0:
  result = zero
elif cmpRunesIgnoreCase(s, "one") == 0:
  result = one
else:
  raise newException(ValueError, format("Cannot parse \"$#\" as DistinctInt", s))

proc tryParseDistinctInt*(s: string; value: var DistinctInt): bool =
if cmpRunesIgnoreCase(s, "zero") == 0:
  value = zero
  result = true
elif cmpRunesIgnoreCase(s, "one") == 0:
  value = one
  result = true
else:
  result = false
]#

doAssert $zero == "zero"
doAssert $one == "one"

doAssert 0.DistinctInt == zero
doAssert one != zero

doAssert "zero".parseDistinctInt() == zero

var parsed: DistinctInt
doAssert "ZeRo".tryParseDistinctInt(parsed) and parsed == zero
