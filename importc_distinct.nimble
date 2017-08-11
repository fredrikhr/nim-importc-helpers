# Package

packageName   = "importc_distinct"
version       = "0.1.0"
author        = "Fredrik H\x9Bis\x91ther Rasch"
description   = "Nim support library for importing enum and flag types from C to fully implemented distinct types"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 0.17.0"

import strutils, ospaths

before test:
  mkDir "bin"

before debugBuild:
  mkDir "bin"

before docall:
  mkDir "doc"

task docall, "Document srcDir recursively":
  proc recurseDir(srcDir, docDir: string, nimOpts: string = "") =
    for srcFile in listFiles(srcDir):
      if not srcFile.endsWith(".nim"):
        echo "skipping non nim file: $#" % [srcFile]
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
  exec "nim compile --run --nimcache:obj -o:" & ("bin" / packageName) & " " & (srcDir / packageName)

task debugBuild, "Creates a debug build of the package":
  exec "nim compile --nimcache:obj -o:" & ("bin" / packageName) & " " & (srcDir / packageName)
