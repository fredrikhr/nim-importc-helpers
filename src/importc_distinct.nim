import macros

macro implementDistinctEnum*(`distinct`, base: typed, knownValues: varargs[untyped]): typed =
  ## Declares common procs for a distinct value type with the specified base type
  ## 
  ## Common procs for distinct value types:
  ## - Equality (``==``) operator, comparing by using the base type value
  ## - Stringify (``$``) operator, which returns the matching identifier name in **all uppercase**
  ##   specified in the ``knownValues`` parameter.
  ## - ``parse<distinct>`` which parses a string value using case-insensitive matching against
  ##   the identifiers specified in the ``knownValues`` parameter. Throws a ``ValueError`` if
  ##   no match is found
  ## - ``tryParse<distinct>`` does the same as ``parse<distinct>``, but writes the result into an
  ##   optional var argument and returns a boolean value to indicate success. Does not throw an error.
  discard
  # echo treeRepr(`distinct`)
  `distinct`.expectKind({nnkIdent, nnkSym})
  # echo treeRepr(base)
  base.expectKind({nnkIdent, nnkSym})
  # echo treeRepr(knownValues)
  knownValues.expectKind({nnkArgList, nnkBracket})

type DistinctInt = distinct int
implementDistinctEnum(DistinctInt, int)
