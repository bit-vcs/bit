///| Structure-aware fuzzing for the packfile parser.
///
/// Random-bytes-only fuzzing of `parse_packfile_stream` is low-signal:
/// the magic-bytes check (`PACK`) rejects ~99.6% of inputs in the
/// first 4 bytes, so the fuzzer never reaches the per-object decoder.
///
/// Here we build a small corpus of *valid* packfiles, then mutate
/// each one byte-at-a-time and feed the result back through the
/// parser. The contract under test is: parsing arbitrary mutations of
/// a valid pack must `raise` (or succeed), never crash.

///|
fn make_test_blobs(count : Int) -> Array[@bit.PackObject] {
  let objects : Array[@bit.PackObject] = []
  for i in 0..<count {
    // Build a blob whose content varies with i so delta-compression
    // has both similar (header) and dissimilar (id) sections.
    let s = "test blob \{i}: shared header padding for delta. tail \{i * 7}\n"
    let data = Bytes::from_array(
      FixedArray::makei(s.length(), j => s[j].to_int().to_byte()),
    )
    objects.push(@bit.PackObject::new(@bit.ObjectType::Blob, data))
  }
  objects
}

///|
/// Build a small valid pack file. Wrapped in a function (rather than a
/// `let`) so failures show the right test name.
fn build_corpus_pack_small() -> Bytes {
  @pack.create_packfile(make_test_blobs(3))
}

///|
fn build_corpus_pack_with_delta() -> Bytes {
  @pack.create_packfile_with_delta(
    make_test_blobs(8),
    @bit.PackDeltaMode::RefDelta,
  )
}

///|
fn build_corpus_pack_ofs_delta() -> Bytes {
  @pack.create_packfile_with_delta(
    make_test_blobs(8),
    @bit.PackDeltaMode::OfsDelta,
  )
}

///|
/// In-place single-byte mutation: replace byte at `offset` with `value`.
fn mutate_byte_at(pack : Bytes, offset : Int, value : Byte) -> Bytes {
  Bytes::makei(pack.length(), fn(i) {
    if i == offset {
      value
    } else {
      pack[i]
    }
  })
}

///|
/// Insert a single byte at `offset`. Shifts everything after by 1.
fn mutate_insert_byte(pack : Bytes, offset : Int, value : Byte) -> Bytes {
  Bytes::makei(pack.length() + 1, fn(i) {
    if i < offset {
      pack[i]
    } else if i == offset {
      value
    } else {
      pack[i - 1]
    }
  })
}

///|
/// Delete a single byte at `offset`.
fn mutate_delete_byte(pack : Bytes, offset : Int) -> Bytes {
  if pack.length() == 0 {
    return pack
  }
  Bytes::makei(pack.length() - 1, fn(i) {
    if i < offset {
      pack[i]
    } else {
      pack[i + 1]
    }
  })
}

///|
/// Truncate the pack to `new_len` bytes.
fn mutate_truncate(pack : Bytes, new_len : Int) -> Bytes {
  let n = if new_len < 0 {
    0
  } else if new_len > pack.length() {
    pack.length()
  } else {
    new_len
  }
  Bytes::makei(n, i => pack[i])
}

///|
/// Drive `parse_packfile_stream` with whatever bytes we have. We
/// always discard the streamed objects (the harness only cares that
/// the call returns or raises, not what comes out).
fn try_parse(bytes : Bytes) -> Unit {
  ignore(try? @pack.parse_packfile_stream(bytes, fn(_obj) { () }))
}

///|
/// Single-byte-flip fuzz over each corpus entry. We touch every byte
/// (capped) so we hit header, version, count, type-and-size varints,
/// zlib stream, and the trailing SHA1.
test "fuzz: packfile single-byte flip across valid corpus" {
  let rng = Lcg::new(0xCAFEBEEF)
  let corpus = [
    build_corpus_pack_small(),
    build_corpus_pack_with_delta(),
    build_corpus_pack_ofs_delta(),
  ]
  for pack in corpus {
    // Cap iteration count to keep test runtime bounded.
    let iters = if pack.length() < 64 { pack.length() } else { 64 }
    for _ in 0..<iters {
      let offset = rng.next_int() % pack.length()
      let value = rng.next_byte()
      try_parse(mutate_byte_at(pack, offset, value))
    }
  }
}

///|
test "fuzz: packfile single-byte insert across valid corpus" {
  let rng = Lcg::new(0xCAFE2)
  let corpus = [
    build_corpus_pack_small(),
    build_corpus_pack_with_delta(),
    build_corpus_pack_ofs_delta(),
  ]
  for pack in corpus {
    let iters = if pack.length() < 32 { pack.length() } else { 32 }
    for _ in 0..<iters {
      let offset = rng.next_int() % (pack.length() + 1)
      let value = rng.next_byte()
      try_parse(mutate_insert_byte(pack, offset, value))
    }
  }
}

///|
test "fuzz: packfile single-byte delete across valid corpus" {
  let rng = Lcg::new(0xCAFE3)
  let corpus = [
    build_corpus_pack_small(),
    build_corpus_pack_with_delta(),
    build_corpus_pack_ofs_delta(),
  ]
  for pack in corpus {
    let iters = if pack.length() < 32 { pack.length() } else { 32 }
    for _ in 0..<iters {
      let offset = rng.next_int() % pack.length()
      try_parse(mutate_delete_byte(pack, offset))
    }
  }
}

///|
/// Truncate at every possible boundary — including 0 bytes, just past
/// the header, in the middle of the first object's varint, etc.
test "fuzz: packfile truncation across valid corpus" {
  let corpus = [
    build_corpus_pack_small(),
    build_corpus_pack_with_delta(),
    build_corpus_pack_ofs_delta(),
  ]
  for pack in corpus {
    // Sample every ~4 bytes for the smaller pack, ~16 for larger.
    let step = if pack.length() < 256 { 4 } else { 16 }
    let mut n = 0
    while n <= pack.length() {
      try_parse(mutate_truncate(pack, n))
      n += step
    }
  }
}

///|
/// Object count field is at bytes 8..12 (big-endian u32). Setting it
/// to large values used to trick naive parsers into pre-allocating
/// huge arrays. Verify the parser refuses gracefully.
test "fuzz: packfile object-count field with extreme values" {
  let pack = build_corpus_pack_small()
  let test_counts : Array[Int] = [0, 1, 100, 1_000_000, 0x7fff_ffff]
  for n in test_counts {
    let b0 = ((n >> 24) & 0xff).to_byte()
    let b1 = ((n >> 16) & 0xff).to_byte()
    let b2 = ((n >> 8) & 0xff).to_byte()
    let b3 = (n & 0xff).to_byte()
    let mutated = Bytes::makei(pack.length(), fn(i) {
      if i == 8 {
        b0
      } else if i == 9 {
        b1
      } else if i == 10 {
        b2
      } else if i == 11 {
        b3
      } else {
        pack[i]
      }
    })
    try_parse(mutated)
  }
}

///|
/// Version field is at bytes 4..8. Real values are 2 or 3. Test
/// extremes and zero.
test "fuzz: packfile version field with extreme values" {
  let pack = build_corpus_pack_small()
  let test_versions : Array[Int] = [0, 1, 2, 3, 4, 99, 0x7fff_ffff]
  for v in test_versions {
    let b0 = ((v >> 24) & 0xff).to_byte()
    let b1 = ((v >> 16) & 0xff).to_byte()
    let b2 = ((v >> 8) & 0xff).to_byte()
    let b3 = (v & 0xff).to_byte()
    let mutated = Bytes::makei(pack.length(), fn(i) {
      if i == 4 {
        b0
      } else if i == 5 {
        b1
      } else if i == 6 {
        b2
      } else if i == 7 {
        b3
      } else {
        pack[i]
      }
    })
    try_parse(mutated)
  }
}
