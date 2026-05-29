/*
 * SHA-1 acceleration using Intel SHA-NI extensions.
 *
 * Falls back to a portable C implementation when SHA-NI is not available
 * (TCC or older CPUs). The MoonBit caller checks sha1_ni_available() first.
 *
 * SHA-NI path based on the public-domain algorithm by Sean Gulley / Intel.
 */

#include <stdint.h>
#include <stddef.h>
#include <string.h>

/*
 * Function-level target attributes allow SHA-NI intrinsics with clang/gcc
 * even without -msha on the command line.
 * TCC doesn't support __attribute__((target(...))), so we fall back there.
 */
#if !defined(__TINYC__) && (defined(__clang__) || defined(__GNUC__))
#  include <immintrin.h>
#  define USE_SHA_NI 1
#  define SHA_NI_TARGET __attribute__((target("sha,sse4.1")))
#else
#  define USE_SHA_NI 0
#  define SHA_NI_TARGET
#endif

/* ── runtime capability query ─────────────────────────────────────────── */

int32_t sha1_ni_available(void) {
  return USE_SHA_NI ? 1 : 0;
}

/* ── portable big-endian helpers ──────────────────────────────────────── */

static inline uint32_t be32(const uint8_t* p) {
  return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) |
         ((uint32_t)p[2] << 8)  |  (uint32_t)p[3];
}

static inline uint32_t rotl32(uint32_t x, int n) {
  return (x << n) | (x >> (32 - n));
}

/* ── SHA-NI fast path (x86 with SHA extensions) ───────────────────────── */

#if USE_SHA_NI

/*
 * Process `num_blocks` 64-byte blocks in-place.
 * state[0..4] = {H0,H1,H2,H3,H4}  (big-endian word order)
 */
SHA_NI_TARGET
static void sha1_ni_blocks(uint32_t state[5], const uint8_t* data, size_t num_blocks) {
  __m128i abcd, e0, e1;
  __m128i abcd_save, e_save;
  __m128i msg0, msg1, msg2, msg3;
  __m128i shuf_mask;

  shuf_mask = _mm_set_epi64x(0x0001020304050607ULL, 0x08090a0b0c0d0e0fULL);

  /* Load initial state */
  abcd = _mm_loadu_si128((__m128i const*)state);
  e0   = _mm_set_epi32(state[4], 0, 0, 0);
  abcd = _mm_shuffle_epi32(abcd, 0x1b); /* DCBA -> ABCD */

  while (num_blocks--) {
    abcd_save = abcd;
    e_save    = e0;

    /* Rounds 0-3 */
    msg0 = _mm_loadu_si128((__m128i const*)(data +  0));
    msg0 = _mm_shuffle_epi8(msg0, shuf_mask);
    e0   = _mm_add_epi32(e0, msg0);
    e1   = abcd;
    abcd = _mm_sha1rnds4_epu32(abcd, e0, 0);

    /* Rounds 4-7 */
    msg1 = _mm_loadu_si128((__m128i const*)(data + 16));
    msg1 = _mm_shuffle_epi8(msg1, shuf_mask);
    e1   = _mm_sha1nexte_epu32(e1, msg1);
    e0   = abcd;
    abcd = _mm_sha1rnds4_epu32(abcd, e1, 0);
    msg0 = _mm_sha1msg1_epu32(msg0, msg1);

    /* Rounds 8-11 */
    msg2 = _mm_loadu_si128((__m128i const*)(data + 32));
    msg2 = _mm_shuffle_epi8(msg2, shuf_mask);
    e0   = _mm_sha1nexte_epu32(e0, msg2);
    e1   = abcd;
    abcd = _mm_sha1rnds4_epu32(abcd, e0, 0);
    msg1 = _mm_sha1msg1_epu32(msg1, msg2);
    msg0 = _mm_xor_si128(msg0, msg2);

    /* Rounds 12-15 */
    msg3 = _mm_loadu_si128((__m128i const*)(data + 48));
    msg3 = _mm_shuffle_epi8(msg3, shuf_mask);
    e1   = _mm_sha1nexte_epu32(e1, msg3);
    e0   = abcd;
    msg0 = _mm_sha1msg2_epu32(msg0, msg3);
    abcd = _mm_sha1rnds4_epu32(abcd, e1, 0);
    msg2 = _mm_sha1msg1_epu32(msg2, msg3);
    msg1 = _mm_xor_si128(msg1, msg3);

    /* Rounds 16-19 */
    e0   = _mm_sha1nexte_epu32(e0, msg0);
    e1   = abcd;
    msg1 = _mm_sha1msg2_epu32(msg1, msg0);
    abcd = _mm_sha1rnds4_epu32(abcd, e0, 0);
    msg3 = _mm_sha1msg1_epu32(msg3, msg0);
    msg2 = _mm_xor_si128(msg2, msg0);

    /* Rounds 20-23 */
    e1   = _mm_sha1nexte_epu32(e1, msg1);
    e0   = abcd;
    msg2 = _mm_sha1msg2_epu32(msg2, msg1);
    abcd = _mm_sha1rnds4_epu32(abcd, e1, 1);
    msg0 = _mm_sha1msg1_epu32(msg0, msg1);
    msg3 = _mm_xor_si128(msg3, msg1);

    /* Rounds 24-27 */
    e0   = _mm_sha1nexte_epu32(e0, msg2);
    e1   = abcd;
    msg3 = _mm_sha1msg2_epu32(msg3, msg2);
    abcd = _mm_sha1rnds4_epu32(abcd, e0, 1);
    msg1 = _mm_sha1msg1_epu32(msg1, msg2);
    msg0 = _mm_xor_si128(msg0, msg2);

    /* Rounds 28-31 */
    e1   = _mm_sha1nexte_epu32(e1, msg3);
    e0   = abcd;
    msg0 = _mm_sha1msg2_epu32(msg0, msg3);
    abcd = _mm_sha1rnds4_epu32(abcd, e1, 1);
    msg2 = _mm_sha1msg1_epu32(msg2, msg3);
    msg1 = _mm_xor_si128(msg1, msg3);

    /* Rounds 32-35 */
    e0   = _mm_sha1nexte_epu32(e0, msg0);
    e1   = abcd;
    msg1 = _mm_sha1msg2_epu32(msg1, msg0);
    abcd = _mm_sha1rnds4_epu32(abcd, e0, 1);
    msg3 = _mm_sha1msg1_epu32(msg3, msg0);
    msg2 = _mm_xor_si128(msg2, msg0);

    /* Rounds 36-39 */
    e1   = _mm_sha1nexte_epu32(e1, msg1);
    e0   = abcd;
    msg2 = _mm_sha1msg2_epu32(msg2, msg1);
    abcd = _mm_sha1rnds4_epu32(abcd, e1, 1);
    msg0 = _mm_sha1msg1_epu32(msg0, msg1);
    msg3 = _mm_xor_si128(msg3, msg1);

    /* Rounds 40-43 */
    e0   = _mm_sha1nexte_epu32(e0, msg2);
    e1   = abcd;
    msg3 = _mm_sha1msg2_epu32(msg3, msg2);
    abcd = _mm_sha1rnds4_epu32(abcd, e0, 2);
    msg1 = _mm_sha1msg1_epu32(msg1, msg2);
    msg0 = _mm_xor_si128(msg0, msg2);

    /* Rounds 44-47 */
    e1   = _mm_sha1nexte_epu32(e1, msg3);
    e0   = abcd;
    msg0 = _mm_sha1msg2_epu32(msg0, msg3);
    abcd = _mm_sha1rnds4_epu32(abcd, e1, 2);
    msg2 = _mm_sha1msg1_epu32(msg2, msg3);
    msg1 = _mm_xor_si128(msg1, msg3);

    /* Rounds 48-51 */
    e0   = _mm_sha1nexte_epu32(e0, msg0);
    e1   = abcd;
    msg1 = _mm_sha1msg2_epu32(msg1, msg0);
    abcd = _mm_sha1rnds4_epu32(abcd, e0, 2);
    msg3 = _mm_sha1msg1_epu32(msg3, msg0);
    msg2 = _mm_xor_si128(msg2, msg0);

    /* Rounds 52-55 */
    e1   = _mm_sha1nexte_epu32(e1, msg1);
    e0   = abcd;
    msg2 = _mm_sha1msg2_epu32(msg2, msg1);
    abcd = _mm_sha1rnds4_epu32(abcd, e1, 2);
    msg0 = _mm_sha1msg1_epu32(msg0, msg1);
    msg3 = _mm_xor_si128(msg3, msg1);

    /* Rounds 56-59 */
    e0   = _mm_sha1nexte_epu32(e0, msg2);
    e1   = abcd;
    msg3 = _mm_sha1msg2_epu32(msg3, msg2);
    abcd = _mm_sha1rnds4_epu32(abcd, e0, 2);
    msg1 = _mm_sha1msg1_epu32(msg1, msg2);
    msg0 = _mm_xor_si128(msg0, msg2);

    /* Rounds 60-63 */
    e1   = _mm_sha1nexte_epu32(e1, msg3);
    e0   = abcd;
    msg0 = _mm_sha1msg2_epu32(msg0, msg3);
    abcd = _mm_sha1rnds4_epu32(abcd, e1, 3);
    msg2 = _mm_sha1msg1_epu32(msg2, msg3);
    msg1 = _mm_xor_si128(msg1, msg3);

    /* Rounds 64-67 */
    e0   = _mm_sha1nexte_epu32(e0, msg0);
    e1   = abcd;
    msg1 = _mm_sha1msg2_epu32(msg1, msg0);
    abcd = _mm_sha1rnds4_epu32(abcd, e0, 3);
    msg3 = _mm_sha1msg1_epu32(msg3, msg0);
    msg2 = _mm_xor_si128(msg2, msg0);

    /* Rounds 68-71 */
    e1   = _mm_sha1nexte_epu32(e1, msg1);
    e0   = abcd;
    msg2 = _mm_sha1msg2_epu32(msg2, msg1);
    abcd = _mm_sha1rnds4_epu32(abcd, e1, 3);
    msg3 = _mm_xor_si128(msg3, msg1);

    /* Rounds 72-75 */
    e0   = _mm_sha1nexte_epu32(e0, msg2);
    e1   = abcd;
    msg3 = _mm_sha1msg2_epu32(msg3, msg2);
    abcd = _mm_sha1rnds4_epu32(abcd, e0, 3);

    /* Rounds 76-79 */
    e1   = _mm_sha1nexte_epu32(e1, msg3);
    e0   = abcd;
    abcd = _mm_sha1rnds4_epu32(abcd, e1, 3);

    /* Combine with saved state */
    e0   = _mm_sha1nexte_epu32(e0, e_save);
    abcd = _mm_add_epi32(abcd, abcd_save);

    data += 64;
  }

  abcd = _mm_shuffle_epi32(abcd, 0x1b); /* ABCD -> DCBA */
  _mm_storeu_si128((__m128i*)state, abcd);
  state[4] = _mm_extract_epi32(e0, 3);
}

#endif /* USE_SHA_NI */

/* ── portable scalar block processor ─────────────────────────────────── */

static void sha1_scalar_blocks(uint32_t h[5], const uint8_t* data, size_t num_blocks) {
  while (num_blocks--) {
    uint32_t w[80];
    for (int i = 0; i < 16; i++) {
      w[i] = ((uint32_t)data[i*4]   << 24) |
             ((uint32_t)data[i*4+1] << 16) |
             ((uint32_t)data[i*4+2] <<  8) |
              (uint32_t)data[i*4+3];
    }
    for (int i = 16; i < 80; i++) {
      w[i] = rotl32(w[i-3] ^ w[i-8] ^ w[i-14] ^ w[i-16], 1);
    }
    uint32_t a = h[0], b = h[1], c = h[2], d = h[3], e = h[4];
    for (int i = 0; i < 20; i++) {
      uint32_t f = (b & c) | (~b & d);
      uint32_t t = rotl32(a,5) + f + e + 0x5a827999u + w[i];
      e=d; d=c; c=rotl32(b,30); b=a; a=t;
    }
    for (int i = 20; i < 40; i++) {
      uint32_t f = b ^ c ^ d;
      uint32_t t = rotl32(a,5) + f + e + 0x6ed9eba1u + w[i];
      e=d; d=c; c=rotl32(b,30); b=a; a=t;
    }
    for (int i = 40; i < 60; i++) {
      uint32_t f = (b & c) | (b & d) | (c & d);
      uint32_t t = rotl32(a,5) + f + e + 0x8f1bbcdcu + w[i];
      e=d; d=c; c=rotl32(b,30); b=a; a=t;
    }
    for (int i = 60; i < 80; i++) {
      uint32_t f = b ^ c ^ d;
      uint32_t t = rotl32(a,5) + f + e + 0xca62c1d6u + w[i];
      e=d; d=c; c=rotl32(b,30); b=a; a=t;
    }
    h[0] += a; h[1] += b; h[2] += c; h[3] += d; h[4] += e;
    data += 64;
  }
}

/* ── MoonBit-callable entry points ────────────────────────────────────── */

/*
 * sha1_compute(data, len, out)
 *   data : FixedArray[Byte] — input (passed as Bytes from MoonBit)
 *   len  : number of bytes to hash
 *   out  : FixedArray[Byte] with at least 20 bytes — receives digest
 *
 * One-shot SHA-1: handles padding, block processing, and output in C.
 * Single FFI call per sha1_raw invocation.
 */
void sha1_compute(const uint8_t* data, int32_t len, uint8_t* out) {
  uint32_t state[5] = {
    0x67452301u, 0xefcdab89u, 0x98badcfeu, 0x10325476u, 0xc3d2e1f0u
  };

  /* Process all full blocks from the input directly. */
  int32_t full_blocks = len / 64;
  int32_t remainder   = len % 64;

  if (full_blocks > 0) {
#if USE_SHA_NI
    sha1_ni_blocks(state, data, (size_t)full_blocks);
#else
    sha1_scalar_blocks(state, data, (size_t)full_blocks);
#endif
  }

  /* Build the padding block(s) in a local buffer. */
  uint8_t pad[128];
  memcpy(pad, data + full_blocks * 64, (size_t)remainder);
  pad[remainder] = 0x80;

  int32_t pad_len;
  if (remainder < 55) {
    /* One padding block. */
    memset(pad + remainder + 1, 0, (size_t)(55 - remainder));
    pad_len = 64;
  } else {
    /* Two padding blocks. */
    memset(pad + remainder + 1, 0, (size_t)(119 - remainder));
    pad_len = 128;
  }

  /* Append big-endian bit length at bytes [pad_len-8 .. pad_len-1]. */
  uint64_t bit_len = (uint64_t)len * 8;
  pad[pad_len - 8] = (uint8_t)(bit_len >> 56);
  pad[pad_len - 7] = (uint8_t)(bit_len >> 48);
  pad[pad_len - 6] = (uint8_t)(bit_len >> 40);
  pad[pad_len - 5] = (uint8_t)(bit_len >> 32);
  pad[pad_len - 4] = (uint8_t)(bit_len >> 24);
  pad[pad_len - 3] = (uint8_t)(bit_len >> 16);
  pad[pad_len - 2] = (uint8_t)(bit_len >>  8);
  pad[pad_len - 1] = (uint8_t)(bit_len      );

#if USE_SHA_NI
  sha1_ni_blocks(state, pad, (size_t)(pad_len / 64));
#else
  sha1_scalar_blocks(state, pad, (size_t)(pad_len / 64));
#endif

  /* Write digest in big-endian. */
  for (int i = 0; i < 5; i++) {
    out[i*4    ] = (uint8_t)(state[i] >> 24);
    out[i*4 + 1] = (uint8_t)(state[i] >> 16);
    out[i*4 + 2] = (uint8_t)(state[i] >>  8);
    out[i*4 + 3] = (uint8_t)(state[i]      );
  }
}

/*
 * sha1_process_blocks(h, data, offset, num_blocks)
 *   h          : FixedArray[Int]  — 5-word state, updated in-place
 *   data       : FixedArray[Byte]
 *   offset     : byte offset into data
 *   num_blocks : number of 64-byte blocks to process
 *
 * Used by Sha1State::update_slice for incremental hashing.
 */
void sha1_process_blocks(int32_t* h, const uint8_t* data,
                         int32_t offset, int32_t num_blocks) {
  uint32_t state[5];
  state[0] = (uint32_t)h[0]; state[1] = (uint32_t)h[1];
  state[2] = (uint32_t)h[2]; state[3] = (uint32_t)h[3];
  state[4] = (uint32_t)h[4];

#if USE_SHA_NI
  sha1_ni_blocks(state, data + offset, (size_t)num_blocks);
#else
  sha1_scalar_blocks(state, data + offset, (size_t)num_blocks);
#endif

  h[0] = (int32_t)state[0]; h[1] = (int32_t)state[1];
  h[2] = (int32_t)state[2]; h[3] = (int32_t)state[3];
  h[4] = (int32_t)state[4];
}
