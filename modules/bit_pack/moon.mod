name = "mizchi/bit_pack"

version = "0.48.1"

import {
  "mizchi/bit_core@0.48.1",
  "mizchi/bit_object@0.48.1",
  "mizchi/bit_repo@0.48.1",
  "mizchi/bit_types@0.48.1",
  "mizchi/tempfile@0.1.3",
  "mizchi/zlib@0.4.10",
  "moonbitlang/async@0.22.5",
  "moonbitlang/x@0.5.6",
}

repository = "https://github.com/mizchi/bit-vcs"

license = "Apache-2.0"

keywords = [ "git", "pack", "packfile", "index" ]

description = "Git packfile encoder/decoder + index (gix-pack equivalent)"

source = "src"

preferred_target = "native"
