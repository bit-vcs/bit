name = "mizchi/bitx_wal"

version = "0.49.0"

import {
  "mizchi/bit_hash@0.49.0",
  "mizchi/bit_object@0.49.0",
  "mizchi/bit_objstore@0.49.0",
  "moonbitlang/async@0.22.5",
}

repository = "https://github.com/mizchi/bit-vcs"

license = "Apache-2.0"

keywords = [ "wal", "storage", "cas", "log" ]

description = "Write-ahead log over object storage, coordinated by compare-and-swap"

source = "src"

preferred_target = "native"
