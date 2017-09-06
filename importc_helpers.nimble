# Package

packageName   = "importc_helpers"
version       = "0.2.1"
author        = "Fredrik H\x9Bis\x91ther Rasch"
description   = "Nim support library for importing symbols from C"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 0.17.0"

import strutils, ospaths

before test:
  mkDir "bin"

before docall:
  mkDir "doc"

task docall, "Document srcDir recursively":
  proc recurseDir(srcDir, docDir: string, nimOpts: string = "") =
    for srcFile in listFiles(srcDir):
      if not srcFile.endsWith(".nim"):
        echo "skipping non nim file: $#" % [srcFile]
        continue
      const htmlExt = ".html"
      let docFile = docDir & srcFile[srcDir.len ..^ htmlExt.len] & htmlExt
      echo "file: $# -> $#" % [srcFile, docFile]
      exec "nim doc2 $# -o:\"$#\" \"$#\"" % [nimOpts, docFile, srcFile]
    for srcSubDir in listDirs(srcDir):
      let docSubDir = docDir & srcSubDir[srcDir.len ..^ 1]
      # echo "dir: $# -> $#" % [srcSubDir, docSubDir]
      mkDir docSubDir
      recurseDir(srcSubDir, docSubDir)

  let docDir = "doc"
  recurseDir(srcDir, docDir)

task test, "Test runs the package":
  for srcFile in listFiles("test"):
    if srcFile.endsWith(".nim"):
      let srcName = srcFile.splitFile().name
      let cmd = "nim compile --run --nimcache:obj -o:\"" & ("bin" / srcName) & "\" \"" & srcFile & "\""
      echo cmd
      exec cmd
