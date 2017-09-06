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

proc getDistinctAndBaseSym(t: typedesc): tuple[`distinct`, base: NimNode] {.compileTime.} =
  var beD = t.getType()
  beD.expectKind(nnkBracketExpr)
  beD.expectMinLen(2)
  let dSym = beD[1]
  dSym.expectKind(nnkSym)
  let beB = dSym.getType()
  beB.expectKind(nnkBracketExpr)
  beB.expectMinLen(2)
  let bSym = beB[1]
  result = (dSym, bSym)

proc getIdentAndStrLit(value: NimNode): tuple[ident, strLit: NimNode] {.compileTime.} =
  var strLit, ident: NimNode
  case value.kind
  of nnkPragmaExpr:
    value.expectMinLen(1)
    return value[0].getIdentAndStrLit
  of nnkPostfix:
    value.expectMinLen(2)
    return value[1].getIdentAndStrLit
  of nnkSym, nnkIdent:
    ident = value
    strLit = newLit($ident)
  of nnkAccQuoted:
    ident = value
    ident.expectLen(1)
    ident[0].expectKind({nnkSym, nnkIdent})
    strLit = newLit($ident)
  else: ident.expectKind({nnkSym, nnkIdent, nnkAccQuoted})
  result = (ident, strLit)

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

proc createStringifyOperator(`distinct`, base: NimNode, values: openarray[NimNode], exportable: bool = true, docString: string = nil): NimNode =
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
    elseValue = prefix(newDotExpr(valueIdent, base), "$")
  if values.len > 0:
    var ifStmt = newNimNode(nnkIfExpr)
    for value in values:
      let
        identLitTuple = value.getIdentAndStrLit()
        ident = identLitTuple.ident
        strLit = identLitTuple.strLit
      let cond = infix(valueIdent, "==", ident)
      ifStmt.add(newNimNode(nnkElifExpr).add(cond, strLit))
    ifStmt.add(newNimNode(nnkElseExpr).add(elseValue))
    procBody.add(ifStmt)
  else:
    procBody.add(elseValue)
  let procDef = newProc(
    name = if exportable: postfix(stringify, "*") else: stringify,
    params = [newIdentNode("string"), newIdentDefs(valueIdent, `distinct`)],
    body = procBody)
  result = procDef

proc createStringParseProc(`distinct`: NimNode, values: openarray[NimNode], tryParse = false, exportable = true): NimNode =
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
    for value in values:
      let
        identLitTuple = value.getIdentAndStrLit()
        ident = identLitTuple.ident
        strLit = identLitTuple.strLit
      let cmpCall = newCall(compareIdent, inputIdent, strLit)
      let condition = infix(cmpCall, "==", zeroLit)
      var branchStmts = newStmtList()
      if tryParse:
        branchStmts.add(newAssignment(targetIdent, ident))
        branchStmts.add(resultTrueAssignment)
      else:
        branchStmts = newAssignment(resultIdent, ident)
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

proc implementDistinctEnumProc(`distinct`, base: NimNode, knownValues: openArray[NimNode]): NimNode {.compileTime.} =
  ## Declares common procs for a distinct value type with the specified base type
  ## 
  ## Common procs for distinct value types:
  ## - Equality (``==``) operator, comparing by using the base type value
  ## - Stringify (``$``) operator, which returns the matching identifier name
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
  
  result = newStmtList()
  result.add(createBorrowInfixOperator(`distinct`, base, "==", docString = "Equality (``==``) " &
    "operator for the $1 type. Comparison is done by converting both the left and right argument to " & 
    "the $2 type and calling the ``==`` operator for the $2 type.".format(`distinct`, base)))
  result.add(createStringifyOperator(`distinct`, base, knownValues))
  result.add(createStringParseProc(`distinct`, knownValues))
  result.add(createStringParseProc(`distinct`, knownValues, tryParse = true))

macro implementDistinctEnum*(typ: typedesc, knownValueDecl: untyped): typed =
  ## Declares common procs for a distinct value type with the specified base type
  ##
  ## **Note**: The variable declarations in the ``knownValueDecl`` **must** all be of the distinct type.
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
  let 
    typedescTuple = getDistinctAndBaseSym(typ)
    distinctSym = typedescTuple.`distinct`
    baseSym = typedescTuple.base
  knownValueDecl.expectKind(nnkStmtList)
  result = knownValueDecl
  var knownValueIdents = newSeq[NimNode]()
  for i in 0 ..< knownValueDecl.len:
    let declSect = knownValueDecl[i]
    case declSect.kind
    of nnkConstSection, nnkLetSection, nnkVarSection:
      for j in 0 ..< declSect.len:
        let identDefs = declSect[j]
        case identDefs.kind
        of nnkConstDef, nnkIdentDefs:
          for k in 0 ..< (identDefs.len - 2):
            let
              variableDef = identDefs[k]
              variableDefTuple = variableDef.getIdentAndStrLit
              variableIdent = variableDefTuple.ident
            knownValueIdents.add(variableIdent)
        else: continue
    else: continue
  result.add(implementDistinctEnumProc(distinctSym, baseSym, knownValueIdents))
