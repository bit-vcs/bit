name = "mizchi/bitx_rebase_ai"

version = "0.50.0"

import {
  "mizchi/bit_core@0.50.0",
  "mizchi/bit_object@0.50.0",
  "mizchi/bit_lib@0.50.0",
  "mizchi/bit_types@0.50.0",
  "mizchi/bit_runtime@0.50.0",
  "mizchi/bit_osfs@0.50.0",
  "mizchi/bit_utils@0.50.0",
  "mizchi/llm@0.3.2",
  "mizchi/x@0.8.0",
  "moonbitlang/regexp@0.3.7",
  "moonbitlang/x@0.5.7",
}

repository = "https://github.com/mizchi/bit-vcs"

license = "Apache-2.0"

keywords = [ "git", "ai", "rebase" ]

description = "AI-assisted rebase helpers (extension module for mizchi/bit)"

source = "src"

preferred_target = "native"
