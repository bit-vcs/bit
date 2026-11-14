// Thin zlib (RFC 1950) helpers for git objects and packfiles, built on
// `moonbitlang/core/compress`. Core's `@czlib.decompress` only accepts a whole
// stream; packfiles need to decode a stream that starts at an offset and learn
// where it ends, which `zlib_decompress_at` provides via `@flate.inflate_prefix`.

///|
/// Default ceiling for decompressed output (256 MiB), guarding against
/// decompression bombs.
pub let default_max_decompressed_size : Int = 256 * 1024 * 1024

///|
pub using @czlib {type ZlibErrorKind}

///|
/// zlib decoding failure: core's `ZlibErrorKind` category plus a diagnostic.
pub(all) suberror ZlibError {
  ZlibError(ZlibErrorKind, String)
}

///|
pub impl Show for ZlibError with output(self, logger) {
  let ZlibError(_, msg) = self
  logger.write_string(msg)
}

///|
pub extend ZlibError with Show::{to_string, output}

///|
/// Compress `data` into a zlib stream (default DEFLATE strategy).
pub fn zlib_compress(data : BytesView) -> Bytes {
  @czlib.compress(data)
}

///|
/// Compress `data` into a zlib stream with fast, low-effort settings
/// (equivalent to zlib level 1, git's default for pack data).
pub fn zlib_compress_fast(data : BytesView) -> Bytes {
  @czlib.compress(data, strategy=Standard(level=1))
}

///|
/// Wrap `data` in a zlib stream made of DEFLATE stored (uncompressed) blocks.
pub fn zlib_compress_stored(data : BytesView) -> Bytes {
  @czlib.compress(data, strategy=Standard(level=0))
}

///|
/// Decompress a complete zlib stream; trailing bytes are rejected.
pub fn zlib_decompress(
  data : BytesView,
  max_size? : Int = default_max_decompressed_size,
) -> Bytes raise ZlibError {
  @czlib.decompress(data, max_output=max_size) catch {
    @czlib.ZlibError(kind, msg) => raise ZlibError(kind, msg)
  }
}

///|
/// Decompress the zlib stream that starts at `start` in `data`, returning the
/// decoded bytes and the offset just past the stream's Adler-32 trailer.
/// Bytes after the stream are left untouched.
pub fn zlib_decompress_at(
  data : BytesView,
  start : Int,
  max_size? : Int = default_max_decompressed_size,
) -> (Bytes, Int) raise ZlibError {
  let len = data.length()
  if start < 0 || start > len {
    raise ZlibError(InvalidArgument, "zlib: start offset out of range")
  }
  if max_size < 0 {
    raise ZlibError(InvalidArgument, "zlib: max_size must be non-negative")
  }
  if len - start < 2 {
    raise ZlibError(Truncated, "zlib: truncated header")
  }
  let cmf = data[start].to_int()
  let flg = data[start + 1].to_int()
  if (cmf & 0x0f) != 8 || cmf >> 4 > 7 || ((cmf << 8) | flg) % 31 != 0 {
    raise ZlibError(InvalidHeader, "zlib: invalid header")
  }
  if (flg & 0x20) != 0 {
    raise ZlibError(DictionaryRequired, "zlib: preset dictionary not supported")
  }
  let body = start + 2
  let decoded = @flate.inflate_prefix(data[body:], max_output=max_size) catch {
    @flate.InflateError(kind, msg) =>
      raise ZlibError(
        match kind {
          Truncated => Truncated
          Corrupt => InvalidDeflate
          TrailingData => TrailingData
          OutputLimitExceeded(limit~, observed~) =>
            OutputLimitExceeded(limit~, observed~)
          Cancelled => Cancelled
          InvalidArgument => InvalidArgument
        },
        msg,
      )
  }
  let trailer = body + decoded.consumed
  if len - trailer < 4 {
    raise ZlibError(Truncated, "zlib: truncated Adler-32 trailer")
  }
  let expected = (data[trailer].to_uint() << 24) |
    (data[trailer + 1].to_uint() << 16) |
    (data[trailer + 2].to_uint() << 8) |
    data[trailer + 3].to_uint()
  if adler32(decoded.data) != expected {
    raise ZlibError(ChecksumMismatch, "zlib: Adler-32 checksum mismatch")
  }
  (decoded.data, trailer + 4)
}

///|
/// Adler-32 checksum (RFC 1950).
pub fn adler32(data : BytesView) -> UInt {
  let mod_adler = 65521U
  // Largest n such that 255n(n+1)/2 + (n+1)(BASE-1) fits in 32 bits.
  let nmax = 5552
  let mut a = 1U
  let mut b = 0U
  let len = data.length()
  let mut i = 0
  while i < len {
    let end = if len - i > nmax { i + nmax } else { len }
    while i < end {
      a += data[i].to_uint()
      b += a
      i += 1
    }
    a %= mod_adler
    b %= mod_adler
  }
  (b << 16) | a
}
