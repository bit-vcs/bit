name = "mizchi/bitx_kv"

version = "0.49.1"

import {
  "mizchi/bit_core@0.49.1",
  "mizchi/bit_object@0.49.1",
  "mizchi/bit_repo@0.49.1",
  "mizchi/bit_io@0.49.1",
  "mizchi/bit_lib@0.49.1",
  "mizchi/bit_types@0.49.1",
  "mizchi/bit_vfs@0.49.1",
  "mizchi/bit_osfs@0.49.1",
  "moonbitlang/async@0.22.5",
  "moonbitlang/x@0.5.6",
  "mizchi/x@0.6.1",
  "moonbitlang/regexp@0.3.6",
}

readme = "src/README.md"

repository = "https://github.com/mizchi/bit-vcs"

license = "Apache-2.0"

keywords = [ "git", "kv", "sync" ]

description = "Git-backed KV store with CRDT sync (extension module for mizchi/bit)"

source = "src"

preferred_target = "native"
