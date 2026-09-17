name = "mizchi/bit_pack"

version = "0.47.0"

import {
  "mizchi/bit_core@0.47.0",
  "mizchi/bit_object@0.47.0",
  "mizchi/bit_repo@0.47.0",
  "mizchi/bit_types@0.47.0",
  "mizchi/tempfile@0.1.2",
  "mizchi/zlib@0.4.9",
  "moonbitlang/async@0.22.1",
  "moonbitlang/x@0.5.5",
}

repository = "https://github.com/mizchi/bit-vcs"

license = "Apache-2.0"

keywords = [ "git", "pack", "packfile", "index" ]

description = "Git packfile encoder/decoder + index (gix-pack equivalent)"

source = "src"

preferred_target = "native"
