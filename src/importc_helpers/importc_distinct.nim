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

proc createBorrowInfixOperator(`distinct`, base: NimNode, op: string,
  returnType: NimNode = bindSym("bool"), exportable: bool = true,
  docString: string = nil): NimNode =
  let
    leftArgIdent = ident("a")
    rightArgIdent = ident("b")
    leftBaseValue = newDotExpr(leftArgIdent, base) # a.base
    rightBaseValue = newDotExpr(rightArgIdent, base) # b.base
    argsIdentDefs = newNimNode(nnkIdentDefs)
      .add(leftArgIdent, rightArgIdent, `distinct`, newEmptyNode())
  var procBody = infix(leftBaseValue, op, rightBaseValue)
  if docString.len > 0:
    var docComment = newNimNode(nnkCommentStmt)
    docComment.strVal = docString
    procBody = newStmtList(docComment, procBody)
  var procName = newNimNode(nnkAccQuoted).add(ident(op))
  if exportable: procName = postfix(procName, "*")
  result = newProc(
    name = procName, params = [returnType, argsIdentDefs],
    body = procBody)

proc createStringifyOperator(`distinct`, base: NimNode,
  values: openarray[NimNode], exportable: bool = true,
  docString: string = nil): NimNode =
  var procBody = newStmtList()
  var docComment = newNimNode(nnkCommentStmt)
  if docString.isNil or docString.len < 1:
    docComment.strVal = ("Stringify (``$$``) operator that converts a ``$1`` value to its string representation").format(`distinct`)
    discard
  else:
    docComment.strVal = docString
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
    params = [bindSym("string"), newIdentDefs(valueIdent, `distinct`)],
    body = procBody)
  result = procDef

proc createStringParseProc(`distinct`: NimNode, values: openarray[NimNode],
  tryParse = false, exportable = true): NimNode =
  let
    procIdent = if tryParse: ident("tryParse" & $`distinct`)
      else: ident("parse" & $`distinct`)
    inputIdent = ident("s")
    inputType = ident("string")
    resultIdent = ident("result")
    compareIdent = bindSym("cmpRunesIgnoreCase")
    zeroLit = newLit(0)
    targetIdent = ident("value")
    resultTrueAssignment = newAssignment(resultIdent, newLit(true))
    resultFalseAssignment = newAssignment(resultIdent, newLit(false))
    messageFormatLit = newLit("Cannot parse \"$$#\" as $#".format(`distinct`))
    messageCall = newCall(bindSym("format"), messageFormatLit, inputIdent)
    newExceptionCall = newCall(
      bindSym("newException"),
      ident("ValueError"),
      messageCall)
    raiseStmt = newNimNode(nnkRaiseStmt).add(newExceptionCall)
  var procBody = newStmtList()
  var docComment = newNimNode(nnkCommentStmt)
  if tryParse:
    docComment.strVal = ("Attempts to parse the string ``s`` to a ``$#`` value. Sets ``value`` to the parsed value and returns ``true`` if successful. Returns ``false`` and leaves ``value`` unmodified otherwise.")
      .format(`distinct`)
  else:
    docComment.strVal = ("Parse the string ``s`` to a ``$#`` value. Raises a ``ValueError`` if unsuccessful.")
      .format(`distinct`)
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
  if tryParse: paramsSeq.add(newIdentDefs(targetIdent, newNimNode(nnkVarTy)
    .add(`distinct`)))
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

proc implementDistinctEnumProc(`distinct`, base: NimNode,
  knownValues: openArray[NimNode]): NimNode {.compileTime.} =
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
  result.add(createBorrowInfixOperator(`distinct`, base, "==", docString = ("Equality (``==``) " &
    "operator for the ``$1`` type. Comparison is done by converting both the left and right argument to " &
    "the ``$2`` type and calling the ``==`` operator for the ``$2`` type.").format(`distinct`, base)))
  result.add(createStringifyOperator(`distinct`, base, knownValues))
  result.add(createStringParseProc(`distinct`, knownValues))
  result.add(createStringParseProc(`distinct`, knownValues, tryParse = true))

macro implementDistinctEnum*(typ: typedesc, noStrings: static[bool], knownValueDecl: untyped): typed =
  ## Declares common procs for a distinct value type with the specified base type
  ##
  ## Optionally, suppresses the generation of stringify and parse procs, to prevent string literals
  ## increasing compile time and output binary size. If ``noStrings`` is set to ``true`` at
  ## compile time, the stringify (``$``) operator, the ``parse`` and the ``tryParse`` procs are
  ## not generated.
  ##
  ## **Note**: The variable declarations in the ``knownValueDecl`` **must** all be of the distinct type.
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

macro implementDistinctEnum*(typ: typedesc, knownValueDecl: untyped): typed =
  ## Declares common procs for a distinct value type with the specified base type
  ##
  ## **Note**: The variable declarations in the ``knownValueDecl`` **must** all be of the distinct type.
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
  getAst(implementDistinctEnum(typ, false, knownValueDecl))

proc createSimpleProc(procIdent, `distinct`, resultType: NimNode, resultValue: proc(aIdent, bIdent: NimNode): NimNode {.noSideEffect.}, exportable = true, docString: string = nil): NimNode {.compileTime.} =
  var
    procBody = newStmtList()
  if docString.len > 0:
    var docComment = newNimNode(nnkCommentStmt)
    docComment.strVal = docString
    procBody.add(docComment)
  let
    aIdent = ident("a")
    bIdent = ident("b")
    resultIdent = ident("result")
    returnStmt = newAssignment(resultIdent, resultValue(aIdent, bIdent))
  procBody.add(returnStmt)
  var paramsIdentDefs = newNimNode(nnkIdentDefs)
  paramsIdentDefs.add(aIdent, bIdent, `distinct`, newEmptyNode())
  result = newProc(
    name = if exportable: postfix(procIdent, "*") else: procIdent,
    params = [resultType, paramsIdentDefs],
    body = procBody)

proc createSimpleProc(procIdent, `distinct`, resultType: NimNode, resultValue: proc(aIdent: NimNode): NimNode {.noSideEffect.}, exportable = true, docString: string = nil): NimNode {.compileTime.} =
  var
    procBody = newStmtList()
  if docString.len > 0:
    var docComment = newNimNode(nnkCommentStmt)
    docComment.strVal = docString
    procBody.add(docComment)
  let
    aIdent = ident("a")
    resultIdent = ident("result")
    returnStmt = newAssignment(resultIdent, resultValue(aIdent))
  procBody.add(returnStmt)
  var paramsIdentDefs = newNimNode(nnkIdentDefs)
  paramsIdentDefs.add(aIdent, `distinct`, newEmptyNode())
  result = newProc(
    name = if exportable: postfix(procIdent, "*") else: procIdent,
    params = [resultType, paramsIdentDefs],
    body = procBody)

proc createSimpleVarAssignProc(procIdent, `distinct`: NimNode, targetValue: proc(aIdent, bIdent: NimNode): NimNode {.noSideEffect.}, exportable = true, docString: string = nil): NimNode {.compileTime.} =
  var
    procBody = newStmtList()
  if docString.len > 0:
    var docComment = newNimNode(nnkCommentStmt)
    docComment.strVal = docString
    procBody.add(docComment)
  let
    aIdent = ident("a")
    bIdent = ident("b")
    returnStmt = newAssignment(aIdent, targetValue(aIdent, bIdent))
  procBody.add(returnStmt)
  var
    targetIdentType = newNimNode(nnkVarTy)
    targetIdentDefs = newNimNode(nnkIdentDefs)
    valueIdentDefs = newNimNode(nnkIdentDefs)
  targetIdentType.add(`distinct`)
  targetIdentDefs.add(aIdent, targetIdentType, newEmptyNode())
  valueIdentDefs.add(bIdent, `distinct`, newEmptyNode())
  result = newProc(
    name = if exportable: postfix(procIdent, "*") else: procIdent,
    params = [newEmptyNode(), targetIdentDefs, valueIdentDefs],
    body = procBody)

proc createSimpleOperatorProc(`distinct`, resultType: NimNode, operator: string, resultValue: proc(aIdent, bIdent: NimNode): NimNode {.noSideEffect.}, exportable: bool = true, docString: string = nil): NimNode {.compileTime.} =
  let op = newNimNode(nnkAccQuoted).add(ident(operator))
  result = createSimpleProc(op, `distinct`, resultType, resultValue, exportable, docString)

proc createSimpleOperatorProc(`distinct`, resultType: NimNode, operator: string, resultValue: proc(aIdent: NimNode): NimNode {.noSideEffect.}, exportable: bool = true, docString: string = nil): NimNode {.compileTime.} =
  let op = newNimNode(nnkAccQuoted).add(ident(operator))
  result = createSimpleProc(op, `distinct`, resultType, resultValue, exportable, docString)

proc createSimpleOperatorProc(`distinct`: NimNode, operator: string, resultValue: proc(aIdent, bIdent: NimNode): NimNode {.noSideEffect.}, exportable: bool = true, docString: string = nil): NimNode {.compileTime.} =
  createSimpleOperatorProc(`distinct`, `distinct`, operator, resultValue, exportable, docString)

proc createSimpleOperatorProc(`distinct`: NimNode, operator: string, resultValue: proc(aIdent: NimNode): NimNode {.noSideEffect.}, exportable: bool = true, docString: string = nil): NimNode {.compileTime.} =
  createSimpleOperatorProc(`distinct`, `distinct`, operator, resultValue, exportable, docString)

proc createContainsFlagsProc(`distinct`: NimNode, exportable: bool = true, docString: string = nil): NimNode {.compileTime.} =
  let resultProc = proc(aIdent, bIdent: NimNode): NimNode {.noSideEffect.} =
    infix(newPar(infix(bIdent, "and", aIdent)), "==", bIdent)
  let docStringVal = if docString.len > 0: docString
    else: "Returns whether all bits in ``b`` are set in ``a`` and is equal to ``(b and a) == b``."
  result = createSimpleProc(ident("contains"), `distinct`, bindSym("bool"), resultProc, exportable, docStringVal)

proc createUnionFlagsOperator(`distinct`: NimNode, exportable: bool = true, docString: string = nil): NimNode {.compileTime.} =
  let resultProc = proc(aIdent, bIdent: NimNode): NimNode {.noSideEffect.} =
    infix(aIdent, "or", bIdent)
  let docStringVal = if docString.len > 0: docString
    else: "Union operator for ``$#`` values. Returns the binary AND of the two operands and is equal to ``a or b``.".format(`distinct`)
  result = createSimpleOperatorProc(`distinct`, "+", resultProc, exportable, docStringVal)

proc createIntersectionFlagsOperator(`distinct`: NimNode, exportable: bool = true, docString: string = nil): NimNode {.compileTime.} =
  let resultProc = proc(aIdent, bIdent: NimNode): NimNode {.noSideEffect.} =
    infix(aIdent, "and", bIdent)
  let docStringVal = if docString.len > 0: docString
    else: "Intersection operator for ``$#`` values. Returns the binary AND of the two operands and is equal to ``a and b``.".format(`distinct`)
  result = createSimpleOperatorProc(`distinct`, "*", resultProc, exportable, docStringVal)

proc createDifferenceFlagsOperator(`distinct`: NimNode, exportable: bool = true, docString: string = nil): NimNode {.compileTime.} =
  let resultProc = proc(aIdent, bIdent: NimNode): NimNode {.noSideEffect.} =
    infix(aIdent, "and", newPar(prefix(bIdent, "not")))
  let docStringVal = if docString.len > 0: docString
    else: "Difference operator for ``$#`` values. Returns ``a`` intersected with the binary complement of ``b`` and is equal to ``a and (not b)``.".format(`distinct`)
  result = createSimpleOperatorProc(`distinct`, "-", resultProc, exportable, docStringVal)

proc createSubsetFlagsOperator(`distinct`: NimNode, exportable: bool = true, docString: string = nil): NimNode {.compileTime.} =
  let resultProc = proc(aIdent, bIdent: NimNode): NimNode {.noSideEffect.} =
    infix(aIdent, "in", bIdent)
  let docStringVal = if docString.len > 0: docString
    else: "Subset operator for ``$#`` values. Returns whether ``a`` is a subset of ``b`` and is equal to ``(a and b) == a``.".format(`distinct`)
  result = createSimpleOperatorProc(`distinct`, bindSym("bool"), "<=", resultProc, exportable, docStringVal)

proc createProperSubsetFlagsOperator(`distinct`: NimNode, exportable: bool = true, docString: string = nil): NimNode {.compileTime.} =
  let resultProc = proc(aIdent, bIdent: NimNode): NimNode {.noSideEffect.} =
    infix(newPar(infix(aIdent, "!=", bIdent)), "and", newPar(infix(aIdent, "in", bIdent)))
  let docStringVal = if docString.len > 0: docString
    else: "Proper Subset operator for ``$1`` values. Returns whether ``a`` is a proper subset of ``b`` and is equal to ``(a != b) and (a in b)``.".format(`distinct`)
  result = createSimpleOperatorProc(`distinct`, bindSym("bool"), "<", resultProc, exportable, docStringVal)

proc createIncludeFlagsProc(`distinct`: NimNode, exportable = true, docString: string = nil): NimNode {.compileTime.} =
  let asgnProc = proc(aIdent, bIdent: NimNode): NimNode {.noSideEffect.} =
    infix(aIdent, "+", bIdent)
  let docStringVal = if docString.len > 0: docString
    else: "Include flags proc for ``$1`` values. Same as ``a = a + b``.".format(`distinct`)
  result = createSimpleVarAssignProc(ident("incl"), `distinct`, asgnProc, exportable, docStringVal)

proc createExcludeFlagsProc(`distinct`: NimNode, exportable = true, docString: string = nil): NimNode {.compileTime.} =
  let asgnProc = proc(aIdent, bIdent: NimNode): NimNode {.noSideEffect.} =
    infix(aIdent, "-", bIdent)
  let docStringVal = if docString.len > 0: docString
    else: "Exclude flags proc for ``$1`` values. Same as ``a = a - b``.".format(`distinct`)
  result = createSimpleVarAssignProc(ident("excl"), `distinct`, asgnProc, exportable, docStringVal)

proc createStringifyFlagsOperator(`distinct`, base: NimNode, values: openarray[NimNode], exportable: bool = true, docString: string = nil): NimNode =
  var procBody = newStmtList()
  var docComment = newNimNode(nnkCommentStmt)
  if docString.isNil or docString.len < 1:
    docComment.strVal = "Stringify (``$$``) operator that converts a ``$1`` value to its string representation".format(`distinct`)
  else:
    docComment.strVal = docString
  procBody.add(docComment)
  let
    stringify = newNimNode(nnkAccQuoted).add(ident("$"))
    stringSym = bindSym("string")
    seqSym = bindSym("seq")
    valueIdent = ident("v")
    xIdent = ident("x")
    xIdentDefs = newIdentDefs(xIdent, newEmptyNode(), valueIdent)
    tIdent = ident("t")
    tIdentDefs = newIdentDefs(tIdent, base)
    sseqIdent = ident("sseq")
    sseqType = newNimNode(nnkBracketExpr).add(seqSym, stringSym)
    sseqInitValue = prefix(newNimNode(nnkBracket), "@")
    sseqIdentDefs = newIdentDefs(sseqIdent, sseqType, sseqInitValue)
    addSym = bindSym("add")
    exclIdent = ident("excl")
    resultIdent = ident("result")
  procBody.add(newNimNode(nnkVarSection).add(xIdentDefs, tIdentDefs, sseqIdentDefs))
  for knownValue in values:
    let
      identLitTuple = knownValue.getIdentAndStrLit()
      knownIdent = identLitTuple.ident
      knownStrLit = identLitTuple.strLit
      cond = infix(knownIdent, "in", valueIdent)
      addCall = newCall(addSym, sseqIdent, knownStrLit)
      exclCall = newCall(exclIdent, xIdent, knownIdent)
    procBody.add(newIfStmt((cond, newStmtList(addCall, exclCall))))
  let
    xBaseValue = newDotExpr(xIdent, base)
    nonzeroCond = infix(xBaseValue, "!=", tIdent)
    xBaseStringify = prefix(xBaseValue, "$")
    addCall = newCall(addSym, sseqIdent, xBaseStringify)
  procBody.add(newIfStmt((nonzeroCond, newStmtList(addCall))))
  let
    sJoinedIdent = ident("sJoined")
    sJoinedValue = newCall(bindSym("join"), sseqIdent, newLit(", "))
    sJoinedIdentDefs = newIdentDefs(sJoinedIdent, stringSym, sJoinedValue)
  procBody.add(newNimNode(nnkLetSection).add(sJoinedIdentDefs))
  let
    noJoinedStringCond = infix(newCall(bindSym("len"), sJoinedIdent), "<", newLit(1))
    valueBaseStringify = newPar(prefix(newDotExpr(valueIdent, base), "$"))
    prefixLit = newLit("{ ")
    postfixLit = newLit(" }")
    altResultValue = infix(infix(prefixLit, "&", valueBaseStringify), "&", postfixLit)
    altResultAsgn = newAssignment(resultIdent, altResultValue)
    resultValue = infix(infix(prefixLit, "&", sJoinedIdent), "&", postfixLit)
    resultAsgn = newAssignment(resultIdent, resultValue)
  var resultIfStmt = newIfStmt((noJoinedStringCond, newStmtList(altResultAsgn)))
  resultIfStmt.add(newNimNode(nnkElse).add(newStmtList(resultAsgn)))
  procBody.add(resultIfStmt)
  let procDef = newProc(
    name = if exportable: postfix(stringify, "*") else: stringify,
    params = [stringSym, newIdentDefs(valueIdent, `distinct`)],
    body = procBody)
  result = procDef

proc implementDistinctFlagsProc(`distinct`, base: NimNode, noStrings: bool, knownValues: openArray[NimNode]): NimNode {.compileTime.} =
  # echo treeRepr(`distinct`)
  `distinct`.expectKind({nnkIdent, nnkSym})
  # echo treeRepr(base)
  base.expectKind({nnkIdent, nnkSym})
  # echo treeRepr(knownValues)

  result = newStmtList()
  result.add(createBorrowInfixOperator(`distinct`, base, "==", docString = ("Equality (``==``) " &
    "operator for the ``$1`` type. Comparison is done by converting both the left and right argument to " &
    "the ``$2`` type and calling the ``==`` operator for the ``$2`` type.").format(`distinct`, base)))
  let
    andResult = proc(aIdent, bIdent: NimNode): NimNode {.noSideEffect.} =
      newDotExpr(newPar(infix(newPar(newDotExpr(aIdent, base)), "and", newPar(newDotExpr(bIdent, base)))), `distinct`)
    orResult = proc(aIdent, bIdent: NimNode): NimNode {.noSideEffect.} =
      newDotExpr(newPar(infix(newPar(newDotExpr(aIdent, base)), "or", newPar(newDotExpr(bIdent, base)))), `distinct`)
    notResult = proc(vIdent: NimNode): NimNode {.noSideEffect.} =
      newDotExpr(newPar(newCall(ident("not"), newDotExpr(vIdent, base))), `distinct`)
  result.add(createSimpleOperatorProc(`distinct`, "and", andResult, docString = ("Binary AND (``and``) " &
    "operator (``&`` in C-like languages) for the ``$1`` type. Implemented by converting both the left and right argument to " &
    "the ``$2`` type and calling the ``and`` operator for the ``$2`` type.").format(`distinct`, base)))
  result.add(createSimpleOperatorProc(`distinct`, "or", orResult, docString = ("Binary OR (``or``) " &
    "operator (``|`` in C-like languages) for the ``$1`` type. Implemented by converting both the left and right argument to " &
    "the ``$2`` type and calling the ``or`` operator for the ``$2`` type.").format(`distinct`, base)))
  result.add(createSimpleOperatorProc(`distinct`, "not", notResult, docString = ("Binary complement (``not``) " &
    "operator (``~`` in C-like languages) for the ``$1`` type. Implemented by converting both the argument to " &
    "the ``$2`` type and calling the ``not`` operator for the ``$2`` type.").format(`distinct`, base)))
  result.add(createContainsFlagsProc(`distinct`))
  result.add(createUnionFlagsOperator(`distinct`))
  result.add(createIntersectionFlagsOperator(`distinct`))
  result.add(createDifferenceFlagsOperator(`distinct`))
  result.add(createSubsetFlagsOperator(`distinct`))
  result.add(createProperSubsetFlagsOperator(`distinct`))
  result.add(createIncludeFlagsProc(`distinct`))
  result.add(createExcludeFlagsProc(`distinct`))
  if not noStrings:
    result.add(createStringifyFlagsOperator(`distinct`, base, knownValues))
    result.add(createStringParseProc(`distinct`, knownValues))
    result.add(createStringParseProc(`distinct`, knownValues, tryParse = true))

macro implementDistinctFlags*(typ: typedesc, noStrings: static[bool], knownValueDecl: untyped): typed =
  ## Declares common procs for a distinct flags type with the specified base type
  ##
  ## Optionally, suppresses the generation of stringify and parse procs, to prevent string literals
  ## increasing compile time and output binary size. If ``noStrings`` is set to ``true`` at
  ## compile time, the stringify (``$``) operator, the ``parse`` and the ``tryParse`` procs are
  ## not generated.
  ##
  ## **Note**: The variable declarations in the ``knownValueDecl`` **must** all be of the distinct type.
  ##
  ## Common procs for distinct value types:
  ## - Equality (``==``) operator, comparing by using the base type value
  ## - Binary AND (``and``) operator (``&`` in C), using the ``and`` operator on the base type value
  ## - Binary OR (``or``) operator (``|`` in C), using the ``or`` operator on the base type value
  ## - Binary complement (``not``) operator (``~`` in C), using the ``or`` operator on the base type value
  ## - Nim's set-union (``+``) operator as an alias to `or`.
  ## - Nim's set-intersection (``*``) operator as an alias to `and`.
  ## - Nim's set-difference (``-``) operator.
  ## - Nim's subset (``<=``) operator.
  ## - Nim's strong subset (``<``) operator.
  ## - A ``contains(A, e)`` proc that checks whether all bits in ``e`` are set in ``A``.
  ## - An ``incl(A, elem)`` as an alias for ``A = A + elem``
  ## - An ``excl(A, elem)`` as an alias for ``A = A - elem``
  ## - | Stringify (``$``) operator, which returns the Nim set notation for a flags value.
  ##   | E.g.: ``"{ bit_1, bit2, bit3 }"``
  ## - ``parse<distinct>`` which parses a string value using case-insensitive matching against
  ##   the identifiers specified in the ``knownValues`` parameter. Throws a ``ValueError`` if
  ##   no match is found.
  ## - ``tryParse<distinct>`` does the same as ``parse<distinct>``, but writes the result into a
  ##   var argument and returns a boolean value to indicate success. Does not throw an error.
  ## **Note that parsing flags values only works for one flag at a time.**
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
  result.add(implementDistinctFlagsProc(distinctSym, baseSym, noStrings, knownValueIdents))

macro implementDistinctFlags*(typ: typedesc, knownValueDecl: untyped): typed =
  ## Declares common procs for a distinct flags type with the specified base type
  ##
  ## **Note**: The variable declarations in the ``knownValueDecl`` **must** all be of the distinct type.
  ##
  ## Common procs for distinct value types:
  ## - Equality (``==``) operator, comparing by using the base type value
  ## - Binary AND (``and``) operator (``&`` in C), using the ``and`` operator on the base type value
  ## - Binary OR (``or``) operator (``|`` in C), using the ``or`` operator on the base type value
  ## - Binary complement (``not``) operator (``~`` in C), using the ``or`` operator on the base type value
  ## - Nim's set-union (``+``) operator as an alias to `or`.
  ## - Nim's set-intersection (``*``) operator as an alias to `and`.
  ## - Nim's set-difference (``-``) operator.
  ## - Nim's subset (``<=``) operator.
  ## - Nim's strong subset (``<``) operator.
  ## - A ``contains(A, e)`` proc that checks whether all bits in ``e`` are set in ``A``.
  ## - An ``incl(A, elem)`` as an alias for ``A = A + elem``
  ## - An ``excl(A, elem)`` as an alias for ``A = A - elem``
  ## - | Stringify (``$``) operator, which returns the Nim set notation for a flags value.
  ##   | E.g.: ``"{ bit_1, bit2, bit3 }"``
  ## - ``parse<distinct>`` which parses a string value using case-insensitive matching against
  ##   the identifiers specified in the ``knownValues`` parameter. Throws a ``ValueError`` if
  ##   no match is found.
  ## - ``tryParse<distinct>`` does the same as ``parse<distinct>``, but writes the result into a
  ##   var argument and returns a boolean value to indicate success. Does not throw an error.
  ## **Note that parsing flags values only works for one flag at a time.**
  getAst(implementDistinctFlags(typ, false, knownValueDecl))
