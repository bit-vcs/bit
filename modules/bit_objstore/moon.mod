name = "mizchi/bit_objstore"

version = "0.46.4"

import {
  "mizchi/bit_hash@0.46.4",
  "mizchi/bit_object@0.46.4",
  "mizchi/bit_types@0.46.4",
  "moonbitlang/async@0.22.1",
}

repository = "https://github.com/mizchi/bit-vcs"

license = "Apache-2.0"

keywords = [ "git", "storage", "s3", "object-store" ]

description = "Object storage abstraction with compare-and-swap writes (S3/R2/GCS)"

source = "src"

preferred_target = "native"
