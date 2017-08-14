import macros, strutils

type ImportcNamingRule* = enum
  inrNone ## Perform no transformation on nim ident to produce C identifier
  inrAllUppercase
  inrCapitalize

proc transformWithNamingRule(ident: string, rule: ImportcNamingRule): string =
  ident

macro importc*(namingRule: ImportcNamingRule, ast: typed): typed =
  echo "Before:"
  echo ast.treeRepr()
  result = ast
  case result.kind
  of nnkProcDef:
    discard
  else: discard

when isMainModule:
  proc testProc(): void {.importc: inrAllUppercase.}
