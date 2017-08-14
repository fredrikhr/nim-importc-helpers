## Provides macros to auto-implement procs for distinct types that have been
## declared to represent groups of C define symbols.
##
## For the most this module differentiates between two variations of dinstinct
## types:
## Distinct Value types:
##     Like an enum type, but with an actual base type, so that the values can
##     be used in ``importc`` calls.
##     
##     In C, this would typically manifest itself as multiple ``#define``
##     statements each with a common prefix and an all caps identifier
##
##     The HRESULT Values in the Windows SDK as documented on MSDN are a good
##     example of this. (ref.: https://msdn.microsoft.com/en-us/library/cc704587.aspx )
##
## Distinct Flag types:
##     Similar to the one above, but with the values being arranged for a 
##     bit-pattern. Flag types also require the binary ``and``, ``or`` and ``not``
##     operators to be useful.

import macros, strutils, unicode

proc createBorrowInfixOperator(`distinct`, base: NimNode, op: string, returnType: NimNode = ident("bool"), exportable: bool = true, docString: string = nil): NimNode =
  let
    leftArgIdent = ident("a")
    rightArgIdent = ident("b")
    leftBaseValue = newDotExpr(leftArgIdent, base) # a.base
    rightBaseValue = newDotExpr(rightArgIdent, base) # b.base
    argsIdentDefs = newNimNode(nnkIdentDefs).add(leftArgIdent, rightArgIdent, `distinct`, newEmptyNode())
  var procBody = infix(leftBaseValue, op, rightBaseValue)
  if docString.len > 0:
    var docComment = newNimNode(nnkCommentStmt)
    # docComment.strVal = docComment
    procBody = newStmtList(docComment, procBody)
  var procName = newNimNode(nnkAccQuoted).add(ident(op))
  if exportable: procName = postfix(procName, "*")
  result = newProc(
    name = procName, params = [returnType, argsIdentDefs],
    body = procBody)
  when defined(debug): echo repr(result)

proc createStringifyOperator(`distinct`, base, values: NimNode, exportable: bool = true, docString: string = nil): NimNode =
  var procBody = newStmtList()
  var docComment = newNimNode(nnkCommentStmt)
  if docString.isNil or docString.len < 1:
    # docComment.strVal = "Stringify (``$$``) operator that converts a $1 value to its **all uppercase** string representation".format(`distinct`)
    discard
  else:
    # docComment.strVal = docString
    discard
  procBody.add(docComment)
  let
    valueIdent = ident("v")
    stringify = newNimNode(nnkAccQuoted).add(ident("$"))
  var caseStmt = newNimNode(nnkCaseStmt).add(valueIdent)
  if values.len > 0:
    for value in values.children:
      var strLit: NimNode
      case value.kind
      of nnkIdent, nnkSym:
        strLit = newLit(unicode.toUpper($value))
      of nnkAccQuoted:
        value.expectLen(1)
        value[0].expectKind({nnkIdent, nnkSym})
        strLit = newLit(unicode.toUpper($value[0]))
      else: value.expectKind({nnkIdent, nnkSym, nnkAccQuoted})
      caseStmt.add(newNimNode(nnkOfBranch).add(value, strLit))
  caseStmt.add(newNimNode(nnkElse).add(prefix(newDotExpr(valueIdent, base), "$")))
  procBody.add(caseStmt)
  let procDef = newProc(
    name = if exportable: postfix(stringify, "*") else: stringify,
    params = [newIdentNode("string"), newIdentDefs(valueIdent, `distinct`)],
    body = procBody)
  result = procDef

proc createStringParseProc(`distinct`, values: NimNode, tryParse = false, exportable = true): NimNode =
  let
    procIdent = if tryParse: ident("tryParse" & $`distinct`) else: ident("parse" & $`distinct`)
    inputIdent = ident("s")
    inputType = ident("string")
    resultIdent = ident("result")
    compareIdent = ident("cmpRunesIgnoreCase")
    zeroLit = newLit(0)
    targetIdent = ident("value")
    resultTrueAssignment = newAssignment(resultIdent, newLit(true))
    resultFalseAssignment = newAssignment(resultIdent, newLit(false))
    messageFormatLit = newLit("Cannot parse \"$$#\" as $#".format(`distinct`))
    messageCall = newCall(bindSym("format"), messageFormatLit, inputIdent)
    newExceptionCall = newCall(bindSym("newException"), ident("ValueError"), messageCall)
    raiseStmt = newNimNode(nnkRaiseStmt).add(newExceptionCall)
  var procBody = newStmtList()
  var docComment = newNimNode(nnkCommentStmt)
  if tryParse:
    # docComment.strVal = "Attempts to parse the string ``s`` to a $# value. Sets ``value`` to the parsed value and returns ``true`` if successful. Returns ``false`` and leaves ``value`` unmodified otherwise.".format(`distinct`)
    discard
  else:
    # docComment.strVal = "Parse the string ``s`` to a $# value. Raises a ValueError if unsuccessful.".format(`distinct`)
    discard
  procBody.add(docComment)
  if values.len > 0:
    var ifStmt = newNimNode(nnkIfStmt)
    for value in values.children:
      var strLit: NimNode
      case value.kind
      of nnkSym, nnkIdent:
        strLit = newLit($value)
      of nnkAccQuoted:
        value.expectLen(1)
        value[0].expectKind({nnkSym, nnkIdent})
        strLit = newLit($value)
      else: value.expectKind({nnkSym, nnkIdent, nnkAccQuoted})
      let cmpCall = newCall(compareIdent, inputIdent, strLit)
      let condition = infix(cmpCall, "==", zeroLit)
      var branchStmts = newStmtList()
      if tryParse:
        branchStmts.add(newAssignment(targetIdent, value))
        branchStmts.add(resultTrueAssignment)
      else:
        branchStmts = newAssignment(resultIdent, value)
      let branchNode = newNimNode(nnkElifBranch)
      branchNode.add(condition, branchStmts)
      ifStmt.add(branchNode)
    var elseBranch = newNimNode(nnkElse)
    var elseStmts = newStmtList()
    if tryParse:
      elseStmts.add(resultFalseAssignment)
    else:
      elseStmts = raiseStmt
    elseBranch.add(elseStmts)
    ifStmt.add(elseBranch)
    procBody.add(ifStmt)
  elif tryParse:
    procBody.add(resultFalseAssignment)
  else:
    procBody.add(raiseStmt)
  var paramsSeq = newSeqOfCap[NimNode](3)
  if tryParse:
    paramsSeq.add(ident("bool"))
  else:
    paramsSeq.add(`distinct`)
  paramsSeq.add(newIdentDefs(inputIdent, inputType))
  if tryParse: paramsSeq.add(newIdentDefs(targetIdent, newNimNode(nnkVarTy).add(`distinct`)))
  var procDef = newProc(
    name = if exportable: postfix(procIdent, "*") else: procIdent,
    params = paramsSeq,
    body = procBody
    )
  if not tryParse:
    let
      bracket = newNimNode(nnkBracket).add(ident("ValueError"))
      pragmaExpr = newColonExpr(ident("raises"), bracket)
    procDef.addPragma(pragmaExpr)
  result = procDef

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
  ## - ``tryParse<distinct>`` does the same as ``parse<distinct>``, but writes the result into a
  ##   var argument and returns a boolean value to indicate success. Does not throw an error.
  # echo treeRepr(`distinct`)
  `distinct`.expectKind({nnkIdent, nnkSym})
  # echo treeRepr(base)
  base.expectKind({nnkIdent, nnkSym})
  # echo treeRepr(knownValues)
  knownValues.expectKind({nnkArgList, nnkBracket})

  result = newStmtList()
  result.add(createBorrowInfixOperator(`distinct`, base, "==", docString = "Equality (``==``) " &
    "operator for the $1 type. Comparison is done by converting both the left and right argument to " & 
    "the $2 type and calling the ``==`` operator for the $2 type.".format(`distinct`, base)))
  result.add(createStringifyOperator(`distinct`, base, knownValues))
  result.add(createStringParseProc(`distinct`, knownValues))
  result.add(createStringParseProc(`distinct`, knownValues, tryParse = true))

when isMainModule:
  type DistinctInt = distinct int
  const zero = 0.DistinctInt
  const one = 1.DistinctInt
  implementDistinctEnum(DistinctInt, int, zero, one)

  doAssert $zero == "ZERO"
  doAssert $one == "ONE"

  doAssert 0.DistinctInt == zero
  doAssert one != zero

  doAssert "zero".parseDistinctInt() == zero
  
  var parsed: DistinctInt
  doAssert "ZeRo".tryParseDistinctInt(parsed) and parsed == zero
