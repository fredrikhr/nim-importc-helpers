# ImportC Helpers for Nim

This nimble package provides some helper functionality for doing
foreign-function-interfacing (FFI) with C functions in the Nim programming
language.

* [Distinct Type Helpers](#distinct-type-helpers)
  * [Enums as distinct Types](#enums-as-distinct-types)
  * [Bitflags as distinct types](#bitflags-as-distinct-types)
  * [Extra information](#extra-information)

## Distinct Type Helpers

Even though Nim does have enum types, these are not always the best choice
when passing values on to a native C API. Also, bitflags are regurlarly used
in C APIs, but in Nim we would rather use the `set` type for that purpose.

This nimble package provides helpers to bridge enums, semi-enums and bitflags
from C to Nim.

### Enums as distinct Types

In many C APIs, especially those that are tied to the operating system, a group
of constants is not implemented as an enum type, but rather as a series of
`#define` constants. Often this is done, to provide a clear definition of the
bit length for a parameter, since the bit-length of an enum type in C can be
ambigious depending on the compiler, target platform and other factors.

Unfortunenately, this habit makes it harder to translate C headers to equivalent
Nim bindings.

The `implementDistictEnum` macro can be placed in front of a block that declares
values for a distinct type, and will automatically implement the equality
operator, and if desired, stringify and parse procs.

Consider the following C code:

``` c
#define COLOUR_RED 1
#define COLOUR_BLUE 2
#define COLOUR_GREEN 3

typedef int COLOUR, *PCOLOR;
```

Even though this `COLOUR` type can easily be implemented as an enum, there are
cases when this is not possible or will cause complications.

Instead, let us implement the type above in Nim using a distinct type:

``` nim
type Colour = distinct int32
const
  colour_red = 1.Colour
  colour_blue = 2.Colour
  colour_green = 3.Colour
```

If we have a C API that returns a `COLOUR` value, and we wanted to do something
depending on the value returned, we would now have to implement the `==`
operator for the distinct `Colour` type in Nim. Sure, the implementation is
trivial, but it still has to be done, if we do not want to cast every `Colour`
value to an `int32` everytime we want to do something useful with it.

For that purpose, this package provides the `implementDistinctEnum` macro.

``` nim
type Colour = distinct int32
implementDistinctEnum(Colour):
  const
    colour_red = 1.Colour
    colour_blue = 2.Colour
    colour_green = 3.Colour
```

Note that the `const` block is now nested inside the `implementDistinctEnum`
macro invocation. The macro peeks into the const block and finds all identifier
definitions in the block. The identifiers that are found are used by the macro
as the *list of known values* for the `Colour` type. Then the macro generates
the simple trivial implementations for these procs:

``` nim
proc `==`*(a, b: Colour): bool = a.int32 == b.int32
proc `$`*(v: Colour): string =
  if v == colour_red: "colour_red"
  elif v == colour_blue: "colour_blue"
  elif v == colour_green: "colour_green"
  else: $(v.int32)
proc parseColour(s: string): Colour
proc tryParseColour(s: string, v: var Colour): bool
```

Note that it uses the *list of known values* for the `Colour` type to implement
the stringify and parse procs. The parse procs use case-**insensitive**
unicode comparison with the identifiers of the known values.

### Bitflags as distinct types

The Nim Manual states that `set` types should be used when implementing flag
types. However, the `set` type is not compatible with bitflags that are
regurlarly used in C, and `set` types in Nim only support bitlength of up to
16-bits.

With the `implementDistinctFlags` macro, you can easily define a bitflags type
as a distinct numeric type, and the macro will provide all the procs you would
expect from a regular Nim `set` type.

Consider the following C example:

``` c
#define BIT_0 (1 << 0)
#define BIT_1 (1 << 1)
#define BIT_2 (1 << 2)
#define BIT_3 (1 << 3)
#define BIT_4 (1 << 4)
#define BIT_5 (1 << 5)
#define BIT_6 (1 << 6)
#define BIT_7 (1 << 7)

typedef int BITFLAGS8, *PBITFLAGS8;
```

*The example above is shortened to only use 8 bits out the availble 32 bits.
Look at the test case for this package, where all 32 bits are used.*

In Nim with the `implementDistinctFlags` macro:

``` nim
type Bitflags8 = distinct int32
implementDistinctFlags(Bitflags8):
  const
    bit_0 = (1 shl 0).Bitflags8
    bit_1 = (1 shl 1).Bitflags8
    bit_2 = (1 shl 2).Bitflags8
    bit_3 = (1 shl 3).Bitflags8
    bit_4 = (1 shl 4).Bitflags8
    bit_5 = (1 shl 5).Bitflags8
    bit_6 = (1 shl 6).Bitflags8
    bit_7 = (1 shl 7).Bitflags8
```

The macro automatically provides the following procs:

``` nim
proc `==`(a, b: Bitflags8): bool
proc `and`(a, b: Bitflags8): Bitflags8
proc `or`(a, b: Bitflags8): Bitflags8
proc `not`(v: Bitflags8): Bitflags8
proc contains(a, b: Bitflags8): bool
proc `+`(a, b: Bitflags8): Bitflags8
proc `*`(a, b: Bitflags8): Bitflags8
proc `-`(a, b: Bitflags8): Bitflags8
proc `<=`(a, b: Bitflags8): bool
proc `<`(a, b: Bitflags8): bool
proc incl(a: var Bitflags8, b: Bitflags8): Bitflags8
proc excl(a: var Bitflags8, b: Bitflags8): Bitflags8
proc `$`(v: Bitflags8): string
proc parseBitflags8(s: string): Bitflags8
proc tryParseBitflags8(s: string, v: var Bitflags8): bool
```

The `==`, `contains`, `+`, `*`, `-`, `<=`, `<`, `incl`, `excl` procs provide
the `Bitflags8` with all the procs that you would get if `Bitflags8` was a `set`
type.

Stringify for Bitflags returns a comma-separated list of all set flags in the
specified value, if there are bits set that have no known value associated with
them, the remainder is shown as its decimal representation.

``` nim
doAssert (bit_0 + bit_4 + bit_6) == "{ bit_0, bit_4, bit_6 }"
doAssert (bit_0 + bit_4 + (1 shl 8).Bitflags8) == "{ bit_0, bit_4, 256 }"
```

### Extra information

For both the `implementDistinctEnum` and the `implementDistinctFlags` macros,
there are overloads that accept a static bool argument, to indicate whether the
macro should generate the stringify and parse procs. Since these methods carry
the string literals in the resulting code and thus also into the output binary,
generating these string procs can significantly increase the output binary size.
For example, the Windows SDK has several thousand lines of code where it defines
`HRESULT` values that represent various error conditions. Producing a binary
with the names of all these constants inside it can easily increase the binary
size with approximately 7 MiB.

The AST block containing the known values for the distinct type that is passed
in as the last argument for the `implementDistinctEnum` and the
`implementDistinctFlags` macros can contain multiple `const` sections. However,
**ALL** identifiers declared in that block **MUST** have the same type as the
one specified for the macro.

Passing `let` or `var` sections instead of `const` sections for the known values
to the `implementDistinctEnum` and the `implementDistinctFlags` macros is
possible, but not necessarily recommended.
