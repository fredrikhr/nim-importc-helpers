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

type Bitflags32 = distinct uint32
implementDistinctFlags(Bitflags32):
  const
    bit_0 = (1 shl 0).Bitflags32
    bit_1 = (1 shl 1).Bitflags32
    bit_2 = (1 shl 2).Bitflags32
    bit_3 = (1 shl 3).Bitflags32
    bit_4 = (1 shl 4).Bitflags32
    bit_5 = (1 shl 5).Bitflags32
    bit_6 = (1 shl 6).Bitflags32
    bit_7 = (1 shl 7).Bitflags32
    bit_8 = (1 shl 8).Bitflags32
    bit_9 = (1 shl 9).Bitflags32
    bit_10 = (1 shl 10).Bitflags32
    bit_11 = (1 shl 11).Bitflags32
    bit_12 = (1 shl 12).Bitflags32
    bit_13 = (1 shl 13).Bitflags32
    bit_14 = (1 shl 14).Bitflags32
    bit_15 = (1 shl 15).Bitflags32
    bit_16 = (1 shl 16).Bitflags32
    bit_17 = (1 shl 17).Bitflags32
    bit_18 = (1 shl 18).Bitflags32
    bit_19 = (1 shl 19).Bitflags32
    bit_20 = (1 shl 20).Bitflags32
    bit_21 = (1 shl 21).Bitflags32
    bit_22 = (1 shl 22).Bitflags32
    bit_23 = (1 shl 23).Bitflags32
    bit_24 = (1 shl 24).Bitflags32
    bit_25 = (1 shl 25).Bitflags32
    bit_26 = (1 shl 26).Bitflags32
    bit_27 = (1 shl 27).Bitflags32
    bit_28 = (1 shl 28).Bitflags32
    bit_29 = (1 shl 29).Bitflags32
    bit_30 = (1 shl 30).Bitflags32
    bit_31 = (1 shl 31).Bitflags32

let
  v1 = bit_0 or bit_1
  v2 = 3.Bitflags32
doAssert v1 == v2
doAssert bit_0 in v1
doAssert bit_30 notin v1

let v3 = v2 and bit_1
doAssert v3 == bit_1

let v4 = not bit_30
doAssert bit_30 notin v4
doAssert bit_2 in v4

let
  v5 = bit_0 + bit_4 + bit_6
  v6 = bit_1 + bit_4 + bit_8
doAssert bit_6 in v5
doAssert bit_1 in v6

let
  v7 = v5 * v6
  v8 = v5 - v1
doAssert v7 == bit_4
doAssert bit_0 notin v8

var v9 = not bit_28
v9.excl bit_4
doAssert bit_4 notin v9
v9.incl bit_28
doAssert bit_28 in v9

doAssert "bit_31".parseBitflags32 == bit_31
doAssert "BIT_31".parseBitflags32 == bit_31
var v10: Bitflags32
doAssert "garbage".tryParseBitflags32(v10) == false
doAssert "BIT_28".tryParseBitflags32(v10) == true and v10 == bit_28

doAssert((bit_0 + bit_1) <= v1)
doAssert bit_0 < v1
