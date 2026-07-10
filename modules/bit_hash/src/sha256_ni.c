/*
 * SHA-256 with optional SHA-NI acceleration (x86 sha_ni + sse4.1 + ssse3).
 *
 * SHA-NI path: public-domain implementation by Sean Gulley / Intel,
 * adapted and verified against NIST test vectors.
 *
 * Falls back to a portable C scalar implementation on TCC or CPUs without
 * the required extensions.
 */

#include <stdint.h>
#include <stddef.h>
#include <string.h>

#if !defined(__TINYC__) && \
    (defined(__x86_64__) || defined(__i386__)) && \
    (defined(__clang__) || defined(__GNUC__))
#  include <immintrin.h>
#  define USE_SHA256_NI 1
#  define SHA256_TARGET __attribute__((target("sha,sse4.1,ssse3")))
#else
#  define USE_SHA256_NI 0
#  define SHA256_TARGET
#endif

#if USE_SHA256_NI
static int sha256_hw_ok = -1;
static int sha256_ni_ok(void) {
  if (sha256_hw_ok < 0)
    sha256_hw_ok = (__builtin_cpu_supports("sha") != 0) &
                   (__builtin_cpu_supports("sse4.1") != 0) &
                   (__builtin_cpu_supports("ssse3") != 0);
  return sha256_hw_ok;
}
#endif

/* ── SHA-256 K constants ──────────────────────────────────────────────── */

static const uint32_t K256[64] = {
  0x428a2f98u,0x71374491u,0xb5c0fbcfu,0xe9b5dba5u,
  0x3956c25bu,0x59f111f1u,0x923f82a4u,0xab1c5ed5u,
  0xd807aa98u,0x12835b01u,0x243185beu,0x550c7dc3u,
  0x72be5d74u,0x80deb1feu,0x9bdc06a7u,0xc19bf174u,
  0xe49b69c1u,0xefbe4786u,0x0fc19dc6u,0x240ca1ccu,
  0x2de92c6fu,0x4a7484aau,0x5cb0a9dcu,0x76f988dau,
  0x983e5152u,0xa831c66du,0xb00327c8u,0xbf597fc7u,
  0xc6e00bf3u,0xd5a79147u,0x06ca6351u,0x14292967u,
  0x27b70a85u,0x2e1b2138u,0x4d2c6dfcu,0x53380d13u,
  0x650a7354u,0x766a0abbu,0x81c2c92eu,0x92722c85u,
  0xa2bfe8a1u,0xa81a664bu,0xc24b8b70u,0xc76c51a3u,
  0xd192e819u,0xd6990624u,0xf40e3585u,0x106aa070u,
  0x19a4c116u,0x1e376c08u,0x2748774cu,0x34b0bcb5u,
  0x391c0cb3u,0x4ed8aa4au,0x5b9cca4fu,0x682e6ff3u,
  0x748f82eeu,0x78a5636fu,0x84c87814u,0x8cc70208u,
  0x90befffau,0xa4506cebu,0xbef9a3f7u,0xc67178f2u,
};

/* ── SHA-NI fast path ─────────────────────────────────────────────────── */

#if USE_SHA256_NI

SHA256_TARGET
static void sha256_ni_blocks(uint32_t state[8], const uint8_t* data, size_t num_blocks) {
  __m128i state0, state1, msg, tmp;
  __m128i msg0, msg1, msg2, msg3;
  __m128i abef_save, cdgh_save;
  const __m128i SHUF_MASK =
    _mm_set_epi64x(0x0c0d0e0f08090a0bULL, 0x0405060700010203ULL);

  /* Load state: state[0..3]=ABCD, state[4..7]=EFGH */
  tmp    = _mm_loadu_si128((__m128i const*)&state[0]); /* ABCD */
  state1 = _mm_loadu_si128((__m128i const*)&state[4]); /* EFGH */
  tmp    = _mm_shuffle_epi32(tmp,    0xb1); /* CDAB */
  state1 = _mm_shuffle_epi32(state1, 0x1b); /* EFGH -> GHEF */
  state0 = _mm_alignr_epi8(tmp, state1, 8); /* ABEF */
  state1 = _mm_blend_epi16(state1, tmp, 0xf0); /* CDGH */

  while (num_blocks--) {
    abef_save = state0;
    cdgh_save = state1;

#define SHA256_DO4(msg_cur, msg_prev, msg_next0, msg_next1, k0k1)         \
    do {                                                                    \
      msg  = _mm_add_epi32((msg_cur),                                      \
               _mm_set_epi64x((k0k1) >> 32, (k0k1) & 0xffffffffULL));     \
      state1 = _mm_sha256rnds2_epu32(state1, state0, msg);                 \
      msg    = _mm_shuffle_epi32(msg, 0x0e);                               \
      state0 = _mm_sha256rnds2_epu32(state0, state1, msg);                 \
      (msg_prev) = _mm_sha256msg1_epu32((msg_prev), (msg_cur));            \
      if ((msg_next0) != NULL && (msg_next1) != NULL) {                    \
        tmp = _mm_alignr_epi8(*(msg_next1), (msg_cur), 4);                 \
        *(msg_next0) = _mm_add_epi32(*(msg_next0), tmp);                   \
        *(msg_next0) = _mm_sha256msg2_epu32(*(msg_next0), *(msg_next1));   \
      }                                                                     \
    } while(0)

    /* Load and byte-swap message blocks */
    msg0 = _mm_shuffle_epi8(_mm_loadu_si128((__m128i const*)(data +  0)), SHUF_MASK);
    msg1 = _mm_shuffle_epi8(_mm_loadu_si128((__m128i const*)(data + 16)), SHUF_MASK);
    msg2 = _mm_shuffle_epi8(_mm_loadu_si128((__m128i const*)(data + 32)), SHUF_MASK);
    msg3 = _mm_shuffle_epi8(_mm_loadu_si128((__m128i const*)(data + 48)), SHUF_MASK);

    /* Rounds 0-3: msg0 + K[0..3] */
    msg = _mm_add_epi32(msg0, _mm_loadu_si128((__m128i const*)&K256[0]));
    state1 = _mm_sha256rnds2_epu32(state1, state0, msg);
    msg    = _mm_shuffle_epi32(msg, 0x0e);
    state0 = _mm_sha256rnds2_epu32(state0, state1, msg);

    /* Rounds 4-7: msg1 + K[4..7]; msg0 = sha256msg1(msg0, msg1) */
    msg = _mm_add_epi32(msg1, _mm_loadu_si128((__m128i const*)&K256[4]));
    state1 = _mm_sha256rnds2_epu32(state1, state0, msg);
    msg    = _mm_shuffle_epi32(msg, 0x0e);
    state0 = _mm_sha256rnds2_epu32(state0, state1, msg);
    msg0   = _mm_sha256msg1_epu32(msg0, msg1);

    /* Rounds 8-11: msg2 + K[8..11]; msg1 = sha256msg1(msg1, msg2) */
    msg = _mm_add_epi32(msg2, _mm_loadu_si128((__m128i const*)&K256[8]));
    state1 = _mm_sha256rnds2_epu32(state1, state0, msg);
    msg    = _mm_shuffle_epi32(msg, 0x0e);
    state0 = _mm_sha256rnds2_epu32(state0, state1, msg);
    msg1   = _mm_sha256msg1_epu32(msg1, msg2);

    /* Rounds 12-15: msg3 + K[12..15];
       msg0 = sha256msg2(msg0 + alignr(msg3, msg2, 4), msg3);
       msg2 = sha256msg1(msg2, msg3) */
    msg = _mm_add_epi32(msg3, _mm_loadu_si128((__m128i const*)&K256[12]));
    state1 = _mm_sha256rnds2_epu32(state1, state0, msg);
    tmp    = _mm_alignr_epi8(msg3, msg2, 4);
    msg0   = _mm_add_epi32(msg0, tmp);
    msg0   = _mm_sha256msg2_epu32(msg0, msg3);
    msg    = _mm_shuffle_epi32(msg, 0x0e);
    state0 = _mm_sha256rnds2_epu32(state0, state1, msg);
    msg2   = _mm_sha256msg1_epu32(msg2, msg3);

#define SHA256_FULL_ROUND(cur, prv, nxt0, nxt1, ki)                        \
    msg = _mm_add_epi32((cur), _mm_loadu_si128((__m128i const*)&K256[ki])); \
    state1 = _mm_sha256rnds2_epu32(state1, state0, msg);                   \
    tmp    = _mm_alignr_epi8((cur), (prv), 4);                              \
    (nxt0) = _mm_add_epi32((nxt0), tmp);                                    \
    (nxt0) = _mm_sha256msg2_epu32((nxt0), (cur));                           \
    msg    = _mm_shuffle_epi32(msg, 0x0e);                                  \
    state0 = _mm_sha256rnds2_epu32(state0, state1, msg);                   \
    (nxt1) = _mm_sha256msg1_epu32((nxt1), (cur));

    SHA256_FULL_ROUND(msg0, msg3, msg1, msg3, 16) /* rounds 16-19 */
    SHA256_FULL_ROUND(msg1, msg0, msg2, msg0, 20) /* rounds 20-23 */
    SHA256_FULL_ROUND(msg2, msg1, msg3, msg1, 24) /* rounds 24-27 */
    SHA256_FULL_ROUND(msg3, msg2, msg0, msg2, 28) /* rounds 28-31 */
    SHA256_FULL_ROUND(msg0, msg3, msg1, msg3, 32) /* rounds 32-35 */
    SHA256_FULL_ROUND(msg1, msg0, msg2, msg0, 36) /* rounds 36-39 */
    SHA256_FULL_ROUND(msg2, msg1, msg3, msg1, 40) /* rounds 40-43 */
    SHA256_FULL_ROUND(msg3, msg2, msg0, msg2, 44) /* rounds 44-47 */
    SHA256_FULL_ROUND(msg0, msg3, msg1, msg3, 48) /* rounds 48-51 */
    SHA256_FULL_ROUND(msg1, msg0, msg2, msg0, 52) /* rounds 52-55 */
    SHA256_FULL_ROUND(msg2, msg1, msg3, msg1, 56) /* rounds 56-59 */

    /* Rounds 60-63: last 4 rounds, no message schedule update */
    msg = _mm_add_epi32(msg3, _mm_loadu_si128((__m128i const*)&K256[60]));
    state1 = _mm_sha256rnds2_epu32(state1, state0, msg);
    msg    = _mm_shuffle_epi32(msg, 0x0e);
    state0 = _mm_sha256rnds2_epu32(state0, state1, msg);

    state0 = _mm_add_epi32(state0, abef_save);
    state1 = _mm_add_epi32(state1, cdgh_save);
    data  += 64;
  }

  /* Unpack state back to ABCDEFGH order */
  tmp    = _mm_shuffle_epi32(state0, 0x1b); /* FEBA */
  state1 = _mm_shuffle_epi32(state1, 0xb1); /* DCHG */
  state0 = _mm_blend_epi16(tmp, state1, 0xf0); /* DCBA */
  state1 = _mm_alignr_epi8(state1, tmp, 8); /* ABEF */
  _mm_storeu_si128((__m128i*)&state[0], state0);
  _mm_storeu_si128((__m128i*)&state[4], state1);
}

#endif /* USE_SHA256_NI */

/* ── portable scalar SHA-256 ──────────────────────────────────────────── */

static inline uint32_t rotr32(uint32_t x, int n) {
  return (x >> n) | (x << (32 - n));
}

static void sha256_scalar_blocks(uint32_t h[8], const uint8_t* data, size_t num_blocks) {
  while (num_blocks--) {
    uint32_t w[64];
    for (int i = 0; i < 16; i++) {
      w[i] = ((uint32_t)data[i*4]   << 24) | ((uint32_t)data[i*4+1] << 16) |
             ((uint32_t)data[i*4+2] <<  8) |  (uint32_t)data[i*4+3];
    }
    for (int i = 16; i < 64; i++) {
      uint32_t s0 = rotr32(w[i-15], 7)  ^ rotr32(w[i-15], 18) ^ (w[i-15] >> 3);
      uint32_t s1 = rotr32(w[i-2],  17) ^ rotr32(w[i-2],  19) ^ (w[i-2]  >> 10);
      w[i] = w[i-16] + s0 + w[i-7] + s1;
    }
    uint32_t a=h[0],b=h[1],c=h[2],d=h[3],e=h[4],f=h[5],g=h[6],hh=h[7];
    for (int i = 0; i < 64; i++) {
      uint32_t S1  = rotr32(e,6) ^ rotr32(e,11) ^ rotr32(e,25);
      uint32_t ch  = (e & f) ^ (~e & g);
      uint32_t T1  = hh + S1 + ch + K256[i] + w[i];
      uint32_t S0  = rotr32(a,2) ^ rotr32(a,13) ^ rotr32(a,22);
      uint32_t maj = (a & b) ^ (a & c) ^ (b & c);
      uint32_t T2  = S0 + maj;
      hh=g; g=f; f=e; e=d+T1; d=c; c=b; b=a; a=T1+T2;
    }
    h[0]+=a; h[1]+=b; h[2]+=c; h[3]+=d;
    h[4]+=e; h[5]+=f; h[6]+=g; h[7]+=hh;
    data += 64;
  }
}

/* ── MoonBit-callable entry point ─────────────────────────────────────── */

/*
 * sha256_compute(data, len, out)
 *   data : Bytes (passed as const uint8_t* from MoonBit native)
 *   len  : number of bytes to hash
 *   out  : FixedArray[Byte] with at least 32 bytes
 *
 * One-shot SHA-256: one FFI call per sha256_raw invocation.
 */
SHA256_TARGET
void sha256_compute(const uint8_t* data, int32_t len, uint8_t* out) {
  uint32_t state[8] = {
    0x6a09e667u, 0xbb67ae85u, 0x3c6ef372u, 0xa54ff53au,
    0x510e527fu, 0x9b05688cu, 0x1f83d9abu, 0x5be0cd19u,
  };

  int32_t full_blocks = len / 64;
  int32_t remainder   = len % 64;

#if USE_SHA256_NI
#  define SHA256_DISPATCH(st, d, n) \
     (sha256_ni_ok() ? sha256_ni_blocks((st),(d),(n)) : sha256_scalar_blocks((st),(d),(n)))
#else
#  define SHA256_DISPATCH(st, d, n) sha256_scalar_blocks((st),(d),(n))
#endif

  if (full_blocks > 0) {
    SHA256_DISPATCH(state, data, (size_t)full_blocks);
  }

  uint8_t pad[128];
  memcpy(pad, data + (size_t)full_blocks * 64, (size_t)remainder);
  pad[remainder] = 0x80;

  int32_t pad_len;
  if (remainder < 55) {
    memset(pad + remainder + 1, 0, (size_t)(55 - remainder));
    pad_len = 64;
  } else {
    memset(pad + remainder + 1, 0, (size_t)(119 - remainder));
    pad_len = 128;
  }

  uint64_t bit_len = (uint64_t)len * 8;
  pad[pad_len - 8] = (uint8_t)(bit_len >> 56);
  pad[pad_len - 7] = (uint8_t)(bit_len >> 48);
  pad[pad_len - 6] = (uint8_t)(bit_len >> 40);
  pad[pad_len - 5] = (uint8_t)(bit_len >> 32);
  pad[pad_len - 4] = (uint8_t)(bit_len >> 24);
  pad[pad_len - 3] = (uint8_t)(bit_len >> 16);
  pad[pad_len - 2] = (uint8_t)(bit_len >>  8);
  pad[pad_len - 1] = (uint8_t)(bit_len      );

  SHA256_DISPATCH(state, pad, (size_t)(pad_len / 64));

  for (int i = 0; i < 8; i++) {
    out[i*4    ] = (uint8_t)(state[i] >> 24);
    out[i*4 + 1] = (uint8_t)(state[i] >> 16);
    out[i*4 + 2] = (uint8_t)(state[i] >>  8);
    out[i*4 + 3] = (uint8_t)(state[i]      );
  }
}
