import macros

type ImportcNamingRule* = enum
  inrNone ## Perform no transformation on nim ident to produce C identifier
  inrAllUppercase
  inrCapitalize

macro importc*(namingRule: ImportcNamingRule, ast: typed): untyped =
  echo "Before:"
  echo ast.treeRepr()
  result = ast
  case result.kind
  of nnkProcDef:
    discard
  else: discard

