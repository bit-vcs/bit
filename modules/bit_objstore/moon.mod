name = "mizchi/bit_objstore"

version = "0.48.1"

import {
  "mizchi/bit_hash@0.48.1",
  "mizchi/bit_object@0.48.1",
  "mizchi/bit_types@0.48.1",
  "moonbitlang/async@0.22.5",
}

repository = "https://github.com/mizchi/bit-vcs"

license = "Apache-2.0"

keywords = [ "git", "storage", "s3", "object-store" ]

description = "Object storage abstraction with compare-and-swap writes (S3/R2/GCS)"

source = "src"

preferred_target = "native"
