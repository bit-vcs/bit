///| Broader-coverage fuzz tests for the byte-level parsers that bit
/// exposes to untrusted input (wire protocol, packfile, refs, config,
/// dates). Each test feeds 64–256 random / borderline-malformed inputs
/// through the parser and asserts only that it does not crash the
/// process. The contract being tested is "raises GitError or returns,
/// never panics".

///|
fn random_bytes(rng : Lcg, len : Int) -> Bytes {
  Bytes::makei(len, fn(_i) { rng.next_byte() })
}

///|
fn random_ascii_string(rng : Lcg, len : Int) -> String {
  let sb = StringBuilder::new()
  for _ in 0..<len {
    let code = rng.next_int() % 95 + 32
    sb.write_char(code.unsafe_to_char())
  }
  sb.to_string()
}

///|
/// pkt-line ref advertisement (v0). The first ref line carries the
/// capability list after a NUL; both shapes (well-formed and short-
/// truncated) need to fail soft.
test "fuzz: parse_refs (v0 advertised refs)" {
  let rng = Lcg::new(0xA11CE)
  for _ in 0..<128 {
    let len = rng.next_int() % 1024
    ignore(@protocol.parse_refs(random_bytes(rng, len))) catch {
      _ => ()
    }
  }
}

///|
/// v0 capability advertisement. Real upload-pack starts with a pkt-line
/// containing `ref\0caps`; we feed random bytes to surface buffer
/// over-reads.
test "fuzz: parse_v0_advertised_caps" {
  let rng = Lcg::new(0xB0B)
  for _ in 0..<128 {
    let len = rng.next_int() % 1024
    ignore(@protocol.parse_v0_advertised_caps(random_bytes(rng, len))) catch {
      _ => ()
    }
  }
}

///|
/// v2 capability advertisement (separate framing, capability=value).
test "fuzz: parse_v2_advertised_caps" {
  let rng = Lcg::new(0xCAFE)
  for _ in 0..<128 {
    let len = rng.next_int() % 1024
    ignore(@protocol.parse_v2_advertised_caps(random_bytes(rng, len))) catch {
      _ => ()
    }
  }
}

///|
/// `ls-refs` response is also pkt-line framed and parsed eagerly.
test "fuzz: parse_ls_refs_response" {
  let rng = Lcg::new(0xDEAD)
  for _ in 0..<128 {
    let len = rng.next_int() % 1024
    ignore(@protocol.parse_ls_refs_response(random_bytes(rng, len))) catch {
      _ => ()
    }
  }
}

///|
/// Sideband demux peels off a stream identifier byte. Empty/short
/// inputs and unknown band ids must not blow up.
test "fuzz: parse_sideband" {
  let rng = Lcg::new(0xBEEF)
  for _ in 0..<128 {
    let len = rng.next_int() % 256
    ignore(@protocol.parse_sideband(random_bytes(rng, len)))
  }
}

///|
/// receive-pack reports look like pkt-lines starting with `unpack ok`
/// or `unpack <msg>` followed by per-ref status lines. The parser
/// returns a Result and shouldn't crash on garbage.
test "fuzz: parse_receive_pack_response" {
  let rng = Lcg::new(0xC0FFEE)
  for _ in 0..<128 {
    let len = rng.next_int() % 512
    ignore(@protocol.parse_receive_pack_response(random_bytes(rng, len)))
  }
}

///|
/// pack header is `PACK` + 4-byte version + 4-byte object count. We
/// occasionally prefix with the literal magic to push the parser past
/// the header into per-object decoding.
test "fuzz: parse_packfile_stream with biased header" {
  let rng = Lcg::new(0xFEED)
  for _ in 0..<32 {
    let len = rng.next_int() % 2048
    let raw = random_bytes(rng, len)
    let prefixed = if rng.next_int() % 2 == 0 {
      // Splice PACK magic at the start by rebuilding via FixedArray.
      let total_len = if raw.length() < 4 { 4 } else { raw.length() }
      Bytes::makei(total_len, fn(i) {
        if i == 0 {
          b'P'
        } else if i == 1 {
          b'A'
        } else if i == 2 {
          b'C'
        } else if i == 3 {
          b'K'
        } else if i < raw.length() {
          raw[i]
        } else {
          b'\x00'
        }
      })
    } else {
      raw
    }
    ignore(@pack.parse_packfile_stream(prefixed, fn(_obj) { () })) catch {
      _ => ()
    }
  }
}

///|
/// pack object size header is varint; bad varints (run-on continuation
/// bits, oversize fields) historically cause integer overflow / OOM in
/// other Git impls. We only check non-crashing here.
test "fuzz: decode_type_and_size_at" {
  let rng = Lcg::new(0xBADC0DE)
  for _ in 0..<128 {
    let len = rng.next_int() % 64 + 1
    let bytes = random_bytes(rng, len)
    let off = rng.next_int() % len
    ignore(@pack.decode_type_and_size_at(bytes, off)) catch {
      _ => ()
    }
  }
}

///|
/// Tree parser already had basic fuzzing; add a path-name-biased
/// generator that emphasizes `/`, `.`, NUL — i.e., the bytes that
/// matter for path-traversal checking. The parser shouldn't loop
/// forever or read past the buffer.
test "fuzz: parse_tree with path-byte-biased payload" {
  let rng = Lcg::new(0xF1B5)
  for _ in 0..<128 {
    let len = rng.next_int() % 256
    let bytes = Bytes::makei(len, fn(_i) {
      let v = rng.next_int() % 10
      match v {
        0 => b'\x00'
        1 => b'.'
        2 => b'/'
        3 => b' '
        4 => b'0'
        5 => b'1'
        6 => b'4'
        7 => b'7'
        _ => rng.next_byte()
      }
    })
    ignore(@bit.parse_tree(bytes)) catch {
      _ => ()
    }
  }
}

///|
/// .gitignore matcher is a state machine over user-controlled patterns
/// (.gitignore comes from the repo; on hostile clones it is attacker-
/// controlled). Random patterns + random paths should never crash the
/// matcher.
test "fuzz: ignore Matcher with random patterns" {
  let rng = Lcg::new(0x10001)
  for _ in 0..<128 {
    let pat = random_ascii_string(rng, rng.next_int() % 64)
    let path = random_ascii_string(rng, rng.next_int() % 64)
    ignore(@ignore.match_glob(pat, path))
  }
}

///|
/// `[section "name"]` headers, `key = value` lines, `key.subkey`
/// dotted forms — config is parsed eagerly on repo open, so a hostile
/// `.git/config` or `~/.gitconfig` is an attack surface.
test "fuzz: config_parse parse_config_key / section header" {
  let rng = Lcg::new(0x60FC)
  for _ in 0..<128 {
    let s = random_ascii_string(rng, rng.next_int() % 96)
    ignore(@config_parse.parse_config_key(s))
    ignore(@config_parse.parse_section_header_line(s))
    ignore(@config_parse.parse_config_value(s))
    ignore(@config_parse.parse_bool_keyword_value(s))
    ignore(@config_parse.parse_config_int_value(s))
  }
}

///|
test "fuzz: date_parse approxidate" {
  let rng = Lcg::new(0xDA7E)
  for _ in 0..<128 {
    let s = random_ascii_string(rng, rng.next_int() % 64)
    ignore(@date_parse.parse_approxidate(s, 1_700_000_000L))
  }
}

///|
test "fuzz: date_parse approxidate_iso8601" {
  let rng = Lcg::new(0xDA7F)
  for _ in 0..<128 {
    let s = random_ascii_string(rng, rng.next_int() % 64)
    ignore(@date_parse.parse_approxidate_iso8601(s))
  }
}

///|
test "fuzz: date_parse approxidate_iso_date" {
  let rng = Lcg::new(0xDA80)
  for _ in 0..<128 {
    let s = random_ascii_string(rng, rng.next_int() % 64)
    ignore(@date_parse.parse_approxidate_iso_date(s))
  }
}

///|
test "fuzz: date_parse approxidate_human" {
  let rng = Lcg::new(0xDA81)
  for _ in 0..<128 {
    let s = random_ascii_string(rng, rng.next_int() % 64)
    ignore(@date_parse.parse_approxidate_human(s))
  }
}

///|
test "fuzz: date_parse approxidate_relative" {
  let rng = Lcg::new(0xDA82)
  for _ in 0..<128 {
    let s = random_ascii_string(rng, rng.next_int() % 64)
    ignore(@date_parse.parse_approxidate_relative(s, 1_700_000_000L))
  }
}

///|
/// `parse_rev_parse_short_length` accepts decimal digits and rejects
/// anything else. Random ASCII (whitespace, sign chars, huge numbers)
/// must not crash via integer overflow.
test "fuzz: parse_rev_parse_short_length with random ascii" {
  let rng = Lcg::new(0x5407)
  for _ in 0..<128 {
    let s = random_ascii_string(rng, rng.next_int() % 24)
    ignore(@bitlib.parse_rev_parse_short_length(s))
  }
}

///|
/// `parse_reflog_selector` decodes `<ref>@{N}` forms. Mutate the
/// boundary cases: empty ref, missing `@{`, missing `}`, non-digit
/// number, overflow-length number.
test "fuzz: parse_reflog_selector with random spec" {
  let rng = Lcg::new(0xEF10)
  for _ in 0..<128 {
    let s = random_ascii_string(rng, rng.next_int() % 32)
    ignore(@bitlib.parse_reflog_selector(s))
  }
  // Structured: `<refname>@{<digits>}`
  for _ in 0..<128 {
    let sb = StringBuilder::new()
    sb.write_string(random_ascii_string(rng, rng.next_int() % 12))
    sb.write_string("@{")
    let digit_count = rng.next_int() % 20
    for _ in 0..<digit_count {
      let code = rng.next_int() % 10 + 48
      sb.write_char(code.unsafe_to_char())
    }
    sb.write_string("}")
    ignore(@bitlib.parse_reflog_selector(sb.to_string()))
  }
}

///|
/// `parse_reflog_date_selector` decodes `<ref>@{<date>}` forms.
test "fuzz: parse_reflog_date_selector with random spec" {
  let rng = Lcg::new(0xDA7E)
  for _ in 0..<128 {
    let s = random_ascii_string(rng, rng.next_int() % 32)
    ignore(@bitlib.parse_reflog_date_selector(s))
  }
}

///|
/// `parse_index_pathspec` decodes `:<stage>:<path>` index pathspecs.
/// Stage byte ('0'..'3') vs arbitrary bytes is the interesting axis.
test "fuzz: parse_index_pathspec with random spec" {
  let rng = Lcg::new(0x9A7)
  for _ in 0..<128 {
    let s = random_ascii_string(rng, rng.next_int() % 32)
    ignore(@bitlib.parse_index_pathspec(s))
  }
  // Bias toward the `:N:` prefix form.
  for _ in 0..<128 {
    let sb = StringBuilder::new()
    sb.write_char(':')
    let stage_code = rng.next_int() % 60 + 48 // 0..<60 + '0'
    sb.write_char(stage_code.unsafe_to_char())
    sb.write_char(':')
    sb.write_string(random_ascii_string(rng, rng.next_int() % 20))
    ignore(@bitlib.parse_index_pathspec(sb.to_string()))
  }
}
