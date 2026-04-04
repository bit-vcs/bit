function _M0TPB15WasmHelperCache(param0, param1) {
  this.tried = param0;
  this.exports = param1;
}
const $1L = { hi: 0, lo: 1 };
function _M0TP26mizchi4zlib8RleToken(param0, param1, param2) {
  this.sym = param0;
  this.extra_bits = param1;
  this.extra_val = param2;
}
function _M0TP36mizchi3bit2io14EnvProviderBox(param0) {
  this.value = param0;
}
class $PanicError extends Error {}
function $panic() {
  throw new $PanicError();
}
function $bound_check(arr, index) {
  if (index < 0 || index >= arr.length) throw new Error("Index out of bounds");
}
function _M0TPB13StringBuilder(param0) {
  this.val = param0;
}
function _M0TPC16string10StringView(param0, param1, param2) {
  this.str = param0;
  this.start = param1;
  this.end = param2;
}
function _M0TPB7MyInt64(param0, param1) {
  this.hi = param0;
  this.lo = param1;
}
function $compare_int(a, b) {
  return (a >= b) - (a <= b);
}
const _M0FPB12random__seed = () => {
  if (globalThis.crypto?.getRandomValues) {
    const array = new Uint32Array(1);
    globalThis.crypto.getRandomValues(array);
    return array[0] | 0; // Convert to signed 32
  } else {
    return Math.floor(Math.random() * 0x100000000) | 0; // Fallback to Math.random
  }
};
function _M0TPB6Hasher(param0) {
  this.acc = param0;
}
const _M0FPB19int__to__string__js = (x, radix) => {
  return x.toString(radix);
};
const _M0FPB21int64__to__string__js = (num, radix) => {
  let val = (BigInt(num.hi >>> 0) << 32n) | BigInt(num.lo >>> 0);
  if (val & (1n << 63n)) {
    val = val - (1n << 64n);
  }
  return val.toString(radix);
};
function $unsafe_bytes_sub_string(bytes, byte_offset, byte_length) {
  const end_offset = byte_offset + byte_length;
  let buf = '';
  while (byte_offset < end_offset) {
    buf += String.fromCharCode(bytes[byte_offset] | (bytes[byte_offset + 1] << 8));
    byte_offset += 2;
  }
  return buf;
}
function $makebytes(a, b) {
  const arr = new Uint8Array(a);
  if (b !== 0) {
    arr.fill(b);
  }
  return arr;
}
function _M0TPB8MutLocalGiE(param0) {
  this.val = param0;
}
function $make_array_len_and_init(a, b) {
  const arr = new Array(a);
  arr.fill(b);
  return arr;
}
const _M0MPB7JSArray4push = (arr, val) => { arr.push(val); };
function _M0TPB8MutLocalGORPC16string10StringViewE(param0) {
  this.val = param0;
}
function _M0TPB9ArrayViewGjE(param0, param1, param2) {
  this.buf = param0;
  this.start = param1;
  this.end = param2;
}
function _M0TPB9ArrayViewGyE(param0, param1, param2) {
  this.buf = param0;
  this.start = param1;
  this.end = param2;
}
function _M0TPB12MutArrayViewGRP46mizchi3bit1x3hub12IssueCommentE(param0, param1, param2) {
  this.buf = param0;
  this.start = param1;
  this.end = param2;
}
function _M0TPB3MapGsbE(param0, param1, param2, param3, param4, param5, param6) {
  this.entries = param0;
  this.size = param1;
  this.capacity = param2;
  this.capacity_mask = param3;
  this.grow_at = param4;
  this.head = param5;
  this.tail = param6;
}
function _M0TPB3MapGslE(param0, param1, param2, param3, param4, param5, param6) {
  this.entries = param0;
  this.size = param1;
  this.capacity = param2;
  this.capacity_mask = param3;
  this.grow_at = param4;
  this.head = param5;
  this.tail = param6;
}
function _M0TPB5EntryGsbE(param0, param1, param2, param3, param4, param5) {
  this.prev = param0;
  this.next = param1;
  this.psl = param2;
  this.hash = param3;
  this.key = param4;
  this.value = param5;
}
function _M0TPB5EntryGsRP36mizchi3bit6object8ObjectIdE(param0, param1, param2, param3, param4, param5) {
  this.prev = param0;
  this.next = param1;
  this.psl = param2;
  this.hash = param3;
  this.key = param4;
  this.value = param5;
}
function _M0TPB5EntryGssE(param0, param1, param2, param3, param4, param5) {
  this.prev = param0;
  this.next = param1;
  this.psl = param2;
  this.hash = param3;
  this.key = param4;
  this.value = param5;
}
function _M0TPB5EntryGslE(param0, param1, param2, param3, param4, param5) {
  this.prev = param0;
  this.next = param1;
  this.psl = param2;
  this.hash = param3;
  this.key = param4;
  this.value = param5;
}
function _M0TPB5EntryGszE(param0, param1, param2, param3, param4, param5) {
  this.prev = param0;
  this.next = param1;
  this.psl = param2;
  this.hash = param3;
  this.key = param4;
  this.value = param5;
}
const _M0FPB23try__init__wasm__helper = function() {
  try {
    return new WebAssembly.Instance(new WebAssembly.Module(new Uint8Array([0, 97, 115, 109, 1, 0, 0, 0, 1, 13, 2, 96, 0, 1, 127, 96, 4, 127, 127, 127, 127, 1, 127, 3, 7, 6, 0, 1, 1, 1, 1, 1, 6, 6, 1, 127, 1, 65, 0, 11, 7, 50, 6, 3, 109, 117, 108, 0, 1, 5, 100, 105, 118, 95, 115, 0, 2, 5, 100, 105, 118, 95, 117, 0, 3, 5, 114, 101, 109, 95, 115, 0, 4, 5, 114, 101, 109, 95, 117, 0, 5, 8, 103, 101, 116, 95, 104, 105, 103, 104, 0, 0, 10, 191, 1, 6, 4, 0, 35, 0, 11, 36, 1, 1, 126, 32, 0, 173, 32, 1, 173, 66, 32, 134, 132, 32, 2, 173, 32, 3, 173, 66, 32, 134, 132, 126, 34, 4, 66, 32, 135, 167, 36, 0, 32, 4, 167, 11, 36, 1, 1, 126, 32, 0, 173, 32, 1, 173, 66, 32, 134, 132, 32, 2, 173, 32, 3, 173, 66, 32, 134, 132, 127, 34, 4, 66, 32, 135, 167, 36, 0, 32, 4, 167, 11, 36, 1, 1, 126, 32, 0, 173, 32, 1, 173, 66, 32, 134, 132, 32, 2, 173, 32, 3, 173, 66, 32, 134, 132, 128, 34, 4, 66, 32, 135, 167, 36, 0, 32, 4, 167, 11, 36, 1, 1, 126, 32, 0, 173, 32, 1, 173, 66, 32, 134, 132, 32, 2, 173, 32, 3, 173, 66, 32, 134, 132, 129, 34, 4, 66, 32, 135, 167, 36, 0, 32, 4, 167, 11, 36, 1, 1, 126, 32, 0, 173, 32, 1, 173, 66, 32, 134, 132, 32, 2, 173, 32, 3, 173, 66, 32, 134, 132, 130, 34, 4, 66, 32, 135, 167, 36, 0, 32, 4, 167, 11])), {}).exports;
  } catch (e) {
    return undefined;
  }
};
const _M0MPB7MyInt6411div__bigint = (a, b) => {
  const aVal = (BigInt(a.hi) << 32n) | BigInt(a.lo >>> 0);
  const bVal = (BigInt(b.hi) << 32n) | BigInt(b.lo >>> 0);
  const result = aVal / bVal;
  const lo = Number(result & 0xFFFFFFFFn);
  const hi = Number((result >> 32n) & 0xFFFFFFFFn);
  return { hi: hi | 0, lo: lo | 0 };
};
const _M0MPB7MyInt647compare = (a, b) => {
  const ahi = a.hi;
  const bhi = b.hi;
  if (ahi < bhi) {
    return -1;
  }
  if (ahi > bhi) {
    return 1;
  }
  const alo = a.lo >>> 0;
  const blo = b.lo >>> 0;
  if (alo < blo) {
    return -1;
  }
  if (alo > blo) {
    return 1;
  }
  return 0;
};
const _M0MPB7MyInt6410compare__u = (a, b) => {
  const ahi = a.hi >>> 0;
  const bhi = b.hi >>> 0;
  if (ahi < bhi) {
    return -1;
  }
  if (ahi > bhi) {
    return 1;
  }
  const alo = a.lo >>> 0;
  const blo = b.lo >>> 0;
  if (alo < blo) {
    return -1;
  }
  if (alo > blo) {
    return 1;
  }
  return 0;
};
const _M0MPB7JSArray4copy = (arr) => arr.slice(0);
const _M0MPB7MyInt6412from__double = (a) => {
  if (isNaN(a)) {
    return { hi: 0, lo: 0 };
  }
  if (a >= 9223372036854775807) {
    return { hi: 0x7fffffff, lo: 0xffffffff };
  }
  if (a <= -9223372036854775808) {
    return { hi: -2147483648, lo: 0 };
  }
  let neg = false;
  if (a < 0) {
    neg = true;
    a = -a;
  }
  let hi = (a * (1 / 0x100000000)) | 0;
  let lo = a >>> 0;
  if (neg) {
    if (lo === 0) {
      hi = ~hi + 1;
    } else {
      hi = ~hi;
      lo = ~lo + 1;
    }
  }
  return { hi, lo };
};
const $bytes_literal$0 = new Uint8Array();
function _M0TPC15bytes9BytesView(param0, param1, param2) {
  this.bytes = param0;
  this.start = param1;
  this.end = param2;
}
const _M0MPB7JSArray11set__length = (arr, len) => { arr.length = len; };
const _M0MPB7JSArray3pop = (arr) => arr.pop();
const _M0MPB7JSArray6splice = (arr, idx, cnt) => arr.splice(idx, cnt);
function _M0TPB9ArrayViewGsE(param0, param1, param2) {
  this.buf = param0;
  this.start = param1;
  this.end = param2;
}
function _M0TPC16buffer6Buffer(param0, param1) {
  this.data = param0;
  this.len = param1;
}
function _M0DTPC16result6ResultGUiRPC16string10StringViewbERPC17strconv12StrConvErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGUiRPC16string10StringViewbERPC17strconv12StrConvErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGUiRPC16string10StringViewbERPC17strconv12StrConvErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGUiRPC16string10StringViewbERPC17strconv12StrConvErrorE2Ok.prototype.$tag = 1;
function _M0DTPC15error5Error43mizchi_2fbit_2fx_2fhub_2ePrError_2eNotFound(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error43mizchi_2fbit_2fx_2fhub_2ePrError_2eNotFound.prototype.$tag = 10;
function _M0DTPC15error5Error48mizchi_2fbit_2fx_2fhub_2ePrError_2eInvalidFormat(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error48mizchi_2fbit_2fx_2fhub_2ePrError_2eInvalidFormat.prototype.$tag = 9;
function _M0DTPC15error5Error47mizchi_2fbit_2fx_2fhub_2ePrError_2eInvalidState(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error47mizchi_2fbit_2fx_2fhub_2ePrError_2eInvalidState.prototype.$tag = 8;
function _M0DTPC15error5Error48mizchi_2fbit_2fx_2fhub_2ePrError_2eMergeConflict(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error48mizchi_2fbit_2fx_2fhub_2ePrError_2eMergeConflict.prototype.$tag = 7;
function _M0DTPC15error5Error58moonbitlang_2fcore_2fstrconv_2eStrConvError_2eStrConvError(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error58moonbitlang_2fcore_2fstrconv_2eStrConvError_2eStrConvError.prototype.$tag = 6;
function _M0DTPC15error5Error39mizchi_2fzlib_2eZlibError_2eInvalidData(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error39mizchi_2fzlib_2eZlibError_2eInvalidData.prototype.$tag = 5;
function _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject.prototype.$tag = 4;
function _M0DTPC15error5Error47mizchi_2fbit_2fobject_2eGitError_2eHashMismatch(param0, param1) {
  this._0 = param0;
  this._1 = param1;
}
_M0DTPC15error5Error47mizchi_2fbit_2fobject_2eGitError_2eHashMismatch.prototype.$tag = 3;
function _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2ePackfileError(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2ePackfileError.prototype.$tag = 2;
function _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eProtocolError(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eProtocolError.prototype.$tag = 1;
function _M0DTPC15error5Error42mizchi_2fbit_2fobject_2eGitError_2eIoError(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error42mizchi_2fbit_2fobject_2eGitError_2eIoError.prototype.$tag = 0;
function _M0DTPC16result6ResultGuRPC17strconv12StrConvErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGuRPC17strconv12StrConvErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGuRPC17strconv12StrConvErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGuRPC17strconv12StrConvErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGlRPC17strconv12StrConvErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGlRPC17strconv12StrConvErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGlRPC17strconv12StrConvErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGlRPC17strconv12StrConvErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGiRPC17strconv12StrConvErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGiRPC17strconv12StrConvErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGiRPC17strconv12StrConvErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGiRPC17strconv12StrConvErrorE2Ok.prototype.$tag = 1;
const $9223372036854775807L = { hi: 2147483647, lo: -1 };
const $10L = { hi: 0, lo: 10 };
const $16L = { hi: 0, lo: 16 };
const $_9223372036854775808L = { hi: -2147483648, lo: 0 };
const $0L = { hi: 0, lo: 0 };
function _M0TP311moonbitlang1x6crypto6SHA256(param0, param1, param2, param3) {
  this.reg = param0;
  this.len = param1;
  this.buf = param2;
  this.buf_index = param3;
}
const $512L = { hi: 0, lo: 512 };
const $8L = { hi: 0, lo: 8 };
function _M0TP36mizchi3bit4hash11Sha256State(param0) {
  this.inner = param0;
}
function _M0TP36mizchi3bit4hash9Sha1State(param0, param1, param2, param3, param4) {
  this.h = param0;
  this.block = param1;
  this.w = param2;
  this.block_len = param3;
  this.total_len = param4;
}
const $255L = { hi: 0, lo: 255 };
function _M0DTPC16result6ResultGuRP26mizchi4zlib9ZlibErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGuRP26mizchi4zlib9ZlibErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGuRP26mizchi4zlib9ZlibErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGuRP26mizchi4zlib9ZlibErrorE2Ok.prototype.$tag = 1;
function _M0TP26mizchi4zlib11HuffmanTree(param0, param1, param2, param3, param4, param5, param6, param7, param8, param9) {
  this.left = param0;
  this.right = param1;
  this.symbol = param2;
  this.table_bits = param3;
  this.table_symbol = param4;
  this.table_len = param5;
  this.table_sub = param6;
  this.sub_bits = param7;
  this.sub_symbol = param8;
  this.sub_len = param9;
}
function _M0DTPC16result6ResultGRP26mizchi4zlib11HuffmanTreeRP26mizchi4zlib9ZlibErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP26mizchi4zlib11HuffmanTreeRP26mizchi4zlib9ZlibErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRP26mizchi4zlib11HuffmanTreeRP26mizchi4zlib9ZlibErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP26mizchi4zlib11HuffmanTreeRP26mizchi4zlib9ZlibErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGiRP26mizchi4zlib9ZlibErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGiRP26mizchi4zlib9ZlibErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGiRP26mizchi4zlib9ZlibErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGiRP26mizchi4zlib9ZlibErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGURP26mizchi4zlib11HuffmanTreeRP26mizchi4zlib11HuffmanTreeERP26mizchi4zlib9ZlibErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGURP26mizchi4zlib11HuffmanTreeRP26mizchi4zlib11HuffmanTreeERP26mizchi4zlib9ZlibErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGURP26mizchi4zlib11HuffmanTreeRP26mizchi4zlib11HuffmanTreeERP26mizchi4zlib9ZlibErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGURP26mizchi4zlib11HuffmanTreeRP26mizchi4zlib11HuffmanTreeERP26mizchi4zlib9ZlibErrorE2Ok.prototype.$tag = 1;
function _M0TP26mizchi4zlib9BitReader(param0, param1, param2, param3) {
  this.data = param0;
  this.byte_pos = param1;
  this.bit_buf = param2;
  this.bit_count = param3;
}
function _M0DTPC16result6ResultGUziERP26mizchi4zlib9ZlibErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGUziERP26mizchi4zlib9ZlibErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGUziERP26mizchi4zlib9ZlibErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGUziERP26mizchi4zlib9ZlibErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGzRP26mizchi4zlib9ZlibErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGzRP26mizchi4zlib9ZlibErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGzRP26mizchi4zlib9ZlibErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGzRP26mizchi4zlib9ZlibErrorE2Ok.prototype.$tag = 1;
function _M0TP26mizchi4zlib8HuffNode(param0, param1, param2, param3) {
  this.freq = param0;
  this.left = param1;
  this.right = param2;
  this.sym = param3;
}
function _M0DTPC16option6OptionGRPB5ArrayGiEE4None() {}
_M0DTPC16option6OptionGRPB5ArrayGiEE4None.prototype.$tag = 0;
const _M0DTPC16option6OptionGRPB5ArrayGiEE4None__ = new _M0DTPC16option6OptionGRPB5ArrayGiEE4None();
function _M0DTPC16option6OptionGRPB5ArrayGiEE4Some(param0) {
  this._0 = param0;
}
_M0DTPC16option6OptionGRPB5ArrayGiEE4Some.prototype.$tag = 1;
function _M0DTP26mizchi4zlib12DeflateToken3Lit(param0) {
  this._0 = param0;
}
_M0DTP26mizchi4zlib12DeflateToken3Lit.prototype.$tag = 0;
function _M0DTP26mizchi4zlib12DeflateToken5Match(param0, param1) {
  this._0 = param0;
  this._1 = param1;
}
_M0DTP26mizchi4zlib12DeflateToken5Match.prototype.$tag = 1;
function _M0TP26mizchi4zlib9BitWriter(param0, param1, param2) {
  this.buf = param0;
  this.bit_buf = param1;
  this.bit_count = param2;
}
function _M0TP36mizchi3bit6object8ObjectId(param0) {
  this.bytes = param0;
}
function _M0DTPC16result6ResultGiRP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGiRP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGiRP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGiRP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGRP36mizchi3bit6object8ObjectIdRP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP36mizchi3bit6object8ObjectIdRP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRP36mizchi3bit6object8ObjectIdRP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP36mizchi3bit6object8ObjectIdRP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0TP36mizchi3bit6object9TreeEntry(param0, param1, param2) {
  this.mode = param0;
  this.name = param1;
  this.id = param2;
}
function _M0TP36mizchi3bit6object6Commit(param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10) {
  this.tree = param0;
  this.parents = param1;
  this.author = param2;
  this.author_time = param3;
  this.author_tz = param4;
  this.committer = param5;
  this.commit_time = param6;
  this.committer_tz = param7;
  this.message = param8;
  this.encoding = param9;
  this.verbatim_message = param10;
}
function _M0TP36mizchi3bit6object9Sha1State(param0) {
  this.inner = param0;
}
function _M0TP36mizchi3bit6object10PackObject(param0, param1, param2, param3, param4) {
  this.obj_type = param0;
  this.data = param1;
  this.id = param2;
  this.offset = param3;
  this.crc32 = param4;
}
function _M0TP36mizchi3bit6object11Sha256State(param0) {
  this.inner = param0;
}
function _M0DTP36mizchi3bit6object9HashState3HS1(param0) {
  this._0 = param0;
}
_M0DTP36mizchi3bit6object9HashState3HS1.prototype.$tag = 0;
function _M0DTP36mizchi3bit6object9HashState5HS256(param0) {
  this._0 = param0;
}
_M0DTP36mizchi3bit6object9HashState5HS256.prototype.$tag = 1;
function _M0TP36mizchi3bit2io11EnvProvider(param0, param1) {
  this.get = param0;
  this.current_dir = param1;
}
function _M0DTPC16result6ResultGRP36mizchi3bit4repo10CommitInfoRP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP36mizchi3bit4repo10CommitInfoRP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRP36mizchi3bit4repo10CommitInfoRP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP36mizchi3bit4repo10CommitInfoRP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0TP36mizchi3bit4repo10CommitInfo(param0, param1) {
  this.tree = param0;
  this.parents = param1;
}
function _M0DTPC16result6ResultGRPB5ArrayGRP36mizchi3bit6object9TreeEntryERP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRPB5ArrayGRP36mizchi3bit6object9TreeEntryERP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRPB5ArrayGRP36mizchi3bit6object9TreeEntryERP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRPB5ArrayGRP36mizchi3bit6object9TreeEntryERP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGUiiERP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGUiiERP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGUiiERP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGUiiERP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGzRP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGzRP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGzRP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGzRP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGUiiiERP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGUiiiERP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGUiiiERP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGUiiiERP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGRP36mizchi3bit6object10ObjectTypeRP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP36mizchi3bit6object10ObjectTypeRP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRP36mizchi3bit6object10ObjectTypeRP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP36mizchi3bit6object10ObjectTypeRP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGUsiERP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGUsiERP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGUsiERP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGUsiERP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGRPB5ArrayGsERP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRPB5ArrayGsERP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRPB5ArrayGsERP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRPB5ArrayGsERP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGRPB5ArrayGzERP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRPB5ArrayGzERP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRPB5ArrayGzERP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRPB5ArrayGzERP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
const $7L = { hi: 0, lo: 7 };
function _M0DTP36mizchi3bit8reftable8RefValue8Deletion() {}
_M0DTP36mizchi3bit8reftable8RefValue8Deletion.prototype.$tag = 0;
const _M0DTP36mizchi3bit8reftable8RefValue8Deletion__ = new _M0DTP36mizchi3bit8reftable8RefValue8Deletion();
function _M0DTP36mizchi3bit8reftable8RefValue4Val1(param0) {
  this._0 = param0;
}
_M0DTP36mizchi3bit8reftable8RefValue4Val1.prototype.$tag = 1;
function _M0DTP36mizchi3bit8reftable8RefValue4Val2(param0, param1) {
  this._0 = param0;
  this._1 = param1;
}
_M0DTP36mizchi3bit8reftable8RefValue4Val2.prototype.$tag = 2;
function _M0DTP36mizchi3bit8reftable8RefValue6Symref(param0) {
  this._0 = param0;
}
_M0DTP36mizchi3bit8reftable8RefValue6Symref.prototype.$tag = 3;
function _M0TP36mizchi3bit8reftable9RefRecord(param0, param1, param2) {
  this.refname = param0;
  this.update_index = param1;
  this.value = param2;
}
function _M0TP36mizchi3bit8reftable14ReftableHeader(param0, param1, param2, param3) {
  this.version = param0;
  this.block_size = param1;
  this.min_update_index = param2;
  this.max_update_index = param3;
}
function _M0TP36mizchi3bit8reftable14ReftableFooter(param0, param1, param2, param3, param4, param5, param6) {
  this.header = param0;
  this.ref_index_offset = param1;
  this.obj_offset = param2;
  this.obj_index_offset = param3;
  this.log_offset = param4;
  this.log_index_offset = param5;
  this.crc32 = param6;
}
function _M0DTPC16option6OptionGRPB5ArrayGRP36mizchi3bit8reftable9RefRecordEE4None() {}
_M0DTPC16option6OptionGRPB5ArrayGRP36mizchi3bit8reftable9RefRecordEE4None.prototype.$tag = 0;
const _M0DTPC16option6OptionGRPB5ArrayGRP36mizchi3bit8reftable9RefRecordEE4None__ = new _M0DTPC16option6OptionGRPB5ArrayGRP36mizchi3bit8reftable9RefRecordEE4None();
function _M0DTPC16option6OptionGRPB5ArrayGRP36mizchi3bit8reftable9RefRecordEE4Some(param0) {
  this._0 = param0;
}
_M0DTPC16option6OptionGRPB5ArrayGRP36mizchi3bit8reftable9RefRecordEE4Some.prototype.$tag = 1;
function _M0DTPC16result6ResultGORP36mizchi3bit6object8ObjectIdRP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGORP36mizchi3bit6object8ObjectIdRP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGORP36mizchi3bit6object8ObjectIdRP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGORP36mizchi3bit6object8ObjectIdRP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGsRP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGsRP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGsRP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGsRP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
const $4294967295L = { hi: 0, lo: -1 };
function _M0DTPC16result6ResultGRP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
const $2147483647L = { hi: 0, lo: 2147483647 };
function _M0DTPC16result6ResultGlRP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGlRP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGlRP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGlRP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGRP36mizchi3bit3lib9PackIndexRP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP36mizchi3bit3lib9PackIndexRP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRP36mizchi3bit3lib9PackIndexRP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP36mizchi3bit3lib9PackIndexRP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0TP36mizchi3bit3lib9PackIndex(param0, param1, param2, param3) {
  this.pack_path = param0;
  this.ids = param1;
  this.offsets = param2;
  this.version = param3;
}
const $4285812579L = { hi: 0, lo: -9154717 };
const $2L = { hi: 0, lo: 2 };
const $2147483648L = { hi: 0, lo: -2147483648 };
function _M0DTPC16result6ResultGOlRP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGOlRP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGOlRP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGOlRP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0TPB9ArrayViewGUsbEE(param0, param1, param2) {
  this.buf = param0;
  this.start = param1;
  this.end = param2;
}
function _M0DTPC16result6ResultGORP36mizchi3bit3lib15CommitGraphFileRP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGORP36mizchi3bit3lib15CommitGraphFileRP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGORP36mizchi3bit3lib15CommitGraphFileRP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGORP36mizchi3bit3lib15CommitGraphFileRP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0TP36mizchi3bit3lib15CommitGraphFile(param0, param1, param2, param3, param4, param5, param6) {
  this.data = param0;
  this.hash_size = param1;
  this.num_commits = param2;
  this.oidf_offset = param3;
  this.oidl_offset = param4;
  this.cdat_offset = param5;
  this.edge_offset = param6;
}
function _M0TP36mizchi3bit3lib13LazyPackIndex(param0, param1, param2) {
  this.idx_path = param0;
  this.pack_path = param1;
  this.loaded = param2;
}
function _M0DTPC16result6ResultGRPB5ArrayGRP36mizchi3bit3lib13LazyPackIndexERP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRPB5ArrayGRP36mizchi3bit3lib13LazyPackIndexERP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRPB5ArrayGRP36mizchi3bit3lib13LazyPackIndexERP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRPB5ArrayGRP36mizchi3bit3lib13LazyPackIndexERP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGRP36mizchi3bit3lib8ObjectDbRP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP36mizchi3bit3lib8ObjectDbRP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRP36mizchi3bit3lib8ObjectDbRP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP36mizchi3bit3lib8ObjectDbRP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0TP36mizchi3bit3lib8ObjectDb(param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10) {
  this.objects_dir = param0;
  this.loose_paths = param1;
  this.packs = param2;
  this.lazy_packs = param3;
  this.pack_cache = param4;
  this.pack_cache_order = param5;
  this.pack_cache_limit = param6;
  this.prefer_packed = param7;
  this.saw_corrupt_pack = param8;
  this.skip_verify = param9;
  this.commit_graph = param10;
}
function _M0TPB9ArrayViewGUssEE(param0, param1, param2) {
  this.buf = param0;
  this.start = param1;
  this.end = param2;
}
function _M0TPB9ArrayViewGUszEE(param0, param1, param2) {
  this.buf = param0;
  this.start = param1;
  this.end = param2;
}
function _M0TP46mizchi3bit1x3hub8WorkItem(param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10, param11, param12) {
  this.id = param0;
  this.title = param1;
  this.body = param2;
  this.author = param3;
  this.created_at = param4;
  this.updated_at = param5;
  this.state = param6;
  this.labels = param7;
  this.assignees = param8;
  this.linked_prs = param9;
  this.linked_issues = param10;
  this.patch = param11;
  this.parent_id = param12;
}
function _M0TP46mizchi3bit1x3hub13WorkItemPatch(param0, param1, param2, param3, param4, param5, param6, param7) {
  this.source_branch = param0;
  this.source_repo = param1;
  this.source_ref = param2;
  this.source_commit = param3;
  this.target_branch = param4;
  this.target_commit = param5;
  this.closes_issues = param6;
  this.merge_commit = param7;
}
function _M0DTPC16result6ResultGRP46mizchi3bit1x3hub8WorkItemRP46mizchi3bit1x3hub7PrErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP46mizchi3bit1x3hub8WorkItemRP46mizchi3bit1x3hub7PrErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRP46mizchi3bit1x3hub8WorkItemRP46mizchi3bit1x3hub7PrErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP46mizchi3bit1x3hub8WorkItemRP46mizchi3bit1x3hub7PrErrorE2Ok.prototype.$tag = 1;
function _M0TPB9ArrayViewGUslEE(param0, param1, param2) {
  this.buf = param0;
  this.start = param1;
  this.end = param2;
}
function _M0TP46mizchi3bit1x3hub9HubRecord(param0, param1, param2, param3, param4, param5, param6, param7, param8) {
  this.version = param0;
  this.key = param1;
  this.kind = param2;
  this.clock = param3;
  this.timestamp = param4;
  this.node = param5;
  this.deleted = param6;
  this.signature = param7;
  this.payload = param8;
}
function _M0DTPC16result6ResultGuRP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGuRP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGuRP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGuRP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16option6OptionGOsE4None() {}
_M0DTPC16option6OptionGOsE4None.prototype.$tag = 0;
const _M0DTPC16option6OptionGOsE4None__ = new _M0DTPC16option6OptionGOsE4None();
function _M0DTPC16option6OptionGOsE4Some(param0) {
  this._0 = param0;
}
_M0DTPC16option6OptionGOsE4Some.prototype.$tag = 1;
function _M0DTPC16result6ResultGRP46mizchi3bit1x3hub9HubRecordRP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP46mizchi3bit1x3hub9HubRecordRP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRP46mizchi3bit1x3hub9HubRecordRP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP46mizchi3bit1x3hub9HubRecordRP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0TP46mizchi3bit1x3hub5Issue(param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10, param11) {
  this.id = param0;
  this.title = param1;
  this.body = param2;
  this.author = param3;
  this.created_at = param4;
  this.updated_at = param5;
  this.state = param6;
  this.labels = param7;
  this.assignees = param8;
  this.linked_prs = param9;
  this.linked_issues = param10;
  this.parent_id = param11;
}
function _M0DTPC16option6OptionGRPB5ArrayGsEE4None() {}
_M0DTPC16option6OptionGRPB5ArrayGsEE4None.prototype.$tag = 0;
const _M0DTPC16option6OptionGRPB5ArrayGsEE4None__ = new _M0DTPC16option6OptionGRPB5ArrayGsEE4None();
function _M0DTPC16option6OptionGRPB5ArrayGsEE4Some(param0) {
  this._0 = param0;
}
_M0DTPC16option6OptionGRPB5ArrayGsEE4Some.prototype.$tag = 1;
function _M0DTPC16option6OptionGORP46mizchi3bit1x3hub13WorkItemPatchE4None() {}
_M0DTPC16option6OptionGORP46mizchi3bit1x3hub13WorkItemPatchE4None.prototype.$tag = 0;
const _M0DTPC16option6OptionGORP46mizchi3bit1x3hub13WorkItemPatchE4None__ = new _M0DTPC16option6OptionGORP46mizchi3bit1x3hub13WorkItemPatchE4None();
function _M0DTPC16option6OptionGORP46mizchi3bit1x3hub13WorkItemPatchE4Some(param0) {
  this._0 = param0;
}
_M0DTPC16option6OptionGORP46mizchi3bit1x3hub13WorkItemPatchE4Some.prototype.$tag = 1;
function _M0TP46mizchi3bit1x3hub12IssueComment(param0, param1, param2, param3, param4, param5) {
  this.id = param0;
  this.issue_id = param1;
  this.author = param2;
  this.body = param3;
  this.created_at = param4;
  this.reply_to = param5;
}
function _M0TPB9ArrayViewGUsRP36mizchi3bit6object8ObjectIdEE(param0, param1, param2) {
  this.buf = param0;
  this.start = param1;
  this.end = param2;
}
function _M0DTPC16result6ResultGRP46mizchi3bit1x3hub8HubStoreRP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP46mizchi3bit1x3hub8HubStoreRP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRP46mizchi3bit1x3hub8HubStoreRP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP46mizchi3bit1x3hub8HubStoreRP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0TP46mizchi3bit1x3hub8HubStore(param0, param1, param2, param3, param4) {
  this.node_id = param0;
  this.signing_key = param1;
  this.require_signed = param2;
  this.entries = param3;
  this.head = param4;
}
function _M0DTPC16result6ResultGRP46mizchi3bit1x3hub3HubRP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP46mizchi3bit1x3hub3HubRP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRP46mizchi3bit1x3hub3HubRP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP46mizchi3bit1x3hub3HubRP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0TP46mizchi3bit1x3hub3Hub(param0) {
  this.store = param0;
}
function _M0TP46mizchi3bit1x3hub11HubJsHostFs(param0) {
  this.host_id = param0;
}
const _M0FP46mizchi3bit1x3hub26hub__js__host__last__error = () => globalThis.__bitGitJsLastError ?? "";
const _M0FP46mizchi3bit1x3hub26hub__js__host__write__file = (hostId, path, content) => {
   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
   const host = state.hosts.get(hostId);
   if (!host) return `host ${hostId} not found`;
   try { host.writeFile(path, Uint8Array.from(content ?? [])); return undefined; }
   catch (e) { return String(e?.message ?? e); }
 };
const _M0FP46mizchi3bit1x3hub28hub__js__host__write__string = (hostId, path, content) => {
   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
   const host = state.hosts.get(hostId);
   if (!host) return `host ${hostId} not found`;
   try { host.writeString(path, content); return undefined; }
   catch (e) { return String(e?.message ?? e); }
 };
const _M0FP46mizchi3bit1x3hub23hub__js__host__mkdir__p = (hostId, path) => {
   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
   const host = state.hosts.get(hostId);
   if (!host) return `host ${hostId} not found`;
   try { host.mkdirP(path); return undefined; }
   catch (e) { return String(e?.message ?? e); }
 };
const _M0FP46mizchi3bit1x3hub25hub__js__host__read__file = (hostId, path) => {
   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
   const host = state.hosts.get(hostId);
   if (!host) { globalThis.__bitGitJsLastError = `host ${hostId} not found`; return { $tag: 0 }; }
   try {
     const v = host.readFile(path);
     if (v instanceof Uint8Array) return { $tag: 1, _0: Array.from(v) };
     if (v instanceof ArrayBuffer) return { $tag: 1, _0: Array.from(new Uint8Array(v)) };
     if (Array.isArray(v)) return { $tag: 1, _0: v.map(x => Number(x) & 0xff) };
     if (typeof v === 'string') return { $tag: 1, _0: Array.from(new TextEncoder().encode(v)) };
     globalThis.__bitGitJsLastError = 'readFile must return Uint8Array/ArrayBuffer/Array/string';
     return { $tag: 0 };
   } catch (e) { globalThis.__bitGitJsLastError = String(e?.message ?? e); return { $tag: 0 }; }
 };
const _M0FP46mizchi3bit1x3hub22hub__js__host__readdir = (hostId, path) => {
   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
   const host = state.hosts.get(hostId);
   if (!host) { globalThis.__bitGitJsLastError = `host ${hostId} not found`; return { $tag: 0 }; }
   try {
     const entries = host.readdir(path);
     return { $tag: 1, _0: Array.from(entries) };
   } catch (e) { globalThis.__bitGitJsLastError = String(e?.message ?? e); return { $tag: 0 }; }
 };
const _M0FP46mizchi3bit1x3hub22hub__js__host__is__dir = (hostId, path) => {
   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
   const host = state.hosts.get(hostId);
   return host?.isDir?.(path) ?? false;
 };
const _M0FP46mizchi3bit1x3hub23hub__js__host__is__file = (hostId, path) => {
   const state = globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() };
   const host = state.hosts.get(hostId);
   return host?.isFile?.(path) ?? false;
 };
function _M0DTPC16result6ResultGusE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGusE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGusE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGusE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGRPB5ArrayGRP46mizchi3bit1x3hub5IssueEsE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRPB5ArrayGRP46mizchi3bit1x3hub5IssueEsE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRPB5ArrayGRP46mizchi3bit1x3hub5IssueEsE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRPB5ArrayGRP46mizchi3bit1x3hub5IssueEsE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGRP46mizchi3bit1x3hub5IssuesE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP46mizchi3bit1x3hub5IssuesE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRP46mizchi3bit1x3hub5IssuesE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP46mizchi3bit1x3hub5IssuesE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGbRP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGbRP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGbRP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGbRP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
const _M0FP46mizchi3bit1x3hub18hub__js__date__now = () => Date.now();
function _M0TP46mizchi3bit1x3hub16HubJsObjectStore(param0, param1) {
  this.fs = param0;
  this.git_dir = param1;
}
function _M0TP46mizchi3bit1x3hub13HubJsRefStore(param0, param1) {
  this.fs = param0;
  this.git_dir = param1;
}
const $1000L = { hi: 0, lo: 1000 };
function _M0TP46mizchi3bit1x3hub10HubJsClock(param0) {
  this.timestamp = param0;
}
function _M0DTPC16result6ResultGURP46mizchi3bit1x3hub16HubJsObjectStoreRP46mizchi3bit1x3hub13HubJsRefStoreRP46mizchi3bit1x3hub10HubJsClockERP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGURP46mizchi3bit1x3hub16HubJsObjectStoreRP46mizchi3bit1x3hub13HubJsRefStoreRP46mizchi3bit1x3hub10HubJsClockERP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGURP46mizchi3bit1x3hub16HubJsObjectStoreRP46mizchi3bit1x3hub13HubJsRefStoreRP46mizchi3bit1x3hub10HubJsClockERP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGURP46mizchi3bit1x3hub16HubJsObjectStoreRP46mizchi3bit1x3hub13HubJsRefStoreRP46mizchi3bit1x3hub10HubJsClockERP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGRPB5ArrayGRP46mizchi3bit1x3hub5IssueERP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRPB5ArrayGRP46mizchi3bit1x3hub5IssueERP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRPB5ArrayGRP46mizchi3bit1x3hub5IssueERP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRPB5ArrayGRP46mizchi3bit1x3hub5IssueERP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGORP46mizchi3bit1x3hub5IssueRP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGORP46mizchi3bit1x3hub5IssueRP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGORP46mizchi3bit1x3hub5IssueRP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGORP46mizchi3bit1x3hub5IssueRP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGRP46mizchi3bit1x3hub5IssueRP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP46mizchi3bit1x3hub5IssueRP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRP46mizchi3bit1x3hub5IssueRP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP46mizchi3bit1x3hub5IssueRP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGRP46mizchi3bit1x3hub12IssueCommentRP46mizchi3bit1x3hub7PrErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP46mizchi3bit1x3hub12IssueCommentRP46mizchi3bit1x3hub7PrErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRP46mizchi3bit1x3hub12IssueCommentRP46mizchi3bit1x3hub7PrErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP46mizchi3bit1x3hub12IssueCommentRP46mizchi3bit1x3hub7PrErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGRPB5ArrayGRP46mizchi3bit1x3hub12IssueCommentERP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRPB5ArrayGRP46mizchi3bit1x3hub12IssueCommentERP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRPB5ArrayGRP46mizchi3bit1x3hub12IssueCommentERP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRPB5ArrayGRP46mizchi3bit1x3hub12IssueCommentERP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGRP46mizchi3bit1x3hub12IssueCommentRP36mizchi3bit6object8GitErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP46mizchi3bit1x3hub12IssueCommentRP36mizchi3bit6object8GitErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRP46mizchi3bit1x3hub12IssueCommentRP36mizchi3bit6object8GitErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP46mizchi3bit1x3hub12IssueCommentRP36mizchi3bit6object8GitErrorE2Ok.prototype.$tag = 1;
const _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsHostFs_24as_24_40mizchi_2fbit_2ftypes_2eRepoFileSystem = { method_0: _M0IP46mizchi3bit1x3hub11HubJsHostFsP36mizchi3bit5types14RepoFileSystem10read__file, method_1: _M0IP46mizchi3bit1x3hub11HubJsHostFsP36mizchi3bit5types14RepoFileSystem7readdir, method_2: _M0IP46mizchi3bit1x3hub11HubJsHostFsP36mizchi3bit5types14RepoFileSystem7is__dir, method_3: _M0IP46mizchi3bit1x3hub11HubJsHostFsP36mizchi3bit5types14RepoFileSystem8is__file };
const _M0FP092moonbitlang_2fcore_2fbuiltin_2fStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger = { method_0: _M0IPB13StringBuilderPB6Logger13write__string, method_1: _M0IP016_24default__implPB6Logger16write__substringGRPB13StringBuilderE, method_2: _M0IPB13StringBuilderPB6Logger11write__view, method_3: _M0IPB13StringBuilderPB6Logger11write__char };
const _M0FP078mizchi_2fbit_2fx_2fhub_2fHubJsRefStore_24as_24_40mizchi_2fbit_2flib_2eRefStore = { method_0: _M0IP46mizchi3bit1x3hub13HubJsRefStoreP36mizchi3bit3lib8RefStore7resolve, method_1: _M0IP46mizchi3bit1x3hub13HubJsRefStoreP36mizchi3bit3lib8RefStore6update, method_2: _M0IP46mizchi3bit1x3hub13HubJsRefStoreP36mizchi3bit3lib8RefStore4list };
const _M0FP080mizchi_2fbit_2fx_2fhub_2fHubJsHostFs_24as_24_40mizchi_2fbit_2ftypes_2eFileSystem = { method_0: _M0IP46mizchi3bit1x3hub11HubJsHostFsP36mizchi3bit5types10FileSystem8mkdir__p, method_1: _M0IP46mizchi3bit1x3hub11HubJsHostFsP36mizchi3bit5types10FileSystem11write__file, method_2: _M0IP46mizchi3bit1x3hub11HubJsHostFsP36mizchi3bit5types10FileSystem13write__string, method_3: _M0IP46mizchi3bit1x3hub11HubJsHostFsP36mizchi3bit5types10FileSystem12remove__file, method_4: _M0IP46mizchi3bit1x3hub11HubJsHostFsP36mizchi3bit5types10FileSystem11remove__dir };
const _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsObjectStore_24as_24_40mizchi_2fbit_2flib_2eObjectStore = { method_0: _M0IP46mizchi3bit1x3hub16HubJsObjectStoreP36mizchi3bit3lib11ObjectStore3get, method_1: _M0IP46mizchi3bit1x3hub16HubJsObjectStoreP36mizchi3bit3lib11ObjectStore3put, method_2: _M0IP46mizchi3bit1x3hub16HubJsObjectStoreP36mizchi3bit3lib11ObjectStore3has };
const _M0FP072mizchi_2fbit_2fx_2fhub_2fHubJsClock_24as_24_40mizchi_2fbit_2flib_2eClock = { method_0: _M0IP46mizchi3bit1x3hub10HubJsClockP36mizchi3bit3lib5Clock3now };
const _M0MPC16string6String4trimN7_2abindS5836 = "\t\n\r ";
const _M0FPB19wasm__helper__cache = new _M0TPB15WasmHelperCache(false, undefined);
const _M0FPC17strconv14base__err__str = "invalid base";
const _M0FPC17strconv15range__err__str = "value out of range";
const _M0FPC17strconv16syntax__err__str = "invalid syntax";
const _M0FPC17strconv20parse__int64_2einnerN7_2abindS539 = "";
const _M0FP311moonbitlang1x6crypto9sha256__t = [1116352408, 1899447441, -1245643825, -373957723, 961987163, 1508970993, -1841331548, -1424204075, -670586216, 310598401, 607225278, 1426881987, 1925078388, -2132889090, -1680079193, -1046744716, -459576895, -272742522, 264347078, 604807628, 770255983, 1249150122, 1555081692, 1996064986, -1740746414, -1473132947, -1341970488, -1084653625, -958395405, -710438585, 113926993, 338241895, 666307205, 773529912, 1294757372, 1396182291, 1695183700, 1986661051, -2117940946, -1838011259, -1564481375, -1474664885, -1035236496, -949202525, -778901479, -694614492, -200395387, 275423344, 430227734, 506948616, 659060556, 883997877, 958139571, 1322822218, 1537002063, 1747873779, 1955562222, 2024104815, -2067236844, -1933114872, -1866530822, -1538233109, -1090935817, -965641998];
const _M0FP26mizchi4zlib10adler__mod = 65521;
const _M0MP26mizchi4zlib9BitReader10peek__bitsN3oneS37 = $1L;
const _M0FP26mizchi4zlib10dist__base = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577];
const _M0FP26mizchi4zlib11dist__extra = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13];
const _M0FP26mizchi4zlib12length__base = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258];
const _M0FP26mizchi4zlib13length__extra = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0];
const _M0FP26mizchi4zlib19deflate__dist__base = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577];
const _M0FP26mizchi4zlib20deflate__dist__extra = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13];
const _M0FP26mizchi4zlib21deflate__length__base = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258];
const _M0FP26mizchi4zlib22deflate__length__extra = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0];
const _M0FP36mizchi3bit4repo13parse__commitN7_2abindS189 = "\n";
const _M0FP36mizchi3bit4repo13parse__commitN7_2abindS177 = "tree ";
const _M0FP36mizchi3bit4repo13parse__commitN7_2abindS178 = "parent ";
const _M0FP36mizchi3bit8reftable15reftable__magic = new Uint8Array([82, 69, 70, 84]);
const _M0FP36mizchi3bit6remote15resolve__gitdirN7_2abindS326 = "gitdir: ";
const _M0FP36mizchi3bit6remote15resolve__gitdirN7_2abindS327 = "/";
const _M0FP36mizchi3bit6remote15resolve__gitdirN7_2abindS328 = "/";
const _M0FP36mizchi3bit3lib10join__pathN7_2abindS8089 = "/";
const _M0FP36mizchi3bit3lib10join__pathN7_2abindS8090 = "/";
const _M0FP36mizchi3bit3lib15normalize__pathN7_2abindS8113 = "/";
const _M0FP36mizchi3bit3lib15normalize__pathN7_2abindS8102 = "/";
const _M0FP36mizchi3bit3lib15normalize__pathN7_2abindS8115 = "/";
const _M0FP36mizchi3bit3lib15normalize__pathN7_2abindS8114 = "/";
const _M0FP36mizchi3bit3lib31normalize__repo__path__internalN7_2abindS8130 = "/";
const _M0FP36mizchi3bit3lib31normalize__repo__path__internalN7_2abindS8119 = "/";
const _M0FP36mizchi3bit3lib31normalize__repo__path__internalN7_2abindS8132 = "/";
const _M0FP36mizchi3bit3lib31normalize__repo__path__internalN7_2abindS8131 = "/";
const _M0FP36mizchi3bit3lib21normalize__repo__pathN7_2abindS8134 = "/";
const _M0FP36mizchi3bit3lib21normalize__repo__pathN7_2abindS8133 = "../";
const _M0FP36mizchi3bit3lib10trim__lineN7_2abindS8135 = "\r";
const _M0FP36mizchi3bit3lib15read__ref__lineN7_2abindS8148 = "\n";
const _M0FP36mizchi3bit3lib20resolve__packed__refN7_2abindS8169 = "\n";
const _M0FP36mizchi3bit3lib20resolve__packed__refN7_2abindS8152 = "#";
const _M0FP36mizchi3bit3lib20resolve__packed__refN7_2abindS8153 = "^";
const _M0FP36mizchi3bit3lib20resolve__packed__refN7_2abindS8158 = " ";
const _M0FP36mizchi3bit3lib23resolve__ref__commondirN7_2abindS8171 = "/";
const _M0FP36mizchi3bit3lib19resolve__ref__innerN7_2abindS8175 = "ref: ";
const _M0FP36mizchi3bit3lib28collect__lazy__pack__indexesN7_2abindS9785 = ".idx";
const _M0FP46mizchi3bit1x3hub42canonical__work__item__record__kind__value = "work-item";
const _M0FP46mizchi3bit1x3hub17parse__work__itemN7_2abindS2271 = "\n";
const _M0FP46mizchi3bit1x3hub17parse__work__itemN7_2abindS2260 = " ";
const _M0FP46mizchi3bit1x3hub17parse__work__itemN7_2abindS2272 = "\n";
const _M0FP46mizchi3bit1x3hub31work__item__meta__prefix__value = "hub/work-item/";
const _M0FP46mizchi3bit1x3hub12parse__clockN7_2abindS2317 = ",";
const _M0FP46mizchi3bit1x3hub12parse__clockN7_2abindS2306 = "=";
const _M0FP46mizchi3bit1x3hub18parse__hub__recordN7_2abindS2380 = "\n";
const _M0FP46mizchi3bit1x3hub18parse__hub__recordN7_2abindS2369 = " ";
const _M0FP46mizchi3bit1x3hub18parse__hub__recordN7_2abindS2381 = "\n";
const _M0FP46mizchi3bit1x3hub17clock__to__stringN7_2abindS2390 = ",";
const _M0FP46mizchi3bit1x3hub14hub__notes__ns = "bit-hub";
const _M0MP46mizchi3bit1x3hub3Hub25list__work__items_2einnerN7_2abindS2597 = "/meta";
const _M0FP46mizchi3bit1x3hub17hub__parent__pathN7_2abindS3881 = "/";
const _M0FP46mizchi3bit1x3hub21parse__issue__commentN7_2abindS4069 = "\n";
const _M0FP46mizchi3bit1x3hub21parse__issue__commentN7_2abindS4058 = " ";
const _M0FP46mizchi3bit1x3hub21parse__issue__commentN7_2abindS4070 = "\n";
const _M0FP46mizchi3bit1x3hub32to__issue__state_2econstr_2f4222 = 0;
const _M0FP46mizchi3bit1x3hub32to__issue__state_2econstr_2f4223 = 1;
const _M0FPB33brute__force__find_2econstr_2f354 = 0;
const _M0FPB43boyer__moore__horspool__find_2econstr_2f340 = 0;
const _M0FP36mizchi3bit8reftable12crc32__table = _M0FP36mizchi3bit8reftable19build__crc32__table();
const _M0FP26mizchi4zlib33length__code__info_2etuple_2f2742 = { _0: 285, _1: 0, _2: 0 };
const _M0FP26mizchi4zlib38build__canonical__codes_2etuple_2f2642 = { _0: 0, _1: 0 };
const _M0FP26mizchi4zlib34emit__rle__lengths_2erecord_2f2724 = new _M0TP26mizchi4zlib8RleToken(0, 0, 0);
const _M0FPB4seed = _M0FPB12random__seed();
const _M0FP36mizchi3bit2io18env__provider__box = new _M0TP36mizchi3bit2io14EnvProviderBox(_M0MP36mizchi3bit2io11EnvProvider4none());
const _M0FP46mizchi3bit1x3hub15hub__notes__ref = `refs/notes/${_M0FP46mizchi3bit1x3hub14hub__notes__ns}`;
const _M0FP46mizchi3bit1x3hub36list__issues_2einner_2econstr_2f4572 = 0;
const _M0FP46mizchi3bit1x3hub36js__hub__issue__list_2econstr_2f4588 = 0;
const _M0FP46mizchi3bit1x3hub36js__hub__issue__list_2econstr_2f4589 = 1;
const _M0FP46mizchi3bit1x3hub27put__record_2econstr_2f4145 = false;
const _M0FP46mizchi3bit1x3hub38js__hub__issue__search_2econstr_2f4821 = 0;
const _M0FP46mizchi3bit1x3hub38js__hub__issue__search_2econstr_2f4822 = 1;
function _M0FPC15abort5abortGRPC16string10StringViewE(msg) {
  return $panic();
}
function _M0FPC15abort5abortGuE(msg) {
  $panic();
}
function _M0FPC15abort5abortGyE(msg) {
  return $panic();
}
function _M0FPC15abort5abortGiE(msg) {
  return $panic();
}
function _M0FPC15abort5abortGOiE(msg) {
  return $panic();
}
function _M0MPB6Logger13write__objectGsE(self, obj) {
  _M0IPC16string6StringPB4Show6output(obj, self);
}
function _M0MPB6Hasher8consume4(self, input) {
  const _p = (self.acc >>> 0) + ((Math.imul(input, -1028477379) | 0) >>> 0) | 0;
  const _p$2 = 17;
  self.acc = Math.imul(_p << _p$2 | (_p >>> (32 - _p$2 | 0) | 0), 668265263) | 0;
}
function _M0MPB6Hasher13combine__uint(self, value) {
  self.acc = (self.acc >>> 0) + (4 >>> 0) | 0;
  _M0MPB6Hasher8consume4(self, value);
}
function _M0FPB5abortGRPC16string10StringViewE(string, loc) {
  return _M0FPC15abort5abortGRPC16string10StringViewE(`${string}\n  at ${_M0IP016_24default__implPB4Show10to__stringGRPB9SourceLocE(loc)}\n`);
}
function _M0FPB5abortGuE(string, loc) {
  _M0FPC15abort5abortGuE(`${string}\n  at ${_M0IP016_24default__implPB4Show10to__stringGRPB9SourceLocE(loc)}\n`);
}
function _M0FPB5abortGyE(string, loc) {
  return _M0FPC15abort5abortGyE(`${string}\n  at ${_M0IP016_24default__implPB4Show10to__stringGRPB9SourceLocE(loc)}\n`);
}
function _M0FPB5abortGiE(string, loc) {
  return _M0FPC15abort5abortGiE(`${string}\n  at ${_M0IP016_24default__implPB4Show10to__stringGRPB9SourceLocE(loc)}\n`);
}
function _M0FPB5abortGOiE(string, loc) {
  return _M0FPC15abort5abortGOiE(`${string}\n  at ${_M0IP016_24default__implPB4Show10to__stringGRPB9SourceLocE(loc)}\n`);
}
function _M0MPC15array10FixedArray12unsafe__blitGyE(dst, dst_offset, src, src_offset, len) {
  if (dst === src && dst_offset < src_offset) {
    let _tmp = 0;
    while (true) {
      const i = _tmp;
      if (i < len) {
        const _tmp$2 = dst_offset + i | 0;
        const _tmp$3 = src_offset + i | 0;
        $bound_check(src, _tmp$3);
        $bound_check(dst, _tmp$2);
        dst[_tmp$2] = src[_tmp$3];
        _tmp = i + 1 | 0;
        continue;
      } else {
        return;
      }
    }
  } else {
    let _tmp = len - 1 | 0;
    while (true) {
      const i = _tmp;
      if (i >= 0) {
        const _tmp$2 = dst_offset + i | 0;
        const _tmp$3 = src_offset + i | 0;
        $bound_check(src, _tmp$3);
        $bound_check(dst, _tmp$2);
        dst[_tmp$2] = src[_tmp$3];
        _tmp = i - 1 | 0;
        continue;
      } else {
        return;
      }
    }
  }
}
function _M0MPC15array10FixedArray12unsafe__blitGRPB17UnsafeMaybeUninitGyEE(dst, dst_offset, src, src_offset, len) {
  if (dst === src && dst_offset < src_offset) {
    let _tmp = 0;
    while (true) {
      const i = _tmp;
      if (i < len) {
        const _tmp$2 = dst_offset + i | 0;
        const _tmp$3 = src_offset + i | 0;
        $bound_check(src, _tmp$3);
        $bound_check(dst, _tmp$2);
        dst[_tmp$2] = src[_tmp$3];
        _tmp = i + 1 | 0;
        continue;
      } else {
        return;
      }
    }
  } else {
    let _tmp = len - 1 | 0;
    while (true) {
      const i = _tmp;
      if (i >= 0) {
        const _tmp$2 = dst_offset + i | 0;
        const _tmp$3 = src_offset + i | 0;
        $bound_check(src, _tmp$3);
        $bound_check(dst, _tmp$2);
        dst[_tmp$2] = src[_tmp$3];
        _tmp = i - 1 | 0;
        continue;
      } else {
        return;
      }
    }
  }
}
function _M0MPB18UninitializedArray12unsafe__blitGyE(dst, dst_offset, src, src_offset, len) {
  _M0MPC15array10FixedArray12unsafe__blitGRPB17UnsafeMaybeUninitGyEE(dst, dst_offset, src, src_offset, len);
}
function _M0MPB13StringBuilder11new_2einner(size_hint) {
  return new _M0TPB13StringBuilder("");
}
function _M0IPB13StringBuilderPB6Logger11write__char(self, ch) {
  self.val = `${self.val}${String.fromCodePoint(ch)}`;
}
function _M0MPC16uint166UInt1622is__leading__surrogate(self) {
  return _M0IP016_24default__implPB7Compare6op__geGkE(self, 55296) && _M0IP016_24default__implPB7Compare6op__leGkE(self, 56319);
}
function _M0MPC16uint166UInt1623is__trailing__surrogate(self) {
  return _M0IP016_24default__implPB7Compare6op__geGkE(self, 56320) && _M0IP016_24default__implPB7Compare6op__leGkE(self, 57343);
}
function _M0FPB32code__point__of__surrogate__pair(leading, trailing) {
  return (((Math.imul(leading - 55296 | 0, 1024) | 0) + trailing | 0) - 56320 | 0) + 65536 | 0;
}
function _M0MPC16string6String16unsafe__char__at(self, index) {
  const c1 = self.charCodeAt(index);
  if (_M0MPC16uint166UInt1622is__leading__surrogate(c1)) {
    const c2 = self.charCodeAt(index + 1 | 0);
    return _M0FPB32code__point__of__surrogate__pair(c1, c2);
  } else {
    return c1;
  }
}
function _M0MPC14byte4Byte7to__hexN14to__hex__digitS3442(i) {
  if (i < 10) {
    const _p = 48;
    const _p$2 = (i + _p | 0) & 255;
    return _p$2;
  } else {
    const _p = 97;
    const _p$2 = (i + _p | 0) & 255;
    const _p$3 = 10;
    const _p$4 = (_p$2 - _p$3 | 0) & 255;
    return _p$4;
  }
}
function _M0MPC14byte4Byte7to__hex(b) {
  const _self = _M0MPB13StringBuilder11new_2einner(0);
  const _p = 16;
  _M0IPB13StringBuilderPB6Logger11write__char(_self, _M0MPC14byte4Byte7to__hexN14to__hex__digitS3442((b / _p | 0) & 255));
  const _p$2 = 16;
  _M0IPB13StringBuilderPB6Logger11write__char(_self, _M0MPC14byte4Byte7to__hexN14to__hex__digitS3442((b % _p$2 | 0) & 255));
  const _p$3 = _self;
  return _p$3.val;
}
function _M0MPC16string10StringView11sub_2einner(self, start, end) {
  const str_len = self.str.length;
  let abs_end;
  if (end === undefined) {
    abs_end = self.end;
  } else {
    const _Some = end;
    const _end = _Some;
    abs_end = _end < 0 ? self.end + _end | 0 : self.start + _end | 0;
  }
  const abs_start = start < 0 ? self.end + start | 0 : self.start + start | 0;
  if (abs_start >= self.start && (abs_start <= abs_end && abs_end <= self.end)) {
    if (abs_start < str_len) {
      if (!_M0MPC16uint166UInt1623is__trailing__surrogate(self.str.charCodeAt(abs_start))) {
      } else {
        $panic();
      }
    }
    if (abs_end < str_len) {
      if (!_M0MPC16uint166UInt1623is__trailing__surrogate(self.str.charCodeAt(abs_end))) {
      } else {
        $panic();
      }
    }
    return new _M0TPC16string10StringView(self.str, abs_start, abs_end);
  } else {
    return $panic();
  }
}
function _M0MPC16string10StringView18escape__to_2einnerN14flush__segmentS3427(_env, seg, i) {
  const self = _env._1;
  const logger = _env._0;
  if (i > seg) {
    logger.method_table.method_2(logger.self, _M0MPC16string10StringView11sub_2einner(self, seg, i));
    return;
  } else {
    return;
  }
}
function _M0MPC16string10StringView18escape__to_2einner(self, logger, quote) {
  if (quote) {
    logger.method_table.method_3(logger.self, 34);
  }
  const len = self.end - self.start | 0;
  const _env = { _0: logger, _1: self };
  let _tmp = 0;
  let _tmp$2 = 0;
  _L: while (true) {
    const i = _tmp;
    const seg = _tmp$2;
    if (i >= len) {
      _M0MPC16string10StringView18escape__to_2einnerN14flush__segmentS3427(_env, seg, i);
      break;
    }
    const code = self.str.charCodeAt(self.start + i | 0);
    let c;
    _L$2: {
      switch (code) {
        case 34: {
          c = code;
          break _L$2;
        }
        case 92: {
          c = code;
          break _L$2;
        }
        case 10: {
          _M0MPC16string10StringView18escape__to_2einnerN14flush__segmentS3427(_env, seg, i);
          logger.method_table.method_0(logger.self, "\\n");
          _tmp = i + 1 | 0;
          _tmp$2 = i + 1 | 0;
          continue _L;
        }
        case 13: {
          _M0MPC16string10StringView18escape__to_2einnerN14flush__segmentS3427(_env, seg, i);
          logger.method_table.method_0(logger.self, "\\r");
          _tmp = i + 1 | 0;
          _tmp$2 = i + 1 | 0;
          continue _L;
        }
        case 8: {
          _M0MPC16string10StringView18escape__to_2einnerN14flush__segmentS3427(_env, seg, i);
          logger.method_table.method_0(logger.self, "\\b");
          _tmp = i + 1 | 0;
          _tmp$2 = i + 1 | 0;
          continue _L;
        }
        case 9: {
          _M0MPC16string10StringView18escape__to_2einnerN14flush__segmentS3427(_env, seg, i);
          logger.method_table.method_0(logger.self, "\\t");
          _tmp = i + 1 | 0;
          _tmp$2 = i + 1 | 0;
          continue _L;
        }
        default: {
          if (_M0IP016_24default__implPB7Compare6op__ltGkE(code, 32)) {
            _M0MPC16string10StringView18escape__to_2einnerN14flush__segmentS3427(_env, seg, i);
            logger.method_table.method_0(logger.self, "\\u{");
            logger.method_table.method_0(logger.self, _M0MPC14byte4Byte7to__hex(code & 255));
            logger.method_table.method_3(logger.self, 125);
            _tmp = i + 1 | 0;
            _tmp$2 = i + 1 | 0;
            continue _L;
          } else {
            _tmp = i + 1 | 0;
            continue _L;
          }
        }
      }
    }
    _M0MPC16string10StringView18escape__to_2einnerN14flush__segmentS3427(_env, seg, i);
    logger.method_table.method_3(logger.self, 92);
    logger.method_table.method_3(logger.self, c);
    _tmp = i + 1 | 0;
    _tmp$2 = i + 1 | 0;
    continue;
  }
  if (quote) {
    logger.method_table.method_3(logger.self, 34);
    return;
  } else {
    return;
  }
}
function _M0IPB13StringBuilderPB6Logger13write__string(self, str) {
  self.val = `${self.val}${str}`;
}
function _M0MPC16uint646UInt647to__int(self) {
  const _p = self;
  return _p.lo;
}
function _M0MPC16uint646UInt648to__byte(self) {
  return _M0MPC16uint646UInt647to__int(self) & 255;
}
function _M0MPB7MyInt649from__int(value) {
  return new _M0TPB7MyInt64(value >> 31 & -1, value | 0);
}
function _M0MPC13int3Int9to__int64(self) {
  return _M0MPB7MyInt649from__int(self);
}
function _M0MPC13int3Int10to__uint64(self) {
  return _M0MPC13int3Int9to__int64(self);
}
function _M0MPB6Hasher7combineGsE(self, value) {
  _M0IPC16string6StringPB4Hash13hash__combine(value, self);
}
function _M0IP016_24default__implPB2Eq10not__equalGRP46mizchi3bit1x3hub10IssueStateE(x, y) {
  return !_M0IP46mizchi3bit1x3hub10IssueStatePB2Eq5equal(x, y);
}
function _M0IP016_24default__implPB2Eq10not__equalGlE(x, y) {
  return !_M0IPC15int645Int64PB2Eq5equal(x, y);
}
function _M0IP016_24default__implPB2Eq10not__equalGRPC16string10StringViewE(x, y) {
  return !_M0IPC16string10StringViewPB2Eq5equal(x, y);
}
function _M0IP016_24default__implPB7Compare6op__ltGlE(x, y) {
  return _M0IPC15int645Int64PB7Compare7compare(x, y) < 0;
}
function _M0IP016_24default__implPB7Compare6op__ltGkE(x, y) {
  return $compare_int(x, y) < 0;
}
function _M0IP016_24default__implPB7Compare6op__gtGlE(x, y) {
  return _M0IPC15int645Int64PB7Compare7compare(x, y) > 0;
}
function _M0IP016_24default__implPB7Compare6op__gtGmE(x, y) {
  return _M0IPC16uint646UInt64PB7Compare7compare(x, y) > 0;
}
function _M0IP016_24default__implPB7Compare6op__leGkE(x, y) {
  return $compare_int(x, y) <= 0;
}
function _M0IP016_24default__implPB7Compare6op__leGlE(x, y) {
  return _M0IPC15int645Int64PB7Compare7compare(x, y) <= 0;
}
function _M0IP016_24default__implPB7Compare6op__geGkE(x, y) {
  return $compare_int(x, y) >= 0;
}
function _M0IP016_24default__implPB7Compare6op__geGlE(x, y) {
  return _M0IPC15int645Int64PB7Compare7compare(x, y) >= 0;
}
function _M0MPB6Hasher9avalanche(self) {
  let acc = self.acc;
  acc = acc ^ (acc >>> 15 | 0);
  acc = Math.imul(acc, -2048144777) | 0;
  acc = acc ^ (acc >>> 13 | 0);
  acc = Math.imul(acc, -1028477379) | 0;
  acc = acc ^ (acc >>> 16 | 0);
  return acc;
}
function _M0MPB6Hasher8finalize(self) {
  return _M0MPB6Hasher9avalanche(self);
}
function _M0MPB6Hasher11new_2einner(seed) {
  return new _M0TPB6Hasher((seed >>> 0) + (374761393 >>> 0) | 0);
}
function _M0MPB6Hasher3new(seed$46$opt) {
  let seed;
  if (seed$46$opt === undefined) {
    seed = _M0FPB4seed;
  } else {
    const _Some = seed$46$opt;
    seed = _Some;
  }
  return _M0MPB6Hasher11new_2einner(seed);
}
function _M0IP016_24default__implPB4Hash4hashGsE(self) {
  const h = _M0MPB6Hasher3new(undefined);
  _M0MPB6Hasher7combineGsE(h, self);
  return _M0MPB6Hasher8finalize(h);
}
function _M0MPC16string6String11sub_2einner(self, start, end) {
  const len = self.length;
  let end$2;
  if (end === undefined) {
    end$2 = len;
  } else {
    const _Some = end;
    const _end = _Some;
    end$2 = _end < 0 ? len + _end | 0 : _end;
  }
  const start$2 = start < 0 ? len + start | 0 : start;
  if (start$2 >= 0 && (start$2 <= end$2 && end$2 <= len)) {
    if (start$2 < len) {
      if (!_M0MPC16uint166UInt1623is__trailing__surrogate(self.charCodeAt(start$2))) {
      } else {
        $panic();
      }
    }
    if (end$2 < len) {
      if (!_M0MPC16uint166UInt1623is__trailing__surrogate(self.charCodeAt(end$2))) {
      } else {
        $panic();
      }
    }
    return new _M0TPC16string10StringView(self, start$2, end$2);
  } else {
    return $panic();
  }
}
function _M0IP016_24default__implPB6Logger16write__substringGRPB13StringBuilderE(self, value, start, len) {
  _M0IPB13StringBuilderPB6Logger11write__view(self, _M0MPC16string6String11sub_2einner(value, start, start + len | 0));
}
function _M0IP016_24default__implPB4Show10to__stringGRP26mizchi4zlib9ZlibErrorE(self) {
  const logger = _M0MPB13StringBuilder11new_2einner(0);
  _M0IP26mizchi4zlib9ZlibErrorPB4Show6output(self, { self: logger, method_table: _M0FP092moonbitlang_2fcore_2fbuiltin_2fStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger });
  return logger.val;
}
function _M0IP016_24default__implPB4Show10to__stringGiE(self) {
  const logger = _M0MPB13StringBuilder11new_2einner(0);
  _M0IPC13int3IntPB4Show6output(self, { self: logger, method_table: _M0FP092moonbitlang_2fcore_2fbuiltin_2fStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger });
  return logger.val;
}
function _M0IP016_24default__implPB4Show10to__stringGRPB9SourceLocE(self) {
  const logger = _M0MPB13StringBuilder11new_2einner(0);
  const _p = { self: logger, method_table: _M0FP092moonbitlang_2fcore_2fbuiltin_2fStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger };
  _p.method_table.method_0(_p.self, self);
  return logger.val;
}
function _M0IP016_24default__implPB4Show10to__stringGlE(self) {
  const logger = _M0MPB13StringBuilder11new_2einner(0);
  _M0IPC15int645Int64PB4Show6output(self, { self: logger, method_table: _M0FP092moonbitlang_2fcore_2fbuiltin_2fStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger });
  return logger.val;
}
function _M0MPB4Iter4nextGcE(self) {
  const _func = self;
  return _func();
}
function _M0MPB4Iter4nextGRPC16string10StringViewE(self) {
  const _func = self;
  return _func();
}
function _M0MPB4Iter4nextGyE(self) {
  const _func = self;
  return _func();
}
function _M0MPB4Iter4nextGjE(self) {
  const _func = self;
  return _func();
}
function _M0MPC13int3Int18to__string_2einner(self, radix) {
  return _M0FPB19int__to__string__js(self, radix);
}
function _M0MPC15int645Int6418to__string_2einner(self, radix) {
  return _M0FPB21int64__to__string__js(self, radix);
}
function _M0MPC16string10StringView12view_2einner(self, start_offset, end_offset) {
  let end_offset$2;
  if (end_offset === undefined) {
    end_offset$2 = self.end - self.start | 0;
  } else {
    const _Some = end_offset;
    end_offset$2 = _Some;
  }
  return start_offset >= 0 && (start_offset <= end_offset$2 && end_offset$2 <= (self.end - self.start | 0)) ? new _M0TPC16string10StringView(self.str, self.start + start_offset | 0, self.start + end_offset$2 | 0) : _M0FPB5abortGRPC16string10StringViewE("Invalid index for View", "builtin/stringview.mbt:113:5-113:36@moonbitlang/core");
}
function _M0FPB19unsafe__sub__string(_tmp, _tmp$2, _tmp$3) {
  return $unsafe_bytes_sub_string(_tmp, _tmp$2, _tmp$3);
}
function _M0MPC15bytes5Bytes29to__unchecked__string_2einner(self, offset, length) {
  const len = self.length;
  let length$2;
  if (length === undefined) {
    length$2 = len - offset | 0;
  } else {
    const _Some = length;
    length$2 = _Some;
  }
  return offset >= 0 && (length$2 >= 0 && (offset + length$2 | 0) <= len) ? _M0FPB19unsafe__sub__string(self, offset, length$2) : $panic();
}
function _M0IPC16string10StringViewPB4Show10to__string(self) {
  return self.str.substring(self.start, self.end);
}
function _M0MPC16string10StringView4iter(self) {
  const start = self.start;
  const end = self.end;
  const index = new _M0TPB8MutLocalGiE(start);
  const _p = () => {
    if (index.val < end) {
      const c1 = self.str.charCodeAt(index.val);
      if (_M0MPC16uint166UInt1622is__leading__surrogate(c1) && (index.val + 1 | 0) < self.end) {
        const c2 = self.str.charCodeAt(index.val + 1 | 0);
        if (_M0MPC16uint166UInt1623is__trailing__surrogate(c2)) {
          index.val = index.val + 2 | 0;
          return _M0FPB32code__point__of__surrogate__pair(c1, c2);
        }
      }
      index.val = index.val + 1 | 0;
      return c1;
    } else {
      return -1;
    }
  };
  return _p;
}
function _M0MPB5Iter23newGicE(f) {
  return f;
}
function _M0MPC16string10StringView5iter2(self) {
  const start = self.start;
  const end = self.end;
  const index = new _M0TPB8MutLocalGiE(start);
  const char_index = new _M0TPB8MutLocalGiE(0);
  return _M0MPB5Iter23newGicE(() => {
    if (index.val < end) {
      const c1 = self.str.charCodeAt(index.val);
      if (_M0MPC16uint166UInt1622is__leading__surrogate(c1) && (index.val + 1 | 0) < self.end) {
        const c2 = self.str.charCodeAt(index.val + 1 | 0);
        if (_M0MPC16uint166UInt1623is__trailing__surrogate(c2)) {
          const result = { _0: char_index.val, _1: _M0FPB32code__point__of__surrogate__pair(c1, c2) };
          index.val = index.val + 2 | 0;
          char_index.val = char_index.val + 1 | 0;
          return result;
        }
      }
      const result = { _0: char_index.val, _1: c1 };
      index.val = index.val + 1 | 0;
      char_index.val = char_index.val + 1 | 0;
      return result;
    } else {
      return undefined;
    }
  });
}
function _M0IPC16string10StringViewPB2Eq5equal(self, other) {
  const len = self.end - self.start | 0;
  if (len === (other.end - other.start | 0)) {
    if (self.str === other.str && self.start === other.start) {
      return true;
    }
    let _tmp = 0;
    while (true) {
      const i = _tmp;
      if (i < len) {
        const _p = self.str.charCodeAt(self.start + i | 0);
        const _p$2 = other.str.charCodeAt(other.start + i | 0);
        if (_p === _p$2) {
        } else {
          return false;
        }
        _tmp = i + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    return true;
  } else {
    return false;
  }
}
function _M0MPC16string6String12view_2einner(self, start_offset, end_offset) {
  let end_offset$2;
  if (end_offset === undefined) {
    end_offset$2 = self.length;
  } else {
    const _Some = end_offset;
    end_offset$2 = _Some;
  }
  return start_offset >= 0 && (start_offset <= end_offset$2 && end_offset$2 <= self.length) ? new _M0TPC16string10StringView(self, start_offset, end_offset$2) : _M0FPB5abortGRPC16string10StringViewE("Invalid index for View", "builtin/stringview.mbt:398:5-398:36@moonbitlang/core");
}
function _M0MPC16string6String24char__length__eq_2einner(self, len, start_offset, end_offset) {
  let end_offset$2;
  if (end_offset === undefined) {
    end_offset$2 = self.length;
  } else {
    const _Some = end_offset;
    end_offset$2 = _Some;
  }
  let _tmp = start_offset;
  let _tmp$2 = 0;
  while (true) {
    const index = _tmp;
    const count = _tmp$2;
    if (index < end_offset$2 && count < len) {
      const c1 = self.charCodeAt(index);
      if (_M0MPC16uint166UInt1622is__leading__surrogate(c1) && (index + 1 | 0) < end_offset$2) {
        const c2 = self.charCodeAt(index + 1 | 0);
        if (_M0MPC16uint166UInt1623is__trailing__surrogate(c2)) {
          _tmp = index + 2 | 0;
          _tmp$2 = count + 1 | 0;
          continue;
        } else {
          _M0FPB5abortGuE("invalid surrogate pair", "builtin/string.mbt:429:9-429:40@moonbitlang/core");
        }
      }
      _tmp = index + 1 | 0;
      _tmp$2 = count + 1 | 0;
      continue;
    } else {
      return count === len && index === end_offset$2;
    }
  }
}
function _M0MPC16string6String24char__length__ge_2einner(self, len, start_offset, end_offset) {
  let end_offset$2;
  if (end_offset === undefined) {
    end_offset$2 = self.length;
  } else {
    const _Some = end_offset;
    end_offset$2 = _Some;
  }
  let _tmp = start_offset;
  let _tmp$2 = 0;
  while (true) {
    const index = _tmp;
    const count = _tmp$2;
    if (index < end_offset$2 && count < len) {
      const c1 = self.charCodeAt(index);
      if (_M0MPC16uint166UInt1622is__leading__surrogate(c1) && (index + 1 | 0) < end_offset$2) {
        const c2 = self.charCodeAt(index + 1 | 0);
        if (_M0MPC16uint166UInt1623is__trailing__surrogate(c2)) {
          _tmp = index + 2 | 0;
          _tmp$2 = count + 1 | 0;
          continue;
        } else {
          _M0FPB5abortGuE("invalid surrogate pair", "builtin/string.mbt:457:9-457:40@moonbitlang/core");
        }
      }
      _tmp = index + 1 | 0;
      _tmp$2 = count + 1 | 0;
      continue;
    } else {
      return count >= len;
    }
  }
}
function _M0MPC16string6String31offset__of__nth__char__backward(self, n, start_offset, end_offset) {
  let _tmp = end_offset;
  let _tmp$2 = 0;
  while (true) {
    const utf16_offset = _tmp;
    const char_count = _tmp$2;
    if ((utf16_offset - 1 | 0) >= start_offset && char_count < n) {
      const c = self.charCodeAt(utf16_offset - 1 | 0);
      if (_M0MPC16uint166UInt1623is__trailing__surrogate(c)) {
        _tmp = utf16_offset - 2 | 0;
        _tmp$2 = char_count + 1 | 0;
        continue;
      } else {
        _tmp = utf16_offset - 1 | 0;
        _tmp$2 = char_count + 1 | 0;
        continue;
      }
    } else {
      return char_count < n || utf16_offset < start_offset ? undefined : utf16_offset;
    }
  }
}
function _M0MPC16string6String30offset__of__nth__char__forward(self, n, start_offset, end_offset) {
  if (start_offset >= 0 && start_offset <= end_offset) {
    let _tmp = start_offset;
    let _tmp$2 = 0;
    while (true) {
      const utf16_offset = _tmp;
      const char_count = _tmp$2;
      if (utf16_offset < end_offset && char_count < n) {
        const c = self.charCodeAt(utf16_offset);
        if (_M0MPC16uint166UInt1622is__leading__surrogate(c)) {
          _tmp = utf16_offset + 2 | 0;
          _tmp$2 = char_count + 1 | 0;
          continue;
        } else {
          _tmp = utf16_offset + 1 | 0;
          _tmp$2 = char_count + 1 | 0;
          continue;
        }
      } else {
        return char_count < n || utf16_offset >= end_offset ? undefined : utf16_offset;
      }
    }
  } else {
    return _M0FPB5abortGOiE("Invalid start index", "builtin/string.mbt:329:5-329:33@moonbitlang/core");
  }
}
function _M0MPC16string6String29offset__of__nth__char_2einner(self, i, start_offset, end_offset) {
  let end_offset$2;
  if (end_offset === undefined) {
    end_offset$2 = self.length;
  } else {
    const _Some = end_offset;
    end_offset$2 = _Some;
  }
  return i >= 0 ? _M0MPC16string6String30offset__of__nth__char__forward(self, i, start_offset, end_offset$2) : _M0MPC16string6String31offset__of__nth__char__backward(self, -i | 0, start_offset, end_offset$2);
}
function _M0IPB13StringBuilderPB6Logger11write__view(self, str) {
  self.val = `${self.val}${_M0IPC16string10StringViewPB4Show10to__string(str)}`;
}
function _M0MPB13StringBuilder5reset(self) {
  self.val = "";
}
function _M0FPB28boyer__moore__horspool__find(haystack, needle) {
  const haystack_len = haystack.end - haystack.start | 0;
  const needle_len = needle.end - needle.start | 0;
  if (needle_len > 0) {
    if (haystack_len >= needle_len) {
      const skip_table = $make_array_len_and_init(256, needle_len);
      const _bind = needle_len - 1 | 0;
      let _tmp = 0;
      while (true) {
        const i = _tmp;
        if (i < _bind) {
          const _tmp$2 = needle.str.charCodeAt(needle.start + i | 0) & 255;
          $bound_check(skip_table, _tmp$2);
          skip_table[_tmp$2] = (needle_len - 1 | 0) - i | 0;
          _tmp = i + 1 | 0;
          continue;
        } else {
          break;
        }
      }
      let _tmp$2 = 0;
      while (true) {
        const i = _tmp$2;
        if (i <= (haystack_len - needle_len | 0)) {
          const _bind$2 = needle_len - 1 | 0;
          let _tmp$3 = 0;
          while (true) {
            const j = _tmp$3;
            if (j <= _bind$2) {
              const _p = i + j | 0;
              const _p$2 = haystack.str.charCodeAt(haystack.start + _p | 0);
              const _p$3 = needle.str.charCodeAt(needle.start + j | 0);
              if (_p$2 !== _p$3) {
                break;
              }
              _tmp$3 = j + 1 | 0;
              continue;
            } else {
              return i;
            }
          }
          const _p = (i + needle_len | 0) - 1 | 0;
          const _tmp$4 = haystack.str.charCodeAt(haystack.start + _p | 0) & 255;
          $bound_check(skip_table, _tmp$4);
          _tmp$2 = i + skip_table[_tmp$4] | 0;
          continue;
        } else {
          break;
        }
      }
      return undefined;
    } else {
      return undefined;
    }
  } else {
    return _M0FPB43boyer__moore__horspool__find_2econstr_2f340;
  }
}
function _M0FPB18brute__force__find(haystack, needle) {
  const haystack_len = haystack.end - haystack.start | 0;
  const needle_len = needle.end - needle.start | 0;
  if (needle_len > 0) {
    if (haystack_len >= needle_len) {
      const _p = 0;
      const needle_first = needle.str.charCodeAt(needle.start + _p | 0);
      const forward_len = haystack_len - needle_len | 0;
      let _tmp = 0;
      while (true) {
        const i = _tmp;
        if (i <= forward_len) {
          const _p$2 = haystack.str.charCodeAt(haystack.start + i | 0);
          if (_p$2 !== needle_first) {
            _tmp = i + 1 | 0;
            continue;
          }
          let _tmp$2 = 1;
          while (true) {
            const j = _tmp$2;
            if (j < needle_len) {
              const _p$3 = i + j | 0;
              const _p$4 = haystack.str.charCodeAt(haystack.start + _p$3 | 0);
              const _p$5 = needle.str.charCodeAt(needle.start + j | 0);
              if (_p$4 !== _p$5) {
                break;
              }
              _tmp$2 = j + 1 | 0;
              continue;
            } else {
              return i;
            }
          }
          _tmp = i + 1 | 0;
          continue;
        } else {
          break;
        }
      }
      return undefined;
    } else {
      return undefined;
    }
  } else {
    return _M0FPB33brute__force__find_2econstr_2f354;
  }
}
function _M0MPC16string10StringView4find(self, str) {
  return (str.end - str.start | 0) <= 4 ? _M0FPB18brute__force__find(self, str) : _M0FPB28boyer__moore__horspool__find(self, str);
}
function _M0FPB33boyer__moore__horspool__rev__find(haystack, needle) {
  const haystack_len = haystack.end - haystack.start | 0;
  const needle_len = needle.end - needle.start | 0;
  if (needle_len > 0) {
    if (haystack_len >= needle_len) {
      const skip_table = $make_array_len_and_init(256, needle_len);
      let _tmp = needle_len - 1 | 0;
      while (true) {
        const i = _tmp;
        if (i >= 1) {
          const _tmp$2 = needle.str.charCodeAt(needle.start + i | 0) & 255;
          $bound_check(skip_table, _tmp$2);
          skip_table[_tmp$2] = i;
          _tmp = i - 1 | 0;
          continue;
        } else {
          break;
        }
      }
      let _tmp$2 = haystack_len - needle_len | 0;
      while (true) {
        const i = _tmp$2;
        if (i >= 0) {
          let _tmp$3 = 0;
          while (true) {
            const j = _tmp$3;
            if (j < needle_len) {
              const _p = i + j | 0;
              const _p$2 = haystack.str.charCodeAt(haystack.start + _p | 0);
              const _p$3 = needle.str.charCodeAt(needle.start + j | 0);
              if (_p$2 !== _p$3) {
                break;
              }
              _tmp$3 = j + 1 | 0;
              continue;
            } else {
              return i;
            }
          }
          const _tmp$4 = haystack.str.charCodeAt(haystack.start + i | 0) & 255;
          $bound_check(skip_table, _tmp$4);
          _tmp$2 = i - skip_table[_tmp$4] | 0;
          continue;
        } else {
          break;
        }
      }
      return undefined;
    } else {
      return undefined;
    }
  } else {
    return haystack_len;
  }
}
function _M0MPC16string6String4find(self, str) {
  return _M0MPC16string10StringView4find(new _M0TPC16string10StringView(self, 0, self.length), str);
}
function _M0MPC16string10StringView8find__by(self, pred) {
  const _it = _M0MPC16string10StringView5iter2(self);
  while (true) {
    const _bind = _M0MPB5Iter24nextGicE(_it);
    if (_bind === undefined) {
      break;
    } else {
      const _Some = _bind;
      const _x = _Some;
      const _i = _x._0;
      const _c = _x._1;
      if (pred(_c)) {
        return _i;
      }
      continue;
    }
  }
  return undefined;
}
function _M0MPC16string6String8find__by(self, pred) {
  return _M0MPC16string10StringView8find__by(new _M0TPC16string10StringView(self, 0, self.length), pred);
}
function _M0FPB23brute__force__rev__find(haystack, needle) {
  const haystack_len = haystack.end - haystack.start | 0;
  const needle_len = needle.end - needle.start | 0;
  if (needle_len > 0) {
    if (haystack_len >= needle_len) {
      const _p = 0;
      const needle_first = needle.str.charCodeAt(needle.start + _p | 0);
      let _tmp = haystack_len - needle_len | 0;
      while (true) {
        const i = _tmp;
        if (i >= 0) {
          const _p$2 = haystack.str.charCodeAt(haystack.start + i | 0);
          if (_p$2 !== needle_first) {
            _tmp = i - 1 | 0;
            continue;
          }
          let _tmp$2 = 1;
          while (true) {
            const j = _tmp$2;
            if (j < needle_len) {
              const _p$3 = i + j | 0;
              const _p$4 = haystack.str.charCodeAt(haystack.start + _p$3 | 0);
              const _p$5 = needle.str.charCodeAt(needle.start + j | 0);
              if (_p$4 !== _p$5) {
                break;
              }
              _tmp$2 = j + 1 | 0;
              continue;
            } else {
              return i;
            }
          }
          _tmp = i - 1 | 0;
          continue;
        } else {
          break;
        }
      }
      return undefined;
    } else {
      return undefined;
    }
  } else {
    return haystack_len;
  }
}
function _M0MPC16string10StringView9rev__find(self, str) {
  return (str.end - str.start | 0) <= 4 ? _M0FPB23brute__force__rev__find(self, str) : _M0FPB33boyer__moore__horspool__rev__find(self, str);
}
function _M0MPC16string6String9rev__find(self, str) {
  return _M0MPC16string10StringView9rev__find(new _M0TPC16string10StringView(self, 0, self.length), str);
}
function _M0MPC16string10StringView11has__suffix(self, str) {
  const _bind = _M0MPC16string10StringView9rev__find(self, str);
  if (_bind === undefined) {
    return false;
  } else {
    const _Some = _bind;
    const _i = _Some;
    return _i === ((self.end - self.start | 0) - (str.end - str.start | 0) | 0);
  }
}
function _M0MPC16string6String11has__suffix(self, str) {
  return _M0MPC16string10StringView11has__suffix(new _M0TPC16string10StringView(self, 0, self.length), str);
}
function _M0MPC16string10StringView11has__prefix(self, str) {
  const _bind = _M0MPC16string10StringView4find(self, str);
  if (_bind === undefined) {
    return false;
  } else {
    const _Some = _bind;
    const _i = _Some;
    return _i === 0;
  }
}
function _M0MPC16string6String11has__prefix(self, str) {
  return _M0MPC16string10StringView11has__prefix(new _M0TPC16string10StringView(self, 0, self.length), str);
}
function _M0MPC15array5Array11new_2einnerGyE(capacity) {
  return [];
}
function _M0MPC15array5Array11new_2einnerGcE(capacity) {
  return [];
}
function _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(self, value) {
  _M0MPB7JSArray4push(self, value);
}
function _M0MPC15array5Array4pushGyE(self, value) {
  _M0MPB7JSArray4push(self, value);
}
function _M0MPC15array5Array4pushGiE(self, value) {
  _M0MPB7JSArray4push(self, value);
}
function _M0MPC15array5Array4pushGcE(self, value) {
  _M0MPB7JSArray4push(self, value);
}
function _M0MPC16string10StringView8contains(self, str) {
  const _bind = _M0MPC16string10StringView4find(self, str);
  return !(_bind === undefined);
}
function _M0MPC16string6String8contains(self, str) {
  return _M0MPC16string10StringView8contains(new _M0TPC16string10StringView(self, 0, self.length), str);
}
function _M0MPC16string10StringView14contains__char(self, c) {
  const len = self.end - self.start | 0;
  if (len > 0) {
    const c$2 = c;
    if (c$2 <= 65535) {
      let _tmp = 0;
      while (true) {
        const i = _tmp;
        if (i < len) {
          if (self.str.charCodeAt(self.start + i | 0) === c$2) {
            return true;
          }
          _tmp = i + 1 | 0;
          continue;
        } else {
          break;
        }
      }
    } else {
      if (len >= 2) {
        const adj = c$2 - 65536 | 0;
        const high = 55296 + (adj >> 10) | 0;
        const low = 56320 + (adj & 1023) | 0;
        let _tmp = 0;
        while (true) {
          const i = _tmp;
          if (i < (len - 1 | 0)) {
            if (self.str.charCodeAt(self.start + i | 0) === high) {
              const _p = i + 1 | 0;
              if (self.str.charCodeAt(self.start + _p | 0) === low) {
                return true;
              }
              _tmp = i + 2 | 0;
              continue;
            }
            _tmp = i + 1 | 0;
            continue;
          } else {
            break;
          }
        }
      } else {
        return false;
      }
    }
    return false;
  } else {
    return false;
  }
}
function _M0MPC16string10StringView19trim__start_2einner(self, chars) {
  let _tmp = self;
  while (true) {
    const _param = _tmp;
    if (_M0MPC16string6String24char__length__eq_2einner(_param.str, 0, _param.start, _param.end)) {
      return _param;
    } else {
      const _c = _M0MPC16string6String16unsafe__char__at(_param.str, _M0MPC16string6String29offset__of__nth__char_2einner(_param.str, 0, _param.start, _param.end));
      const _tmp$2 = _param.str;
      const _bind = _M0MPC16string6String29offset__of__nth__char_2einner(_param.str, 1, _param.start, _param.end);
      let _tmp$3;
      if (_bind === undefined) {
        _tmp$3 = _param.end;
      } else {
        const _Some = _bind;
        _tmp$3 = _Some;
      }
      const _x = new _M0TPC16string10StringView(_tmp$2, _tmp$3, _param.end);
      if (_M0MPC16string10StringView14contains__char(chars, _c)) {
        _tmp = _x;
        continue;
      } else {
        return _param;
      }
    }
  }
}
function _M0MPC16string10StringView17trim__end_2einner(self, chars) {
  let _tmp = self;
  while (true) {
    const _param = _tmp;
    if (_M0MPC16string6String24char__length__eq_2einner(_param.str, 0, _param.start, _param.end)) {
      return _param;
    } else {
      const _c = _M0MPC16string6String16unsafe__char__at(_param.str, _M0MPC16string6String29offset__of__nth__char_2einner(_param.str, -1, _param.start, _param.end));
      const _x = new _M0TPC16string10StringView(_param.str, _param.start, _M0MPC16string6String29offset__of__nth__char_2einner(_param.str, -1, _param.start, _param.end));
      if (_M0MPC16string10StringView14contains__char(chars, _c)) {
        _tmp = _x;
        continue;
      } else {
        return _param;
      }
    }
  }
}
function _M0MPC16string10StringView12trim_2einner(self, chars) {
  return _M0MPC16string10StringView17trim__end_2einner(_M0MPC16string10StringView19trim__start_2einner(self, chars), chars);
}
function _M0MPC16string6String12trim_2einner(self, chars) {
  return _M0MPC16string10StringView12trim_2einner(new _M0TPC16string10StringView(self, 0, self.length), chars);
}
function _M0MPC16string6String4trim(self, chars$46$opt) {
  let chars;
  if (chars$46$opt === undefined) {
    chars = new _M0TPC16string10StringView(_M0MPC16string6String4trimN7_2abindS5836, 0, _M0MPC16string6String4trimN7_2abindS5836.length);
  } else {
    const _Some = chars$46$opt;
    chars = _Some;
  }
  return _M0MPC16string6String12trim_2einner(self, chars);
}
function _M0MPC16string6String4iter(self) {
  const len = self.length;
  const index = new _M0TPB8MutLocalGiE(0);
  const _p = () => {
    if (index.val < len) {
      const c1 = self.charCodeAt(index.val);
      if (_M0MPC16uint166UInt1622is__leading__surrogate(c1) && (index.val + 1 | 0) < len) {
        const c2 = self.charCodeAt(index.val + 1 | 0);
        if (_M0MPC16uint166UInt1623is__trailing__surrogate(c2)) {
          const c = _M0FPB32code__point__of__surrogate__pair(c1, c2);
          index.val = index.val + 2 | 0;
          return c;
        }
      }
      index.val = index.val + 1 | 0;
      return c1;
    } else {
      return -1;
    }
  };
  return _p;
}
function _M0MPB4Iter3mapGcRPC16string10StringViewE(self, f) {
  return () => {
    const _bind = _M0MPB4Iter4nextGcE(self);
    if (_bind === -1) {
      return undefined;
    } else {
      const _Some = _bind;
      const _x = _Some;
      return f(_x);
    }
  };
}
function _M0IPC14char4CharPB4Show10to__string(self) {
  return String.fromCodePoint(self);
}
function _M0MPC16string10StringView5split(self, sep) {
  const sep_len = sep.end - sep.start | 0;
  if (sep_len === 0) {
    return _M0MPB4Iter3mapGcRPC16string10StringViewE(_M0MPC16string10StringView4iter(self), (c) => _M0MPC16string6String12view_2einner(_M0IPC14char4CharPB4Show10to__string(c), 0, undefined));
  }
  const remaining = new _M0TPB8MutLocalGORPC16string10StringViewE(self);
  const _p = () => {
    const _bind = remaining.val;
    if (_bind === undefined) {
      return undefined;
    } else {
      const _Some = _bind;
      const _view = _Some;
      const _bind$2 = _M0MPC16string10StringView4find(_view, sep);
      if (_bind$2 === undefined) {
        remaining.val = undefined;
        return _view;
      } else {
        const _Some$2 = _bind$2;
        const _end = _Some$2;
        remaining.val = _M0MPC16string10StringView12view_2einner(_view, _end + sep_len | 0, undefined);
        return _M0MPC16string10StringView12view_2einner(_view, 0, _end);
      }
    }
  };
  return _p;
}
function _M0MPC16string6String5split(self, sep) {
  return _M0MPC16string10StringView5split(new _M0TPC16string10StringView(self, 0, self.length), sep);
}
function _M0MPB4Iter9to__arrayGyE(self) {
  const result = [];
  while (true) {
    const _bind = _M0MPB4Iter4nextGyE(self);
    if (_bind === -1) {
      break;
    } else {
      const _Some = _bind;
      const _x = _Some;
      _M0MPC15array5Array4pushGyE(result, _x);
      continue;
    }
  }
  return result;
}
function _M0MPC14char4Char20is__ascii__uppercase(self) {
  return self >= 65 && self <= 90;
}
function _M0MPC16string10StringView9to__lower(self) {
  const _bind = _M0MPC16string10StringView8find__by(self, (x) => _M0MPC14char4Char20is__ascii__uppercase(x));
  if (_bind === undefined) {
    return self;
  } else {
    const _Some = _bind;
    const _idx = _Some;
    const buf = _M0MPB13StringBuilder11new_2einner(self.end - self.start | 0);
    const head = _M0MPC16string10StringView12view_2einner(self, 0, _idx);
    _M0IP016_24default__implPB6Logger16write__substringGRPB13StringBuilderE(buf, head.str, head.start, head.end - head.start | 0);
    const _it = _M0MPC16string10StringView4iter(_M0MPC16string10StringView12view_2einner(self, _idx, undefined));
    while (true) {
      const _bind$2 = _M0MPB4Iter4nextGcE(_it);
      if (_bind$2 === -1) {
        break;
      } else {
        const _Some$2 = _bind$2;
        const _c = _Some$2;
        if (_M0MPC14char4Char20is__ascii__uppercase(_c)) {
          _M0IPB13StringBuilderPB6Logger11write__char(buf, _c + 32 | 0);
        } else {
          _M0IPB13StringBuilderPB6Logger11write__char(buf, _c);
        }
        continue;
      }
    }
    const _bind$2 = buf.val;
    return new _M0TPC16string10StringView(_bind$2, 0, _bind$2.length);
  }
}
function _M0MPC16string6String9to__lower(self) {
  const _bind = _M0MPC16string6String8find__by(self, (x) => _M0MPC14char4Char20is__ascii__uppercase(x));
  if (_bind === undefined) {
    return self;
  } else {
    const _Some = _bind;
    const _idx = _Some;
    const buf = _M0MPB13StringBuilder11new_2einner(self.length);
    const head = _M0MPC16string6String12view_2einner(self, 0, _idx);
    _M0IP016_24default__implPB6Logger16write__substringGRPB13StringBuilderE(buf, head.str, head.start, head.end - head.start | 0);
    const _it = _M0MPC16string10StringView4iter(_M0MPC16string6String12view_2einner(self, _idx, undefined));
    while (true) {
      const _bind$2 = _M0MPB4Iter4nextGcE(_it);
      if (_bind$2 === -1) {
        break;
      } else {
        const _Some$2 = _bind$2;
        const _c = _Some$2;
        if (_M0MPC14char4Char20is__ascii__uppercase(_c)) {
          _M0IPB13StringBuilderPB6Logger11write__char(buf, _c + 32 | 0);
        } else {
          _M0IPB13StringBuilderPB6Logger11write__char(buf, _c);
        }
        continue;
      }
    }
    return buf.val;
  }
}
function _M0IPC16string6StringPB12ToStringView16to__string__view(self) {
  return new _M0TPC16string10StringView(self, 0, self.length);
}
function _M0IPC16string6StringPB7Compare7compare(self, other) {
  const len = self.length;
  const _bind = $compare_int(len, other.length);
  if (_bind === 0) {
    let _tmp = 0;
    while (true) {
      const i = _tmp;
      if (i < len) {
        const _p = self.charCodeAt(i);
        const _p$2 = other.charCodeAt(i);
        const order = $compare_int(_p, _p$2);
        if (order !== 0) {
          return order;
        }
        _tmp = i + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    return 0;
  } else {
    return _bind;
  }
}
function _M0MPC16string6String9to__array(self) {
  const _p = _M0MPC16string6String4iter(self);
  const _p$2 = _M0MPC15array5Array11new_2einnerGcE(self.length);
  let _p$3 = _p$2;
  while (true) {
    const _p$4 = _M0MPB4Iter4nextGcE(_p);
    if (_p$4 === -1) {
      break;
    } else {
      const _p$5 = _p$4;
      const _p$6 = _p$5;
      const _p$7 = _p$3;
      _M0MPC15array5Array4pushGcE(_p$7, _p$6);
      _p$3 = _p$7;
      continue;
    }
  }
  return _p$3;
}
function _M0IPC13int3IntPB4Show6output(self, logger) {
  logger.method_table.method_0(logger.self, _M0MPC13int3Int18to__string_2einner(self, 10));
}
function _M0IPC15int645Int64PB4Show6output(self, logger) {
  logger.method_table.method_0(logger.self, _M0MPC15int645Int6418to__string_2einner(self, 10));
}
function _M0IPC16string6StringPB4Show6output(self, logger) {
  _M0MPC16string10StringView18escape__to_2einner(new _M0TPC16string10StringView(self, 0, self.length), logger, true);
}
function _M0MPC15array9ArrayView4iterGyE(self) {
  const i = new _M0TPB8MutLocalGiE(0);
  const _p = () => {
    if (i.val < (self.end - self.start | 0)) {
      const elem = self.buf[self.start + i.val | 0];
      i.val = i.val + 1 | 0;
      return elem;
    } else {
      return -1;
    }
  };
  return _p;
}
function _M0MPC15array9ArrayView4iterGjE(self) {
  const i = new _M0TPB8MutLocalGiE(0);
  const _p = () => {
    if (i.val < (self.end - self.start | 0)) {
      const elem = self.buf[self.start + i.val | 0];
      i.val = i.val + 1 | 0;
      return elem;
    } else {
      return undefined;
    }
  };
  return _p;
}
function _M0MPC15array10FixedArray4iterGjE(self) {
  return _M0MPC15array9ArrayView4iterGjE(new _M0TPB9ArrayViewGjE(self, 0, self.length));
}
function _M0MPC15array5Array4iterGyE(self) {
  return _M0MPC15array9ArrayView4iterGyE(new _M0TPB9ArrayViewGyE(self, 0, self.length));
}
function _M0MPC15array10FixedArray5makeiGyE(length, value) {
  if (length <= 0) {
    return new Uint8Array([]);
  } else {
    const array = $makebytes(length, value(0));
    let _tmp = 1;
    while (true) {
      const i = _tmp;
      if (i < length) {
        $bound_check(array, i);
        array[i] = value(i);
        _tmp = i + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    return array;
  }
}
function _M0MPC15array9ArrayView6searchGsE(self, value) {
  const _bind = self.end - self.start | 0;
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < _bind) {
      if (self.buf[self.start + i | 0] === value) {
        return i;
      }
      _tmp = i + 1 | 0;
      continue;
    } else {
      return undefined;
    }
  }
}
function _M0MPC15array9ArrayView2atGyE(self, index) {
  if (index >= 0 && index < (self.end - self.start | 0)) {
    const _tmp = self.buf;
    const _tmp$2 = self.start + index | 0;
    $bound_check(_tmp, _tmp$2);
    return _tmp[_tmp$2];
  } else {
    return _M0FPB5abortGyE(`index out of bounds: the len is from 0 to ${_M0IP016_24default__implPB4Show10to__stringGiE(self.end - self.start | 0)} but the index is ${_M0IP016_24default__implPB4Show10to__stringGiE(index)}`, "builtin/arrayview.mbt:138:5-140:6@moonbitlang/core");
  }
}
function _M0MPC15array10FixedArray12view_2einnerGyE(self, start, end) {
  const len = self.length;
  let end$2;
  if (end === undefined) {
    end$2 = len;
  } else {
    const _Some = end;
    const _end = _Some;
    end$2 = _end < 0 ? len + _end | 0 : _end;
  }
  const start$2 = start < 0 ? len + start | 0 : start;
  if (start$2 >= 0 && (start$2 <= end$2 && end$2 <= len)) {
    const _bind = self;
    const _bind$2 = end$2 - start$2 | 0;
    return new _M0TPB9ArrayViewGyE(_bind, start$2, start$2 + _bind$2 | 0);
  } else {
    return _M0FPB5abortGRPC16string10StringViewE("View index out of bounds", "builtin/arrayview.mbt:454:5-454:38@moonbitlang/core");
  }
}
function _M0MPC15array12MutArrayView2atGRP46mizchi3bit1x3hub12IssueCommentE(self, index) {
  if (index >= 0 && index < (self.end - self.start | 0)) {
    const _tmp = self.buf;
    const _tmp$2 = self.start + index | 0;
    $bound_check(_tmp, _tmp$2);
    return _tmp[_tmp$2];
  } else {
    return _M0FPB5abortGRPC16string10StringViewE(`index out of bounds: the len is from 0 to ${_M0IP016_24default__implPB4Show10to__stringGiE(self.end - self.start | 0)} but the index is ${_M0IP016_24default__implPB4Show10to__stringGiE(index)}`, "builtin/mutarrayview.mbt:118:5-120:6@moonbitlang/core");
  }
}
function _M0MPC15array12MutArrayView3setGRP46mizchi3bit1x3hub12IssueCommentE(self, index, value) {
  if (index >= 0 && index < (self.end - self.start | 0)) {
    const _tmp = self.buf;
    const _tmp$2 = self.start + index | 0;
    $bound_check(_tmp, _tmp$2);
    _tmp[_tmp$2] = value;
    return;
  } else {
    _M0FPB5abortGuE(`index out of bounds: the len is from 0 to ${_M0IP016_24default__implPB4Show10to__stringGiE(self.end - self.start | 0)} but the index is ${_M0IP016_24default__implPB4Show10to__stringGiE(index)}`, "builtin/mutarrayview.mbt:182:5-184:6@moonbitlang/core");
    return;
  }
}
function _M0MPC15array5Array17mut__view_2einnerGRP46mizchi3bit1x3hub12IssueCommentE(self, start, end) {
  const len = self.length;
  let end$2;
  if (end === undefined) {
    end$2 = len;
  } else {
    const _Some = end;
    const _end = _Some;
    end$2 = _end < 0 ? len + _end | 0 : _end;
  }
  const start$2 = start < 0 ? len + start | 0 : start;
  if (start$2 >= 0 && (start$2 <= end$2 && end$2 <= len)) {
    const _bind = self;
    const _bind$2 = end$2 - start$2 | 0;
    return new _M0TPB12MutArrayViewGRP46mizchi3bit1x3hub12IssueCommentE(_bind, start$2, start$2 + _bind$2 | 0);
  } else {
    return _M0FPB5abortGRPC16string10StringViewE("View index out of bounds", "builtin/mutarrayview.mbt:258:5-258:38@moonbitlang/core");
  }
}
function _M0MPC15array12MutArrayView17mut__view_2einnerGRP46mizchi3bit1x3hub12IssueCommentE(self, start, end) {
  const len = self.end - self.start | 0;
  let end$2;
  if (end === undefined) {
    end$2 = len;
  } else {
    const _Some = end;
    const _end = _Some;
    end$2 = _end < 0 ? len + _end | 0 : _end;
  }
  const start$2 = start < 0 ? len + start | 0 : start;
  if (start$2 >= 0 && (start$2 <= end$2 && end$2 <= len)) {
    const _bind = self.buf;
    const _bind$2 = self.start + start$2 | 0;
    const _bind$3 = end$2 - start$2 | 0;
    return new _M0TPB12MutArrayViewGRP46mizchi3bit1x3hub12IssueCommentE(_bind, _bind$2, _bind$2 + _bind$3 | 0);
  } else {
    return _M0FPB5abortGRPC16string10StringViewE("View index out of bounds", "builtin/mutarrayview.mbt:307:5-307:38@moonbitlang/core");
  }
}
function _M0MPC15array5Array4makeGiE(len, elem) {
  const arr = new Array(len);
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < len) {
      arr[i] = elem;
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return arr;
}
function _M0MPC15array5Array4makeGUiiEE(len, elem) {
  const arr = new Array(len);
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < len) {
      arr[i] = elem;
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return arr;
}
function _M0MPC15array5Array4makeGyE(len, elem) {
  const arr = new Array(len);
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < len) {
      arr[i] = elem;
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return arr;
}
function _M0MPC15array5Array3setGlE(self, index, value) {
  const len = self.length;
  if (index >= 0 && index < len) {
    $bound_check(self, index);
    self[index] = value;
    return;
  } else {
    $panic();
    return;
  }
}
function _M0MPC15array5Array3setGiE(self, index, value) {
  const len = self.length;
  if (index >= 0 && index < len) {
    $bound_check(self, index);
    self[index] = value;
    return;
  } else {
    $panic();
    return;
  }
}
function _M0MPC15array5Array3setGyE(self, index, value) {
  const len = self.length;
  if (index >= 0 && index < len) {
    $bound_check(self, index);
    self[index] = value;
    return;
  } else {
    $panic();
    return;
  }
}
function _M0MPC13int3Int20next__power__of__two(self) {
  if (self >= 0) {
    if (self <= 1) {
      return 1;
    }
    if (self > 1073741824) {
      return 1073741824;
    }
    return (2147483647 >> (Math.clz32(self - 1 | 0) - 1 | 0)) + 1 | 0;
  } else {
    return $panic();
  }
}
function _M0MPB3Map11new_2einnerGsbE(capacity) {
  const capacity$2 = _M0MPC13int3Int20next__power__of__two(capacity);
  const _bind = capacity$2 - 1 | 0;
  const _bind$2 = (Math.imul(capacity$2, 13) | 0) / 16 | 0;
  const _bind$3 = $make_array_len_and_init(capacity$2, undefined);
  const _bind$4 = undefined;
  return new _M0TPB3MapGsbE(_bind$3, 0, capacity$2, _bind, _bind$2, _bind$4, -1);
}
function _M0MPB3Map11new_2einnerGslE(capacity) {
  const capacity$2 = _M0MPC13int3Int20next__power__of__two(capacity);
  const _bind = capacity$2 - 1 | 0;
  const _bind$2 = (Math.imul(capacity$2, 13) | 0) / 16 | 0;
  const _bind$3 = $make_array_len_and_init(capacity$2, undefined);
  const _bind$4 = undefined;
  return new _M0TPB3MapGslE(_bind$3, 0, capacity$2, _bind, _bind$2, _bind$4, -1);
}
function _M0MPB3Map20add__entry__to__tailGsbE(self, idx, entry) {
  const _bind = self.tail;
  if (_bind === -1) {
    self.head = entry;
  } else {
    const _tmp = self.entries;
    $bound_check(_tmp, _bind);
    const _p = _tmp[_bind];
    let _tmp$2;
    if (_p === undefined) {
      _tmp$2 = $panic();
    } else {
      const _p$2 = _p;
      _tmp$2 = _p$2;
    }
    _tmp$2.next = entry;
  }
  self.tail = idx;
  const _tmp = self.entries;
  $bound_check(_tmp, idx);
  _tmp[idx] = entry;
  self.size = self.size + 1 | 0;
}
function _M0MPB3Map20add__entry__to__tailGsRP36mizchi3bit6object8ObjectIdE(self, idx, entry) {
  const _bind = self.tail;
  if (_bind === -1) {
    self.head = entry;
  } else {
    const _tmp = self.entries;
    $bound_check(_tmp, _bind);
    const _p = _tmp[_bind];
    let _tmp$2;
    if (_p === undefined) {
      _tmp$2 = $panic();
    } else {
      const _p$2 = _p;
      _tmp$2 = _p$2;
    }
    _tmp$2.next = entry;
  }
  self.tail = idx;
  const _tmp = self.entries;
  $bound_check(_tmp, idx);
  _tmp[idx] = entry;
  self.size = self.size + 1 | 0;
}
function _M0MPB3Map10set__entryGsbE(self, entry, new_idx) {
  const _tmp = self.entries;
  $bound_check(_tmp, new_idx);
  _tmp[new_idx] = entry;
  const _bind = entry.next;
  if (_bind === undefined) {
    self.tail = new_idx;
    return;
  } else {
    const _Some = _bind;
    const _next = _Some;
    _next.prev = new_idx;
    return;
  }
}
function _M0MPB3Map10set__entryGsRP36mizchi3bit6object8ObjectIdE(self, entry, new_idx) {
  const _tmp = self.entries;
  $bound_check(_tmp, new_idx);
  _tmp[new_idx] = entry;
  const _bind = entry.next;
  if (_bind === undefined) {
    self.tail = new_idx;
    return;
  } else {
    const _Some = _bind;
    const _next = _Some;
    _next.prev = new_idx;
    return;
  }
}
function _M0MPB3Map10push__awayGsbE(self, idx, entry) {
  let _tmp = entry.psl + 1 | 0;
  let _tmp$2 = idx + 1 & self.capacity_mask;
  let _tmp$3 = entry;
  while (true) {
    const psl = _tmp;
    const idx$2 = _tmp$2;
    const entry$2 = _tmp$3;
    const _tmp$4 = self.entries;
    $bound_check(_tmp$4, idx$2);
    const _bind = _tmp$4[idx$2];
    if (_bind === undefined) {
      entry$2.psl = psl;
      _M0MPB3Map10set__entryGsbE(self, entry$2, idx$2);
      return;
    } else {
      const _Some = _bind;
      const _curr_entry = _Some;
      if (psl > _curr_entry.psl) {
        entry$2.psl = psl;
        _M0MPB3Map10set__entryGsbE(self, entry$2, idx$2);
        _tmp = _curr_entry.psl + 1 | 0;
        _tmp$2 = idx$2 + 1 & self.capacity_mask;
        _tmp$3 = _curr_entry;
        continue;
      } else {
        _tmp = psl + 1 | 0;
        _tmp$2 = idx$2 + 1 & self.capacity_mask;
        continue;
      }
    }
  }
}
function _M0MPB3Map10push__awayGsRP36mizchi3bit6object8ObjectIdE(self, idx, entry) {
  let _tmp = entry.psl + 1 | 0;
  let _tmp$2 = idx + 1 & self.capacity_mask;
  let _tmp$3 = entry;
  while (true) {
    const psl = _tmp;
    const idx$2 = _tmp$2;
    const entry$2 = _tmp$3;
    const _tmp$4 = self.entries;
    $bound_check(_tmp$4, idx$2);
    const _bind = _tmp$4[idx$2];
    if (_bind === undefined) {
      entry$2.psl = psl;
      _M0MPB3Map10set__entryGsRP36mizchi3bit6object8ObjectIdE(self, entry$2, idx$2);
      return;
    } else {
      const _Some = _bind;
      const _curr_entry = _Some;
      if (psl > _curr_entry.psl) {
        entry$2.psl = psl;
        _M0MPB3Map10set__entryGsRP36mizchi3bit6object8ObjectIdE(self, entry$2, idx$2);
        _tmp = _curr_entry.psl + 1 | 0;
        _tmp$2 = idx$2 + 1 & self.capacity_mask;
        _tmp$3 = _curr_entry;
        continue;
      } else {
        _tmp = psl + 1 | 0;
        _tmp$2 = idx$2 + 1 & self.capacity_mask;
        continue;
      }
    }
  }
}
function _M0MPB3Map15set__with__hashGsbE(self, key, value, hash) {
  let _tmp = 0;
  let _tmp$2 = hash & self.capacity_mask;
  while (true) {
    const psl = _tmp;
    const idx = _tmp$2;
    const _tmp$3 = self.entries;
    $bound_check(_tmp$3, idx);
    const _bind = _tmp$3[idx];
    if (_bind === undefined) {
      if (self.size >= self.grow_at) {
        _M0MPB3Map4growGsbE(self);
        _tmp = 0;
        _tmp$2 = hash & self.capacity_mask;
        continue;
      }
      const _bind$2 = self.tail;
      const _bind$3 = undefined;
      const entry = new _M0TPB5EntryGsbE(_bind$2, _bind$3, psl, hash, key, value);
      _M0MPB3Map20add__entry__to__tailGsbE(self, idx, entry);
      return undefined;
    } else {
      const _Some = _bind;
      const _curr_entry = _Some;
      if (_curr_entry.hash === hash && _curr_entry.key === key) {
        _curr_entry.value = value;
        return undefined;
      }
      if (psl > _curr_entry.psl) {
        if (self.size >= self.grow_at) {
          _M0MPB3Map4growGsbE(self);
          _tmp = 0;
          _tmp$2 = hash & self.capacity_mask;
          continue;
        }
        _M0MPB3Map10push__awayGsbE(self, idx, _curr_entry);
        const _bind$2 = self.tail;
        const _bind$3 = undefined;
        const entry = new _M0TPB5EntryGsbE(_bind$2, _bind$3, psl, hash, key, value);
        _M0MPB3Map20add__entry__to__tailGsbE(self, idx, entry);
        return undefined;
      }
      _tmp = psl + 1 | 0;
      _tmp$2 = idx + 1 & self.capacity_mask;
      continue;
    }
  }
}
function _M0MPB3Map15set__with__hashGsRP36mizchi3bit6object8ObjectIdE(self, key, value, hash) {
  let _tmp = 0;
  let _tmp$2 = hash & self.capacity_mask;
  while (true) {
    const psl = _tmp;
    const idx = _tmp$2;
    const _tmp$3 = self.entries;
    $bound_check(_tmp$3, idx);
    const _bind = _tmp$3[idx];
    if (_bind === undefined) {
      if (self.size >= self.grow_at) {
        _M0MPB3Map4growGsRP36mizchi3bit6object8ObjectIdE(self);
        _tmp = 0;
        _tmp$2 = hash & self.capacity_mask;
        continue;
      }
      const _bind$2 = self.tail;
      const _bind$3 = undefined;
      const entry = new _M0TPB5EntryGsRP36mizchi3bit6object8ObjectIdE(_bind$2, _bind$3, psl, hash, key, value);
      _M0MPB3Map20add__entry__to__tailGsRP36mizchi3bit6object8ObjectIdE(self, idx, entry);
      return undefined;
    } else {
      const _Some = _bind;
      const _curr_entry = _Some;
      if (_curr_entry.hash === hash && _curr_entry.key === key) {
        _curr_entry.value = value;
        return undefined;
      }
      if (psl > _curr_entry.psl) {
        if (self.size >= self.grow_at) {
          _M0MPB3Map4growGsRP36mizchi3bit6object8ObjectIdE(self);
          _tmp = 0;
          _tmp$2 = hash & self.capacity_mask;
          continue;
        }
        _M0MPB3Map10push__awayGsRP36mizchi3bit6object8ObjectIdE(self, idx, _curr_entry);
        const _bind$2 = self.tail;
        const _bind$3 = undefined;
        const entry = new _M0TPB5EntryGsRP36mizchi3bit6object8ObjectIdE(_bind$2, _bind$3, psl, hash, key, value);
        _M0MPB3Map20add__entry__to__tailGsRP36mizchi3bit6object8ObjectIdE(self, idx, entry);
        return undefined;
      }
      _tmp = psl + 1 | 0;
      _tmp$2 = idx + 1 & self.capacity_mask;
      continue;
    }
  }
}
function _M0MPB3Map15set__with__hashGssE(self, key, value, hash) {
  let _tmp = 0;
  let _tmp$2 = hash & self.capacity_mask;
  while (true) {
    const psl = _tmp;
    const idx = _tmp$2;
    const _tmp$3 = self.entries;
    $bound_check(_tmp$3, idx);
    const _bind = _tmp$3[idx];
    if (_bind === undefined) {
      if (self.size >= self.grow_at) {
        _M0MPB3Map4growGssE(self);
        _tmp = 0;
        _tmp$2 = hash & self.capacity_mask;
        continue;
      }
      const _bind$2 = self.tail;
      const _bind$3 = undefined;
      const entry = new _M0TPB5EntryGssE(_bind$2, _bind$3, psl, hash, key, value);
      _M0MPB3Map20add__entry__to__tailGsRP36mizchi3bit6object8ObjectIdE(self, idx, entry);
      return undefined;
    } else {
      const _Some = _bind;
      const _curr_entry = _Some;
      if (_curr_entry.hash === hash && _curr_entry.key === key) {
        _curr_entry.value = value;
        return undefined;
      }
      if (psl > _curr_entry.psl) {
        if (self.size >= self.grow_at) {
          _M0MPB3Map4growGssE(self);
          _tmp = 0;
          _tmp$2 = hash & self.capacity_mask;
          continue;
        }
        _M0MPB3Map10push__awayGsRP36mizchi3bit6object8ObjectIdE(self, idx, _curr_entry);
        const _bind$2 = self.tail;
        const _bind$3 = undefined;
        const entry = new _M0TPB5EntryGssE(_bind$2, _bind$3, psl, hash, key, value);
        _M0MPB3Map20add__entry__to__tailGsRP36mizchi3bit6object8ObjectIdE(self, idx, entry);
        return undefined;
      }
      _tmp = psl + 1 | 0;
      _tmp$2 = idx + 1 & self.capacity_mask;
      continue;
    }
  }
}
function _M0MPB3Map15set__with__hashGslE(self, key, value, hash) {
  let _tmp = 0;
  let _tmp$2 = hash & self.capacity_mask;
  while (true) {
    const psl = _tmp;
    const idx = _tmp$2;
    const _tmp$3 = self.entries;
    $bound_check(_tmp$3, idx);
    const _bind = _tmp$3[idx];
    if (_bind === undefined) {
      if (self.size >= self.grow_at) {
        _M0MPB3Map4growGslE(self);
        _tmp = 0;
        _tmp$2 = hash & self.capacity_mask;
        continue;
      }
      const _bind$2 = self.tail;
      const _bind$3 = undefined;
      const entry = new _M0TPB5EntryGslE(_bind$2, _bind$3, psl, hash, key, value);
      _M0MPB3Map20add__entry__to__tailGsRP36mizchi3bit6object8ObjectIdE(self, idx, entry);
      return undefined;
    } else {
      const _Some = _bind;
      const _curr_entry = _Some;
      if (_curr_entry.hash === hash && _curr_entry.key === key) {
        _curr_entry.value = value;
        return undefined;
      }
      if (psl > _curr_entry.psl) {
        if (self.size >= self.grow_at) {
          _M0MPB3Map4growGslE(self);
          _tmp = 0;
          _tmp$2 = hash & self.capacity_mask;
          continue;
        }
        _M0MPB3Map10push__awayGsRP36mizchi3bit6object8ObjectIdE(self, idx, _curr_entry);
        const _bind$2 = self.tail;
        const _bind$3 = undefined;
        const entry = new _M0TPB5EntryGslE(_bind$2, _bind$3, psl, hash, key, value);
        _M0MPB3Map20add__entry__to__tailGsRP36mizchi3bit6object8ObjectIdE(self, idx, entry);
        return undefined;
      }
      _tmp = psl + 1 | 0;
      _tmp$2 = idx + 1 & self.capacity_mask;
      continue;
    }
  }
}
function _M0MPB3Map15set__with__hashGszE(self, key, value, hash) {
  let _tmp = 0;
  let _tmp$2 = hash & self.capacity_mask;
  while (true) {
    const psl = _tmp;
    const idx = _tmp$2;
    const _tmp$3 = self.entries;
    $bound_check(_tmp$3, idx);
    const _bind = _tmp$3[idx];
    if (_bind === undefined) {
      if (self.size >= self.grow_at) {
        _M0MPB3Map4growGszE(self);
        _tmp = 0;
        _tmp$2 = hash & self.capacity_mask;
        continue;
      }
      const _bind$2 = self.tail;
      const _bind$3 = undefined;
      const entry = new _M0TPB5EntryGszE(_bind$2, _bind$3, psl, hash, key, value);
      _M0MPB3Map20add__entry__to__tailGsRP36mizchi3bit6object8ObjectIdE(self, idx, entry);
      return undefined;
    } else {
      const _Some = _bind;
      const _curr_entry = _Some;
      if (_curr_entry.hash === hash && _curr_entry.key === key) {
        _curr_entry.value = value;
        return undefined;
      }
      if (psl > _curr_entry.psl) {
        if (self.size >= self.grow_at) {
          _M0MPB3Map4growGszE(self);
          _tmp = 0;
          _tmp$2 = hash & self.capacity_mask;
          continue;
        }
        _M0MPB3Map10push__awayGsRP36mizchi3bit6object8ObjectIdE(self, idx, _curr_entry);
        const _bind$2 = self.tail;
        const _bind$3 = undefined;
        const entry = new _M0TPB5EntryGszE(_bind$2, _bind$3, psl, hash, key, value);
        _M0MPB3Map20add__entry__to__tailGsRP36mizchi3bit6object8ObjectIdE(self, idx, entry);
        return undefined;
      }
      _tmp = psl + 1 | 0;
      _tmp$2 = idx + 1 & self.capacity_mask;
      continue;
    }
  }
}
function _M0MPB3Map4growGsbE(self) {
  const old_head = self.head;
  const new_capacity = self.capacity << 1;
  self.entries = $make_array_len_and_init(new_capacity, undefined);
  self.capacity = new_capacity;
  self.capacity_mask = new_capacity - 1 | 0;
  const _p = self.capacity;
  self.grow_at = (Math.imul(_p, 13) | 0) / 16 | 0;
  self.size = 0;
  self.head = undefined;
  self.tail = -1;
  let _tmp = old_head;
  while (true) {
    const _param = _tmp;
    if (_param === undefined) {
      return;
    } else {
      const _Some = _param;
      const _x = _Some;
      const _next = _x.next;
      const _key = _x.key;
      const _value = _x.value;
      const _hash = _x.hash;
      _M0MPB3Map15set__with__hashGsbE(self, _key, _value, _hash);
      _tmp = _next;
      continue;
    }
  }
}
function _M0MPB3Map4growGsRP36mizchi3bit6object8ObjectIdE(self) {
  const old_head = self.head;
  const new_capacity = self.capacity << 1;
  self.entries = $make_array_len_and_init(new_capacity, undefined);
  self.capacity = new_capacity;
  self.capacity_mask = new_capacity - 1 | 0;
  const _p = self.capacity;
  self.grow_at = (Math.imul(_p, 13) | 0) / 16 | 0;
  self.size = 0;
  self.head = undefined;
  self.tail = -1;
  let _tmp = old_head;
  while (true) {
    const _param = _tmp;
    if (_param === undefined) {
      return;
    } else {
      const _Some = _param;
      const _x = _Some;
      const _next = _x.next;
      const _key = _x.key;
      const _value = _x.value;
      const _hash = _x.hash;
      _M0MPB3Map15set__with__hashGsRP36mizchi3bit6object8ObjectIdE(self, _key, _value, _hash);
      _tmp = _next;
      continue;
    }
  }
}
function _M0MPB3Map4growGssE(self) {
  const old_head = self.head;
  const new_capacity = self.capacity << 1;
  self.entries = $make_array_len_and_init(new_capacity, undefined);
  self.capacity = new_capacity;
  self.capacity_mask = new_capacity - 1 | 0;
  const _p = self.capacity;
  self.grow_at = (Math.imul(_p, 13) | 0) / 16 | 0;
  self.size = 0;
  self.head = undefined;
  self.tail = -1;
  let _tmp = old_head;
  while (true) {
    const _param = _tmp;
    if (_param === undefined) {
      return;
    } else {
      const _Some = _param;
      const _x = _Some;
      const _next = _x.next;
      const _key = _x.key;
      const _value = _x.value;
      const _hash = _x.hash;
      _M0MPB3Map15set__with__hashGssE(self, _key, _value, _hash);
      _tmp = _next;
      continue;
    }
  }
}
function _M0MPB3Map4growGslE(self) {
  const old_head = self.head;
  const new_capacity = self.capacity << 1;
  self.entries = $make_array_len_and_init(new_capacity, undefined);
  self.capacity = new_capacity;
  self.capacity_mask = new_capacity - 1 | 0;
  const _p = self.capacity;
  self.grow_at = (Math.imul(_p, 13) | 0) / 16 | 0;
  self.size = 0;
  self.head = undefined;
  self.tail = -1;
  let _tmp = old_head;
  while (true) {
    const _param = _tmp;
    if (_param === undefined) {
      return;
    } else {
      const _Some = _param;
      const _x = _Some;
      const _next = _x.next;
      const _key = _x.key;
      const _value = _x.value;
      const _hash = _x.hash;
      _M0MPB3Map15set__with__hashGslE(self, _key, _value, _hash);
      _tmp = _next;
      continue;
    }
  }
}
function _M0MPB3Map4growGszE(self) {
  const old_head = self.head;
  const new_capacity = self.capacity << 1;
  self.entries = $make_array_len_and_init(new_capacity, undefined);
  self.capacity = new_capacity;
  self.capacity_mask = new_capacity - 1 | 0;
  const _p = self.capacity;
  self.grow_at = (Math.imul(_p, 13) | 0) / 16 | 0;
  self.size = 0;
  self.head = undefined;
  self.tail = -1;
  let _tmp = old_head;
  while (true) {
    const _param = _tmp;
    if (_param === undefined) {
      return;
    } else {
      const _Some = _param;
      const _x = _Some;
      const _next = _x.next;
      const _key = _x.key;
      const _value = _x.value;
      const _hash = _x.hash;
      _M0MPB3Map15set__with__hashGszE(self, _key, _value, _hash);
      _tmp = _next;
      continue;
    }
  }
}
function _M0MPB3Map3setGsbE(self, key, value) {
  _M0MPB3Map15set__with__hashGsbE(self, key, value, _M0IP016_24default__implPB4Hash4hashGsE(key));
}
function _M0MPB3Map3setGsRP36mizchi3bit6object8ObjectIdE(self, key, value) {
  _M0MPB3Map15set__with__hashGsRP36mizchi3bit6object8ObjectIdE(self, key, value, _M0IP016_24default__implPB4Hash4hashGsE(key));
}
function _M0MPB3Map3setGssE(self, key, value) {
  _M0MPB3Map15set__with__hashGssE(self, key, value, _M0IP016_24default__implPB4Hash4hashGsE(key));
}
function _M0MPB3Map3setGslE(self, key, value) {
  _M0MPB3Map15set__with__hashGslE(self, key, value, _M0IP016_24default__implPB4Hash4hashGsE(key));
}
function _M0MPB3Map3setGszE(self, key, value) {
  _M0MPB3Map15set__with__hashGszE(self, key, value, _M0IP016_24default__implPB4Hash4hashGsE(key));
}
function _M0MPB3Map11from__arrayGsbE(arr) {
  const length = arr.end - arr.start | 0;
  let capacity = _M0MPC13int3Int20next__power__of__two(length);
  const _p = capacity;
  if (length > ((Math.imul(_p, 13) | 0) / 16 | 0)) {
    capacity = Math.imul(capacity, 2) | 0;
  }
  const m = _M0MPB3Map11new_2einnerGsbE(capacity);
  const _bind = arr.end - arr.start | 0;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind) {
      const e = arr.buf[arr.start + _ | 0];
      _M0MPB3Map3setGsbE(m, e._0, e._1);
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return m;
}
function _M0MPB3Map11from__arrayGslE(arr) {
  const length = arr.end - arr.start | 0;
  let capacity = _M0MPC13int3Int20next__power__of__two(length);
  const _p = capacity;
  if (length > ((Math.imul(_p, 13) | 0) / 16 | 0)) {
    capacity = Math.imul(capacity, 2) | 0;
  }
  const m = _M0MPB3Map11new_2einnerGslE(capacity);
  const _bind = arr.end - arr.start | 0;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind) {
      const e = arr.buf[arr.start + _ | 0];
      _M0MPB3Map3setGslE(m, e._0, e._1);
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return m;
}
function _M0MPB3Map11from__arrayGssE(arr) {
  const length = arr.end - arr.start | 0;
  let capacity = _M0MPC13int3Int20next__power__of__two(length);
  const _p = capacity;
  if (length > ((Math.imul(_p, 13) | 0) / 16 | 0)) {
    capacity = Math.imul(capacity, 2) | 0;
  }
  const m = _M0MPB3Map11new_2einnerGslE(capacity);
  const _bind = arr.end - arr.start | 0;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind) {
      const e = arr.buf[arr.start + _ | 0];
      _M0MPB3Map3setGssE(m, e._0, e._1);
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return m;
}
function _M0MPB3Map11from__arrayGszE(arr) {
  const length = arr.end - arr.start | 0;
  let capacity = _M0MPC13int3Int20next__power__of__two(length);
  const _p = capacity;
  if (length > ((Math.imul(_p, 13) | 0) / 16 | 0)) {
    capacity = Math.imul(capacity, 2) | 0;
  }
  const m = _M0MPB3Map11new_2einnerGslE(capacity);
  const _bind = arr.end - arr.start | 0;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind) {
      const e = arr.buf[arr.start + _ | 0];
      _M0MPB3Map3setGszE(m, e._0, e._1);
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return m;
}
function _M0MPB3Map11from__arrayGsRP36mizchi3bit6object8ObjectIdE(arr) {
  const length = arr.end - arr.start | 0;
  let capacity = _M0MPC13int3Int20next__power__of__two(length);
  const _p = capacity;
  if (length > ((Math.imul(_p, 13) | 0) / 16 | 0)) {
    capacity = Math.imul(capacity, 2) | 0;
  }
  const m = _M0MPB3Map11new_2einnerGslE(capacity);
  const _bind = arr.end - arr.start | 0;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind) {
      const e = arr.buf[arr.start + _ | 0];
      _M0MPB3Map3setGsRP36mizchi3bit6object8ObjectIdE(m, e._0, e._1);
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return m;
}
function _M0MPB3Map3getGssE(self, key) {
  const hash = _M0IP016_24default__implPB4Hash4hashGsE(key);
  let _tmp = 0;
  let _tmp$2 = hash & self.capacity_mask;
  while (true) {
    const i = _tmp;
    const idx = _tmp$2;
    const _tmp$3 = self.entries;
    $bound_check(_tmp$3, idx);
    const _bind = _tmp$3[idx];
    if (_bind === undefined) {
      return undefined;
    } else {
      const _Some = _bind;
      const _entry = _Some;
      if (_entry.hash === hash && _entry.key === key) {
        return _entry.value;
      }
      if (i > _entry.psl) {
        return undefined;
      }
      _tmp = i + 1 | 0;
      _tmp$2 = idx + 1 & self.capacity_mask;
      continue;
    }
  }
}
function _M0MPB3Map3getGsRP36mizchi3bit6object8ObjectIdE(self, key) {
  const hash = _M0IP016_24default__implPB4Hash4hashGsE(key);
  let _tmp = 0;
  let _tmp$2 = hash & self.capacity_mask;
  while (true) {
    const i = _tmp;
    const idx = _tmp$2;
    const _tmp$3 = self.entries;
    $bound_check(_tmp$3, idx);
    const _bind = _tmp$3[idx];
    if (_bind === undefined) {
      return undefined;
    } else {
      const _Some = _bind;
      const _entry = _Some;
      if (_entry.hash === hash && _entry.key === key) {
        return _entry.value;
      }
      if (i > _entry.psl) {
        return undefined;
      }
      _tmp = i + 1 | 0;
      _tmp$2 = idx + 1 & self.capacity_mask;
      continue;
    }
  }
}
function _M0MPB3Map3getGslE(self, key) {
  const hash = _M0IP016_24default__implPB4Hash4hashGsE(key);
  let _tmp = 0;
  let _tmp$2 = hash & self.capacity_mask;
  while (true) {
    const i = _tmp;
    const idx = _tmp$2;
    const _tmp$3 = self.entries;
    $bound_check(_tmp$3, idx);
    const _bind = _tmp$3[idx];
    if (_bind === undefined) {
      return undefined;
    } else {
      const _Some = _bind;
      const _entry = _Some;
      if (_entry.hash === hash && _entry.key === key) {
        return _entry.value;
      }
      if (i > _entry.psl) {
        return undefined;
      }
      _tmp = i + 1 | 0;
      _tmp$2 = idx + 1 & self.capacity_mask;
      continue;
    }
  }
}
function _M0MPB3Map3getGszE(self, key) {
  const hash = _M0IP016_24default__implPB4Hash4hashGsE(key);
  let _tmp = 0;
  let _tmp$2 = hash & self.capacity_mask;
  while (true) {
    const i = _tmp;
    const idx = _tmp$2;
    const _tmp$3 = self.entries;
    $bound_check(_tmp$3, idx);
    const _bind = _tmp$3[idx];
    if (_bind === undefined) {
      return undefined;
    } else {
      const _Some = _bind;
      const _entry = _Some;
      if (_entry.hash === hash && _entry.key === key) {
        return _entry.value;
      }
      if (i > _entry.psl) {
        return undefined;
      }
      _tmp = i + 1 | 0;
      _tmp$2 = idx + 1 & self.capacity_mask;
      continue;
    }
  }
}
function _M0MPB3Map8containsGsbE(self, key) {
  const hash = _M0IP016_24default__implPB4Hash4hashGsE(key);
  let _tmp = 0;
  let _tmp$2 = hash & self.capacity_mask;
  while (true) {
    const i = _tmp;
    const idx = _tmp$2;
    const _tmp$3 = self.entries;
    $bound_check(_tmp$3, idx);
    const _bind = _tmp$3[idx];
    if (_bind === undefined) {
      return false;
    } else {
      const _Some = _bind;
      const _entry = _Some;
      if (_entry.hash === hash && _entry.key === key) {
        return true;
      }
      if (i > _entry.psl) {
        return false;
      }
      _tmp = i + 1 | 0;
      _tmp$2 = idx + 1 & self.capacity_mask;
      continue;
    }
  }
}
function _M0MPB3Map13remove__entryGszE(self, entry) {
  const _bind = entry.prev;
  if (_bind === -1) {
    self.head = entry.next;
  } else {
    const _tmp = self.entries;
    $bound_check(_tmp, _bind);
    const _p = _tmp[_bind];
    let _tmp$2;
    if (_p === undefined) {
      _tmp$2 = $panic();
    } else {
      const _p$2 = _p;
      _tmp$2 = _p$2;
    }
    _tmp$2.next = entry.next;
  }
  const _bind$2 = entry.next;
  if (_bind$2 === undefined) {
    self.tail = entry.prev;
    return;
  } else {
    const _Some = _bind$2;
    const _next = _Some;
    _next.prev = entry.prev;
    return;
  }
}
function _M0MPB3Map11shift__backGszE(self, idx) {
  let _tmp = idx;
  while (true) {
    const idx$2 = _tmp;
    const next = idx$2 + 1 & self.capacity_mask;
    _L: {
      const _tmp$2 = self.entries;
      $bound_check(_tmp$2, next);
      const _bind = _tmp$2[next];
      if (_bind === undefined) {
        break _L;
      } else {
        const _Some = _bind;
        const _x = _Some;
        const _x$2 = _x.psl;
        if (_x$2 === 0) {
          break _L;
        } else {
          _x.psl = _x.psl - 1 | 0;
          _M0MPB3Map10set__entryGsRP36mizchi3bit6object8ObjectIdE(self, _x, idx$2);
          _tmp = next;
          continue;
        }
      }
    }
    const _tmp$2 = self.entries;
    $bound_check(_tmp$2, idx$2);
    _tmp$2[idx$2] = undefined;
    return;
  }
}
function _M0MPB3Map18remove__with__hashGszE(self, key, hash) {
  let _tmp = 0;
  let _tmp$2 = hash & self.capacity_mask;
  while (true) {
    const i = _tmp;
    const idx = _tmp$2;
    const _tmp$3 = self.entries;
    $bound_check(_tmp$3, idx);
    const _bind = _tmp$3[idx];
    if (_bind === undefined) {
      return;
    } else {
      const _Some = _bind;
      const _entry = _Some;
      if (_entry.hash === hash && _entry.key === key) {
        _M0MPB3Map13remove__entryGszE(self, _entry);
        _M0MPB3Map11shift__backGszE(self, idx);
        self.size = self.size - 1 | 0;
        return;
      }
      if (i > _entry.psl) {
        return;
      }
      _tmp = i + 1 | 0;
      _tmp$2 = idx + 1 & self.capacity_mask;
      continue;
    }
  }
}
function _M0MPB3Map6removeGszE(self, key) {
  _M0MPB3Map18remove__with__hashGszE(self, key, _M0IP016_24default__implPB4Hash4hashGsE(key));
}
function _M0MPC15array10FixedArray12fill_2einnerGyE(self, value, start, end) {
  const array_length = self.length;
  if (array_length > 0) {
    if (start >= 0 && start < array_length) {
      let length;
      if (end === undefined) {
        length = array_length - start | 0;
      } else {
        const _Some = end;
        const _e = _Some;
        length = _e >= start && _e <= array_length ? _e - start | 0 : $panic();
      }
      self.fill(value, start, start + length);
      return;
    } else {
      $panic();
      return;
    }
  } else {
    return;
  }
}
function _M0MPB3Map9to__arrayGsRP36mizchi3bit6object8ObjectIdE(self) {
  const arr = new Array(self.size);
  let i = 0;
  let _tmp = self.head;
  while (true) {
    const _param = _tmp;
    if (_param === undefined) {
      break;
    } else {
      const _Some = _param;
      const _x = _Some;
      const _key = _x.key;
      const _value = _x.value;
      const _next = _x.next;
      arr[i] = { _0: _key, _1: _value };
      i = i + 1 | 0;
      _tmp = _next;
      continue;
    }
  }
  return arr;
}
function _M0MPB7MyInt6414extend__i32__u(value) {
  return new _M0TPB7MyInt64(0, value);
}
function _M0MPC16uint646UInt6412extend__uint(value) {
  return _M0MPB7MyInt6414extend__i32__u(value);
}
function _M0MPC14uint4UInt10to__uint64(self) {
  return _M0MPC16uint646UInt6412extend__uint(self);
}
function _M0MPB4Iter4takeGjE(self, n) {
  const remaining = new _M0TPB8MutLocalGiE(n);
  return () => {
    if (remaining.val > 0) {
      const result = _M0MPB4Iter4nextGjE(self);
      if (result === undefined) {
      } else {
        remaining.val = remaining.val - 1 | 0;
      }
      return result;
    } else {
      return undefined;
    }
  };
}
function _M0MPB5Iter24nextGicE(self) {
  return _M0MPB4Iter4nextGRPC16string10StringViewE(self);
}
function _M0MPC14byte4Byte9to__int64(self) {
  return _M0MPC13int3Int9to__int64(self);
}
function _M0MPB7MyInt6411add__hi__lo(self, bhi, blo) {
  const _ahi = self.hi;
  const _alo = self.lo;
  const lo = _alo + blo | 0;
  const s = lo >> 31;
  const as_ = _alo >> 31;
  const bs = blo >> 31;
  const c = (as_ & bs | ~s & (as_ ^ bs)) & 1;
  const hi = (_ahi + bhi | 0) + c | 0;
  return new _M0TPB7MyInt64(hi, lo);
}
function _M0IPB7MyInt64PB3Add3add(self, other) {
  return _M0MPB7MyInt6411add__hi__lo(self, other.hi, other.lo);
}
function _M0IPB7MyInt64PB3Sub3sub(self, other) {
  return other.lo === 0 ? new _M0TPB7MyInt64(self.hi - other.hi | 0, self.lo) : _M0MPB7MyInt6411add__hi__lo(self, ~other.hi, ~other.lo + 1 | 0);
}
function _M0IPB7MyInt64PB3Mul3mul(self, other) {
  const _ahi = self.hi;
  const _alo = self.lo;
  const _bhi = other.hi;
  const _blo = other.lo;
  const ahi = _ahi;
  const alo = _alo;
  const bhi = _bhi;
  const blo = _blo;
  const a48 = ahi >>> 16 | 0;
  const a32 = ahi & 65535;
  const a16 = alo >>> 16 | 0;
  const a00 = alo & 65535;
  const b48 = bhi >>> 16 | 0;
  const b32 = bhi & 65535;
  const b16 = blo >>> 16 | 0;
  const b00 = blo & 65535;
  const c00 = Math.imul(a00, b00) | 0;
  const c16 = c00 >>> 16 | 0;
  const c00$2 = c00 & 65535;
  const c16$2 = (c16 >>> 0) + ((Math.imul(a16, b00) | 0) >>> 0) | 0;
  const c32 = c16$2 >>> 16 | 0;
  const c16$3 = c16$2 & 65535;
  const c16$4 = (c16$3 >>> 0) + ((Math.imul(a00, b16) | 0) >>> 0) | 0;
  const c32$2 = (c32 >>> 0) + ((c16$4 >>> 16 | 0) >>> 0) | 0;
  const c16$5 = c16$4 & 65535;
  const c32$3 = (c32$2 >>> 0) + ((Math.imul(a32, b00) | 0) >>> 0) | 0;
  const c48 = c32$3 >>> 16 | 0;
  const c32$4 = c32$3 & 65535;
  const c32$5 = (c32$4 >>> 0) + ((Math.imul(a16, b16) | 0) >>> 0) | 0;
  const c48$2 = (c48 >>> 0) + ((c32$5 >>> 16 | 0) >>> 0) | 0;
  const c32$6 = c32$5 & 65535;
  const c32$7 = (c32$6 >>> 0) + ((Math.imul(a00, b32) | 0) >>> 0) | 0;
  const c48$3 = (c48$2 >>> 0) + ((c32$7 >>> 16 | 0) >>> 0) | 0;
  const c32$8 = c32$7 & 65535;
  const c48$4 = (((((((c48$3 >>> 0) + ((Math.imul(a48, b00) | 0) >>> 0) | 0) >>> 0) + ((Math.imul(a32, b16) | 0) >>> 0) | 0) >>> 0) + ((Math.imul(a16, b32) | 0) >>> 0) | 0) >>> 0) + ((Math.imul(a00, b48) | 0) >>> 0) | 0;
  const c48$5 = c48$4 & 65535;
  return new _M0TPB7MyInt64(c48$5 << 16 | c32$8, c16$5 << 16 | c00$2);
}
function _M0FPB29try__get__int64__wasm__helper() {
  if (_M0FPB19wasm__helper__cache.tried) {
    const _bind = _M0FPB19wasm__helper__cache.exports;
    return !(_bind === undefined);
  }
  _M0FPB19wasm__helper__cache.tried = true;
  _M0FPB19wasm__helper__cache.exports = _M0FPB23try__init__wasm__helper();
  const _bind = _M0FPB19wasm__helper__cache.exports;
  return !(_bind === undefined);
}
function _M0IPB7MyInt64PB3Div3div(self, other) {
  if (!(other.hi === 0 && other.lo === 0)) {
    if (!_M0FPB29try__get__int64__wasm__helper()) {
      return _M0MPB7MyInt6411div__bigint(self, other);
    }
    const _bind = _M0FPB19wasm__helper__cache.exports;
    if (_bind === undefined) {
      return $panic();
    } else {
      const _Some = _bind;
      const _exports = _Some;
      const _ahi = self.hi;
      const _alo = self.lo;
      const _bhi = other.hi;
      const _blo = other.lo;
      const _func = _exports.div_s;
      const lo = _func(_alo, _ahi, _blo, _bhi);
      const _func$2 = _exports.get_high;
      const hi = _func$2();
      return new _M0TPB7MyInt64(hi, lo);
    }
  } else {
    return $panic();
  }
}
function _M0MPB7MyInt644land(self, other) {
  return new _M0TPB7MyInt64(self.hi & other.hi, self.lo & other.lo);
}
function _M0MPB7MyInt643lor(self, other) {
  return new _M0TPB7MyInt64(self.hi | other.hi, self.lo | other.lo);
}
function _M0MPB7MyInt643lsl(self, shift) {
  const shift$2 = shift & 63;
  if (shift$2 === 0) {
    return self;
  } else {
    if (shift$2 < 32) {
      const _hi = self.hi;
      const _lo = self.lo;
      const hi = _hi;
      const lo = _lo;
      const hi$2 = hi << shift$2 | (lo >>> (32 - shift$2 | 0) | 0);
      const lo$2 = lo << shift$2;
      return new _M0TPB7MyInt64(hi$2, lo$2);
    } else {
      return new _M0TPB7MyInt64(self.lo << (shift$2 - 32 | 0), 0);
    }
  }
}
function _M0MPB7MyInt643lsr(self, shift) {
  const shift$2 = shift & 63;
  return shift$2 === 0 ? self : shift$2 < 32 ? new _M0TPB7MyInt64(self.hi >>> shift$2 | 0, self.lo >>> shift$2 | self.hi << (32 - shift$2 | 0)) : new _M0TPB7MyInt64(0, self.hi >>> (shift$2 - 32 | 0) | 0);
}
function _M0MPB7MyInt643asr(self, shift) {
  const shift$2 = shift & 63;
  return shift$2 === 0 ? self : shift$2 < 32 ? new _M0TPB7MyInt64(self.hi >> shift$2, self.lo >>> shift$2 | self.hi << (32 - shift$2 | 0)) : new _M0TPB7MyInt64(self.hi >> 31, self.hi >> (shift$2 - 32 | 0));
}
function _M0IPC15int645Int64PB3Add3add(self, other) {
  return _M0IPB7MyInt64PB3Add3add(self, other);
}
function _M0IPC15int645Int64PB3Sub3sub(self, other) {
  return _M0IPB7MyInt64PB3Sub3sub(self, other);
}
function _M0IPC15int645Int64PB3Mul3mul(self, other) {
  return _M0IPB7MyInt64PB3Mul3mul(self, other);
}
function _M0IPC15int645Int64PB3Div3div(self, other) {
  return _M0IPB7MyInt64PB3Div3div(self, other);
}
function _M0IPC15int645Int64PB6BitAnd4land(self, other) {
  return _M0MPB7MyInt644land(self, other);
}
function _M0IPC15int645Int64PB5BitOr3lor(self, other) {
  return _M0MPB7MyInt643lor(self, other);
}
function _M0IPC15int645Int64PB3Shr3shr(self, other) {
  return _M0MPB7MyInt643asr(self, other);
}
function _M0IPC15int645Int64PB3Shl3shl(self, other) {
  return _M0MPB7MyInt643lsl(self, other);
}
function _M0IPC15int645Int64PB2Eq5equal(self, other) {
  const _p = self;
  const _p$2 = other;
  return _p.hi === _p$2.hi && _p.lo === _p$2.lo;
}
function _M0IPC15int645Int64PB7Compare7compare(self, other) {
  return _M0MPB7MyInt647compare(self, other);
}
function _M0MPC15int645Int647to__int(self) {
  const _p = self;
  return _p.lo;
}
function _M0MPC15int645Int648to__byte(self) {
  const _p = self;
  return _p.lo & 255;
}
function _M0IPC16uint646UInt64PB3Add3add(self, other) {
  return _M0IPB7MyInt64PB3Add3add(self, other);
}
function _M0IPC16uint646UInt64PB3Sub3sub(self, other) {
  return _M0IPB7MyInt64PB3Sub3sub(self, other);
}
function _M0IPC16uint646UInt64PB3Mul3mul(self, other) {
  return _M0IPB7MyInt64PB3Mul3mul(self, other);
}
function _M0IPC16uint646UInt64PB7Compare7compare(self, other) {
  return _M0MPB7MyInt6410compare__u(self, other);
}
function _M0IPC16uint646UInt64PB6BitAnd4land(self, other) {
  return _M0MPB7MyInt644land(self, other);
}
function _M0IPC16uint646UInt64PB5BitOr3lor(self, other) {
  return _M0MPB7MyInt643lor(self, other);
}
function _M0IPC16uint646UInt64PB3Shl3shl(self, shift) {
  return _M0MPB7MyInt643lsl(self, shift);
}
function _M0IPC16uint646UInt64PB3Shr3shr(self, shift) {
  return _M0MPB7MyInt643lsr(self, shift);
}
function _M0MPB6Hasher15combine__string(self, value) {
  const _bind = value.length;
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < _bind) {
      _M0MPB6Hasher13combine__uint(self, value.charCodeAt(i));
      _tmp = i + 1 | 0;
      continue;
    } else {
      return;
    }
  }
}
function _M0IPC16string6StringPB4Hash13hash__combine(self, hasher) {
  _M0MPB6Hasher15combine__string(hasher, self);
}
function _M0MPC15array10FixedArray16blit__to_2einnerGyE(self, dst, len, src_offset, dst_offset) {
  if (dst_offset >= 0 && (src_offset >= 0 && ((dst_offset + len | 0) <= dst.length && (src_offset + len | 0) <= self.length))) {
    _M0MPC15array10FixedArray12unsafe__blitGyE(dst, dst_offset, self, src_offset, len);
    return;
  } else {
    _M0FPB5abortGuE(`bounds check failed: dst_offset = ${_M0IP016_24default__implPB4Show10to__stringGiE(dst_offset)}, src_offset = ${_M0IP016_24default__implPB4Show10to__stringGiE(src_offset)}, len = ${_M0IP016_24default__implPB4Show10to__stringGiE(len)}, dst.length = ${_M0IP016_24default__implPB4Show10to__stringGiE(dst.length)}, self.length = ${_M0IP016_24default__implPB4Show10to__stringGiE(self.length)}`, "builtin/fixedarray_block.mbt:115:5-117:6@moonbitlang/core");
    return;
  }
}
function _M0MPC15array10FixedArray4copyGjE(self) {
  return _M0MPB7JSArray4copy(self);
}
function _M0MPC16double6Double9to__int64(self) {
  return _M0MPB7MyInt6412from__double(self);
}
function _M0MPC15bytes5Bytes5makei(length, value) {
  if (length <= 0) {
    return $bytes_literal$0;
  }
  const arr = $makebytes(length, value(0));
  let _tmp = 1;
  while (true) {
    const i = _tmp;
    if (i < length) {
      $bound_check(arr, i);
      arr[i] = value(i);
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return arr;
}
function _M0MPC15bytes5Bytes12view_2einner(self, start, end) {
  const len = self.length;
  let end$2;
  if (end === undefined) {
    end$2 = len;
  } else {
    const _Some = end;
    const _end = _Some;
    end$2 = _end < 0 ? len + _end | 0 : _end;
  }
  const start$2 = start < 0 ? len + start | 0 : start;
  if (start$2 >= 0 && (start$2 <= end$2 && end$2 <= len)) {
    const _bind = end$2 - start$2 | 0;
    return new _M0TPC15bytes9BytesView(self, start$2, start$2 + _bind | 0);
  } else {
    return _M0FPB5abortGRPC16string10StringViewE("Invalid index for View", "builtin/bytesview.mbt:180:5-180:36@moonbitlang/core");
  }
}
function _M0MPC15array10FixedArray17blit__from__bytes(self, bytes_offset, src, src_offset, length) {
  const e1 = (bytes_offset + length | 0) - 1 | 0;
  const e2 = (src_offset + length | 0) - 1 | 0;
  const len1 = self.length;
  const len2 = src.length;
  if (length >= 0 && (bytes_offset >= 0 && (e1 < len1 && (src_offset >= 0 && e2 < len2)))) {
    _M0MPC15array10FixedArray12unsafe__blitGyE(self, bytes_offset, src, src_offset, length);
    return;
  } else {
    $panic();
    return;
  }
}
function _M0MPC14byte4Byte10to__uint64(self) {
  return _M0MPC14uint4UInt10to__uint64(self);
}
function _M0MPC15bytes5Bytes11from__array(arr) {
  return _M0MPC15bytes5Bytes5makei(arr.end - arr.start | 0, (i) => _M0MPC15array9ArrayView2atGyE(arr, i));
}
function _M0MPC15bytes5Bytes10from__iter(iter) {
  const _bind = _M0MPB4Iter9to__arrayGyE(iter);
  return _M0MPC15bytes5Bytes11from__array(new _M0TPB9ArrayViewGyE(_bind, 0, _bind.length));
}
function _M0MPC15bytes5Bytes9to__array(self) {
  const len = self.length;
  const rv = _M0MPC15array5Array4makeGyE(len, 48);
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < len) {
      $bound_check(self, i);
      _M0MPC15array5Array3setGyE(rv, i, self[i]);
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return rv;
}
function _M0MPC15array9ArrayView4joinGsE(self, separator) {
  if ((self.end - self.start | 0) === 0) {
    return "";
  } else {
    const _hd = self.buf[self.start];
    const _x_buf = self.buf;
    const _x_start = 1 + self.start | 0;
    const _x_end = self.end;
    const hd = _M0IPC16string6StringPB12ToStringView16to__string__view(_hd);
    const _bind = _x_end - _x_start | 0;
    let size_hint;
    let _tmp = 0;
    let _tmp$2 = hd.end - hd.start | 0;
    while (true) {
      const _ = _tmp;
      const size_hint$2 = _tmp$2;
      if (_ < _bind) {
        const s = _x_buf[_x_start + _ | 0];
        _tmp = _ + 1 | 0;
        const _p = _M0IPC16string6StringPB12ToStringView16to__string__view(s);
        _tmp$2 = (size_hint$2 + (_p.end - _p.start | 0) | 0) + (separator.end - separator.start | 0) | 0;
        continue;
      } else {
        size_hint = size_hint$2;
        break;
      }
    }
    const size_hint$2 = size_hint << 1;
    const buf = _M0MPB13StringBuilder11new_2einner(size_hint$2);
    _M0IPB13StringBuilderPB6Logger11write__view(buf, hd);
    if (_M0MPC16string6String24char__length__eq_2einner(separator.str, 0, separator.start, separator.end)) {
      const _bind$2 = _x_end - _x_start | 0;
      let _tmp$3 = 0;
      while (true) {
        const _ = _tmp$3;
        if (_ < _bind$2) {
          const s = _x_buf[_x_start + _ | 0];
          const s$2 = _M0IPC16string6StringPB12ToStringView16to__string__view(s);
          _M0IPB13StringBuilderPB6Logger11write__view(buf, s$2);
          _tmp$3 = _ + 1 | 0;
          continue;
        } else {
          break;
        }
      }
    } else {
      const _bind$2 = _x_end - _x_start | 0;
      let _tmp$3 = 0;
      while (true) {
        const _ = _tmp$3;
        if (_ < _bind$2) {
          const s = _x_buf[_x_start + _ | 0];
          const s$2 = _M0IPC16string6StringPB12ToStringView16to__string__view(s);
          _M0IPB13StringBuilderPB6Logger11write__view(buf, separator);
          _M0IPB13StringBuilderPB6Logger11write__view(buf, s$2);
          _tmp$3 = _ + 1 | 0;
          continue;
        } else {
          break;
        }
      }
    }
    return buf.val;
  }
}
function _M0MPC15array5Array11unsafe__popGsE(self) {
  return _M0MPB7JSArray3pop(self);
}
function _M0MPC15array5Array3popGsE(self) {
  if (self.length === 0) {
    return undefined;
  } else {
    const v = _M0MPC15array5Array11unsafe__popGsE(self);
    return v;
  }
}
function _M0MPC15array5Array6removeGsE(self, index) {
  if (index >= 0 && index < self.length) {
    $bound_check(self, index);
    const value = self[index];
    _M0MPB7JSArray6splice(self, index, 1);
    return value;
  } else {
    return _M0FPB5abortGRPC16string10StringViewE(`index out of bounds: the len is from 0 to ${_M0IP016_24default__implPB4Show10to__stringGiE(self.length)} but the index is ${_M0IP016_24default__implPB4Show10to__stringGiE(index)}`, "builtin/arraycore_js.mbt:251:5-253:6@moonbitlang/core");
  }
}
function _M0MPC15array5Array6removeGiE(self, index) {
  if (index >= 0 && index < self.length) {
    $bound_check(self, index);
    const value = self[index];
    _M0MPB7JSArray6splice(self, index, 1);
    return value;
  } else {
    return _M0FPB5abortGiE(`index out of bounds: the len is from 0 to ${_M0IP016_24default__implPB4Show10to__stringGiE(self.length)} but the index is ${_M0IP016_24default__implPB4Show10to__stringGiE(index)}`, "builtin/arraycore_js.mbt:251:5-253:6@moonbitlang/core");
  }
}
function _M0MPC15array5Array24unsafe__grow__to__lengthGyE(self, new_len) {
  if (new_len >= self.length) {
    _M0MPB7JSArray11set__length(self, new_len);
    return;
  } else {
    $panic();
    return;
  }
}
function _M0MPC15array5Array2atGUiiEE(self, index) {
  const len = self.length;
  if (index >= 0 && index < len) {
    $bound_check(self, index);
    return self[index];
  } else {
    return $panic();
  }
}
function _M0MPC15array5Array2atGcE(self, index) {
  const len = self.length;
  if (index >= 0 && index < len) {
    $bound_check(self, index);
    return self[index];
  } else {
    return $panic();
  }
}
function _M0MPC15array5Array2atGiE(self, index) {
  const len = self.length;
  if (index >= 0 && index < len) {
    $bound_check(self, index);
    return self[index];
  } else {
    return $panic();
  }
}
function _M0MPC15array5Array2atGyE(self, index) {
  const len = self.length;
  if (index >= 0 && index < len) {
    $bound_check(self, index);
    return self[index];
  } else {
    return $panic();
  }
}
function _M0MPC15array12MutArrayView4swapGRP46mizchi3bit1x3hub12IssueCommentE(arr, i, j) {
  const temp = _M0MPC15array12MutArrayView2atGRP46mizchi3bit1x3hub12IssueCommentE(arr, i);
  _M0MPC15array12MutArrayView3setGRP46mizchi3bit1x3hub12IssueCommentE(arr, i, _M0MPC15array12MutArrayView2atGRP46mizchi3bit1x3hub12IssueCommentE(arr, j));
  _M0MPC15array12MutArrayView3setGRP46mizchi3bit1x3hub12IssueCommentE(arr, j, temp);
}
function _M0MPC15array12MutArrayView5sliceGRP46mizchi3bit1x3hub12IssueCommentE(arr, start, end) {
  return _M0MPC15array12MutArrayView17mut__view_2einnerGRP46mizchi3bit1x3hub12IssueCommentE(arr, start, end);
}
function _M0MPC15array12MutArrayView14rev__in__placeGRP46mizchi3bit1x3hub12IssueCommentE(arr) {
  const len = arr.end - arr.start | 0;
  const mid_len = len / 2 | 0;
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < mid_len) {
      const j = (len - i | 0) - 1 | 0;
      const temp = _M0MPC15array12MutArrayView2atGRP46mizchi3bit1x3hub12IssueCommentE(arr, i);
      _M0MPC15array12MutArrayView3setGRP46mizchi3bit1x3hub12IssueCommentE(arr, i, _M0MPC15array12MutArrayView2atGRP46mizchi3bit1x3hub12IssueCommentE(arr, j));
      _M0MPC15array12MutArrayView3setGRP46mizchi3bit1x3hub12IssueCommentE(arr, j, temp);
      _tmp = i + 1 | 0;
      continue;
    } else {
      return;
    }
  }
}
function _M0FPB17fixed__get__limit(len) {
  let _tmp = len;
  let _tmp$2 = 0;
  while (true) {
    const len$2 = _tmp;
    const limit = _tmp$2;
    if (len$2 > 0) {
      _tmp = len$2 / 2 | 0;
      _tmp$2 = limit + 1 | 0;
      continue;
    } else {
      return limit;
    }
  }
}
function _M0FPB23fixed__bubble__sort__byGRP46mizchi3bit1x3hub12IssueCommentE(arr, cmp) {
  const _bind = arr.end - arr.start | 0;
  let _tmp = 1;
  while (true) {
    const i = _tmp;
    if (i < _bind) {
      let _tmp$2 = i;
      while (true) {
        const j = _tmp$2;
        if (j > 0 && cmp(_M0MPC15array12MutArrayView2atGRP46mizchi3bit1x3hub12IssueCommentE(arr, j - 1 | 0), _M0MPC15array12MutArrayView2atGRP46mizchi3bit1x3hub12IssueCommentE(arr, j)) > 0) {
          _M0MPC15array12MutArrayView4swapGRP46mizchi3bit1x3hub12IssueCommentE(arr, j, j - 1 | 0);
          _tmp$2 = j - 1 | 0;
          continue;
        } else {
          break;
        }
      }
      _tmp = i + 1 | 0;
      continue;
    } else {
      return;
    }
  }
}
function _M0FPB41fixed__choose__pivot__by_2esort__2_2f1557(_env, a, b) {
  const swaps = _env._2;
  const cmp = _env._1;
  const arr = _env._0;
  if (cmp(_M0MPC15array12MutArrayView2atGRP46mizchi3bit1x3hub12IssueCommentE(arr, a), _M0MPC15array12MutArrayView2atGRP46mizchi3bit1x3hub12IssueCommentE(arr, b)) > 0) {
    _M0MPC15array12MutArrayView4swapGRP46mizchi3bit1x3hub12IssueCommentE(arr, a, b);
    swaps.val = swaps.val + 1 | 0;
    return;
  } else {
    return;
  }
}
function _M0FPB41fixed__choose__pivot__by_2esort__3_2f1558(_env, a, b, c) {
  _M0FPB41fixed__choose__pivot__by_2esort__2_2f1557(_env, a, b);
  _M0FPB41fixed__choose__pivot__by_2esort__2_2f1557(_env, b, c);
  _M0FPB41fixed__choose__pivot__by_2esort__2_2f1557(_env, a, b);
}
function _M0FPB24fixed__choose__pivot__byGRP46mizchi3bit1x3hub12IssueCommentE(arr, cmp) {
  const len = arr.end - arr.start | 0;
  const swaps = new _M0TPB8MutLocalGiE(0);
  const b = Math.imul(len / 4 | 0, 2) | 0;
  if (len >= 8) {
    const a = Math.imul(len / 4 | 0, 1) | 0;
    const c = Math.imul(len / 4 | 0, 3) | 0;
    const _env = { _0: arr, _1: cmp, _2: swaps };
    if (len > 50) {
      _M0FPB41fixed__choose__pivot__by_2esort__3_2f1558(_env, a - 1 | 0, a, a + 1 | 0);
      _M0FPB41fixed__choose__pivot__by_2esort__3_2f1558(_env, b - 1 | 0, b, b + 1 | 0);
      _M0FPB41fixed__choose__pivot__by_2esort__3_2f1558(_env, c - 1 | 0, c, c + 1 | 0);
    }
    _M0FPB41fixed__choose__pivot__by_2esort__3_2f1558(_env, a, b, c);
  }
  if (swaps.val === 12) {
    _M0MPC15array12MutArrayView14rev__in__placeGRP46mizchi3bit1x3hub12IssueCommentE(arr);
    return { _0: (len - b | 0) - 1 | 0, _1: true };
  } else {
    return { _0: b, _1: swaps.val === 0 };
  }
}
function _M0FPB21fixed__sift__down__byGRP46mizchi3bit1x3hub12IssueCommentE(arr, index, cmp) {
  const len = arr.end - arr.start | 0;
  let _tmp = index;
  let _tmp$2 = (Math.imul(index, 2) | 0) + 1 | 0;
  while (true) {
    const index$2 = _tmp;
    const child = _tmp$2;
    if (child < len) {
      const child$2 = (child + 1 | 0) < len && cmp(_M0MPC15array12MutArrayView2atGRP46mizchi3bit1x3hub12IssueCommentE(arr, child), _M0MPC15array12MutArrayView2atGRP46mizchi3bit1x3hub12IssueCommentE(arr, child + 1 | 0)) < 0 ? child + 1 | 0 : child;
      if (cmp(_M0MPC15array12MutArrayView2atGRP46mizchi3bit1x3hub12IssueCommentE(arr, index$2), _M0MPC15array12MutArrayView2atGRP46mizchi3bit1x3hub12IssueCommentE(arr, child$2)) >= 0) {
        return undefined;
      }
      _M0MPC15array12MutArrayView4swapGRP46mizchi3bit1x3hub12IssueCommentE(arr, index$2, child$2);
      _tmp = child$2;
      _tmp$2 = (Math.imul(child$2, 2) | 0) + 1 | 0;
      continue;
    } else {
      return;
    }
  }
}
function _M0FPB21fixed__heap__sort__byGRP46mizchi3bit1x3hub12IssueCommentE(arr, cmp) {
  const len = arr.end - arr.start | 0;
  const _bind = len / 2 | 0;
  let _tmp = _bind - 1 | 0;
  while (true) {
    const i = _tmp;
    if (i >= 0) {
      _M0FPB21fixed__sift__down__byGRP46mizchi3bit1x3hub12IssueCommentE(arr, i, cmp);
      _tmp = i - 1 | 0;
      continue;
    } else {
      break;
    }
  }
  let _tmp$2 = len - 1 | 0;
  while (true) {
    const i = _tmp$2;
    if (i >= 1) {
      _M0MPC15array12MutArrayView4swapGRP46mizchi3bit1x3hub12IssueCommentE(arr, 0, i);
      _M0FPB21fixed__sift__down__byGRP46mizchi3bit1x3hub12IssueCommentE(_M0MPC15array12MutArrayView5sliceGRP46mizchi3bit1x3hub12IssueCommentE(arr, 0, i), 0, cmp);
      _tmp$2 = i - 1 | 0;
      continue;
    } else {
      return;
    }
  }
}
function _M0FPB20fixed__partition__byGRP46mizchi3bit1x3hub12IssueCommentE(arr, cmp, pivot_index) {
  _M0MPC15array12MutArrayView4swapGRP46mizchi3bit1x3hub12IssueCommentE(arr, pivot_index, (arr.end - arr.start | 0) - 1 | 0);
  const pivot = _M0MPC15array12MutArrayView2atGRP46mizchi3bit1x3hub12IssueCommentE(arr, (arr.end - arr.start | 0) - 1 | 0);
  const _bind = (arr.end - arr.start | 0) - 1 | 0;
  let _tmp = 0;
  let _tmp$2 = 0;
  let _tmp$3 = true;
  while (true) {
    const j = _tmp;
    const i = _tmp$2;
    const partitioned = _tmp$3;
    if (j < _bind) {
      if (cmp(_M0MPC15array12MutArrayView2atGRP46mizchi3bit1x3hub12IssueCommentE(arr, j), pivot) < 0) {
        if (i !== j) {
          _M0MPC15array12MutArrayView4swapGRP46mizchi3bit1x3hub12IssueCommentE(arr, i, j);
          _tmp = j + 1 | 0;
          _tmp$2 = i + 1 | 0;
          _tmp$3 = false;
          continue;
        } else {
          _tmp = j + 1 | 0;
          _tmp$2 = i + 1 | 0;
          continue;
        }
      } else {
        _tmp = j + 1 | 0;
        continue;
      }
    } else {
      _M0MPC15array12MutArrayView4swapGRP46mizchi3bit1x3hub12IssueCommentE(arr, i, (arr.end - arr.start | 0) - 1 | 0);
      return { _0: i, _1: partitioned };
    }
  }
}
function _M0FPB28fixed__try__bubble__sort__byGRP46mizchi3bit1x3hub12IssueCommentE(arr, cmp) {
  const _bind = arr.end - arr.start | 0;
  let _tmp = 1;
  let _tmp$2 = 0;
  while (true) {
    const i = _tmp;
    const tries = _tmp$2;
    if (i < _bind) {
      let sorted;
      let _tmp$3 = i;
      let _tmp$4 = true;
      while (true) {
        const j = _tmp$3;
        const sorted$2 = _tmp$4;
        if (j > 0 && cmp(_M0MPC15array12MutArrayView2atGRP46mizchi3bit1x3hub12IssueCommentE(arr, j - 1 | 0), _M0MPC15array12MutArrayView2atGRP46mizchi3bit1x3hub12IssueCommentE(arr, j)) > 0) {
          _M0MPC15array12MutArrayView4swapGRP46mizchi3bit1x3hub12IssueCommentE(arr, j, j - 1 | 0);
          _tmp$3 = j - 1 | 0;
          _tmp$4 = false;
          continue;
        } else {
          sorted = sorted$2;
          break;
        }
      }
      if (!sorted) {
        const tries$2 = tries + 1 | 0;
        if (tries$2 > 8) {
          return false;
        }
        _tmp = i + 1 | 0;
        _tmp$2 = tries$2;
        continue;
      } else {
        _tmp = i + 1 | 0;
        continue;
      }
    } else {
      return true;
    }
  }
}
function _M0FPB22fixed__quick__sort__byGRP46mizchi3bit1x3hub12IssueCommentE(arr, cmp, pred, limit) {
  let _tmp = limit;
  let _tmp$2 = arr;
  let _tmp$3 = pred;
  let _tmp$4 = true;
  let _tmp$5 = true;
  while (true) {
    const limit$2 = _tmp;
    const arr$2 = _tmp$2;
    const pred$2 = _tmp$3;
    const was_partitioned = _tmp$4;
    const balanced = _tmp$5;
    const len = arr$2.end - arr$2.start | 0;
    if (len <= 16) {
      if (len >= 2) {
        _M0FPB23fixed__bubble__sort__byGRP46mizchi3bit1x3hub12IssueCommentE(arr$2, cmp);
      }
      return undefined;
    }
    if (limit$2 === 0) {
      _M0FPB21fixed__heap__sort__byGRP46mizchi3bit1x3hub12IssueCommentE(arr$2, cmp);
      return undefined;
    }
    const _bind = _M0FPB24fixed__choose__pivot__byGRP46mizchi3bit1x3hub12IssueCommentE(arr$2, cmp);
    const _pivot_index = _bind._0;
    const _likely_sorted = _bind._1;
    if (was_partitioned && (balanced && _likely_sorted)) {
      if (_M0FPB28fixed__try__bubble__sort__byGRP46mizchi3bit1x3hub12IssueCommentE(arr$2, cmp)) {
        return undefined;
      }
    }
    const _bind$2 = _M0FPB20fixed__partition__byGRP46mizchi3bit1x3hub12IssueCommentE(arr$2, cmp, _pivot_index);
    const _pivot = _bind$2._0;
    const _partitioned = _bind$2._1;
    const _p = len - _pivot | 0;
    const balanced$2 = (_pivot > _p ? _p : _pivot) >= (len / 8 | 0);
    const limit$3 = !balanced$2 ? limit$2 - 1 | 0 : limit$2;
    if (pred$2 === undefined) {
    } else {
      const _Some = pred$2;
      const _p$2 = _Some;
      if (cmp(_p$2, _M0MPC15array12MutArrayView2atGRP46mizchi3bit1x3hub12IssueCommentE(arr$2, _pivot)) === 0) {
        let i;
        let _tmp$6 = _pivot;
        while (true) {
          const i$2 = _tmp$6;
          if (i$2 < len && cmp(_p$2, _M0MPC15array12MutArrayView2atGRP46mizchi3bit1x3hub12IssueCommentE(arr$2, i$2)) === 0) {
            _tmp$6 = i$2 + 1 | 0;
            continue;
          } else {
            i = i$2;
            break;
          }
        }
        _tmp = limit$3;
        _tmp$2 = _M0MPC15array12MutArrayView5sliceGRP46mizchi3bit1x3hub12IssueCommentE(arr$2, i, len);
        _tmp$4 = _partitioned;
        _tmp$5 = balanced$2;
        continue;
      }
    }
    const left = _M0MPC15array12MutArrayView5sliceGRP46mizchi3bit1x3hub12IssueCommentE(arr$2, 0, _pivot);
    const right = _M0MPC15array12MutArrayView5sliceGRP46mizchi3bit1x3hub12IssueCommentE(arr$2, _pivot + 1 | 0, len);
    if ((left.end - left.start | 0) < (right.end - right.start | 0)) {
      _M0FPB22fixed__quick__sort__byGRP46mizchi3bit1x3hub12IssueCommentE(left, cmp, pred$2, limit$3);
      _tmp = limit$3;
      _tmp$2 = right;
      _tmp$3 = _M0MPC15array12MutArrayView2atGRP46mizchi3bit1x3hub12IssueCommentE(arr$2, _pivot);
      _tmp$4 = _partitioned;
      _tmp$5 = balanced$2;
      continue;
    } else {
      _M0FPB22fixed__quick__sort__byGRP46mizchi3bit1x3hub12IssueCommentE(right, cmp, _M0MPC15array12MutArrayView2atGRP46mizchi3bit1x3hub12IssueCommentE(arr$2, _pivot), limit$3);
      _tmp = limit$3;
      _tmp$2 = left;
      _tmp$4 = _partitioned;
      _tmp$5 = balanced$2;
      continue;
    }
  }
}
function _M0MPC15array12MutArrayView8sort__byGRP46mizchi3bit1x3hub12IssueCommentE(self, cmp) {
  _M0FPB22fixed__quick__sort__byGRP46mizchi3bit1x3hub12IssueCommentE(self, cmp, undefined, _M0FPB17fixed__get__limit(self.end - self.start | 0));
}
function _M0MPC15array5Array8sort__byGRP46mizchi3bit1x3hub12IssueCommentE(self, cmp) {
  _M0MPC15array12MutArrayView8sort__byGRP46mizchi3bit1x3hub12IssueCommentE(_M0MPC15array5Array17mut__view_2einnerGRP46mizchi3bit1x3hub12IssueCommentE(self, 0, undefined), cmp);
}
function _M0MPC15array9ArrayView16blit__to_2einnerGyE(self, dst, dst_offset) {
  const len = self.end - self.start | 0;
  if (dst_offset >= 0 && dst_offset <= dst.length) {
    if ((dst_offset + len | 0) > dst.length) {
      _M0MPC15array5Array24unsafe__grow__to__lengthGyE(dst, dst_offset + len | 0);
    }
    _M0MPB18UninitializedArray12unsafe__blitGyE(dst, dst_offset, self.buf, self.start, len);
    return;
  } else {
    $panic();
    return;
  }
}
function _M0MPC15array5Array6appendGyE(self, other) {
  _M0MPC15array9ArrayView16blit__to_2einnerGyE(other, self, self.length);
}
function _M0MPC15array5Array6searchGsE(self, value) {
  return _M0MPC15array9ArrayView6searchGsE(new _M0TPB9ArrayViewGsE(self, 0, self.length), value);
}
function _M0MPC15array5Array4joinGsE(self, separator) {
  return _M0MPC15array9ArrayView4joinGsE(new _M0TPB9ArrayViewGsE(self, 0, self.length), separator);
}
function _M0MPC16buffer6Buffer19grow__if__necessary(self, required) {
  const start = self.data.length <= 0 ? 1 : self.data.length;
  let enough_space;
  let _tmp = start;
  while (true) {
    const space = _tmp;
    if (space >= required) {
      enough_space = space;
      break;
    }
    _tmp = Math.imul(space, 2) | 0;
    continue;
  }
  if (enough_space !== self.data.length) {
    const new_data = $makebytes(enough_space, 0);
    _M0MPC15array10FixedArray12unsafe__blitGyE(new_data, 0, self.data, 0, self.len);
    self.data = new_data;
    return;
  } else {
    return;
  }
}
function _M0MPC16buffer6Buffer9to__bytes(self) {
  return _M0MPC15bytes5Bytes11from__array(_M0MPC15array10FixedArray12view_2einnerGyE(self.data, 0, self.len));
}
function _M0FPC16buffer11new_2einner(size_hint) {
  const initial = size_hint < 1 ? 1 : size_hint;
  const data = $makebytes(initial, 0);
  return new _M0TPC16buffer6Buffer(data, 0);
}
function _M0MPC16buffer6Buffer17write__char__utf8(buf, value) {
  const code = value;
  if (code >>> 0 < 128 >>> 0) {
    _M0MPC16buffer6Buffer19grow__if__necessary(buf, buf.len + 1 | 0);
    const _tmp = buf.data;
    const _tmp$2 = buf.len;
    const _p = code & 127 | 0;
    $bound_check(_tmp, _tmp$2);
    _tmp[_tmp$2] = _p & 255;
    buf.len = buf.len + 1 | 0;
    return;
  } else {
    if (code >>> 0 < 2048 >>> 0) {
      _M0MPC16buffer6Buffer19grow__if__necessary(buf, buf.len + 2 | 0);
      const _tmp = buf.data;
      const _tmp$2 = buf.len;
      const _p = code >>> 6 & 31 | 192;
      $bound_check(_tmp, _tmp$2);
      _tmp[_tmp$2] = _p & 255;
      const _tmp$3 = buf.data;
      const _tmp$4 = buf.len + 1 | 0;
      const _p$2 = code & 63 | 128;
      $bound_check(_tmp$3, _tmp$4);
      _tmp$3[_tmp$4] = _p$2 & 255;
      buf.len = buf.len + 2 | 0;
      return;
    } else {
      if (code >>> 0 < 65536 >>> 0) {
        _M0MPC16buffer6Buffer19grow__if__necessary(buf, buf.len + 3 | 0);
        const _tmp = buf.data;
        const _tmp$2 = buf.len;
        const _p = code >>> 12 & 15 | 224;
        $bound_check(_tmp, _tmp$2);
        _tmp[_tmp$2] = _p & 255;
        const _tmp$3 = buf.data;
        const _tmp$4 = buf.len + 1 | 0;
        const _p$2 = code >>> 6 & 63 | 128;
        $bound_check(_tmp$3, _tmp$4);
        _tmp$3[_tmp$4] = _p$2 & 255;
        const _tmp$5 = buf.data;
        const _tmp$6 = buf.len + 2 | 0;
        const _p$3 = code & 63 | 128;
        $bound_check(_tmp$5, _tmp$6);
        _tmp$5[_tmp$6] = _p$3 & 255;
        buf.len = buf.len + 3 | 0;
        return;
      } else {
        if (code >>> 0 < 1114112 >>> 0) {
          _M0MPC16buffer6Buffer19grow__if__necessary(buf, buf.len + 4 | 0);
          const _tmp = buf.data;
          const _tmp$2 = buf.len;
          const _p = code >>> 18 & 7 | 240;
          $bound_check(_tmp, _tmp$2);
          _tmp[_tmp$2] = _p & 255;
          const _tmp$3 = buf.data;
          const _tmp$4 = buf.len + 1 | 0;
          const _p$2 = code >>> 12 & 63 | 128;
          $bound_check(_tmp$3, _tmp$4);
          _tmp$3[_tmp$4] = _p$2 & 255;
          const _tmp$5 = buf.data;
          const _tmp$6 = buf.len + 2 | 0;
          const _p$3 = code >>> 6 & 63 | 128;
          $bound_check(_tmp$5, _tmp$6);
          _tmp$5[_tmp$6] = _p$3 & 255;
          const _tmp$7 = buf.data;
          const _tmp$8 = buf.len + 3 | 0;
          const _p$4 = code & 63 | 128;
          $bound_check(_tmp$7, _tmp$8);
          _tmp$7[_tmp$8] = _p$4 & 255;
          buf.len = buf.len + 4 | 0;
          return;
        } else {
          _M0FPB5abortGuE("Char out of range", "buffer/buffer.mbt:813:10-813:36@moonbitlang/core");
          return;
        }
      }
    }
  }
}
function _M0MPC16buffer6Buffer19write__string__utf8(buf, string) {
  const _it = _M0MPC16string10StringView4iter(string);
  while (true) {
    const _bind = _M0MPB4Iter4nextGcE(_it);
    if (_bind === -1) {
      return;
    } else {
      const _Some = _bind;
      const _ch = _Some;
      _M0MPC16buffer6Buffer17write__char__utf8(buf, _ch);
      continue;
    }
  }
}
function _M0FPC28encoding4utf814encode_2einner(str, bom) {
  const buffer = _M0FPC16buffer11new_2einner(Math.imul(str.end - str.start | 0, 4) | 0);
  if (bom === true) {
    _M0MPC16buffer6Buffer17write__char__utf8(buffer, 65279);
  }
  _M0MPC16buffer6Buffer19write__string__utf8(buffer, str);
  return _M0MPC16buffer6Buffer9to__bytes(buffer);
}
function _M0FPC28encoding4utf821decode__lossy_2einner(bytes, ignore_bom) {
  let bytes$2;
  _L: {
    _L$2: {
      if (ignore_bom) {
        _L$3: {
          _L$4: {
            if ((bytes.end - bytes.start | 0) >= 3) {
              const _x = bytes.bytes[bytes.start];
              if (_x === 239) {
                const _x$2 = bytes.bytes[bytes.start + 1 | 0];
                if (_x$2 === 187) {
                  const _x$3 = bytes.bytes[bytes.start + 2 | 0];
                  if (_x$3 === 191) {
                    bytes$2 = new _M0TPC15bytes9BytesView(bytes.bytes, bytes.start + 3 | 0, bytes.end);
                  } else {
                    break _L$4;
                  }
                } else {
                  break _L$4;
                }
              } else {
                break _L$4;
              }
            } else {
              break _L$4;
            }
            break _L$3;
          }
          break _L$2;
        }
      } else {
        break _L$2;
      }
      break _L;
    }
    bytes$2 = bytes;
  }
  const t = $makebytes(Math.imul(bytes$2.end - bytes$2.start | 0, 2) | 0, 0);
  let tlen;
  let _tmp = 0;
  let _tmp$2 = bytes$2;
  while (true) {
    const _param_0 = _tmp;
    const _param_1 = _tmp$2;
    let tlen$2;
    let rest;
    _L$2: {
      let rest$2;
      let tlen$3;
      _L$3: {
        let rest$3;
        let tlen$4;
        _L$4: {
          let rest$4;
          let tlen$5;
          _L$5: {
            let tlen$6;
            let b0;
            let b1;
            let b2;
            let b3;
            let rest$5;
            _L$6: {
              let tlen$7;
              let b0$2;
              let b1$2;
              let b2$2;
              let rest$6;
              _L$7: {
                let tlen$8;
                let rest$7;
                let b0$3;
                let b1$3;
                _L$8: {
                  let tlen$9;
                  let rest$8;
                  let b;
                  _L$9: {
                    if ((_param_1.end - _param_1.start | 0) === 0) {
                      tlen = _param_0;
                      break;
                    } else {
                      if ((_param_1.end - _param_1.start | 0) >= 8) {
                        const _x = _param_1.bytes[_param_1.start];
                        if (_x <= 127) {
                          const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                          if (_x$2 <= 127) {
                            const _x$3 = _param_1.bytes[_param_1.start + 2 | 0];
                            if (_x$3 <= 127) {
                              const _x$4 = _param_1.bytes[_param_1.start + 3 | 0];
                              if (_x$4 <= 127) {
                                const _x$5 = _param_1.bytes[_param_1.start + 4 | 0];
                                if (_x$5 <= 127) {
                                  const _x$6 = _param_1.bytes[_param_1.start + 5 | 0];
                                  if (_x$6 <= 127) {
                                    const _x$7 = _param_1.bytes[_param_1.start + 6 | 0];
                                    if (_x$7 <= 127) {
                                      const _x$8 = _param_1.bytes[_param_1.start + 7 | 0];
                                      if (_x$8 <= 127) {
                                        const _x$9 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 8 | 0, _param_1.end);
                                        t[_param_0] = _x;
                                        t[_param_0 + 2 | 0] = _x$2;
                                        t[_param_0 + 4 | 0] = _x$3;
                                        t[_param_0 + 6 | 0] = _x$4;
                                        t[_param_0 + 8 | 0] = _x$5;
                                        t[_param_0 + 10 | 0] = _x$6;
                                        t[_param_0 + 12 | 0] = _x$7;
                                        t[_param_0 + 14 | 0] = _x$8;
                                        _tmp = _param_0 + 16 | 0;
                                        _tmp$2 = _x$9;
                                        continue;
                                      } else {
                                        const _x$9 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                        tlen$9 = _param_0;
                                        rest$8 = _x$9;
                                        b = _x;
                                        break _L$9;
                                      }
                                    } else {
                                      const _x$8 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                      tlen$9 = _param_0;
                                      rest$8 = _x$8;
                                      b = _x;
                                      break _L$9;
                                    }
                                  } else {
                                    const _x$7 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                    tlen$9 = _param_0;
                                    rest$8 = _x$7;
                                    b = _x;
                                    break _L$9;
                                  }
                                } else {
                                  const _x$6 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                  tlen$9 = _param_0;
                                  rest$8 = _x$6;
                                  b = _x;
                                  break _L$9;
                                }
                              } else {
                                const _x$5 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                tlen$9 = _param_0;
                                rest$8 = _x$5;
                                b = _x;
                                break _L$9;
                              }
                            } else {
                              const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                              tlen$9 = _param_0;
                              rest$8 = _x$4;
                              b = _x;
                              break _L$9;
                            }
                          } else {
                            const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                            tlen$9 = _param_0;
                            rest$8 = _x$3;
                            b = _x;
                            break _L$9;
                          }
                        } else {
                          if (_x >= 194 && _x <= 223) {
                            const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                            if (_x$2 >= 128 && _x$2 <= 191) {
                              const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                              tlen$8 = _param_0;
                              rest$7 = _x$3;
                              b0$3 = _x;
                              b1$3 = _x$2;
                              break _L$8;
                            } else {
                              const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                              tlen$2 = _param_0;
                              rest = _x$3;
                              break _L$2;
                            }
                          } else {
                            if (_x === 224) {
                              const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                              if (_x$2 >= 160 && _x$2 <= 191) {
                                const _x$3 = _param_1.bytes[_param_1.start + 2 | 0];
                                if (_x$3 >= 128 && _x$3 <= 191) {
                                  const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 3 | 0, _param_1.end);
                                  tlen$7 = _param_0;
                                  b0$2 = _x;
                                  b1$2 = _x$2;
                                  b2$2 = _x$3;
                                  rest$6 = _x$4;
                                  break _L$7;
                                } else {
                                  const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                  rest$4 = _x$4;
                                  tlen$5 = _param_0;
                                  break _L$5;
                                }
                              } else {
                                const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                tlen$2 = _param_0;
                                rest = _x$3;
                                break _L$2;
                              }
                            } else {
                              if (_x >= 225 && _x <= 236) {
                                const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                                if (_x$2 >= 128 && _x$2 <= 191) {
                                  const _x$3 = _param_1.bytes[_param_1.start + 2 | 0];
                                  if (_x$3 >= 128 && _x$3 <= 191) {
                                    const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 3 | 0, _param_1.end);
                                    tlen$7 = _param_0;
                                    b0$2 = _x;
                                    b1$2 = _x$2;
                                    b2$2 = _x$3;
                                    rest$6 = _x$4;
                                    break _L$7;
                                  } else {
                                    const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                    rest$4 = _x$4;
                                    tlen$5 = _param_0;
                                    break _L$5;
                                  }
                                } else {
                                  const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                  tlen$2 = _param_0;
                                  rest = _x$3;
                                  break _L$2;
                                }
                              } else {
                                if (_x === 237) {
                                  const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                                  if (_x$2 >= 128 && _x$2 <= 159) {
                                    const _x$3 = _param_1.bytes[_param_1.start + 2 | 0];
                                    if (_x$3 >= 128 && _x$3 <= 191) {
                                      const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 3 | 0, _param_1.end);
                                      tlen$7 = _param_0;
                                      b0$2 = _x;
                                      b1$2 = _x$2;
                                      b2$2 = _x$3;
                                      rest$6 = _x$4;
                                      break _L$7;
                                    } else {
                                      const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                      rest$4 = _x$4;
                                      tlen$5 = _param_0;
                                      break _L$5;
                                    }
                                  } else {
                                    const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                    tlen$2 = _param_0;
                                    rest = _x$3;
                                    break _L$2;
                                  }
                                } else {
                                  if (_x >= 238 && _x <= 239) {
                                    const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                                    if (_x$2 >= 128 && _x$2 <= 191) {
                                      const _x$3 = _param_1.bytes[_param_1.start + 2 | 0];
                                      if (_x$3 >= 128 && _x$3 <= 191) {
                                        const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 3 | 0, _param_1.end);
                                        tlen$7 = _param_0;
                                        b0$2 = _x;
                                        b1$2 = _x$2;
                                        b2$2 = _x$3;
                                        rest$6 = _x$4;
                                        break _L$7;
                                      } else {
                                        const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                        rest$4 = _x$4;
                                        tlen$5 = _param_0;
                                        break _L$5;
                                      }
                                    } else {
                                      const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                      tlen$2 = _param_0;
                                      rest = _x$3;
                                      break _L$2;
                                    }
                                  } else {
                                    if (_x === 240) {
                                      const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                                      if (_x$2 >= 144 && _x$2 <= 191) {
                                        const _x$3 = _param_1.bytes[_param_1.start + 2 | 0];
                                        if (_x$3 >= 128 && _x$3 <= 191) {
                                          const _x$4 = _param_1.bytes[_param_1.start + 3 | 0];
                                          if (_x$4 >= 128 && _x$4 <= 191) {
                                            const _x$5 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 4 | 0, _param_1.end);
                                            tlen$6 = _param_0;
                                            b0 = _x;
                                            b1 = _x$2;
                                            b2 = _x$3;
                                            b3 = _x$4;
                                            rest$5 = _x$5;
                                            break _L$6;
                                          } else {
                                            const _x$5 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 3 | 0, _param_1.end);
                                            rest$3 = _x$5;
                                            tlen$4 = _param_0;
                                            break _L$4;
                                          }
                                        } else {
                                          const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                          rest$2 = _x$4;
                                          tlen$3 = _param_0;
                                          break _L$3;
                                        }
                                      } else {
                                        const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                        tlen$2 = _param_0;
                                        rest = _x$3;
                                        break _L$2;
                                      }
                                    } else {
                                      if (_x >= 241 && _x <= 243) {
                                        const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                                        if (_x$2 >= 128 && _x$2 <= 191) {
                                          const _x$3 = _param_1.bytes[_param_1.start + 2 | 0];
                                          if (_x$3 >= 128 && _x$3 <= 191) {
                                            const _x$4 = _param_1.bytes[_param_1.start + 3 | 0];
                                            if (_x$4 >= 128 && _x$4 <= 191) {
                                              const _x$5 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 4 | 0, _param_1.end);
                                              tlen$6 = _param_0;
                                              b0 = _x;
                                              b1 = _x$2;
                                              b2 = _x$3;
                                              b3 = _x$4;
                                              rest$5 = _x$5;
                                              break _L$6;
                                            } else {
                                              const _x$5 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 3 | 0, _param_1.end);
                                              rest$3 = _x$5;
                                              tlen$4 = _param_0;
                                              break _L$4;
                                            }
                                          } else {
                                            const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                            rest$2 = _x$4;
                                            tlen$3 = _param_0;
                                            break _L$3;
                                          }
                                        } else {
                                          const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                          tlen$2 = _param_0;
                                          rest = _x$3;
                                          break _L$2;
                                        }
                                      } else {
                                        if (_x === 244) {
                                          const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                                          if (_x$2 >= 128 && _x$2 <= 143) {
                                            const _x$3 = _param_1.bytes[_param_1.start + 2 | 0];
                                            if (_x$3 >= 128 && _x$3 <= 191) {
                                              const _x$4 = _param_1.bytes[_param_1.start + 3 | 0];
                                              if (_x$4 >= 128 && _x$4 <= 191) {
                                                const _x$5 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 4 | 0, _param_1.end);
                                                tlen$6 = _param_0;
                                                b0 = _x;
                                                b1 = _x$2;
                                                b2 = _x$3;
                                                b3 = _x$4;
                                                rest$5 = _x$5;
                                                break _L$6;
                                              } else {
                                                const _x$5 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 3 | 0, _param_1.end);
                                                rest$3 = _x$5;
                                                tlen$4 = _param_0;
                                                break _L$4;
                                              }
                                            } else {
                                              const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                              rest$2 = _x$4;
                                              tlen$3 = _param_0;
                                              break _L$3;
                                            }
                                          } else {
                                            const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                            tlen$2 = _param_0;
                                            rest = _x$3;
                                            break _L$2;
                                          }
                                        } else {
                                          const _x$2 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                          tlen$2 = _param_0;
                                          rest = _x$2;
                                          break _L$2;
                                        }
                                      }
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      } else {
                        const _x = _param_1.bytes[_param_1.start];
                        if (_x >= 0 && _x <= 127) {
                          const _x$2 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                          tlen$9 = _param_0;
                          rest$8 = _x$2;
                          b = _x;
                          break _L$9;
                        } else {
                          if ((_param_1.end - _param_1.start | 0) >= 2) {
                            if (_x >= 194 && _x <= 223) {
                              const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                              if (_x$2 >= 128 && _x$2 <= 191) {
                                const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                tlen$8 = _param_0;
                                rest$7 = _x$3;
                                b0$3 = _x;
                                b1$3 = _x$2;
                                break _L$8;
                              } else {
                                if ((_param_1.end - _param_1.start | 0) >= 3) {
                                  if ((_param_1.end - _param_1.start | 0) >= 4) {
                                    const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                    tlen$2 = _param_0;
                                    rest = _x$3;
                                    break _L$2;
                                  } else {
                                    const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                    tlen$2 = _param_0;
                                    rest = _x$3;
                                    break _L$2;
                                  }
                                } else {
                                  const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                  tlen$2 = _param_0;
                                  rest = _x$3;
                                  break _L$2;
                                }
                              }
                            } else {
                              if ((_param_1.end - _param_1.start | 0) >= 3) {
                                if (_x === 224) {
                                  const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                                  if (_x$2 >= 160 && _x$2 <= 191) {
                                    const _x$3 = _param_1.bytes[_param_1.start + 2 | 0];
                                    if (_x$3 >= 128 && _x$3 <= 191) {
                                      const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 3 | 0, _param_1.end);
                                      tlen$7 = _param_0;
                                      b0$2 = _x;
                                      b1$2 = _x$2;
                                      b2$2 = _x$3;
                                      rest$6 = _x$4;
                                      break _L$7;
                                    } else {
                                      if ((_param_1.end - _param_1.start | 0) >= 4) {
                                        const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                        rest$4 = _x$4;
                                        tlen$5 = _param_0;
                                        break _L$5;
                                      } else {
                                        const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                        rest$4 = _x$4;
                                        tlen$5 = _param_0;
                                        break _L$5;
                                      }
                                    }
                                  } else {
                                    if ((_param_1.end - _param_1.start | 0) >= 4) {
                                      const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                      tlen$2 = _param_0;
                                      rest = _x$3;
                                      break _L$2;
                                    } else {
                                      const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                      tlen$2 = _param_0;
                                      rest = _x$3;
                                      break _L$2;
                                    }
                                  }
                                } else {
                                  if (_x >= 225 && _x <= 236) {
                                    const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                                    if (_x$2 >= 128 && _x$2 <= 191) {
                                      const _x$3 = _param_1.bytes[_param_1.start + 2 | 0];
                                      if (_x$3 >= 128 && _x$3 <= 191) {
                                        const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 3 | 0, _param_1.end);
                                        tlen$7 = _param_0;
                                        b0$2 = _x;
                                        b1$2 = _x$2;
                                        b2$2 = _x$3;
                                        rest$6 = _x$4;
                                        break _L$7;
                                      } else {
                                        if ((_param_1.end - _param_1.start | 0) >= 4) {
                                          const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                          rest$4 = _x$4;
                                          tlen$5 = _param_0;
                                          break _L$5;
                                        } else {
                                          const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                          rest$4 = _x$4;
                                          tlen$5 = _param_0;
                                          break _L$5;
                                        }
                                      }
                                    } else {
                                      if ((_param_1.end - _param_1.start | 0) >= 4) {
                                        const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                        tlen$2 = _param_0;
                                        rest = _x$3;
                                        break _L$2;
                                      } else {
                                        const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                        tlen$2 = _param_0;
                                        rest = _x$3;
                                        break _L$2;
                                      }
                                    }
                                  } else {
                                    if (_x === 237) {
                                      const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                                      if (_x$2 >= 128 && _x$2 <= 159) {
                                        const _x$3 = _param_1.bytes[_param_1.start + 2 | 0];
                                        if (_x$3 >= 128 && _x$3 <= 191) {
                                          const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 3 | 0, _param_1.end);
                                          tlen$7 = _param_0;
                                          b0$2 = _x;
                                          b1$2 = _x$2;
                                          b2$2 = _x$3;
                                          rest$6 = _x$4;
                                          break _L$7;
                                        } else {
                                          if ((_param_1.end - _param_1.start | 0) >= 4) {
                                            const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                            rest$4 = _x$4;
                                            tlen$5 = _param_0;
                                            break _L$5;
                                          } else {
                                            const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                            rest$4 = _x$4;
                                            tlen$5 = _param_0;
                                            break _L$5;
                                          }
                                        }
                                      } else {
                                        if ((_param_1.end - _param_1.start | 0) >= 4) {
                                          const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                          tlen$2 = _param_0;
                                          rest = _x$3;
                                          break _L$2;
                                        } else {
                                          const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                          tlen$2 = _param_0;
                                          rest = _x$3;
                                          break _L$2;
                                        }
                                      }
                                    } else {
                                      if (_x >= 238 && _x <= 239) {
                                        const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                                        if (_x$2 >= 128 && _x$2 <= 191) {
                                          const _x$3 = _param_1.bytes[_param_1.start + 2 | 0];
                                          if (_x$3 >= 128 && _x$3 <= 191) {
                                            const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 3 | 0, _param_1.end);
                                            tlen$7 = _param_0;
                                            b0$2 = _x;
                                            b1$2 = _x$2;
                                            b2$2 = _x$3;
                                            rest$6 = _x$4;
                                            break _L$7;
                                          } else {
                                            if ((_param_1.end - _param_1.start | 0) >= 4) {
                                              const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                              rest$4 = _x$4;
                                              tlen$5 = _param_0;
                                              break _L$5;
                                            } else {
                                              const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                              rest$4 = _x$4;
                                              tlen$5 = _param_0;
                                              break _L$5;
                                            }
                                          }
                                        } else {
                                          if ((_param_1.end - _param_1.start | 0) >= 4) {
                                            const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                            tlen$2 = _param_0;
                                            rest = _x$3;
                                            break _L$2;
                                          } else {
                                            const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                            tlen$2 = _param_0;
                                            rest = _x$3;
                                            break _L$2;
                                          }
                                        }
                                      } else {
                                        if ((_param_1.end - _param_1.start | 0) >= 4) {
                                          if (_x === 240) {
                                            const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                                            if (_x$2 >= 144 && _x$2 <= 191) {
                                              const _x$3 = _param_1.bytes[_param_1.start + 2 | 0];
                                              if (_x$3 >= 128 && _x$3 <= 191) {
                                                const _x$4 = _param_1.bytes[_param_1.start + 3 | 0];
                                                if (_x$4 >= 128 && _x$4 <= 191) {
                                                  const _x$5 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 4 | 0, _param_1.end);
                                                  tlen$6 = _param_0;
                                                  b0 = _x;
                                                  b1 = _x$2;
                                                  b2 = _x$3;
                                                  b3 = _x$4;
                                                  rest$5 = _x$5;
                                                  break _L$6;
                                                } else {
                                                  const _x$5 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 3 | 0, _param_1.end);
                                                  rest$3 = _x$5;
                                                  tlen$4 = _param_0;
                                                  break _L$4;
                                                }
                                              } else {
                                                const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                                rest$2 = _x$4;
                                                tlen$3 = _param_0;
                                                break _L$3;
                                              }
                                            } else {
                                              const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                              tlen$2 = _param_0;
                                              rest = _x$3;
                                              break _L$2;
                                            }
                                          } else {
                                            if (_x >= 241 && _x <= 243) {
                                              const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                                              if (_x$2 >= 128 && _x$2 <= 191) {
                                                const _x$3 = _param_1.bytes[_param_1.start + 2 | 0];
                                                if (_x$3 >= 128 && _x$3 <= 191) {
                                                  const _x$4 = _param_1.bytes[_param_1.start + 3 | 0];
                                                  if (_x$4 >= 128 && _x$4 <= 191) {
                                                    const _x$5 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 4 | 0, _param_1.end);
                                                    tlen$6 = _param_0;
                                                    b0 = _x;
                                                    b1 = _x$2;
                                                    b2 = _x$3;
                                                    b3 = _x$4;
                                                    rest$5 = _x$5;
                                                    break _L$6;
                                                  } else {
                                                    const _x$5 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 3 | 0, _param_1.end);
                                                    rest$3 = _x$5;
                                                    tlen$4 = _param_0;
                                                    break _L$4;
                                                  }
                                                } else {
                                                  const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                                  rest$2 = _x$4;
                                                  tlen$3 = _param_0;
                                                  break _L$3;
                                                }
                                              } else {
                                                const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                                tlen$2 = _param_0;
                                                rest = _x$3;
                                                break _L$2;
                                              }
                                            } else {
                                              if (_x === 244) {
                                                const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                                                if (_x$2 >= 128 && _x$2 <= 143) {
                                                  const _x$3 = _param_1.bytes[_param_1.start + 2 | 0];
                                                  if (_x$3 >= 128 && _x$3 <= 191) {
                                                    const _x$4 = _param_1.bytes[_param_1.start + 3 | 0];
                                                    if (_x$4 >= 128 && _x$4 <= 191) {
                                                      const _x$5 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 4 | 0, _param_1.end);
                                                      tlen$6 = _param_0;
                                                      b0 = _x;
                                                      b1 = _x$2;
                                                      b2 = _x$3;
                                                      b3 = _x$4;
                                                      rest$5 = _x$5;
                                                      break _L$6;
                                                    } else {
                                                      const _x$5 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 3 | 0, _param_1.end);
                                                      rest$3 = _x$5;
                                                      tlen$4 = _param_0;
                                                      break _L$4;
                                                    }
                                                  } else {
                                                    const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                                    rest$2 = _x$4;
                                                    tlen$3 = _param_0;
                                                    break _L$3;
                                                  }
                                                } else {
                                                  const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                                  tlen$2 = _param_0;
                                                  rest = _x$3;
                                                  break _L$2;
                                                }
                                              } else {
                                                const _x$2 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                                tlen$2 = _param_0;
                                                rest = _x$2;
                                                break _L$2;
                                              }
                                            }
                                          }
                                        } else {
                                          if (_x === 240) {
                                            const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                                            if (_x$2 >= 144 && _x$2 <= 191) {
                                              const _x$3 = _param_1.bytes[_param_1.start + 2 | 0];
                                              if (_x$3 >= 128 && _x$3 <= 191) {
                                                const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 3 | 0, _param_1.end);
                                                rest$3 = _x$4;
                                                tlen$4 = _param_0;
                                                break _L$4;
                                              } else {
                                                const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                                rest$2 = _x$4;
                                                tlen$3 = _param_0;
                                                break _L$3;
                                              }
                                            } else {
                                              const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                              tlen$2 = _param_0;
                                              rest = _x$3;
                                              break _L$2;
                                            }
                                          } else {
                                            if (_x >= 241 && _x <= 243) {
                                              const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                                              if (_x$2 >= 128 && _x$2 <= 191) {
                                                const _x$3 = _param_1.bytes[_param_1.start + 2 | 0];
                                                if (_x$3 >= 128 && _x$3 <= 191) {
                                                  const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 3 | 0, _param_1.end);
                                                  rest$3 = _x$4;
                                                  tlen$4 = _param_0;
                                                  break _L$4;
                                                } else {
                                                  const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                                  rest$2 = _x$4;
                                                  tlen$3 = _param_0;
                                                  break _L$3;
                                                }
                                              } else {
                                                const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                                tlen$2 = _param_0;
                                                rest = _x$3;
                                                break _L$2;
                                              }
                                            } else {
                                              if (_x === 244) {
                                                const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                                                if (_x$2 >= 128 && _x$2 <= 143) {
                                                  const _x$3 = _param_1.bytes[_param_1.start + 2 | 0];
                                                  if (_x$3 >= 128 && _x$3 <= 191) {
                                                    const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 3 | 0, _param_1.end);
                                                    rest$3 = _x$4;
                                                    tlen$4 = _param_0;
                                                    break _L$4;
                                                  } else {
                                                    const _x$4 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                                    rest$2 = _x$4;
                                                    tlen$3 = _param_0;
                                                    break _L$3;
                                                  }
                                                } else {
                                                  const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                                  tlen$2 = _param_0;
                                                  rest = _x$3;
                                                  break _L$2;
                                                }
                                              } else {
                                                const _x$2 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                                tlen$2 = _param_0;
                                                rest = _x$2;
                                                break _L$2;
                                              }
                                            }
                                          }
                                        }
                                      }
                                    }
                                  }
                                }
                              } else {
                                if (_x === 224) {
                                  const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                                  if (_x$2 >= 160 && _x$2 <= 191) {
                                    const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                    rest$4 = _x$3;
                                    tlen$5 = _param_0;
                                    break _L$5;
                                  } else {
                                    const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                    tlen$2 = _param_0;
                                    rest = _x$3;
                                    break _L$2;
                                  }
                                } else {
                                  if (_x >= 225 && _x <= 236) {
                                    const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                                    if (_x$2 >= 128 && _x$2 <= 191) {
                                      const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                      rest$4 = _x$3;
                                      tlen$5 = _param_0;
                                      break _L$5;
                                    } else {
                                      const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                      tlen$2 = _param_0;
                                      rest = _x$3;
                                      break _L$2;
                                    }
                                  } else {
                                    if (_x === 237) {
                                      const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                                      if (_x$2 >= 128 && _x$2 <= 159) {
                                        const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                        rest$4 = _x$3;
                                        tlen$5 = _param_0;
                                        break _L$5;
                                      } else {
                                        const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                        tlen$2 = _param_0;
                                        rest = _x$3;
                                        break _L$2;
                                      }
                                    } else {
                                      if (_x >= 238 && _x <= 239) {
                                        const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                                        if (_x$2 >= 128 && _x$2 <= 191) {
                                          const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                          rest$4 = _x$3;
                                          tlen$5 = _param_0;
                                          break _L$5;
                                        } else {
                                          const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                          tlen$2 = _param_0;
                                          rest = _x$3;
                                          break _L$2;
                                        }
                                      } else {
                                        if (_x === 240) {
                                          const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                                          if (_x$2 >= 144 && _x$2 <= 191) {
                                            const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                            rest$2 = _x$3;
                                            tlen$3 = _param_0;
                                            break _L$3;
                                          } else {
                                            const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                            tlen$2 = _param_0;
                                            rest = _x$3;
                                            break _L$2;
                                          }
                                        } else {
                                          if (_x >= 241 && _x <= 243) {
                                            const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                                            if (_x$2 >= 128 && _x$2 <= 191) {
                                              const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                              rest$2 = _x$3;
                                              tlen$3 = _param_0;
                                              break _L$3;
                                            } else {
                                              const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                              tlen$2 = _param_0;
                                              rest = _x$3;
                                              break _L$2;
                                            }
                                          } else {
                                            if (_x === 244) {
                                              const _x$2 = _param_1.bytes[_param_1.start + 1 | 0];
                                              if (_x$2 >= 128 && _x$2 <= 143) {
                                                const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 2 | 0, _param_1.end);
                                                rest$2 = _x$3;
                                                tlen$3 = _param_0;
                                                break _L$3;
                                              } else {
                                                const _x$3 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                                tlen$2 = _param_0;
                                                rest = _x$3;
                                                break _L$2;
                                              }
                                            } else {
                                              const _x$2 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                                              tlen$2 = _param_0;
                                              rest = _x$2;
                                              break _L$2;
                                            }
                                          }
                                        }
                                      }
                                    }
                                  }
                                }
                              }
                            }
                          } else {
                            const _x$2 = new _M0TPC15bytes9BytesView(_param_1.bytes, _param_1.start + 1 | 0, _param_1.end);
                            tlen$2 = _param_0;
                            rest = _x$2;
                            break _L$2;
                          }
                        }
                      }
                    }
                  }
                  t[tlen$9] = b;
                  _tmp = tlen$9 + 2 | 0;
                  _tmp$2 = rest$8;
                  continue;
                }
                const ch = (b0$3 & 31) << 6 | b1$3 & 63;
                t[tlen$8] = ch & 255;
                t[tlen$8 + 1 | 0] = ch >> 8 & 255;
                _tmp = tlen$8 + 2 | 0;
                _tmp$2 = rest$7;
                continue;
              }
              const ch = (b0$2 & 15) << 12 | (b1$2 & 63) << 6 | b2$2 & 63;
              t[tlen$7] = ch & 255;
              t[tlen$7 + 1 | 0] = ch >> 8 & 255;
              _tmp = tlen$7 + 2 | 0;
              _tmp$2 = rest$6;
              continue;
            }
            const ch = (b0 & 7) << 18 | (b1 & 63) << 12 | (b2 & 63) << 6 | b3 & 63;
            const chm = ch - 65536 | 0;
            const ch1 = (chm >> 10) + 55296 | 0;
            const ch2 = (chm & 1023) + 56320 | 0;
            t[tlen$6] = ch1 & 255;
            t[tlen$6 + 1 | 0] = ch1 >> 8 & 255;
            t[tlen$6 + 2 | 0] = ch2 & 255;
            t[tlen$6 + 3 | 0] = ch2 >> 8 & 255;
            _tmp = tlen$6 + 4 | 0;
            _tmp$2 = rest$5;
            continue;
          }
          t[tlen$5] = 253;
          t[tlen$5 + 1 | 0] = 255;
          _tmp = tlen$5 + 2 | 0;
          _tmp$2 = rest$4;
          continue;
        }
        t[tlen$4] = 253;
        t[tlen$4 + 1 | 0] = 255;
        _tmp = tlen$4 + 2 | 0;
        _tmp$2 = rest$3;
        continue;
      }
      t[tlen$3] = 253;
      t[tlen$3 + 1 | 0] = 255;
      _tmp = tlen$3 + 2 | 0;
      _tmp$2 = rest$2;
      continue;
    }
    t[tlen$2] = 253;
    t[tlen$2 + 1 | 0] = 255;
    _tmp = tlen$2 + 2 | 0;
    _tmp$2 = rest;
    continue;
  }
  return _M0MPC15bytes5Bytes29to__unchecked__string_2einner(t, 0, tlen);
}
function _M0FPC17strconv9base__errGUiRPC16string10StringViewbEE() {
  return new _M0DTPC16result6ResultGUiRPC16string10StringViewbERPC17strconv12StrConvErrorE3Err(new _M0DTPC15error5Error58moonbitlang_2fcore_2fstrconv_2eStrConvError_2eStrConvError(_M0FPC17strconv14base__err__str));
}
function _M0FPC17strconv25check__and__consume__base(view, base) {
  if (base === 0) {
    _L: {
      let rest;
      _L$2: {
        let rest$2;
        _L$3: {
          let rest$3;
          _L$4: {
            if (_M0MPC16string6String24char__length__ge_2einner(view.str, 2, view.start, view.end)) {
              const _x = _M0MPC16string6String16unsafe__char__at(view.str, _M0MPC16string6String29offset__of__nth__char_2einner(view.str, 0, view.start, view.end));
              if (_x === 48) {
                const _x$2 = _M0MPC16string6String16unsafe__char__at(view.str, _M0MPC16string6String29offset__of__nth__char_2einner(view.str, 1, view.start, view.end));
                switch (_x$2) {
                  case 120: {
                    const _tmp = view.str;
                    const _bind = _M0MPC16string6String29offset__of__nth__char_2einner(view.str, 2, view.start, view.end);
                    let _tmp$2;
                    if (_bind === undefined) {
                      _tmp$2 = view.end;
                    } else {
                      const _Some = _bind;
                      _tmp$2 = _Some;
                    }
                    const _x$3 = new _M0TPC16string10StringView(_tmp, _tmp$2, view.end);
                    rest$3 = _x$3;
                    break _L$4;
                  }
                  case 88: {
                    const _tmp$3 = view.str;
                    const _bind$2 = _M0MPC16string6String29offset__of__nth__char_2einner(view.str, 2, view.start, view.end);
                    let _tmp$4;
                    if (_bind$2 === undefined) {
                      _tmp$4 = view.end;
                    } else {
                      const _Some = _bind$2;
                      _tmp$4 = _Some;
                    }
                    const _x$4 = new _M0TPC16string10StringView(_tmp$3, _tmp$4, view.end);
                    rest$3 = _x$4;
                    break _L$4;
                  }
                  case 111: {
                    const _tmp$5 = view.str;
                    const _bind$3 = _M0MPC16string6String29offset__of__nth__char_2einner(view.str, 2, view.start, view.end);
                    let _tmp$6;
                    if (_bind$3 === undefined) {
                      _tmp$6 = view.end;
                    } else {
                      const _Some = _bind$3;
                      _tmp$6 = _Some;
                    }
                    const _x$5 = new _M0TPC16string10StringView(_tmp$5, _tmp$6, view.end);
                    rest$2 = _x$5;
                    break _L$3;
                  }
                  case 79: {
                    const _tmp$7 = view.str;
                    const _bind$4 = _M0MPC16string6String29offset__of__nth__char_2einner(view.str, 2, view.start, view.end);
                    let _tmp$8;
                    if (_bind$4 === undefined) {
                      _tmp$8 = view.end;
                    } else {
                      const _Some = _bind$4;
                      _tmp$8 = _Some;
                    }
                    const _x$6 = new _M0TPC16string10StringView(_tmp$7, _tmp$8, view.end);
                    rest$2 = _x$6;
                    break _L$3;
                  }
                  case 98: {
                    const _tmp$9 = view.str;
                    const _bind$5 = _M0MPC16string6String29offset__of__nth__char_2einner(view.str, 2, view.start, view.end);
                    let _tmp$10;
                    if (_bind$5 === undefined) {
                      _tmp$10 = view.end;
                    } else {
                      const _Some = _bind$5;
                      _tmp$10 = _Some;
                    }
                    const _x$7 = new _M0TPC16string10StringView(_tmp$9, _tmp$10, view.end);
                    rest = _x$7;
                    break _L$2;
                  }
                  case 66: {
                    const _tmp$11 = view.str;
                    const _bind$6 = _M0MPC16string6String29offset__of__nth__char_2einner(view.str, 2, view.start, view.end);
                    let _tmp$12;
                    if (_bind$6 === undefined) {
                      _tmp$12 = view.end;
                    } else {
                      const _Some = _bind$6;
                      _tmp$12 = _Some;
                    }
                    const _x$8 = new _M0TPC16string10StringView(_tmp$11, _tmp$12, view.end);
                    rest = _x$8;
                    break _L$2;
                  }
                  default: {
                    break _L;
                  }
                }
              } else {
                break _L;
              }
            } else {
              break _L;
            }
          }
          return new _M0DTPC16result6ResultGUiRPC16string10StringViewbERPC17strconv12StrConvErrorE2Ok({ _0: 16, _1: rest$3, _2: true });
        }
        return new _M0DTPC16result6ResultGUiRPC16string10StringViewbERPC17strconv12StrConvErrorE2Ok({ _0: 8, _1: rest$2, _2: true });
      }
      return new _M0DTPC16result6ResultGUiRPC16string10StringViewbERPC17strconv12StrConvErrorE2Ok({ _0: 2, _1: rest, _2: true });
    }
    return new _M0DTPC16result6ResultGUiRPC16string10StringViewbERPC17strconv12StrConvErrorE2Ok({ _0: 10, _1: view, _2: false });
  } else {
    _L: {
      let rest;
      _L$2: {
        let rest$2;
        _L$3: {
          let rest$3;
          _L$4: {
            if (_M0MPC16string6String24char__length__ge_2einner(view.str, 2, view.start, view.end)) {
              const _x = _M0MPC16string6String16unsafe__char__at(view.str, _M0MPC16string6String29offset__of__nth__char_2einner(view.str, 0, view.start, view.end));
              if (_x === 48) {
                const _x$2 = _M0MPC16string6String16unsafe__char__at(view.str, _M0MPC16string6String29offset__of__nth__char_2einner(view.str, 1, view.start, view.end));
                switch (_x$2) {
                  case 120: {
                    const _tmp = view.str;
                    const _bind = _M0MPC16string6String29offset__of__nth__char_2einner(view.str, 2, view.start, view.end);
                    let _tmp$2;
                    if (_bind === undefined) {
                      _tmp$2 = view.end;
                    } else {
                      const _Some = _bind;
                      _tmp$2 = _Some;
                    }
                    const _x$3 = new _M0TPC16string10StringView(_tmp, _tmp$2, view.end);
                    if (base === 16) {
                      rest$3 = _x$3;
                      break _L$4;
                    } else {
                      break _L;
                    }
                  }
                  case 88: {
                    const _tmp$3 = view.str;
                    const _bind$2 = _M0MPC16string6String29offset__of__nth__char_2einner(view.str, 2, view.start, view.end);
                    let _tmp$4;
                    if (_bind$2 === undefined) {
                      _tmp$4 = view.end;
                    } else {
                      const _Some = _bind$2;
                      _tmp$4 = _Some;
                    }
                    const _x$4 = new _M0TPC16string10StringView(_tmp$3, _tmp$4, view.end);
                    if (base === 16) {
                      rest$3 = _x$4;
                      break _L$4;
                    } else {
                      break _L;
                    }
                  }
                  case 111: {
                    const _tmp$5 = view.str;
                    const _bind$3 = _M0MPC16string6String29offset__of__nth__char_2einner(view.str, 2, view.start, view.end);
                    let _tmp$6;
                    if (_bind$3 === undefined) {
                      _tmp$6 = view.end;
                    } else {
                      const _Some = _bind$3;
                      _tmp$6 = _Some;
                    }
                    const _x$5 = new _M0TPC16string10StringView(_tmp$5, _tmp$6, view.end);
                    if (base === 8) {
                      rest$2 = _x$5;
                      break _L$3;
                    } else {
                      break _L;
                    }
                  }
                  case 79: {
                    const _tmp$7 = view.str;
                    const _bind$4 = _M0MPC16string6String29offset__of__nth__char_2einner(view.str, 2, view.start, view.end);
                    let _tmp$8;
                    if (_bind$4 === undefined) {
                      _tmp$8 = view.end;
                    } else {
                      const _Some = _bind$4;
                      _tmp$8 = _Some;
                    }
                    const _x$6 = new _M0TPC16string10StringView(_tmp$7, _tmp$8, view.end);
                    if (base === 8) {
                      rest$2 = _x$6;
                      break _L$3;
                    } else {
                      break _L;
                    }
                  }
                  case 98: {
                    const _tmp$9 = view.str;
                    const _bind$5 = _M0MPC16string6String29offset__of__nth__char_2einner(view.str, 2, view.start, view.end);
                    let _tmp$10;
                    if (_bind$5 === undefined) {
                      _tmp$10 = view.end;
                    } else {
                      const _Some = _bind$5;
                      _tmp$10 = _Some;
                    }
                    const _x$7 = new _M0TPC16string10StringView(_tmp$9, _tmp$10, view.end);
                    if (base === 2) {
                      rest = _x$7;
                      break _L$2;
                    } else {
                      break _L;
                    }
                  }
                  case 66: {
                    const _tmp$11 = view.str;
                    const _bind$6 = _M0MPC16string6String29offset__of__nth__char_2einner(view.str, 2, view.start, view.end);
                    let _tmp$12;
                    if (_bind$6 === undefined) {
                      _tmp$12 = view.end;
                    } else {
                      const _Some = _bind$6;
                      _tmp$12 = _Some;
                    }
                    const _x$8 = new _M0TPC16string10StringView(_tmp$11, _tmp$12, view.end);
                    if (base === 2) {
                      rest = _x$8;
                      break _L$2;
                    } else {
                      break _L;
                    }
                  }
                  default: {
                    break _L;
                  }
                }
              } else {
                break _L;
              }
            } else {
              break _L;
            }
          }
          return new _M0DTPC16result6ResultGUiRPC16string10StringViewbERPC17strconv12StrConvErrorE2Ok({ _0: 16, _1: rest$3, _2: true });
        }
        return new _M0DTPC16result6ResultGUiRPC16string10StringViewbERPC17strconv12StrConvErrorE2Ok({ _0: 8, _1: rest$2, _2: true });
      }
      return new _M0DTPC16result6ResultGUiRPC16string10StringViewbERPC17strconv12StrConvErrorE2Ok({ _0: 2, _1: rest, _2: true });
    }
    return base >= 2 && base <= 36 ? new _M0DTPC16result6ResultGUiRPC16string10StringViewbERPC17strconv12StrConvErrorE2Ok({ _0: base, _1: view, _2: false }) : _M0FPC17strconv9base__errGUiRPC16string10StringViewbEE();
  }
}
function _M0FPC17strconv10range__errGuE() {
  return new _M0DTPC16result6ResultGuRPC17strconv12StrConvErrorE3Err(new _M0DTPC15error5Error58moonbitlang_2fcore_2fstrconv_2eStrConvError_2eStrConvError(_M0FPC17strconv15range__err__str));
}
function _M0FPC17strconv10range__errGlE() {
  return new _M0DTPC16result6ResultGlRPC17strconv12StrConvErrorE3Err(new _M0DTPC15error5Error58moonbitlang_2fcore_2fstrconv_2eStrConvError_2eStrConvError(_M0FPC17strconv15range__err__str));
}
function _M0FPC17strconv11syntax__errGiE() {
  return new _M0DTPC16result6ResultGiRPC17strconv12StrConvErrorE3Err(new _M0DTPC15error5Error58moonbitlang_2fcore_2fstrconv_2eStrConvError_2eStrConvError(_M0FPC17strconv16syntax__err__str));
}
function _M0FPC17strconv11syntax__errGlE() {
  return new _M0DTPC16result6ResultGlRPC17strconv12StrConvErrorE3Err(new _M0DTPC15error5Error58moonbitlang_2fcore_2fstrconv_2eStrConvError_2eStrConvError(_M0FPC17strconv16syntax__err__str));
}
function _M0FPC17strconv19overflow__threshold(base, neg) {
  return !neg ? (base === 10 ? _M0IPC15int645Int64PB3Add3add(_M0IPC15int645Int64PB3Div3div($9223372036854775807L, $10L), $1L) : base === 16 ? _M0IPC15int645Int64PB3Add3add(_M0IPC15int645Int64PB3Div3div($9223372036854775807L, $16L), $1L) : _M0IPC15int645Int64PB3Add3add(_M0IPC15int645Int64PB3Div3div($9223372036854775807L, _M0MPC13int3Int9to__int64(base)), $1L)) : base === 10 ? _M0IPC15int645Int64PB3Div3div($_9223372036854775808L, $10L) : base === 16 ? _M0IPC15int645Int64PB3Div3div($_9223372036854775808L, $16L) : _M0IPC15int645Int64PB3Div3div($_9223372036854775808L, _M0MPC13int3Int9to__int64(base));
}
function _M0FPC17strconv20parse__int64_2einner(str, base) {
  if (_M0IP016_24default__implPB2Eq10not__equalGRPC16string10StringViewE(str, new _M0TPC16string10StringView(_M0FPC17strconv20parse__int64_2einnerN7_2abindS539, 0, _M0FPC17strconv20parse__int64_2einnerN7_2abindS539.length))) {
    let neg;
    let rest;
    _L: {
      let rest$2;
      _L$2: {
        const _bind = _M0MPC16string10StringView12view_2einner(str, 0, undefined);
        if (_M0MPC16string6String24char__length__ge_2einner(_bind.str, 1, _bind.start, _bind.end)) {
          const _x = _M0MPC16string6String16unsafe__char__at(_bind.str, _M0MPC16string6String29offset__of__nth__char_2einner(_bind.str, 0, _bind.start, _bind.end));
          switch (_x) {
            case 43: {
              const _tmp = _bind.str;
              const _bind$2 = _M0MPC16string6String29offset__of__nth__char_2einner(_bind.str, 1, _bind.start, _bind.end);
              let _tmp$2;
              if (_bind$2 === undefined) {
                _tmp$2 = _bind.end;
              } else {
                const _Some = _bind$2;
                _tmp$2 = _Some;
              }
              const _x$2 = new _M0TPC16string10StringView(_tmp, _tmp$2, _bind.end);
              neg = false;
              rest = _x$2;
              break _L;
            }
            case 45: {
              const _tmp$3 = _bind.str;
              const _bind$3 = _M0MPC16string6String29offset__of__nth__char_2einner(_bind.str, 1, _bind.start, _bind.end);
              let _tmp$4;
              if (_bind$3 === undefined) {
                _tmp$4 = _bind.end;
              } else {
                const _Some = _bind$3;
                _tmp$4 = _Some;
              }
              const _x$3 = new _M0TPC16string10StringView(_tmp$3, _tmp$4, _bind.end);
              neg = true;
              rest = _x$3;
              break _L;
            }
            default: {
              rest$2 = _bind;
              break _L$2;
            }
          }
        } else {
          rest$2 = _bind;
          break _L$2;
        }
      }
      neg = false;
      rest = rest$2;
      break _L;
    }
    const _bind = _M0FPC17strconv25check__and__consume__base(rest, base);
    let _bind$2;
    if (_bind.$tag === 1) {
      const _ok = _bind;
      _bind$2 = _ok._0;
    } else {
      return _bind;
    }
    const _num_base = _bind$2._0;
    const _rest = _bind$2._1;
    const _allow_underscore = _bind$2._2;
    const overflow_threshold = _M0FPC17strconv19overflow__threshold(_num_base, neg);
    let has_digit;
    if (_M0MPC16string6String24char__length__ge_2einner(_rest.str, 1, _rest.start, _rest.end)) {
      const _x = _M0MPC16string6String16unsafe__char__at(_rest.str, _M0MPC16string6String29offset__of__nth__char_2einner(_rest.str, 0, _rest.start, _rest.end));
      if (_x >= 48 && _x <= 57) {
        has_digit = true;
      } else {
        if (_x >= 97 && _x <= 122) {
          has_digit = true;
        } else {
          if (_x >= 65 && _x <= 90) {
            has_digit = true;
          } else {
            if (_M0MPC16string6String24char__length__ge_2einner(_rest.str, 2, _rest.start, _rest.end)) {
              if (_x === 95) {
                const _x$2 = _M0MPC16string6String16unsafe__char__at(_rest.str, _M0MPC16string6String29offset__of__nth__char_2einner(_rest.str, 1, _rest.start, _rest.end));
                has_digit = _x$2 >= 48 && _x$2 <= 57 ? true : _x$2 >= 97 && _x$2 <= 122 ? true : _x$2 >= 65 && _x$2 <= 90;
              } else {
                has_digit = false;
              }
            } else {
              has_digit = false;
            }
          }
        }
      }
    } else {
      has_digit = false;
    }
    if (has_digit) {
      let _tmp;
      let _tmp$2 = _rest;
      let _tmp$3 = $0L;
      let _tmp$4 = _allow_underscore;
      while (true) {
        const _param_0 = _tmp$2;
        const _param_1 = _tmp$3;
        const _param_2 = _tmp$4;
        let acc;
        let rest$2;
        let c;
        _L$2: {
          if (_M0MPC16string6String24char__length__eq_2einner(_param_0.str, 1, _param_0.start, _param_0.end)) {
            const _x = _M0MPC16string6String16unsafe__char__at(_param_0.str, _M0MPC16string6String29offset__of__nth__char_2einner(_param_0.str, 0, _param_0.start, _param_0.end));
            if (_x === 95) {
              const _bind$3 = _M0FPC17strconv11syntax__errGlE();
              if (_bind$3.$tag === 1) {
                const _ok = _bind$3;
                _tmp = _ok._0;
                break;
              } else {
                return _bind$3;
              }
            } else {
              const _tmp$5 = _param_0.str;
              const _bind$3 = _M0MPC16string6String29offset__of__nth__char_2einner(_param_0.str, 1, _param_0.start, _param_0.end);
              let _tmp$6;
              if (_bind$3 === undefined) {
                _tmp$6 = _param_0.end;
              } else {
                const _Some = _bind$3;
                _tmp$6 = _Some;
              }
              const _x$2 = new _M0TPC16string10StringView(_tmp$5, _tmp$6, _param_0.end);
              acc = _param_1;
              rest$2 = _x$2;
              c = _x;
              break _L$2;
            }
          } else {
            if (_M0MPC16string6String24char__length__ge_2einner(_param_0.str, 1, _param_0.start, _param_0.end)) {
              const _x = _M0MPC16string6String16unsafe__char__at(_param_0.str, _M0MPC16string6String29offset__of__nth__char_2einner(_param_0.str, 0, _param_0.start, _param_0.end));
              if (_x === 95) {
                if (_param_2 === false) {
                  const _bind$3 = _M0FPC17strconv11syntax__errGlE();
                  if (_bind$3.$tag === 1) {
                    const _ok = _bind$3;
                    _tmp = _ok._0;
                    break;
                  } else {
                    return _bind$3;
                  }
                } else {
                  const _tmp$5 = _param_0.str;
                  const _bind$3 = _M0MPC16string6String29offset__of__nth__char_2einner(_param_0.str, 1, _param_0.start, _param_0.end);
                  let _tmp$6;
                  if (_bind$3 === undefined) {
                    _tmp$6 = _param_0.end;
                  } else {
                    const _Some = _bind$3;
                    _tmp$6 = _Some;
                  }
                  const _x$2 = new _M0TPC16string10StringView(_tmp$5, _tmp$6, _param_0.end);
                  _tmp$2 = _x$2;
                  _tmp$4 = false;
                  continue;
                }
              } else {
                const _tmp$5 = _param_0.str;
                const _bind$3 = _M0MPC16string6String29offset__of__nth__char_2einner(_param_0.str, 1, _param_0.start, _param_0.end);
                let _tmp$6;
                if (_bind$3 === undefined) {
                  _tmp$6 = _param_0.end;
                } else {
                  const _Some = _bind$3;
                  _tmp$6 = _Some;
                }
                const _x$2 = new _M0TPC16string10StringView(_tmp$5, _tmp$6, _param_0.end);
                acc = _param_1;
                rest$2 = _x$2;
                c = _x;
                break _L$2;
              }
            } else {
              _tmp = _param_1;
              break;
            }
          }
        }
        const c$2 = c;
        let d;
        if (c$2 >= 48 && c$2 <= 57) {
          d = c$2 - 48 | 0;
        } else {
          if (c$2 >= 97 && c$2 <= 122) {
            d = c$2 + -87 | 0;
          } else {
            if (c$2 >= 65 && c$2 <= 90) {
              d = c$2 + -55 | 0;
            } else {
              const _bind$3 = _M0FPC17strconv11syntax__errGiE();
              if (_bind$3.$tag === 1) {
                const _ok = _bind$3;
                d = _ok._0;
              } else {
                return _bind$3;
              }
            }
          }
        }
        if (d < _num_base) {
          if (neg) {
            if (_M0IP016_24default__implPB7Compare6op__geGlE(acc, overflow_threshold)) {
              const next_acc = _M0IPC15int645Int64PB3Sub3sub(_M0IPC15int645Int64PB3Mul3mul(acc, _M0MPC13int3Int9to__int64(_num_base)), _M0MPC13int3Int9to__int64(d));
              if (_M0IP016_24default__implPB7Compare6op__leGlE(next_acc, acc)) {
                _tmp$2 = rest$2;
                _tmp$3 = next_acc;
                _tmp$4 = true;
                continue;
              } else {
                const _bind$3 = _M0FPC17strconv10range__errGlE();
                if (_bind$3.$tag === 1) {
                  const _ok = _bind$3;
                  _tmp = _ok._0;
                  break;
                } else {
                  return _bind$3;
                }
              }
            } else {
              const _bind$3 = _M0FPC17strconv10range__errGlE();
              if (_bind$3.$tag === 1) {
                const _ok = _bind$3;
                _tmp = _ok._0;
                break;
              } else {
                return _bind$3;
              }
            }
          } else {
            if (_M0IP016_24default__implPB7Compare6op__ltGlE(acc, overflow_threshold)) {
              const next_acc = _M0IPC15int645Int64PB3Add3add(_M0IPC15int645Int64PB3Mul3mul(acc, _M0MPC13int3Int9to__int64(_num_base)), _M0MPC13int3Int9to__int64(d));
              if (_M0IP016_24default__implPB7Compare6op__geGlE(next_acc, acc)) {
                _tmp$2 = rest$2;
                _tmp$3 = next_acc;
                _tmp$4 = true;
                continue;
              } else {
                const _bind$3 = _M0FPC17strconv10range__errGlE();
                if (_bind$3.$tag === 1) {
                  const _ok = _bind$3;
                  _tmp = _ok._0;
                  break;
                } else {
                  return _bind$3;
                }
              }
            } else {
              const _bind$3 = _M0FPC17strconv10range__errGlE();
              if (_bind$3.$tag === 1) {
                const _ok = _bind$3;
                _tmp = _ok._0;
                break;
              } else {
                return _bind$3;
              }
            }
          }
        } else {
          const _bind$3 = _M0FPC17strconv11syntax__errGlE();
          if (_bind$3.$tag === 1) {
            const _ok = _bind$3;
            _tmp = _ok._0;
            break;
          } else {
            return _bind$3;
          }
        }
      }
      return new _M0DTPC16result6ResultGlRPC17strconv12StrConvErrorE2Ok(_tmp);
    } else {
      return _M0FPC17strconv11syntax__errGlE();
    }
  } else {
    return _M0FPC17strconv11syntax__errGlE();
  }
}
function _M0FPC17strconv18parse__int_2einner(str, base) {
  const _bind = _M0FPC17strconv20parse__int64_2einner(str, base);
  let n;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    n = _ok._0;
  } else {
    return _bind;
  }
  if (_M0IP016_24default__implPB7Compare6op__ltGlE(n, _M0MPC13int3Int9to__int64(-2147483648)) || _M0IP016_24default__implPB7Compare6op__gtGlE(n, _M0MPC13int3Int9to__int64(2147483647))) {
    const _bind$2 = _M0FPC17strconv10range__errGuE();
    if (_bind$2.$tag === 1) {
      const _ok = _bind$2;
      _ok._0;
    } else {
      return _bind$2;
    }
  }
  return new _M0DTPC16result6ResultGiRPC17strconv12StrConvErrorE2Ok(_M0MPC15int645Int647to__int(n));
}
function _M0FP311moonbitlang1x6crypto28bytes__u8__to__u32be_2einner(x, i) {
  $bound_check(x, i);
  const _p = x[i];
  const _tmp = _p << 24;
  const _tmp$2 = i + 1 | 0;
  $bound_check(x, _tmp$2);
  const _p$2 = x[_tmp$2];
  const _tmp$3 = _tmp | _p$2 << 16;
  const _tmp$4 = i + 2 | 0;
  $bound_check(x, _tmp$4);
  const _p$3 = x[_tmp$4];
  const _tmp$5 = _tmp$3 | _p$3 << 8;
  const _tmp$6 = i + 3 | 0;
  $bound_check(x, _tmp$6);
  const _p$4 = x[_tmp$6];
  return _tmp$5 | _p$4;
}
function _M0FP311moonbitlang1x6crypto24arr__u32__to__u8be__into(x, buffer, offset) {
  const idx = new _M0TPB8MutLocalGiE(offset);
  while (true) {
    const _p = _M0MPB4Iter4nextGjE(x);
    if (_p === undefined) {
      return;
    } else {
      const _p$2 = _p;
      const _p$3 = _p$2;
      const _tmp = idx.val;
      const _p$4 = _p$3 >>> 24 | 0;
      $bound_check(buffer, _tmp);
      buffer[_tmp] = _p$4 & 255;
      const _tmp$2 = idx.val + 1 | 0;
      const _p$5 = _p$3 >>> 16 | 0;
      $bound_check(buffer, _tmp$2);
      buffer[_tmp$2] = _p$5 & 255;
      const _tmp$3 = idx.val + 2 | 0;
      const _p$6 = _p$3 >>> 8 | 0;
      $bound_check(buffer, _tmp$3);
      buffer[_tmp$3] = _p$6 & 255;
      const _tmp$4 = idx.val + 3 | 0;
      $bound_check(buffer, _tmp$4);
      buffer[_tmp$4] = _p$3 & 255;
      idx.val = idx.val + 4 | 0;
      continue;
    }
  }
}
function _M0MP311moonbitlang1x6crypto6SHA25611new_2einner(reg) {
  return new _M0TP311moonbitlang1x6crypto6SHA256(reg, $0L, $makebytes(64, 0), 0);
}
function _M0MP311moonbitlang1x6crypto6SHA2563new(reg$46$opt) {
  let reg;
  if (reg$46$opt === undefined) {
    reg = [1779033703, -1150833019, 1013904242, -1521486534, 1359893119, -1694144372, 528734635, 1541459225];
  } else {
    const _Some = reg$46$opt;
    reg = _Some;
  }
  return _M0MP311moonbitlang1x6crypto6SHA25611new_2einner(reg);
}
function _M0MP311moonbitlang1x6crypto6SHA2569transform(data, reg) {
  const w = $make_array_len_and_init(64, 0);
  if (reg.length === 8) {
    let a = reg[0];
    let b = reg[1];
    let c = reg[2];
    let d = reg[3];
    let e = reg[4];
    let f = reg[5];
    let g = reg[6];
    let h = reg[7];
    let _tmp = 0;
    while (true) {
      const index = _tmp;
      if (index < 16) {
        $bound_check(w, index);
        w[index] = _M0FP311moonbitlang1x6crypto28bytes__u8__to__u32be_2einner(data, Math.imul(4, index) | 0);
        _tmp = index + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    let _tmp$2 = 16;
    while (true) {
      const index = _tmp$2;
      if (index < 64) {
        const _tmp$3 = index - 15 | 0;
        $bound_check(w, _tmp$3);
        const _p = w[_tmp$3];
        const _p$2 = 7;
        const _tmp$4 = _p >>> _p$2 | _p << (32 - _p$2 | 0);
        const _tmp$5 = index - 15 | 0;
        $bound_check(w, _tmp$5);
        const _p$3 = w[_tmp$5];
        const _p$4 = 18;
        const _tmp$6 = _tmp$4 ^ (_p$3 >>> _p$4 | _p$3 << (32 - _p$4 | 0));
        const _tmp$7 = index - 15 | 0;
        $bound_check(w, _tmp$7);
        const sigma_0 = _tmp$6 ^ (w[_tmp$7] >>> 3 | 0);
        const _tmp$8 = index - 2 | 0;
        $bound_check(w, _tmp$8);
        const _p$5 = w[_tmp$8];
        const _p$6 = 17;
        const _tmp$9 = _p$5 >>> _p$6 | _p$5 << (32 - _p$6 | 0);
        const _tmp$10 = index - 2 | 0;
        $bound_check(w, _tmp$10);
        const _p$7 = w[_tmp$10];
        const _p$8 = 19;
        const _tmp$11 = _tmp$9 ^ (_p$7 >>> _p$8 | _p$7 << (32 - _p$8 | 0));
        const _tmp$12 = index - 2 | 0;
        $bound_check(w, _tmp$12);
        const sigma_1 = _tmp$11 ^ (w[_tmp$12] >>> 10 | 0);
        const _tmp$13 = index - 16 | 0;
        $bound_check(w, _tmp$13);
        const _tmp$14 = (w[_tmp$13] >>> 0) + (sigma_0 >>> 0) | 0;
        const _tmp$15 = index - 7 | 0;
        $bound_check(w, _tmp$15);
        $bound_check(w, index);
        w[index] = (((_tmp$14 >>> 0) + (w[_tmp$15] >>> 0) | 0) >>> 0) + (sigma_1 >>> 0) | 0;
        _tmp$2 = index + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    let _tmp$3 = 0;
    while (true) {
      const index = _tmp$3;
      if (index < 64) {
        const _p = e;
        const _p$2 = 6;
        const _tmp$4 = _p >>> _p$2 | _p << (32 - _p$2 | 0);
        const _p$3 = e;
        const _p$4 = 11;
        const _tmp$5 = _tmp$4 ^ (_p$3 >>> _p$4 | _p$3 << (32 - _p$4 | 0));
        const _p$5 = e;
        const _p$6 = 25;
        const big_sigma_1 = _tmp$5 ^ (_p$5 >>> _p$6 | _p$5 << (32 - _p$6 | 0));
        const _tmp$6 = (h >>> 0) + (big_sigma_1 >>> 0) | 0;
        const _p$7 = e;
        const _p$8 = f;
        const _p$9 = g;
        const _tmp$7 = (_tmp$6 >>> 0) + (((_p$8 ^ _p$9) & _p$7 ^ _p$9) >>> 0) | 0;
        $bound_check(_M0FP311moonbitlang1x6crypto9sha256__t, index);
        const _tmp$8 = (_tmp$7 >>> 0) + (_M0FP311moonbitlang1x6crypto9sha256__t[index] >>> 0) | 0;
        $bound_check(w, index);
        const t_1 = (_tmp$8 >>> 0) + (w[index] >>> 0) | 0;
        const _p$10 = a;
        const _p$11 = 2;
        const _tmp$9 = _p$10 >>> _p$11 | _p$10 << (32 - _p$11 | 0);
        const _p$12 = a;
        const _p$13 = 13;
        const _tmp$10 = _tmp$9 ^ (_p$12 >>> _p$13 | _p$12 << (32 - _p$13 | 0));
        const _p$14 = a;
        const _p$15 = 22;
        const big_sigma_0 = _tmp$10 ^ (_p$14 >>> _p$15 | _p$14 << (32 - _p$15 | 0));
        const _p$16 = a;
        const _p$17 = b;
        const _p$18 = c;
        const t_2 = (big_sigma_0 >>> 0) + ((_p$16 & _p$17 | _p$16 & _p$18 | _p$17 & _p$18) >>> 0) | 0;
        h = g;
        g = f;
        f = e;
        e = (d >>> 0) + (t_1 >>> 0) | 0;
        d = c;
        c = b;
        b = a;
        a = (t_1 >>> 0) + (t_2 >>> 0) | 0;
        _tmp$3 = index + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    reg[0] = (reg[0] >>> 0) + (a >>> 0) | 0;
    reg[1] = (reg[1] >>> 0) + (b >>> 0) | 0;
    reg[2] = (reg[2] >>> 0) + (c >>> 0) | 0;
    reg[3] = (reg[3] >>> 0) + (d >>> 0) | 0;
    reg[4] = (reg[4] >>> 0) + (e >>> 0) | 0;
    reg[5] = (reg[5] >>> 0) + (f >>> 0) | 0;
    reg[6] = (reg[6] >>> 0) + (g >>> 0) | 0;
    reg[7] = (reg[7] >>> 0) + (h >>> 0) | 0;
    return;
  } else {
    $panic();
    return;
  }
}
function _M0MP311moonbitlang1x6crypto6SHA2566updateGzE(self, data) {
  let offset = 0;
  while (true) {
    if (offset < data.length) {
      const min_len = (64 - self.buf_index | 0) >= (data.length - offset | 0) ? data.length - offset | 0 : 64 - self.buf_index | 0;
      _M0IPC15bytes5BytesP311moonbitlang1x6crypto10ByteSource8blit__to(data, self.buf, min_len, offset, self.buf_index);
      self.buf_index = self.buf_index + min_len | 0;
      if (self.buf_index === 64) {
        self.len = _M0IPC16uint646UInt64PB3Add3add(self.len, $512L);
        self.buf_index = 0;
        _M0MP311moonbitlang1x6crypto6SHA2569transform(self.buf, self.reg);
      }
      offset = offset + min_len | 0;
      continue;
    } else {
      return;
    }
  }
}
function _M0MP311moonbitlang1x6crypto6SHA25624__finalize__into_2einner(self, buffer, size, offset) {
  const data = $makebytes(64, 0);
  let cnt = self.buf_index;
  const len = _M0IPC16uint646UInt64PB3Add3add(self.len, _M0IPC16uint646UInt64PB3Mul3mul($8L, _M0MPC13int3Int10to__uint64(cnt)));
  _M0MPC15array10FixedArray16blit__to_2einnerGyE(self.buf, data, cnt, 0, 0);
  const reg = _M0MPC15array10FixedArray4copyGjE(self.reg);
  const _tmp = cnt;
  $bound_check(data, _tmp);
  data[_tmp] = 128;
  cnt = cnt + 1 | 0;
  if (cnt > 56) {
    _M0MP311moonbitlang1x6crypto6SHA2569transform(data, reg);
    _M0MPC15array10FixedArray12fill_2einnerGyE(data, 0, 0, undefined);
  }
  data[56] = _M0MPC16uint646UInt648to__byte(_M0IPC16uint646UInt64PB3Shr3shr(len, 56));
  data[57] = _M0MPC16uint646UInt648to__byte(_M0IPC16uint646UInt64PB3Shr3shr(len, 48));
  data[58] = _M0MPC16uint646UInt648to__byte(_M0IPC16uint646UInt64PB3Shr3shr(len, 40));
  data[59] = _M0MPC16uint646UInt648to__byte(_M0IPC16uint646UInt64PB3Shr3shr(len, 32));
  data[60] = _M0MPC16uint646UInt648to__byte(_M0IPC16uint646UInt64PB3Shr3shr(len, 24));
  data[61] = _M0MPC16uint646UInt648to__byte(_M0IPC16uint646UInt64PB3Shr3shr(len, 16));
  data[62] = _M0MPC16uint646UInt648to__byte(_M0IPC16uint646UInt64PB3Shr3shr(len, 8));
  data[63] = _M0MPC16uint646UInt648to__byte(_M0IPC16uint646UInt64PB3Shr3shr(len, 0));
  _M0MP311moonbitlang1x6crypto6SHA2569transform(data, reg);
  _M0FP311moonbitlang1x6crypto24arr__u32__to__u8be__into(_M0MPB4Iter4takeGjE(_M0MPC15array10FixedArray4iterGjE(reg), size), buffer, offset);
}
function _M0MP311moonbitlang1x6crypto6SHA2568finalize(self) {
  const ret = $makebytes(32, 0);
  _M0MP311moonbitlang1x6crypto6SHA25624__finalize__into_2einner(self, ret, 8, 0);
  return ret;
}
function _M0IPC15bytes5BytesP311moonbitlang1x6crypto10ByteSource8blit__to(self, dst, len, src_offset, dst_offset) {
  _M0MPC15array10FixedArray17blit__from__bytes(dst, dst_offset, self, src_offset, len);
}
function _M0MP36mizchi3bit4hash11Sha256State3new() {
  return new _M0TP36mizchi3bit4hash11Sha256State(_M0MP311moonbitlang1x6crypto6SHA2563new(undefined));
}
function _M0MP36mizchi3bit4hash11Sha256State6update(self, data) {
  _M0MP311moonbitlang1x6crypto6SHA2566updateGzE(self.inner, data);
}
function _M0MP36mizchi3bit4hash11Sha256State14update__string(self, s) {
  _M0MP36mizchi3bit4hash11Sha256State6update(self, _M0FPC28encoding4utf814encode_2einner(new _M0TPC16string10StringView(s, 0, s.length), false));
}
function _M0MP36mizchi3bit4hash11Sha256State11finish__raw(self) {
  return _M0MP311moonbitlang1x6crypto6SHA2568finalize(self.inner);
}
function _M0FP36mizchi3bit4hash6rotl32(x, n) {
  return (x << n | (x >>> (32 - n | 0) | 0)) & -1;
}
function _M0MP36mizchi3bit4hash9Sha1State3new() {
  return new _M0TP36mizchi3bit4hash9Sha1State([1732584193, -271733879, -1732584194, 271733878, -1009589776], $makebytes(64, 0), $make_array_len_and_init(80, 0), 0, $0L);
}
function _M0MP36mizchi3bit4hash9Sha1State14process__block(self) {
  const h = self.h;
  const w = self.w;
  const block = self.block;
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < 16) {
      const _tmp$2 = Math.imul(i, 4) | 0;
      $bound_check(block, _tmp$2);
      const _tmp$3 = block[_tmp$2] << 24;
      const _tmp$4 = (Math.imul(i, 4) | 0) + 1 | 0;
      $bound_check(block, _tmp$4);
      const _tmp$5 = _tmp$3 | block[_tmp$4] << 16;
      const _tmp$6 = (Math.imul(i, 4) | 0) + 2 | 0;
      $bound_check(block, _tmp$6);
      const _tmp$7 = _tmp$5 | block[_tmp$6] << 8;
      const _tmp$8 = (Math.imul(i, 4) | 0) + 3 | 0;
      $bound_check(block, _tmp$8);
      $bound_check(w, i);
      w[i] = _tmp$7 | block[_tmp$8];
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  let _tmp$2 = 16;
  while (true) {
    const i = _tmp$2;
    if (i < 80) {
      const _tmp$3 = i - 3 | 0;
      $bound_check(w, _tmp$3);
      const _tmp$4 = w[_tmp$3];
      const _tmp$5 = i - 8 | 0;
      $bound_check(w, _tmp$5);
      const _tmp$6 = _tmp$4 ^ w[_tmp$5];
      const _tmp$7 = i - 14 | 0;
      $bound_check(w, _tmp$7);
      const _tmp$8 = _tmp$6 ^ w[_tmp$7];
      const _tmp$9 = i - 16 | 0;
      $bound_check(w, _tmp$9);
      $bound_check(w, i);
      w[i] = _M0FP36mizchi3bit4hash6rotl32(_tmp$8 ^ w[_tmp$9], 1);
      _tmp$2 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  $bound_check(h, 0);
  let a = h[0];
  $bound_check(h, 1);
  let b = h[1];
  $bound_check(h, 2);
  let c = h[2];
  $bound_check(h, 3);
  let d = h[3];
  $bound_check(h, 4);
  let e = h[4];
  let _tmp$3 = 0;
  while (true) {
    const i = _tmp$3;
    if (i < 20) {
      const f = b & c | ~b & d;
      const _tmp$4 = ((_M0FP36mizchi3bit4hash6rotl32(a, 5) + f | 0) + e | 0) + 1518500249 | 0;
      $bound_check(w, i);
      const temp = _tmp$4 + w[i] & -1;
      e = d;
      d = c;
      c = _M0FP36mizchi3bit4hash6rotl32(b, 30);
      b = a;
      a = temp;
      _tmp$3 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  let _tmp$4 = 20;
  while (true) {
    const i = _tmp$4;
    if (i < 40) {
      const f = b ^ c ^ d;
      const _tmp$5 = ((_M0FP36mizchi3bit4hash6rotl32(a, 5) + f | 0) + e | 0) + 1859775393 | 0;
      $bound_check(w, i);
      const temp = _tmp$5 + w[i] & -1;
      e = d;
      d = c;
      c = _M0FP36mizchi3bit4hash6rotl32(b, 30);
      b = a;
      a = temp;
      _tmp$4 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  let _tmp$5 = 40;
  while (true) {
    const i = _tmp$5;
    if (i < 60) {
      const f = b & c | b & d | c & d;
      const _tmp$6 = ((_M0FP36mizchi3bit4hash6rotl32(a, 5) + f | 0) + e | 0) + -1894007588 | 0;
      $bound_check(w, i);
      const temp = _tmp$6 + w[i] & -1;
      e = d;
      d = c;
      c = _M0FP36mizchi3bit4hash6rotl32(b, 30);
      b = a;
      a = temp;
      _tmp$5 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  let _tmp$6 = 60;
  while (true) {
    const i = _tmp$6;
    if (i < 80) {
      const f = b ^ c ^ d;
      const _tmp$7 = ((_M0FP36mizchi3bit4hash6rotl32(a, 5) + f | 0) + e | 0) + -899497514 | 0;
      $bound_check(w, i);
      const temp = _tmp$7 + w[i] & -1;
      e = d;
      d = c;
      c = _M0FP36mizchi3bit4hash6rotl32(b, 30);
      b = a;
      a = temp;
      _tmp$6 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  $bound_check(h, 0);
  $bound_check(h, 0);
  h[0] = h[0] + a & -1;
  $bound_check(h, 1);
  $bound_check(h, 1);
  h[1] = h[1] + b & -1;
  $bound_check(h, 2);
  $bound_check(h, 2);
  h[2] = h[2] + c & -1;
  $bound_check(h, 3);
  $bound_check(h, 3);
  h[3] = h[3] + d & -1;
  $bound_check(h, 4);
  $bound_check(h, 4);
  h[4] = h[4] + e & -1;
}
function _M0MP36mizchi3bit4hash9Sha1State13update__slice(self, data, offset, len) {
  let pos = offset;
  const end = offset + len | 0;
  self.total_len = _M0IPC15int645Int64PB3Add3add(self.total_len, _M0MPC13int3Int9to__int64(len));
  while (true) {
    if (pos < end) {
      const space = 64 - self.block_len | 0;
      const to_copy = (end - pos | 0) < space ? end - pos | 0 : space;
      let _tmp = 0;
      while (true) {
        const i = _tmp;
        if (i < to_copy) {
          const _tmp$2 = self.block;
          const _tmp$3 = self.block_len + i | 0;
          const _tmp$4 = pos + i | 0;
          $bound_check(data, _tmp$4);
          $bound_check(_tmp$2, _tmp$3);
          _tmp$2[_tmp$3] = data[_tmp$4];
          _tmp = i + 1 | 0;
          continue;
        } else {
          break;
        }
      }
      self.block_len = self.block_len + to_copy | 0;
      pos = pos + to_copy | 0;
      if (self.block_len === 64) {
        _M0MP36mizchi3bit4hash9Sha1State14process__block(self);
        self.block_len = 0;
      }
      continue;
    } else {
      return;
    }
  }
}
function _M0MP36mizchi3bit4hash9Sha1State6update(self, data) {
  _M0MP36mizchi3bit4hash9Sha1State13update__slice(self, data, 0, data.length);
}
function _M0MP36mizchi3bit4hash9Sha1State14update__string(self, s) {
  _M0MP36mizchi3bit4hash9Sha1State6update(self, _M0FPC28encoding4utf814encode_2einner(new _M0TPC16string10StringView(s, 0, s.length), false));
}
function _M0MP36mizchi3bit4hash9Sha1State11finish__raw(self) {
  const bit_len = _M0IPC15int645Int64PB3Mul3mul(self.total_len, $8L);
  const _tmp = self.block;
  const _tmp$2 = self.block_len;
  $bound_check(_tmp, _tmp$2);
  _tmp[_tmp$2] = 128;
  self.block_len = self.block_len + 1 | 0;
  if (self.block_len > 56) {
    while (true) {
      if (self.block_len < 64) {
        const _tmp$3 = self.block;
        const _tmp$4 = self.block_len;
        $bound_check(_tmp$3, _tmp$4);
        _tmp$3[_tmp$4] = 0;
        self.block_len = self.block_len + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    _M0MP36mizchi3bit4hash9Sha1State14process__block(self);
    self.block_len = 0;
  }
  while (true) {
    if (self.block_len < 56) {
      const _tmp$3 = self.block;
      const _tmp$4 = self.block_len;
      $bound_check(_tmp$3, _tmp$4);
      _tmp$3[_tmp$4] = 0;
      self.block_len = self.block_len + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const _tmp$3 = self.block;
  $bound_check(_tmp$3, 56);
  _tmp$3[56] = _M0MPC15int645Int648to__byte(_M0IPC15int645Int64PB6BitAnd4land(_M0IPC15int645Int64PB3Shr3shr(bit_len, 56), $255L));
  const _tmp$4 = self.block;
  $bound_check(_tmp$4, 57);
  _tmp$4[57] = _M0MPC15int645Int648to__byte(_M0IPC15int645Int64PB6BitAnd4land(_M0IPC15int645Int64PB3Shr3shr(bit_len, 48), $255L));
  const _tmp$5 = self.block;
  $bound_check(_tmp$5, 58);
  _tmp$5[58] = _M0MPC15int645Int648to__byte(_M0IPC15int645Int64PB6BitAnd4land(_M0IPC15int645Int64PB3Shr3shr(bit_len, 40), $255L));
  const _tmp$6 = self.block;
  $bound_check(_tmp$6, 59);
  _tmp$6[59] = _M0MPC15int645Int648to__byte(_M0IPC15int645Int64PB6BitAnd4land(_M0IPC15int645Int64PB3Shr3shr(bit_len, 32), $255L));
  const _tmp$7 = self.block;
  $bound_check(_tmp$7, 60);
  _tmp$7[60] = _M0MPC15int645Int648to__byte(_M0IPC15int645Int64PB6BitAnd4land(_M0IPC15int645Int64PB3Shr3shr(bit_len, 24), $255L));
  const _tmp$8 = self.block;
  $bound_check(_tmp$8, 61);
  _tmp$8[61] = _M0MPC15int645Int648to__byte(_M0IPC15int645Int64PB6BitAnd4land(_M0IPC15int645Int64PB3Shr3shr(bit_len, 16), $255L));
  const _tmp$9 = self.block;
  $bound_check(_tmp$9, 62);
  _tmp$9[62] = _M0MPC15int645Int648to__byte(_M0IPC15int645Int64PB6BitAnd4land(_M0IPC15int645Int64PB3Shr3shr(bit_len, 8), $255L));
  const _tmp$10 = self.block;
  $bound_check(_tmp$10, 63);
  _tmp$10[63] = _M0MPC15int645Int648to__byte(_M0IPC15int645Int64PB6BitAnd4land(bit_len, $255L));
  _M0MP36mizchi3bit4hash9Sha1State14process__block(self);
  const result = $makebytes(20, 0);
  let _tmp$11 = 0;
  while (true) {
    const i = _tmp$11;
    if (i < 5) {
      const _tmp$12 = Math.imul(i, 4) | 0;
      const _tmp$13 = self.h;
      $bound_check(_tmp$13, i);
      $bound_check(result, _tmp$12);
      result[_tmp$12] = _tmp$13[i] >> 24 & 255;
      const _tmp$14 = (Math.imul(i, 4) | 0) + 1 | 0;
      const _tmp$15 = self.h;
      $bound_check(_tmp$15, i);
      $bound_check(result, _tmp$14);
      result[_tmp$14] = _tmp$15[i] >> 16 & 255;
      const _tmp$16 = (Math.imul(i, 4) | 0) + 2 | 0;
      const _tmp$17 = self.h;
      $bound_check(_tmp$17, i);
      $bound_check(result, _tmp$16);
      result[_tmp$16] = _tmp$17[i] >> 8 & 255;
      const _tmp$18 = (Math.imul(i, 4) | 0) + 3 | 0;
      const _tmp$19 = self.h;
      $bound_check(_tmp$19, i);
      $bound_check(result, _tmp$18);
      result[_tmp$18] = _tmp$19[i] & 255;
      _tmp$11 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return result;
}
function _M0FP36mizchi3bit4hash17sha1__prefix__raw(data, len) {
  const msg_len = len < 0 ? 0 : len > data.length ? data.length : len;
  const state = _M0MP36mizchi3bit4hash9Sha1State3new();
  _M0MP36mizchi3bit4hash9Sha1State13update__slice(state, data, 0, msg_len);
  return _M0MP36mizchi3bit4hash9Sha1State11finish__raw(state);
}
function _M0FP36mizchi3bit4hash9sha1__raw(data) {
  return _M0FP36mizchi3bit4hash17sha1__prefix__raw(data, data.length);
}
function _M0IP26mizchi4zlib9ZlibErrorPB4Show6output(_x_516, _x_517) {
  const _InvalidData = _x_516;
  const _$42$arg_518 = _InvalidData._0;
  _x_517.method_table.method_0(_x_517.self, "InvalidData(");
  _M0MPB6Logger13write__objectGsE(_x_517, _$42$arg_518);
  _x_517.method_table.method_0(_x_517.self, ")");
}
function _M0FP26mizchi4zlib14adler32__bytes(data) {
  let s1 = 1;
  let s2 = 0;
  let i = 0;
  const len = data.length;
  while (true) {
    if (i < len) {
      const remaining = len - i | 0;
      const chunk = remaining > 5552 ? 5552 : remaining;
      let _tmp = 0;
      while (true) {
        const j = _tmp;
        if (j < chunk) {
          const _tmp$2 = i + j | 0;
          $bound_check(data, _tmp$2);
          const _p = data[_tmp$2];
          const byte_val = _p;
          s1 = (s1 >>> 0) + (byte_val >>> 0) | 0;
          s2 = (s2 >>> 0) + (s1 >>> 0) | 0;
          _tmp = j + 1 | 0;
          continue;
        } else {
          break;
        }
      }
      s1 = (s1 >>> 0) % (_M0FP26mizchi4zlib10adler__mod >>> 0) | 0;
      s2 = (s2 >>> 0) % (_M0FP26mizchi4zlib10adler__mod >>> 0) | 0;
      i = i + chunk | 0;
      continue;
    } else {
      break;
    }
  }
  return s2 << 16 | s1;
}
function _M0FP26mizchi4zlib7adler32(data) {
  return _M0FP26mizchi4zlib14adler32__bytes(data);
}
function _M0FP26mizchi4zlib14write__u32__be(out, offset, v) {
  $bound_check(out, offset);
  out[offset] = v >> 24 & 255;
  const _tmp = offset + 1 | 0;
  $bound_check(out, _tmp);
  out[_tmp] = v >> 16 & 255;
  const _tmp$2 = offset + 2 | 0;
  $bound_check(out, _tmp$2);
  out[_tmp$2] = v >> 8 & 255;
  const _tmp$3 = offset + 3 | 0;
  $bound_check(out, _tmp$3);
  out[_tmp$3] = v & 255;
}
function _M0FP26mizchi4zlib18bytes__from__array(arr) {
  const _bind = _M0MPC15array10FixedArray5makeiGyE(arr.length, (i) => _M0MPC15array5Array2atGyE(arr, i));
  return _M0MPC15bytes5Bytes11from__array(new _M0TPB9ArrayViewGyE(_bind, 0, _bind.length));
}
function _M0FP26mizchi4zlib18all__zero__lengths(lengths) {
  const _bind = lengths.length;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind) {
      const len = lengths[_];
      if (len !== 0) {
        return false;
      }
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return true;
}
function _M0FP26mizchi4zlib13reverse__bits(code, len) {
  let result = 0;
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < len) {
      const bit = code >> i & 1;
      result = result << 1 | bit;
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return result;
}
function _M0MP26mizchi4zlib11HuffmanTree9add__node(self) {
  _M0MPC15array5Array4pushGiE(self.left, -1);
  _M0MPC15array5Array4pushGiE(self.right, -1);
  _M0MPC15array5Array4pushGiE(self.symbol, -1);
  return self.left.length - 1 | 0;
}
function _M0MP26mizchi4zlib11HuffmanTree6insert(self, code, len, sym) {
  if (len === 0) {
    return new _M0DTPC16result6ResultGuRP26mizchi4zlib9ZlibErrorE2Ok(undefined);
  }
  let node = 0;
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < len) {
      const bit = code >> i & 1;
      const next = bit === 0 ? _M0MPC15array5Array2atGiE(self.left, node) : _M0MPC15array5Array2atGiE(self.right, node);
      let child;
      if (next === -1) {
        const idx = _M0MP26mizchi4zlib11HuffmanTree9add__node(self);
        if (bit === 0) {
          _M0MPC15array5Array3setGiE(self.left, node, idx);
        } else {
          _M0MPC15array5Array3setGiE(self.right, node, idx);
        }
        child = idx;
      } else {
        child = next;
      }
      node = child;
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  if (_M0MPC15array5Array2atGiE(self.symbol, node) !== -1) {
    return new _M0DTPC16result6ResultGuRP26mizchi4zlib9ZlibErrorE3Err(new _M0DTPC15error5Error39mizchi_2fzlib_2eZlibError_2eInvalidData("Invalid Huffman code"));
  }
  return new _M0DTPC16result6ResultGuRP26mizchi4zlib9ZlibErrorE2Ok(_M0MPC15array5Array3setGiE(self.symbol, node, sym));
}
function _M0MP26mizchi4zlib11HuffmanTree3new(table_bits) {
  const size = table_bits <= 0 ? 0 : 1 << table_bits;
  return new _M0TP26mizchi4zlib11HuffmanTree([-1], [-1], [-1], table_bits, $make_array_len_and_init(size, -1), $make_array_len_and_init(size, 0), $make_array_len_and_init(size, -1), [], [], []);
}
function _M0FP26mizchi4zlib20build__huffman__tree(lengths, max_bits) {
  const bl_count = $make_array_len_and_init(max_bits + 1 | 0, 0);
  const _bind = lengths.length;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind) {
      const len = lengths[_];
      if (len > 0) {
        $bound_check(bl_count, len);
        $bound_check(bl_count, len);
        bl_count[len] = bl_count[len] + 1 | 0;
      }
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const next_code = $make_array_len_and_init(max_bits + 1 | 0, 0);
  let code = 0;
  let _tmp$2 = 1;
  while (true) {
    const bits = _tmp$2;
    if (bits <= max_bits) {
      const _tmp$3 = code;
      const _tmp$4 = bits - 1 | 0;
      $bound_check(bl_count, _tmp$4);
      code = _tmp$3 + bl_count[_tmp$4] << 1;
      $bound_check(next_code, bits);
      next_code[bits] = code;
      _tmp$2 = bits + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const table_bits = max_bits > 9 ? 9 : max_bits;
  const tree = _M0MP26mizchi4zlib11HuffmanTree3new(table_bits);
  const rev_codes = [];
  const _bind$2 = lengths.length;
  let _tmp$3 = 0;
  while (true) {
    const _ = _tmp$3;
    if (_ < _bind$2) {
      _M0MPC15array5Array4pushGiE(rev_codes, 0);
      _tmp$3 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const next_code_work = $make_array_len_and_init(max_bits + 1 | 0, 0);
  let _tmp$4 = 0;
  while (true) {
    const i = _tmp$4;
    if (i <= max_bits) {
      $bound_check(next_code, i);
      $bound_check(next_code_work, i);
      next_code_work[i] = next_code[i];
      _tmp$4 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  let _tmp$5 = 0;
  while (true) {
    const i = _tmp$5;
    if (i < lengths.length) {
      const len = _M0MPC15array5Array2atGiE(lengths, i);
      if (len > 0) {
        $bound_check(next_code_work, len);
        const c = next_code_work[len];
        $bound_check(next_code_work, len);
        $bound_check(next_code_work, len);
        next_code_work[len] = next_code_work[len] + 1 | 0;
        _M0MPC15array5Array3setGiE(rev_codes, i, _M0FP26mizchi4zlib13reverse__bits(c, len));
      }
      _tmp$5 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  if (table_bits > 0) {
    const prefix_max = $make_array_len_and_init(1 << table_bits, 0);
    let _tmp$6 = 0;
    while (true) {
      const i = _tmp$6;
      if (i < lengths.length) {
        const len = _M0MPC15array5Array2atGiE(lengths, i);
        if (len > table_bits) {
          const rev = _M0MPC15array5Array2atGiE(rev_codes, i);
          const prefix = rev & ((1 << table_bits) - 1 | 0);
          $bound_check(prefix_max, prefix);
          if (len > prefix_max[prefix]) {
            $bound_check(prefix_max, prefix);
            prefix_max[prefix] = len;
          }
        }
        _tmp$6 = i + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    const _bind$3 = prefix_max.length;
    let _tmp$7 = 0;
    while (true) {
      const prefix = _tmp$7;
      if (prefix < _bind$3) {
        $bound_check(prefix_max, prefix);
        const max_len = prefix_max[prefix];
        if (max_len > table_bits) {
          const sub_bits = max_len - table_bits | 0;
          const size = 1 << sub_bits;
          const sub_idx = tree.sub_bits.length;
          _M0MPC15array5Array4pushGiE(tree.sub_bits, sub_bits);
          _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(tree.sub_symbol, $make_array_len_and_init(size, -1));
          _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(tree.sub_len, $make_array_len_and_init(size, 0));
          const _tmp$8 = tree.table_sub;
          $bound_check(_tmp$8, prefix);
          _tmp$8[prefix] = sub_idx;
        }
        _tmp$7 = prefix + 1 | 0;
        continue;
      } else {
        break;
      }
    }
  }
  let _tmp$6 = 0;
  while (true) {
    const i = _tmp$6;
    if (i < lengths.length) {
      const len = _M0MPC15array5Array2atGiE(lengths, i);
      if (len > 0) {
        const rev = _M0MPC15array5Array2atGiE(rev_codes, i);
        const _bind$3 = _M0MP26mizchi4zlib11HuffmanTree6insert(tree, rev, len, i);
        if (_bind$3.$tag === 1) {
          const _ok = _bind$3;
          _ok._0;
        } else {
          return _bind$3;
        }
        if (len <= table_bits) {
          const fill = 1 << (table_bits - len | 0);
          let _tmp$7 = 0;
          while (true) {
            const j = _tmp$7;
            if (j < fill) {
              const idx = rev | j << len;
              const _tmp$8 = tree.table_symbol;
              $bound_check(_tmp$8, idx);
              _tmp$8[idx] = i;
              const _tmp$9 = tree.table_len;
              $bound_check(_tmp$9, idx);
              _tmp$9[idx] = len;
              _tmp$7 = j + 1 | 0;
              continue;
            } else {
              break;
            }
          }
        } else {
          if (table_bits > 0) {
            const prefix = rev & ((1 << table_bits) - 1 | 0);
            const _tmp$7 = tree.table_sub;
            $bound_check(_tmp$7, prefix);
            const sub_idx = _tmp$7[prefix];
            if (sub_idx === -1) {
              return new _M0DTPC16result6ResultGRP26mizchi4zlib11HuffmanTreeRP26mizchi4zlib9ZlibErrorE3Err(new _M0DTPC15error5Error39mizchi_2fzlib_2eZlibError_2eInvalidData("Invalid Huffman subtable"));
            }
            const sub_bits = _M0MPC15array5Array2atGiE(tree.sub_bits, sub_idx);
            const sub_len = len - table_bits | 0;
            if (sub_len > sub_bits) {
              return new _M0DTPC16result6ResultGRP26mizchi4zlib11HuffmanTreeRP26mizchi4zlib9ZlibErrorE3Err(new _M0DTPC15error5Error39mizchi_2fzlib_2eZlibError_2eInvalidData("Invalid Huffman subtable width"));
            }
            const sub_code = rev >> table_bits;
            const fill = 1 << (sub_bits - sub_len | 0);
            let _tmp$8 = 0;
            while (true) {
              const j = _tmp$8;
              if (j < fill) {
                const idx = sub_code | j << sub_len;
                const _tmp$9 = _M0MPC15array5Array2atGUiiEE(tree.sub_symbol, sub_idx);
                $bound_check(_tmp$9, idx);
                if (_tmp$9[idx] !== -1) {
                  return new _M0DTPC16result6ResultGRP26mizchi4zlib11HuffmanTreeRP26mizchi4zlib9ZlibErrorE3Err(new _M0DTPC15error5Error39mizchi_2fzlib_2eZlibError_2eInvalidData("Invalid Huffman code"));
                }
                const _tmp$10 = _M0MPC15array5Array2atGUiiEE(tree.sub_symbol, sub_idx);
                $bound_check(_tmp$10, idx);
                _tmp$10[idx] = i;
                const _tmp$11 = _M0MPC15array5Array2atGUiiEE(tree.sub_len, sub_idx);
                $bound_check(_tmp$11, idx);
                _tmp$11[idx] = len;
                _tmp$8 = j + 1 | 0;
                continue;
              } else {
                break;
              }
            }
          }
        }
      }
      _tmp$6 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return new _M0DTPC16result6ResultGRP26mizchi4zlib11HuffmanTreeRP26mizchi4zlib9ZlibErrorE2Ok(tree);
}
function _M0MP26mizchi4zlib9BitReader10drop__bits(self, n) {
  if (n === 0) {
    return undefined;
  }
  self.bit_buf = _M0IPC16uint646UInt64PB3Shr3shr(self.bit_buf, n);
  self.bit_count = self.bit_count - n | 0;
}
function _M0MP26mizchi4zlib9BitReader12ensure__bits(self, n) {
  while (true) {
    if (self.bit_count < n) {
      const remaining = self.data.length - self.byte_pos | 0;
      if (remaining <= 0) {
        return new _M0DTPC16result6ResultGuRP26mizchi4zlib9ZlibErrorE3Err(new _M0DTPC15error5Error39mizchi_2fzlib_2eZlibError_2eInvalidData("Unexpected end of deflate stream"));
      }
      if (remaining >= 4 && self.bit_count <= 32) {
        const _tmp = self.data;
        const _tmp$2 = self.byte_pos;
        $bound_check(_tmp, _tmp$2);
        const b0 = _M0MPC14byte4Byte10to__uint64(_tmp[_tmp$2]);
        const _tmp$3 = self.data;
        const _tmp$4 = self.byte_pos + 1 | 0;
        $bound_check(_tmp$3, _tmp$4);
        const b1 = _M0MPC14byte4Byte10to__uint64(_tmp$3[_tmp$4]);
        const _tmp$5 = self.data;
        const _tmp$6 = self.byte_pos + 2 | 0;
        $bound_check(_tmp$5, _tmp$6);
        const b2 = _M0MPC14byte4Byte10to__uint64(_tmp$5[_tmp$6]);
        const _tmp$7 = self.data;
        const _tmp$8 = self.byte_pos + 3 | 0;
        $bound_check(_tmp$7, _tmp$8);
        const b3 = _M0MPC14byte4Byte10to__uint64(_tmp$7[_tmp$8]);
        self.byte_pos = self.byte_pos + 4 | 0;
        self.bit_buf = _M0IPC16uint646UInt64PB5BitOr3lor(_M0IPC16uint646UInt64PB5BitOr3lor(_M0IPC16uint646UInt64PB5BitOr3lor(_M0IPC16uint646UInt64PB5BitOr3lor(self.bit_buf, _M0IPC16uint646UInt64PB3Shl3shl(b0, self.bit_count)), _M0IPC16uint646UInt64PB3Shl3shl(b1, self.bit_count + 8 | 0)), _M0IPC16uint646UInt64PB3Shl3shl(b2, self.bit_count + 16 | 0)), _M0IPC16uint646UInt64PB3Shl3shl(b3, self.bit_count + 24 | 0));
        self.bit_count = self.bit_count + 32 | 0;
      } else {
        if (remaining >= 2 && self.bit_count <= 48) {
          const _tmp = self.data;
          const _tmp$2 = self.byte_pos;
          $bound_check(_tmp, _tmp$2);
          const b0 = _M0MPC14byte4Byte10to__uint64(_tmp[_tmp$2]);
          const _tmp$3 = self.data;
          const _tmp$4 = self.byte_pos + 1 | 0;
          $bound_check(_tmp$3, _tmp$4);
          const b1 = _M0MPC14byte4Byte10to__uint64(_tmp$3[_tmp$4]);
          self.byte_pos = self.byte_pos + 2 | 0;
          self.bit_buf = _M0IPC16uint646UInt64PB5BitOr3lor(_M0IPC16uint646UInt64PB5BitOr3lor(self.bit_buf, _M0IPC16uint646UInt64PB3Shl3shl(b0, self.bit_count)), _M0IPC16uint646UInt64PB3Shl3shl(b1, self.bit_count + 8 | 0));
          self.bit_count = self.bit_count + 16 | 0;
        } else {
          const _tmp = self.data;
          const _tmp$2 = self.byte_pos;
          $bound_check(_tmp, _tmp$2);
          const b = _M0MPC14byte4Byte10to__uint64(_tmp[_tmp$2]);
          self.byte_pos = self.byte_pos + 1 | 0;
          self.bit_buf = _M0IPC16uint646UInt64PB5BitOr3lor(self.bit_buf, _M0IPC16uint646UInt64PB3Shl3shl(b, self.bit_count));
          self.bit_count = self.bit_count + 8 | 0;
        }
      }
      continue;
    } else {
      break;
    }
  }
  return new _M0DTPC16result6ResultGuRP26mizchi4zlib9ZlibErrorE2Ok(undefined);
}
function _M0MP26mizchi4zlib9BitReader10peek__bits(self, n) {
  if (n === 0) {
    return new _M0DTPC16result6ResultGiRP26mizchi4zlib9ZlibErrorE2Ok(0);
  }
  const _bind = _M0MP26mizchi4zlib9BitReader12ensure__bits(self, n);
  if (_bind.$tag === 1) {
    const _ok = _bind;
    _ok._0;
  } else {
    return _bind;
  }
  const mask = _M0IPC16uint646UInt64PB3Sub3sub(_M0IPC16uint646UInt64PB3Shl3shl(_M0MP26mizchi4zlib9BitReader10peek__bitsN3oneS37, n), $1L);
  return new _M0DTPC16result6ResultGiRP26mizchi4zlib9ZlibErrorE2Ok(_M0MPC16uint646UInt647to__int(_M0IPC16uint646UInt64PB6BitAnd4land(self.bit_buf, mask)));
}
function _M0MP26mizchi4zlib9BitReader10read__bits(self, n) {
  const _bind = _M0MP26mizchi4zlib9BitReader10peek__bits(self, n);
  let result;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    result = _ok._0;
  } else {
    return _bind;
  }
  _M0MP26mizchi4zlib9BitReader10drop__bits(self, n);
  return new _M0DTPC16result6ResultGiRP26mizchi4zlib9ZlibErrorE2Ok(result);
}
function _M0MP26mizchi4zlib11HuffmanTree6decode(self, reader) {
  if (self.table_bits > 0) {
    const _bind = _M0MP26mizchi4zlib9BitReader10peek__bits(reader, self.table_bits);
    let bits;
    if (_bind.$tag === 1) {
      const _ok = _bind;
      bits = _ok._0;
    } else {
      return _bind;
    }
    const _tmp = self.table_symbol;
    $bound_check(_tmp, bits);
    const sym = _tmp[bits];
    if (sym !== -1) {
      const _tmp$2 = self.table_len;
      $bound_check(_tmp$2, bits);
      const len = _tmp$2[bits];
      _M0MP26mizchi4zlib9BitReader10drop__bits(reader, len);
      return new _M0DTPC16result6ResultGiRP26mizchi4zlib9ZlibErrorE2Ok(sym);
    }
    const _tmp$2 = self.table_sub;
    $bound_check(_tmp$2, bits);
    const sub_idx = _tmp$2[bits];
    if (sub_idx !== -1) {
      const sub_bits = _M0MPC15array5Array2atGiE(self.sub_bits, sub_idx);
      const _bind$2 = _M0MP26mizchi4zlib9BitReader10peek__bits(reader, self.table_bits + sub_bits | 0);
      let bits2;
      if (_bind$2.$tag === 1) {
        const _ok = _bind$2;
        bits2 = _ok._0;
      } else {
        return _bind$2;
      }
      const sub_index = bits2 >> self.table_bits;
      const _tmp$3 = _M0MPC15array5Array2atGUiiEE(self.sub_symbol, sub_idx);
      $bound_check(_tmp$3, sub_index);
      const sym2 = _tmp$3[sub_index];
      if (sym2 !== -1) {
        const _tmp$4 = _M0MPC15array5Array2atGUiiEE(self.sub_len, sub_idx);
        $bound_check(_tmp$4, sub_index);
        const len2 = _tmp$4[sub_index];
        _M0MP26mizchi4zlib9BitReader10drop__bits(reader, len2);
        return new _M0DTPC16result6ResultGiRP26mizchi4zlib9ZlibErrorE2Ok(sym2);
      }
    }
  }
  let node = 0;
  while (true) {
    const _bind = _M0MP26mizchi4zlib9BitReader10read__bits(reader, 1);
    let bit;
    if (_bind.$tag === 1) {
      const _ok = _bind;
      bit = _ok._0;
    } else {
      return _bind;
    }
    node = bit === 0 ? _M0MPC15array5Array2atGiE(self.left, node) : _M0MPC15array5Array2atGiE(self.right, node);
    if (node === -1) {
      return new _M0DTPC16result6ResultGiRP26mizchi4zlib9ZlibErrorE3Err(new _M0DTPC15error5Error39mizchi_2fzlib_2eZlibError_2eInvalidData("Invalid Huffman code"));
    }
    if (_M0MPC15array5Array2atGiE(self.symbol, node) !== -1) {
      return new _M0DTPC16result6ResultGiRP26mizchi4zlib9ZlibErrorE2Ok(_M0MPC15array5Array2atGiE(self.symbol, node));
    }
    continue;
  }
}
function _M0FP26mizchi4zlib21build__dynamic__trees(reader) {
  const _bind = _M0MP26mizchi4zlib9BitReader10read__bits(reader, 5);
  let _tmp;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    _tmp = _ok._0;
  } else {
    return _bind;
  }
  const hlit = _tmp + 257 | 0;
  const _bind$2 = _M0MP26mizchi4zlib9BitReader10read__bits(reader, 5);
  let _tmp$2;
  if (_bind$2.$tag === 1) {
    const _ok = _bind$2;
    _tmp$2 = _ok._0;
  } else {
    return _bind$2;
  }
  const hdist = _tmp$2 + 1 | 0;
  const _bind$3 = _M0MP26mizchi4zlib9BitReader10read__bits(reader, 4);
  let _tmp$3;
  if (_bind$3.$tag === 1) {
    const _ok = _bind$3;
    _tmp$3 = _ok._0;
  } else {
    return _bind$3;
  }
  const hclen = _tmp$3 + 4 | 0;
  const order = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15];
  const code_len_lengths = [];
  let _tmp$4 = 0;
  while (true) {
    const _ = _tmp$4;
    if (_ < 19) {
      _M0MPC15array5Array4pushGiE(code_len_lengths, 0);
      _tmp$4 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  let _tmp$5 = 0;
  while (true) {
    const i = _tmp$5;
    if (i < hclen) {
      $bound_check(order, i);
      const _tmp$6 = order[i];
      const _bind$4 = _M0MP26mizchi4zlib9BitReader10read__bits(reader, 3);
      let _tmp$7;
      if (_bind$4.$tag === 1) {
        const _ok = _bind$4;
        _tmp$7 = _ok._0;
      } else {
        return _bind$4;
      }
      _M0MPC15array5Array3setGiE(code_len_lengths, _tmp$6, _tmp$7);
      _tmp$5 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const _bind$4 = _M0FP26mizchi4zlib20build__huffman__tree(code_len_lengths, 7);
  let code_len_tree;
  if (_bind$4.$tag === 1) {
    const _ok = _bind$4;
    code_len_tree = _ok._0;
  } else {
    return _bind$4;
  }
  const total = hlit + hdist | 0;
  const lengths = [];
  let prev = 0;
  while (true) {
    if (lengths.length < total) {
      const _bind$5 = _M0MP26mizchi4zlib11HuffmanTree6decode(code_len_tree, reader);
      let sym;
      if (_bind$5.$tag === 1) {
        const _ok = _bind$5;
        sym = _ok._0;
      } else {
        return _bind$5;
      }
      if (sym <= 15) {
        _M0MPC15array5Array4pushGiE(lengths, sym);
        prev = sym;
      } else {
        if (sym === 16) {
          const _bind$6 = _M0MP26mizchi4zlib9BitReader10read__bits(reader, 2);
          let _tmp$6;
          if (_bind$6.$tag === 1) {
            const _ok = _bind$6;
            _tmp$6 = _ok._0;
          } else {
            return _bind$6;
          }
          const repeat = _tmp$6 + 3 | 0;
          let _tmp$7 = 0;
          while (true) {
            const _ = _tmp$7;
            if (_ < repeat) {
              _M0MPC15array5Array4pushGiE(lengths, prev);
              _tmp$7 = _ + 1 | 0;
              continue;
            } else {
              break;
            }
          }
        } else {
          if (sym === 17) {
            const _bind$6 = _M0MP26mizchi4zlib9BitReader10read__bits(reader, 3);
            let _tmp$6;
            if (_bind$6.$tag === 1) {
              const _ok = _bind$6;
              _tmp$6 = _ok._0;
            } else {
              return _bind$6;
            }
            const repeat = _tmp$6 + 3 | 0;
            let _tmp$7 = 0;
            while (true) {
              const _ = _tmp$7;
              if (_ < repeat) {
                _M0MPC15array5Array4pushGiE(lengths, 0);
                _tmp$7 = _ + 1 | 0;
                continue;
              } else {
                break;
              }
            }
            prev = 0;
          } else {
            if (sym === 18) {
              const _bind$6 = _M0MP26mizchi4zlib9BitReader10read__bits(reader, 7);
              let _tmp$6;
              if (_bind$6.$tag === 1) {
                const _ok = _bind$6;
                _tmp$6 = _ok._0;
              } else {
                return _bind$6;
              }
              const repeat = _tmp$6 + 11 | 0;
              let _tmp$7 = 0;
              while (true) {
                const _ = _tmp$7;
                if (_ < repeat) {
                  _M0MPC15array5Array4pushGiE(lengths, 0);
                  _tmp$7 = _ + 1 | 0;
                  continue;
                } else {
                  break;
                }
              }
              prev = 0;
            } else {
              return new _M0DTPC16result6ResultGURP26mizchi4zlib11HuffmanTreeRP26mizchi4zlib11HuffmanTreeERP26mizchi4zlib9ZlibErrorE3Err(new _M0DTPC15error5Error39mizchi_2fzlib_2eZlibError_2eInvalidData("Invalid code length symbol"));
            }
          }
        }
      }
      continue;
    } else {
      break;
    }
  }
  const lit_lengths = [];
  let _tmp$6 = 0;
  while (true) {
    const i = _tmp$6;
    if (i < hlit) {
      _M0MPC15array5Array4pushGiE(lit_lengths, _M0MPC15array5Array2atGiE(lengths, i));
      _tmp$6 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const dist_lengths = [];
  let _tmp$7 = 0;
  while (true) {
    const i = _tmp$7;
    if (i < hdist) {
      _M0MPC15array5Array4pushGiE(dist_lengths, _M0MPC15array5Array2atGiE(lengths, hlit + i | 0));
      _tmp$7 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const _bind$5 = _M0FP26mizchi4zlib20build__huffman__tree(lit_lengths, 15);
  let lit_tree;
  if (_bind$5.$tag === 1) {
    const _ok = _bind$5;
    lit_tree = _ok._0;
  } else {
    return _bind$5;
  }
  let dist_tree;
  if (_M0FP26mizchi4zlib18all__zero__lengths(dist_lengths)) {
    const _bind$6 = _M0FP26mizchi4zlib20build__huffman__tree([1], 1);
    if (_bind$6.$tag === 1) {
      const _ok = _bind$6;
      dist_tree = _ok._0;
    } else {
      return _bind$6;
    }
  } else {
    const _bind$6 = _M0FP26mizchi4zlib20build__huffman__tree(dist_lengths, 15);
    if (_bind$6.$tag === 1) {
      const _ok = _bind$6;
      dist_tree = _ok._0;
    } else {
      return _bind$6;
    }
  }
  return new _M0DTPC16result6ResultGURP26mizchi4zlib11HuffmanTreeRP26mizchi4zlib11HuffmanTreeERP26mizchi4zlib9ZlibErrorE2Ok({ _0: lit_tree, _1: dist_tree });
}
function _M0FP26mizchi4zlib19build__fixed__trees() {
  const lit_lengths = [];
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < 288) {
      const len = i <= 143 ? 8 : i <= 255 ? 9 : i <= 279 ? 7 : 8;
      _M0MPC15array5Array4pushGiE(lit_lengths, len);
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const dist_lengths = [];
  let _tmp$2 = 0;
  while (true) {
    const _ = _tmp$2;
    if (_ < 32) {
      _M0MPC15array5Array4pushGiE(dist_lengths, 5);
      _tmp$2 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const _bind = _M0FP26mizchi4zlib20build__huffman__tree(lit_lengths, 15);
  let lit_tree;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    lit_tree = _ok._0;
  } else {
    return _bind;
  }
  const _bind$2 = _M0FP26mizchi4zlib20build__huffman__tree(dist_lengths, 15);
  let dist_tree;
  if (_bind$2.$tag === 1) {
    const _ok = _bind$2;
    dist_tree = _ok._0;
  } else {
    return _bind$2;
  }
  return new _M0DTPC16result6ResultGURP26mizchi4zlib11HuffmanTreeRP26mizchi4zlib11HuffmanTreeERP26mizchi4zlib9ZlibErrorE2Ok({ _0: lit_tree, _1: dist_tree });
}
function _M0FP26mizchi4zlib23inflate__huffman__block(reader, output, lit_tree, dist_tree) {
  while (true) {
    const _bind = _M0MP26mizchi4zlib11HuffmanTree6decode(lit_tree, reader);
    let sym;
    if (_bind.$tag === 1) {
      const _ok = _bind;
      sym = _ok._0;
    } else {
      return _bind;
    }
    if (sym < 256) {
      _M0MPC15array5Array4pushGyE(output, sym & 255);
      continue;
    }
    if (sym === 256) {
      break;
    }
    if (sym < 257 || sym > 285) {
      return new _M0DTPC16result6ResultGuRP26mizchi4zlib9ZlibErrorE3Err(new _M0DTPC15error5Error39mizchi_2fzlib_2eZlibError_2eInvalidData(`Invalid length symbol: ${_M0IP016_24default__implPB4Show10to__stringGiE(sym)}`));
    }
    const len_index = sym - 257 | 0;
    $bound_check(_M0FP26mizchi4zlib12length__base, len_index);
    const base_len = _M0FP26mizchi4zlib12length__base[len_index];
    $bound_check(_M0FP26mizchi4zlib13length__extra, len_index);
    const extra_bits = _M0FP26mizchi4zlib13length__extra[len_index];
    let extra;
    if (extra_bits === 0) {
      extra = 0;
    } else {
      const _bind$2 = _M0MP26mizchi4zlib9BitReader10read__bits(reader, extra_bits);
      if (_bind$2.$tag === 1) {
        const _ok = _bind$2;
        extra = _ok._0;
      } else {
        return _bind$2;
      }
    }
    const length = base_len + extra | 0;
    const _bind$2 = _M0MP26mizchi4zlib11HuffmanTree6decode(dist_tree, reader);
    let dist_sym;
    if (_bind$2.$tag === 1) {
      const _ok = _bind$2;
      dist_sym = _ok._0;
    } else {
      return _bind$2;
    }
    if (dist_sym < 0 || dist_sym >= _M0FP26mizchi4zlib10dist__base.length) {
      return new _M0DTPC16result6ResultGuRP26mizchi4zlib9ZlibErrorE3Err(new _M0DTPC15error5Error39mizchi_2fzlib_2eZlibError_2eInvalidData(`Invalid distance symbol: ${_M0IP016_24default__implPB4Show10to__stringGiE(dist_sym)}`));
    }
    $bound_check(_M0FP26mizchi4zlib10dist__base, dist_sym);
    const base_dist = _M0FP26mizchi4zlib10dist__base[dist_sym];
    $bound_check(_M0FP26mizchi4zlib11dist__extra, dist_sym);
    const dist_extra_bits = _M0FP26mizchi4zlib11dist__extra[dist_sym];
    let dist_extra_val;
    if (dist_extra_bits === 0) {
      dist_extra_val = 0;
    } else {
      const _bind$3 = _M0MP26mizchi4zlib9BitReader10read__bits(reader, dist_extra_bits);
      if (_bind$3.$tag === 1) {
        const _ok = _bind$3;
        dist_extra_val = _ok._0;
      } else {
        return _bind$3;
      }
    }
    const distance = base_dist + dist_extra_val | 0;
    if (distance <= 0 || distance > output.length) {
      return new _M0DTPC16result6ResultGuRP26mizchi4zlib9ZlibErrorE3Err(new _M0DTPC15error5Error39mizchi_2fzlib_2eZlibError_2eInvalidData("Invalid distance"));
    }
    const start = output.length - distance | 0;
    let remaining = length;
    while (true) {
      if (remaining > 0) {
        const chunk = remaining > distance ? distance : remaining;
        let _tmp = 0;
        while (true) {
          const i = _tmp;
          if (i < chunk) {
            _M0MPC15array5Array4pushGyE(output, _M0MPC15array5Array2atGyE(output, start + i | 0));
            _tmp = i + 1 | 0;
            continue;
          } else {
            break;
          }
        }
        remaining = remaining - chunk | 0;
        continue;
      } else {
        break;
      }
    }
    continue;
  }
  return new _M0DTPC16result6ResultGuRP26mizchi4zlib9ZlibErrorE2Ok(undefined);
}
function _M0MP26mizchi4zlib9BitReader11align__byte(self) {
  const full_bytes = self.bit_count / 8 | 0;
  if (full_bytes > 0) {
    self.byte_pos = self.byte_pos - full_bytes | 0;
  }
  self.bit_buf = $0L;
  self.bit_count = 0;
}
function _M0MP26mizchi4zlib9BitReader20read__bytes__aligned(self, output, len) {
  if (self.bit_count !== 0) {
    _M0MP26mizchi4zlib9BitReader11align__byte(self);
  }
  if ((self.byte_pos + len | 0) > self.data.length) {
    return new _M0DTPC16result6ResultGuRP26mizchi4zlib9ZlibErrorE3Err(new _M0DTPC15error5Error39mizchi_2fzlib_2eZlibError_2eInvalidData("Unexpected end of deflate stream"));
  }
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < len) {
      const _tmp$2 = self.data;
      const _tmp$3 = self.byte_pos + i | 0;
      $bound_check(_tmp$2, _tmp$3);
      _M0MPC15array5Array4pushGyE(output, _tmp$2[_tmp$3]);
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  self.byte_pos = self.byte_pos + len | 0;
  return new _M0DTPC16result6ResultGuRP26mizchi4zlib9ZlibErrorE2Ok(undefined);
}
function _M0MP26mizchi4zlib9BitReader22read__u16__le__aligned(self) {
  if (self.bit_count !== 0) {
    _M0MP26mizchi4zlib9BitReader11align__byte(self);
  }
  if ((self.byte_pos + 2 | 0) > self.data.length) {
    return new _M0DTPC16result6ResultGiRP26mizchi4zlib9ZlibErrorE3Err(new _M0DTPC15error5Error39mizchi_2fzlib_2eZlibError_2eInvalidData("Unexpected end of deflate stream"));
  }
  const _tmp = self.data;
  const _tmp$2 = self.byte_pos;
  $bound_check(_tmp, _tmp$2);
  const b0 = _tmp[_tmp$2];
  const _tmp$3 = self.data;
  const _tmp$4 = self.byte_pos + 1 | 0;
  $bound_check(_tmp$3, _tmp$4);
  const b1 = _tmp$3[_tmp$4];
  self.byte_pos = self.byte_pos + 2 | 0;
  return new _M0DTPC16result6ResultGiRP26mizchi4zlib9ZlibErrorE2Ok(b0 | b1 << 8);
}
function _M0FP26mizchi4zlib22inflate__stored__block(reader, output) {
  _M0MP26mizchi4zlib9BitReader11align__byte(reader);
  const _bind = _M0MP26mizchi4zlib9BitReader22read__u16__le__aligned(reader);
  let len;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    len = _ok._0;
  } else {
    return _bind;
  }
  const _bind$2 = _M0MP26mizchi4zlib9BitReader22read__u16__le__aligned(reader);
  let nlen;
  if (_bind$2.$tag === 1) {
    const _ok = _bind$2;
    nlen = _ok._0;
  } else {
    return _bind$2;
  }
  if ((len ^ nlen) !== 65535) {
    return new _M0DTPC16result6ResultGuRP26mizchi4zlib9ZlibErrorE3Err(new _M0DTPC15error5Error39mizchi_2fzlib_2eZlibError_2eInvalidData("Invalid stored block length"));
  }
  return _M0MP26mizchi4zlib9BitReader20read__bytes__aligned(reader, output, len);
}
function _M0FP26mizchi4zlib15inflate__blocks(reader, output) {
  let is_final = false;
  while (true) {
    if (!is_final) {
      const _bind = _M0MP26mizchi4zlib9BitReader10read__bits(reader, 1);
      let bfinal;
      if (_bind.$tag === 1) {
        const _ok = _bind;
        bfinal = _ok._0;
      } else {
        return _bind;
      }
      const _bind$2 = _M0MP26mizchi4zlib9BitReader10read__bits(reader, 2);
      let btype;
      if (_bind$2.$tag === 1) {
        const _ok = _bind$2;
        btype = _ok._0;
      } else {
        return _bind$2;
      }
      if (btype === 0) {
        const _bind$3 = _M0FP26mizchi4zlib22inflate__stored__block(reader, output);
        if (_bind$3.$tag === 1) {
          const _ok = _bind$3;
          _ok._0;
        } else {
          return _bind$3;
        }
      } else {
        if (btype === 1) {
          const _bind$3 = _M0FP26mizchi4zlib19build__fixed__trees();
          let _bind$4;
          if (_bind$3.$tag === 1) {
            const _ok = _bind$3;
            _bind$4 = _ok._0;
          } else {
            return _bind$3;
          }
          const _lit_tree = _bind$4._0;
          const _dist_tree = _bind$4._1;
          const _bind$5 = _M0FP26mizchi4zlib23inflate__huffman__block(reader, output, _lit_tree, _dist_tree);
          if (_bind$5.$tag === 1) {
            const _ok = _bind$5;
            _ok._0;
          } else {
            return _bind$5;
          }
        } else {
          if (btype === 2) {
            const _bind$3 = _M0FP26mizchi4zlib21build__dynamic__trees(reader);
            let _bind$4;
            if (_bind$3.$tag === 1) {
              const _ok = _bind$3;
              _bind$4 = _ok._0;
            } else {
              return _bind$3;
            }
            const _lit_tree = _bind$4._0;
            const _dist_tree = _bind$4._1;
            const _bind$5 = _M0FP26mizchi4zlib23inflate__huffman__block(reader, output, _lit_tree, _dist_tree);
            if (_bind$5.$tag === 1) {
              const _ok = _bind$5;
              _ok._0;
            } else {
              return _bind$5;
            }
          } else {
            return new _M0DTPC16result6ResultGuRP26mizchi4zlib9ZlibErrorE3Err(new _M0DTPC15error5Error39mizchi_2fzlib_2eZlibError_2eInvalidData("Invalid deflate block type"));
          }
        }
      }
      if (bfinal === 1) {
        is_final = true;
      }
      continue;
    } else {
      break;
    }
  }
  return new _M0DTPC16result6ResultGuRP26mizchi4zlib9ZlibErrorE2Ok(undefined);
}
function _M0MP26mizchi4zlib9BitReader3new(data, start) {
  return new _M0TP26mizchi4zlib9BitReader(data, start, $0L, 0);
}
function _M0FP26mizchi4zlib24inflate__deflate__stream(data, start) {
  const reader = _M0MP26mizchi4zlib9BitReader3new(data, start);
  const output = [];
  const _bind = _M0FP26mizchi4zlib15inflate__blocks(reader, output);
  if (_bind.$tag === 1) {
    const _ok = _bind;
    _ok._0;
  } else {
    return _bind;
  }
  _M0MP26mizchi4zlib9BitReader11align__byte(reader);
  return new _M0DTPC16result6ResultGUziERP26mizchi4zlib9ZlibErrorE2Ok({ _0: _M0FP26mizchi4zlib18bytes__from__array(output), _1: reader.byte_pos });
}
function _M0FP26mizchi4zlib20zlib__decompress__at(data, start) {
  if (start < 0 || (start + 2 | 0) > data.length) {
    return new _M0DTPC16result6ResultGUziERP26mizchi4zlib9ZlibErrorE3Err(new _M0DTPC15error5Error39mizchi_2fzlib_2eZlibError_2eInvalidData("Zlib data too short"));
  }
  $bound_check(data, start);
  const cmf = data[start];
  const _tmp = start + 1 | 0;
  $bound_check(data, _tmp);
  const flg = data[_tmp];
  if ((cmf & 15) !== 8) {
    return new _M0DTPC16result6ResultGUziERP26mizchi4zlib9ZlibErrorE3Err(new _M0DTPC15error5Error39mizchi_2fzlib_2eZlibError_2eInvalidData("Unsupported compression method"));
  }
  if ((((Math.imul(cmf, 256) | 0) + flg | 0) % 31 | 0) !== 0) {
    return new _M0DTPC16result6ResultGUziERP26mizchi4zlib9ZlibErrorE3Err(new _M0DTPC15error5Error39mizchi_2fzlib_2eZlibError_2eInvalidData("Invalid zlib FLG checksum"));
  }
  const fdict = flg >> 5 & 1;
  if (fdict === 1) {
    return new _M0DTPC16result6ResultGUziERP26mizchi4zlib9ZlibErrorE3Err(new _M0DTPC15error5Error39mizchi_2fzlib_2eZlibError_2eInvalidData("Preset dictionary not supported"));
  }
  const deflate_start = start + 2 | 0;
  const _bind = _M0FP26mizchi4zlib24inflate__deflate__stream(data, deflate_start);
  let _bind$2;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    _bind$2 = _ok._0;
  } else {
    return _bind;
  }
  const _result = _bind$2._0;
  const _offset = _bind$2._1;
  if ((_offset + 4 | 0) > data.length) {
    return new _M0DTPC16result6ResultGUziERP26mizchi4zlib9ZlibErrorE3Err(new _M0DTPC15error5Error39mizchi_2fzlib_2eZlibError_2eInvalidData("Missing Adler-32 checksum"));
  }
  $bound_check(data, _offset);
  const _tmp$2 = data[_offset] << 24;
  const _tmp$3 = _offset + 1 | 0;
  $bound_check(data, _tmp$3);
  const _tmp$4 = _tmp$2 | data[_tmp$3] << 16;
  const _tmp$5 = _offset + 2 | 0;
  $bound_check(data, _tmp$5);
  const _tmp$6 = _tmp$4 | data[_tmp$5] << 8;
  const _tmp$7 = _offset + 3 | 0;
  $bound_check(data, _tmp$7);
  const stored_checksum = _tmp$6 | data[_tmp$7];
  const computed_checksum = _M0FP26mizchi4zlib7adler32(_result);
  if (stored_checksum !== computed_checksum) {
    return new _M0DTPC16result6ResultGUziERP26mizchi4zlib9ZlibErrorE3Err(new _M0DTPC15error5Error39mizchi_2fzlib_2eZlibError_2eInvalidData(`Adler-32 mismatch: stored=${_M0IP016_24default__implPB4Show10to__stringGiE(stored_checksum)}, computed=${_M0IP016_24default__implPB4Show10to__stringGiE(computed_checksum)}`));
  }
  return new _M0DTPC16result6ResultGUziERP26mizchi4zlib9ZlibErrorE2Ok({ _0: _result, _1: _offset + 4 | 0 });
}
function _M0FP26mizchi4zlib16zlib__decompress(data) {
  const _bind = _M0FP26mizchi4zlib20zlib__decompress__at(data, 0);
  let _bind$2;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    _bind$2 = _ok._0;
  } else {
    return _bind;
  }
  const _result = _bind$2._0;
  const _offset = _bind$2._1;
  if (_offset !== data.length) {
    return new _M0DTPC16result6ResultGzRP26mizchi4zlib9ZlibErrorE3Err(new _M0DTPC15error5Error39mizchi_2fzlib_2eZlibError_2eInvalidData("Trailing data after zlib stream"));
  }
  return new _M0DTPC16result6ResultGzRP26mizchi4zlib9ZlibErrorE2Ok(_result);
}
function _M0FP26mizchi4zlib22deflate__reverse__bits(code, len) {
  let v = code;
  let out = 0;
  let n = len;
  while (true) {
    if (n > 0) {
      out = out << 1 | v & 1;
      v = v >> 1;
      n = n - 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return out;
}
function _M0FP26mizchi4zlib23build__canonical__codes(lengths, max_bits) {
  const codes = _M0MPC15array5Array4makeGUiiEE(lengths.length, _M0FP26mizchi4zlib38build__canonical__codes_2etuple_2f2642);
  const bl_count = _M0MPC15array5Array4makeGiE(max_bits + 1 | 0, 0);
  const _bind = lengths.length;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind) {
      const len = lengths[_];
      if (len > 0) {
        _M0MPC15array5Array3setGiE(bl_count, len, _M0MPC15array5Array2atGiE(bl_count, len) + 1 | 0);
      }
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const next_code = _M0MPC15array5Array4makeGiE(max_bits + 1 | 0, 0);
  let code = 0;
  let _tmp$2 = 1;
  while (true) {
    const bits = _tmp$2;
    if (bits <= max_bits) {
      code = code + _M0MPC15array5Array2atGiE(bl_count, bits - 1 | 0) << 1;
      _M0MPC15array5Array3setGiE(next_code, bits, code);
      _tmp$2 = bits + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const _bind$2 = lengths.length;
  let _tmp$3 = 0;
  while (true) {
    const sym = _tmp$3;
    if (sym < _bind$2) {
      const len = _M0MPC15array5Array2atGiE(lengths, sym);
      if (len > 0) {
        const c = _M0MPC15array5Array2atGiE(next_code, len);
        _M0MPC15array5Array3setGiE(next_code, len, c + 1 | 0);
        _M0MPC15array5Array3setGlE(codes, sym, { _0: _M0FP26mizchi4zlib22deflate__reverse__bits(c, len), _1: len });
      }
      _tmp$3 = sym + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return codes;
}
function _M0FP26mizchi4zlib23build__huffman__lengths(freqs, max_bits) {
  const lengths = _M0MPC15array5Array4makeGiE(freqs.length, 0);
  const nodes = [];
  const active = [];
  const _bind = freqs.length;
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < _bind) {
      if (_M0MPC15array5Array2atGiE(freqs, i) > 0) {
        _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(nodes, new _M0TP26mizchi4zlib8HuffNode(_M0MPC15array5Array2atGiE(freqs, i), -1, -1, i));
        _M0MPC15array5Array4pushGiE(active, nodes.length - 1 | 0);
      }
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  if (active.length === 0) {
    return _M0DTPC16option6OptionGRPB5ArrayGiEE4None__;
  }
  if (active.length === 1) {
    _M0MPC15array5Array3setGiE(lengths, _M0MPC15array5Array2atGUiiEE(nodes, _M0MPC15array5Array2atGiE(active, 0)).sym, 1);
    return new _M0DTPC16option6OptionGRPB5ArrayGiEE4Some(lengths);
  }
  while (true) {
    if (active.length > 1) {
      let min1 = 0;
      let min2 = 1;
      if (_M0MPC15array5Array2atGUiiEE(nodes, _M0MPC15array5Array2atGiE(active, min2)).freq < _M0MPC15array5Array2atGUiiEE(nodes, _M0MPC15array5Array2atGiE(active, min1)).freq) {
        const tmp = min1;
        min1 = min2;
        min2 = tmp;
      }
      const _bind$2 = active.length;
      let _tmp$2 = 2;
      while (true) {
        const i = _tmp$2;
        if (i < _bind$2) {
          const idx = _M0MPC15array5Array2atGiE(active, i);
          if (_M0MPC15array5Array2atGUiiEE(nodes, idx).freq < _M0MPC15array5Array2atGUiiEE(nodes, _M0MPC15array5Array2atGiE(active, min1)).freq) {
            min2 = min1;
            min1 = i;
          } else {
            if (_M0MPC15array5Array2atGUiiEE(nodes, idx).freq < _M0MPC15array5Array2atGUiiEE(nodes, _M0MPC15array5Array2atGiE(active, min2)).freq) {
              min2 = i;
            }
          }
          _tmp$2 = i + 1 | 0;
          continue;
        } else {
          break;
        }
      }
      const a = _M0MPC15array5Array2atGiE(active, min1);
      const b = _M0MPC15array5Array2atGiE(active, min2);
      if (min1 > min2) {
        _M0MPC15array5Array6removeGiE(active, min1);
        _M0MPC15array5Array6removeGiE(active, min2);
      } else {
        _M0MPC15array5Array6removeGiE(active, min2);
        _M0MPC15array5Array6removeGiE(active, min1);
      }
      _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(nodes, new _M0TP26mizchi4zlib8HuffNode(_M0MPC15array5Array2atGUiiEE(nodes, a).freq + _M0MPC15array5Array2atGUiiEE(nodes, b).freq | 0, a, b, -1));
      _M0MPC15array5Array4pushGiE(active, nodes.length - 1 | 0);
      continue;
    } else {
      break;
    }
  }
  const root = _M0MPC15array5Array2atGiE(active, 0);
  const stack = [{ _0: root, _1: 0 }];
  while (true) {
    if (stack.length > 0) {
      const idx = stack.length - 1 | 0;
      const _bind$2 = _M0MPC15array5Array2atGUiiEE(stack, idx);
      const _node_id = _bind$2._0;
      const _depth = _bind$2._1;
      _M0MPC15array5Array6removeGsE(stack, idx);
      const node = _M0MPC15array5Array2atGUiiEE(nodes, _node_id);
      if (node.left < 0 && node.right < 0) {
        const len = _depth === 0 ? 1 : _depth;
        if (len > max_bits) {
          return _M0DTPC16option6OptionGRPB5ArrayGiEE4None__;
        }
        _M0MPC15array5Array3setGiE(lengths, node.sym, len);
      } else {
        if (node.left >= 0) {
          _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(stack, { _0: node.left, _1: _depth + 1 | 0 });
        }
        if (node.right >= 0) {
          _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(stack, { _0: node.right, _1: _depth + 1 | 0 });
        }
      }
      continue;
    } else {
      break;
    }
  }
  return new _M0DTPC16option6OptionGRPB5ArrayGiEE4Some(lengths);
}
function _M0FP26mizchi4zlib5hash3(data, pos) {
  $bound_check(data, pos);
  const b0 = data[pos];
  const _tmp = pos + 1 | 0;
  $bound_check(data, _tmp);
  const b1 = data[_tmp];
  const _tmp$2 = pos + 2 | 0;
  $bound_check(data, _tmp$2);
  const b2 = data[_tmp$2];
  return (b0 << 8 ^ b1 << 4 ^ b2) & 32767;
}
function _M0FP26mizchi4zlib12insert__hash(data, pos, head, prev) {
  if ((pos + 2 | 0) >= data.length) {
    return undefined;
  }
  const h = _M0FP26mizchi4zlib5hash3(data, pos);
  $bound_check(head, h);
  $bound_check(prev, pos);
  prev[pos] = head[h];
  $bound_check(head, h);
  head[h] = pos;
}
function _M0FP26mizchi4zlib13build__tokens(data) {
  const tokens = [];
  const len = data.length;
  const head = $make_array_len_and_init(32768, -1);
  const prev = $make_array_len_and_init(len, -1);
  let pos = 0;
  while (true) {
    if (pos < len) {
      const remaining = len - pos | 0;
      let best_len = 0;
      let best_dist = 0;
      if (remaining >= 3) {
        const h = _M0FP26mizchi4zlib5hash3(data, pos);
        $bound_check(head, h);
        let candidate = head[h];
        const limit = pos > 32768 ? pos - 32768 | 0 : 0;
        const max_len = remaining < 258 ? remaining : 258;
        let chain = 0;
        while (true) {
          if (candidate >= limit && chain < 64) {
            let _tmp;
            const _tmp$2 = candidate;
            $bound_check(data, _tmp$2);
            const _p = data[_tmp$2];
            const _tmp$3 = pos;
            $bound_check(data, _tmp$3);
            const _p$2 = data[_tmp$3];
            if (_p === _p$2) {
              let _tmp$4;
              const _tmp$5 = candidate + 1 | 0;
              $bound_check(data, _tmp$5);
              const _p$3 = data[_tmp$5];
              const _tmp$6 = pos + 1 | 0;
              $bound_check(data, _tmp$6);
              const _p$4 = data[_tmp$6];
              if (_p$3 === _p$4) {
                const _tmp$7 = candidate + 2 | 0;
                $bound_check(data, _tmp$7);
                const _p$5 = data[_tmp$7];
                const _tmp$8 = pos + 2 | 0;
                $bound_check(data, _tmp$8);
                const _p$6 = data[_tmp$8];
                _tmp$4 = _p$5 === _p$6;
              } else {
                _tmp$4 = false;
              }
              _tmp = _tmp$4;
            } else {
              _tmp = false;
            }
            if (_tmp) {
              let l = 3;
              while (true) {
                let _tmp$4;
                if (l < max_len) {
                  const _tmp$5 = candidate + l | 0;
                  $bound_check(data, _tmp$5);
                  const _p$3 = data[_tmp$5];
                  const _tmp$6 = pos + l | 0;
                  $bound_check(data, _tmp$6);
                  const _p$4 = data[_tmp$6];
                  _tmp$4 = _p$3 === _p$4;
                } else {
                  _tmp$4 = false;
                }
                if (_tmp$4) {
                  l = l + 1 | 0;
                  continue;
                } else {
                  break;
                }
              }
              if (l > best_len) {
                best_len = l;
                best_dist = pos - candidate | 0;
                if (l === max_len) {
                  break;
                }
              }
            }
            const _tmp$4 = candidate;
            $bound_check(prev, _tmp$4);
            candidate = prev[_tmp$4];
            chain = chain + 1 | 0;
            continue;
          } else {
            break;
          }
        }
      }
      if (best_len >= 3) {
        _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(tokens, new _M0DTP26mizchi4zlib12DeflateToken5Match(best_len, best_dist));
        let _tmp = 0;
        while (true) {
          const i = _tmp;
          if (i < best_len) {
            _M0FP26mizchi4zlib12insert__hash(data, pos + i | 0, head, prev);
            _tmp = i + 1 | 0;
            continue;
          } else {
            break;
          }
        }
        pos = pos + best_len | 0;
      } else {
        const _tmp = pos;
        $bound_check(data, _tmp);
        _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(tokens, new _M0DTP26mizchi4zlib12DeflateToken3Lit(data[_tmp]));
        _M0FP26mizchi4zlib12insert__hash(data, pos, head, prev);
        pos = pos + 1 | 0;
      }
      continue;
    } else {
      break;
    }
  }
  return tokens;
}
function _M0FP26mizchi4zlib16dist__code__info(dist) {
  const _bind = _M0FP26mizchi4zlib19deflate__dist__base.length;
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < _bind) {
      $bound_check(_M0FP26mizchi4zlib19deflate__dist__base, i);
      const base = _M0FP26mizchi4zlib19deflate__dist__base[i];
      $bound_check(_M0FP26mizchi4zlib20deflate__dist__extra, i);
      const extra = _M0FP26mizchi4zlib20deflate__dist__extra[i];
      const max_dist = base + ((1 << extra) - 1 | 0) | 0;
      if (dist <= max_dist) {
        return { _0: i, _1: extra, _2: dist - base | 0 };
      }
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  $bound_check(_M0FP26mizchi4zlib19deflate__dist__base, 29);
  return { _0: 29, _1: 13, _2: dist - _M0FP26mizchi4zlib19deflate__dist__base[29] | 0 };
}
function _M0FP26mizchi4zlib18emit__rle__lengths(lengths) {
  const out = [];
  let i = 0;
  while (true) {
    if (i < lengths.length) {
      const len = _M0MPC15array5Array2atGiE(lengths, i);
      let run = 1;
      while (true) {
        if ((i + run | 0) < lengths.length && _M0MPC15array5Array2atGiE(lengths, i + run | 0) === len) {
          run = run + 1 | 0;
          continue;
        } else {
          break;
        }
      }
      if (len === 0) {
        let remaining = run;
        while (true) {
          if (remaining > 0) {
            if (remaining >= 11) {
              const chunk = remaining > 138 ? 138 : remaining;
              _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(out, new _M0TP26mizchi4zlib8RleToken(18, 7, chunk - 11 | 0));
              remaining = remaining - chunk | 0;
            } else {
              if (remaining >= 3) {
                const chunk = remaining > 10 ? 10 : remaining;
                _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(out, new _M0TP26mizchi4zlib8RleToken(17, 3, chunk - 3 | 0));
                remaining = remaining - chunk | 0;
              } else {
                const _bind = remaining;
                let _tmp = 0;
                while (true) {
                  const _ = _tmp;
                  if (_ < _bind) {
                    _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(out, _M0FP26mizchi4zlib34emit__rle__lengths_2erecord_2f2724);
                    _tmp = _ + 1 | 0;
                    continue;
                  } else {
                    break;
                  }
                }
                remaining = 0;
              }
            }
            continue;
          } else {
            break;
          }
        }
      } else {
        _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(out, new _M0TP26mizchi4zlib8RleToken(len, 0, 0));
        let remaining = run - 1 | 0;
        while (true) {
          if (remaining > 0) {
            if (remaining >= 3) {
              const chunk = remaining > 6 ? 6 : remaining;
              _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(out, new _M0TP26mizchi4zlib8RleToken(16, 2, chunk - 3 | 0));
              remaining = remaining - chunk | 0;
            } else {
              _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(out, new _M0TP26mizchi4zlib8RleToken(len, 0, 0));
              remaining = remaining - 1 | 0;
            }
            continue;
          } else {
            break;
          }
        }
      }
      i = i + run | 0;
      continue;
    } else {
      break;
    }
  }
  return out;
}
function _M0FP26mizchi4zlib18length__code__info(len) {
  const _bind = _M0FP26mizchi4zlib21deflate__length__base.length;
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < _bind) {
      $bound_check(_M0FP26mizchi4zlib21deflate__length__base, i);
      const base = _M0FP26mizchi4zlib21deflate__length__base[i];
      $bound_check(_M0FP26mizchi4zlib22deflate__length__extra, i);
      const extra = _M0FP26mizchi4zlib22deflate__length__extra[i];
      const max_len = base + ((1 << extra) - 1 | 0) | 0;
      if (len <= max_len) {
        return { _0: 257 + i | 0, _1: extra, _2: len - base | 0 };
      }
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return _M0FP26mizchi4zlib33length__code__info_2etuple_2f2742;
}
function _M0MP26mizchi4zlib9BitWriter11write__bits(self, bits, count) {
  let value = bits;
  let remaining = count;
  while (true) {
    if (remaining > 0) {
      const available = 8 - self.bit_count | 0;
      const take = remaining < available ? remaining : available;
      const mask = (1 << take) - 1 | 0;
      self.bit_buf = self.bit_buf | (value & mask) << self.bit_count;
      self.bit_count = self.bit_count + take | 0;
      value = value >> take;
      remaining = remaining - take | 0;
      if (self.bit_count === 8) {
        _M0MPC15array5Array4pushGyE(self.buf, self.bit_buf & 255);
        self.bit_buf = 0;
        self.bit_count = 0;
      }
      continue;
    } else {
      return;
    }
  }
}
function _M0FP26mizchi4zlib22write__tokens__dynamic(tokens, lit_codes, dist_codes, writer) {
  const _bind = tokens.length;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind) {
      const t = tokens[_];
      if (t.$tag === 0) {
        const _Lit = t;
        const _sym = _Lit._0;
        const _bind$2 = _M0MPC15array5Array2atGUiiEE(lit_codes, _sym);
        const _code = _bind$2._0;
        const _len = _bind$2._1;
        _M0MP26mizchi4zlib9BitWriter11write__bits(writer, _code, _len);
      } else {
        const _Match = t;
        const _len = _Match._0;
        const _dist = _Match._1;
        const _bind$2 = _M0FP26mizchi4zlib18length__code__info(_len);
        const _len_code = _bind$2._0;
        const _len_extra_bits = _bind$2._1;
        const _len_extra_val = _bind$2._2;
        const _bind$3 = _M0MPC15array5Array2atGUiiEE(lit_codes, _len_code);
        const _code = _bind$3._0;
        const _code_len = _bind$3._1;
        _M0MP26mizchi4zlib9BitWriter11write__bits(writer, _code, _code_len);
        if (_len_extra_bits > 0) {
          _M0MP26mizchi4zlib9BitWriter11write__bits(writer, _len_extra_val, _len_extra_bits);
        }
        const _bind$4 = _M0FP26mizchi4zlib16dist__code__info(_dist);
        const _dist_code = _bind$4._0;
        const _dist_extra_bits = _bind$4._1;
        const _dist_extra_val = _bind$4._2;
        const _bind$5 = _M0MPC15array5Array2atGUiiEE(dist_codes, _dist_code);
        const _dist_bits = _bind$5._0;
        const _dist_len = _bind$5._1;
        _M0MP26mizchi4zlib9BitWriter11write__bits(writer, _dist_bits, _dist_len);
        if (_dist_extra_bits > 0) {
          _M0MP26mizchi4zlib9BitWriter11write__bits(writer, _dist_extra_val, _dist_extra_bits);
        }
      }
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const _bind$2 = _M0MPC15array5Array2atGUiiEE(lit_codes, 256);
  const _eob_code = _bind$2._0;
  const _eob_len = _bind$2._1;
  _M0MP26mizchi4zlib9BitWriter11write__bits(writer, _eob_code, _eob_len);
}
function _M0MP26mizchi4zlib9BitWriter11align__byte(self) {
  if (self.bit_count > 0) {
    _M0MPC15array5Array4pushGyE(self.buf, self.bit_buf & 255);
    self.bit_buf = 0;
    self.bit_count = 0;
    return;
  } else {
    return;
  }
}
function _M0MP26mizchi4zlib9BitWriter6finish(self) {
  _M0MP26mizchi4zlib9BitWriter11align__byte(self);
  const _bind = _M0MPC15array10FixedArray5makeiGyE(self.buf.length, (i) => _M0MPC15array5Array2atGyE(self.buf, i));
  return _M0MPC15bytes5Bytes11from__array(new _M0TPB9ArrayViewGyE(_bind, 0, _bind.length));
}
function _M0MP26mizchi4zlib9BitWriter3new() {
  return new _M0TP26mizchi4zlib9BitWriter([], 0, 0);
}
function _M0FP26mizchi4zlib26deflate__compress__dynamic(data) {
  const tokens = _M0FP26mizchi4zlib13build__tokens(data);
  const lit_freq = _M0MPC15array5Array4makeGiE(286, 0);
  const dist_freq = _M0MPC15array5Array4makeGiE(30, 0);
  const _bind = tokens.length;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind) {
      const t = tokens[_];
      if (t.$tag === 0) {
        const _Lit = t;
        const _sym = _Lit._0;
        _M0MPC15array5Array3setGiE(lit_freq, _sym, _M0MPC15array5Array2atGiE(lit_freq, _sym) + 1 | 0);
      } else {
        const _Match = t;
        const _len = _Match._0;
        const _dist = _Match._1;
        const _bind$2 = _M0FP26mizchi4zlib18length__code__info(_len);
        const _len_code = _bind$2._0;
        const _bind$3 = _M0FP26mizchi4zlib16dist__code__info(_dist);
        const _dist_code = _bind$3._0;
        _M0MPC15array5Array3setGiE(lit_freq, _len_code, _M0MPC15array5Array2atGiE(lit_freq, _len_code) + 1 | 0);
        _M0MPC15array5Array3setGiE(dist_freq, _dist_code, _M0MPC15array5Array2atGiE(dist_freq, _dist_code) + 1 | 0);
      }
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  _M0MPC15array5Array3setGiE(lit_freq, 256, _M0MPC15array5Array2atGiE(lit_freq, 256) + 1 | 0);
  let any_dist = false;
  const _bind$2 = dist_freq.length;
  let _tmp$2 = 0;
  while (true) {
    const _ = _tmp$2;
    if (_ < _bind$2) {
      const v = dist_freq[_];
      if (v > 0) {
        any_dist = true;
        break;
      }
      _tmp$2 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  if (!any_dist) {
    _M0MPC15array5Array3setGiE(dist_freq, 0, 1);
  }
  const _bind$3 = _M0FP26mizchi4zlib23build__huffman__lengths(lit_freq, 15);
  let lit_lengths;
  if (_bind$3.$tag === 0) {
    return undefined;
  } else {
    const _Some = _bind$3;
    lit_lengths = _Some._0;
  }
  const _bind$4 = _M0FP26mizchi4zlib23build__huffman__lengths(dist_freq, 15);
  let dist_lengths;
  if (_bind$4.$tag === 0) {
    return undefined;
  } else {
    const _Some = _bind$4;
    dist_lengths = _Some._0;
  }
  const lit_codes = _M0FP26mizchi4zlib23build__canonical__codes(lit_lengths, 15);
  const dist_codes = _M0FP26mizchi4zlib23build__canonical__codes(dist_lengths, 15);
  let hlit = 286;
  while (true) {
    if (hlit > 257 && _M0MPC15array5Array2atGiE(lit_lengths, hlit - 1 | 0) === 0) {
      hlit = hlit - 1 | 0;
      continue;
    } else {
      break;
    }
  }
  let hdist = 30;
  while (true) {
    if (hdist > 1 && _M0MPC15array5Array2atGiE(dist_lengths, hdist - 1 | 0) === 0) {
      hdist = hdist - 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const combined = [];
  const _bind$5 = hlit;
  let _tmp$3 = 0;
  while (true) {
    const i = _tmp$3;
    if (i < _bind$5) {
      _M0MPC15array5Array4pushGiE(combined, _M0MPC15array5Array2atGiE(lit_lengths, i));
      _tmp$3 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const _bind$6 = hdist;
  let _tmp$4 = 0;
  while (true) {
    const i = _tmp$4;
    if (i < _bind$6) {
      _M0MPC15array5Array4pushGiE(combined, _M0MPC15array5Array2atGiE(dist_lengths, i));
      _tmp$4 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const rle = _M0FP26mizchi4zlib18emit__rle__lengths(combined);
  const cl_freq = _M0MPC15array5Array4makeGiE(19, 0);
  const _bind$7 = rle.length;
  let _tmp$5 = 0;
  while (true) {
    const _ = _tmp$5;
    if (_ < _bind$7) {
      const tok = rle[_];
      _M0MPC15array5Array3setGiE(cl_freq, tok.sym, _M0MPC15array5Array2atGiE(cl_freq, tok.sym) + 1 | 0);
      _tmp$5 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const _bind$8 = _M0FP26mizchi4zlib23build__huffman__lengths(cl_freq, 7);
  let cl_lengths;
  if (_bind$8.$tag === 0) {
    return undefined;
  } else {
    const _Some = _bind$8;
    cl_lengths = _Some._0;
  }
  const cl_codes = _M0FP26mizchi4zlib23build__canonical__codes(cl_lengths, 7);
  const order = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15];
  let hclen = 4;
  const _bind$9 = order.length;
  let _tmp$6 = 0;
  while (true) {
    const i = _tmp$6;
    if (i < _bind$9) {
      $bound_check(order, i);
      if (_M0MPC15array5Array2atGiE(cl_lengths, order[i]) !== 0) {
        hclen = i + 1 | 0;
      }
      _tmp$6 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const writer = _M0MP26mizchi4zlib9BitWriter3new();
  _M0MP26mizchi4zlib9BitWriter11write__bits(writer, 1, 1);
  _M0MP26mizchi4zlib9BitWriter11write__bits(writer, 2, 2);
  _M0MP26mizchi4zlib9BitWriter11write__bits(writer, hlit - 257 | 0, 5);
  _M0MP26mizchi4zlib9BitWriter11write__bits(writer, hdist - 1 | 0, 5);
  _M0MP26mizchi4zlib9BitWriter11write__bits(writer, hclen - 4 | 0, 4);
  const _bind$10 = hclen;
  let _tmp$7 = 0;
  while (true) {
    const i = _tmp$7;
    if (i < _bind$10) {
      $bound_check(order, i);
      _M0MP26mizchi4zlib9BitWriter11write__bits(writer, _M0MPC15array5Array2atGiE(cl_lengths, order[i]), 3);
      _tmp$7 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const _bind$11 = rle.length;
  let _tmp$8 = 0;
  while (true) {
    const _ = _tmp$8;
    if (_ < _bind$11) {
      const tok = rle[_];
      const _bind$12 = _M0MPC15array5Array2atGUiiEE(cl_codes, tok.sym);
      const _code = _bind$12._0;
      const _len = _bind$12._1;
      _M0MP26mizchi4zlib9BitWriter11write__bits(writer, _code, _len);
      if (tok.extra_bits > 0) {
        _M0MP26mizchi4zlib9BitWriter11write__bits(writer, tok.extra_val, tok.extra_bits);
      }
      _tmp$8 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  _M0FP26mizchi4zlib22write__tokens__dynamic(tokens, lit_codes, dist_codes, writer);
  return _M0MP26mizchi4zlib9BitWriter6finish(writer);
}
function _M0FP26mizchi4zlib16fixed__lit__code(sym) {
  if (sym <= 143) {
    const code = sym + 48 | 0;
    return { _0: _M0FP26mizchi4zlib22deflate__reverse__bits(code, 8), _1: 8 };
  } else {
    if (sym <= 255) {
      const code = (sym - 144 | 0) + 400 | 0;
      return { _0: _M0FP26mizchi4zlib22deflate__reverse__bits(code, 9), _1: 9 };
    } else {
      if (sym <= 279) {
        const code = sym - 256 | 0;
        return { _0: _M0FP26mizchi4zlib22deflate__reverse__bits(code, 7), _1: 7 };
      } else {
        const code = (sym - 280 | 0) + 192 | 0;
        return { _0: _M0FP26mizchi4zlib22deflate__reverse__bits(code, 8), _1: 8 };
      }
    }
  }
}
function _M0FP26mizchi4zlib17write__end__block(writer) {
  const _bind = _M0FP26mizchi4zlib16fixed__lit__code(256);
  const _code = _bind._0;
  const _len = _bind._1;
  _M0MP26mizchi4zlib9BitWriter11write__bits(writer, _code, _len);
}
function _M0FP26mizchi4zlib14write__literal(writer, sym) {
  const _bind = _M0FP26mizchi4zlib16fixed__lit__code(sym);
  const _code = _bind._0;
  const _len = _bind._1;
  _M0MP26mizchi4zlib9BitWriter11write__bits(writer, _code, _len);
}
function _M0FP26mizchi4zlib17fixed__dist__code(sym) {
  return { _0: _M0FP26mizchi4zlib22deflate__reverse__bits(sym, 5), _1: 5 };
}
function _M0FP26mizchi4zlib12write__match(writer, length, distance) {
  const _bind = _M0FP26mizchi4zlib18length__code__info(length);
  const _len_code = _bind._0;
  const _len_extra_bits = _bind._1;
  const _len_extra_val = _bind._2;
  const _bind$2 = _M0FP26mizchi4zlib16fixed__lit__code(_len_code);
  const _code_bits = _bind$2._0;
  const _code_len = _bind$2._1;
  _M0MP26mizchi4zlib9BitWriter11write__bits(writer, _code_bits, _code_len);
  if (_len_extra_bits > 0) {
    _M0MP26mizchi4zlib9BitWriter11write__bits(writer, _len_extra_val, _len_extra_bits);
  }
  const _bind$3 = _M0FP26mizchi4zlib16dist__code__info(distance);
  const _dist_code = _bind$3._0;
  const _dist_extra_bits = _bind$3._1;
  const _dist_extra_val = _bind$3._2;
  const _bind$4 = _M0FP26mizchi4zlib17fixed__dist__code(_dist_code);
  const _dist_bits = _bind$4._0;
  const _dist_len = _bind$4._1;
  _M0MP26mizchi4zlib9BitWriter11write__bits(writer, _dist_bits, _dist_len);
  if (_dist_extra_bits > 0) {
    _M0MP26mizchi4zlib9BitWriter11write__bits(writer, _dist_extra_val, _dist_extra_bits);
    return;
  } else {
    return;
  }
}
function _M0FP26mizchi4zlib20write__tokens__fixed(tokens, writer) {
  const _bind = tokens.length;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind) {
      const t = tokens[_];
      if (t.$tag === 0) {
        const _Lit = t;
        const _sym = _Lit._0;
        _M0FP26mizchi4zlib14write__literal(writer, _sym);
      } else {
        const _Match = t;
        const _len = _Match._0;
        const _dist = _Match._1;
        _M0FP26mizchi4zlib12write__match(writer, _len, _dist);
      }
      _tmp = _ + 1 | 0;
      continue;
    } else {
      return;
    }
  }
}
function _M0FP26mizchi4zlib24deflate__compress__fixed(data) {
  const writer = _M0MP26mizchi4zlib9BitWriter3new();
  _M0MP26mizchi4zlib9BitWriter11write__bits(writer, 1, 1);
  _M0MP26mizchi4zlib9BitWriter11write__bits(writer, 1, 2);
  const tokens = _M0FP26mizchi4zlib13build__tokens(data);
  _M0FP26mizchi4zlib20write__tokens__fixed(tokens, writer);
  _M0FP26mizchi4zlib17write__end__block(writer);
  return _M0MP26mizchi4zlib9BitWriter6finish(writer);
}
function _M0FP26mizchi4zlib23deflate__compress__best(data) {
  const fixed = _M0FP26mizchi4zlib24deflate__compress__fixed(data);
  const _bind = _M0FP26mizchi4zlib26deflate__compress__dynamic(data);
  if (_bind === undefined) {
    return fixed;
  } else {
    const _Some = _bind;
    const _dynamic = _Some;
    return _dynamic.length < fixed.length ? _dynamic : fixed;
  }
}
function _M0FP26mizchi4zlib17deflate__compress(data) {
  return _M0FP26mizchi4zlib23deflate__compress__best(data);
}
function _M0FP26mizchi4zlib14zlib__compress(data) {
  const deflated = _M0FP26mizchi4zlib17deflate__compress(data);
  const total_len = (2 + deflated.length | 0) + 4 | 0;
  const result = $makebytes(total_len, 0);
  $bound_check(result, 0);
  result[0] = 120;
  $bound_check(result, 1);
  result[1] = 1;
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < deflated.length) {
      const _tmp$2 = 2 + i | 0;
      $bound_check(deflated, i);
      $bound_check(result, _tmp$2);
      result[_tmp$2] = deflated[i];
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const checksum = _M0FP26mizchi4zlib7adler32(data);
  _M0FP26mizchi4zlib14write__u32__be(result, 2 + deflated.length | 0, checksum);
  return _M0MPC15bytes5Bytes11from__array(new _M0TPB9ArrayViewGyE(result, 0, result.length));
}
function _M0MP36mizchi3bit6object8ObjectId3new(bytes) {
  return new _M0TP36mizchi3bit6object8ObjectId(bytes);
}
function _M0MP36mizchi3bit6object13HashAlgorithm10hash__size(self) {
  if (self === 0) {
    return 20;
  } else {
    return 32;
  }
}
function _M0MP36mizchi3bit6object8ObjectId12zero_2einner(algo) {
  return new _M0TP36mizchi3bit6object8ObjectId($makebytes(_M0MP36mizchi3bit6object13HashAlgorithm10hash__size(algo), 0));
}
function _M0MP36mizchi3bit6object8ObjectId4zero(algo$46$opt) {
  let algo;
  if (algo$46$opt === undefined) {
    algo = 0;
  } else {
    const _Some = algo$46$opt;
    algo = _Some;
  }
  return _M0MP36mizchi3bit6object8ObjectId12zero_2einner(algo);
}
function _M0MP36mizchi3bit6object8ObjectId23from__bytes__at_2einner(data, offset, hash_size) {
  const bytes = $makebytes(hash_size, 0);
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < hash_size) {
      const _tmp$2 = offset + i | 0;
      $bound_check(data, _tmp$2);
      $bound_check(bytes, i);
      bytes[i] = data[_tmp$2];
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return new _M0TP36mizchi3bit6object8ObjectId(bytes);
}
function _M0FP36mizchi3bit6object18hex__char__to__int(c) {
  if (c >= 48 && c <= 57) {
    return new _M0DTPC16result6ResultGiRP36mizchi3bit6object8GitErrorE2Ok(c - 48 | 0);
  } else {
    if (c >= 97 && c <= 102) {
      return new _M0DTPC16result6ResultGiRP36mizchi3bit6object8GitErrorE2Ok((c - 97 | 0) + 10 | 0);
    } else {
      if (c >= 65 && c <= 70) {
        return new _M0DTPC16result6ResultGiRP36mizchi3bit6object8GitErrorE2Ok((c - 65 | 0) + 10 | 0);
      } else {
        return new _M0DTPC16result6ResultGiRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject(`Invalid hex char: ${_M0IPC14char4CharPB4Show10to__string(c)}`));
      }
    }
  }
}
function _M0MP36mizchi3bit6object8ObjectId9from__hex(hex) {
  if (hex.length !== 40 && hex.length !== 64) {
    return new _M0DTPC16result6ResultGRP36mizchi3bit6object8ObjectIdRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject(`Invalid hex length: ${_M0IP016_24default__implPB4Show10to__stringGiE(hex.length)}`));
  }
  const byte_len = hex.length / 2 | 0;
  const bytes = $makebytes(byte_len, 0);
  const chars = _M0MPC16string6String9to__array(hex);
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < byte_len) {
      const _bind = _M0FP36mizchi3bit6object18hex__char__to__int(_M0MPC15array5Array2atGcE(chars, Math.imul(i, 2) | 0));
      let hi;
      if (_bind.$tag === 1) {
        const _ok = _bind;
        hi = _ok._0;
      } else {
        return _bind;
      }
      const _bind$2 = _M0FP36mizchi3bit6object18hex__char__to__int(_M0MPC15array5Array2atGcE(chars, (Math.imul(i, 2) | 0) + 1 | 0));
      let lo;
      if (_bind$2.$tag === 1) {
        const _ok = _bind$2;
        lo = _ok._0;
      } else {
        return _bind$2;
      }
      $bound_check(bytes, i);
      bytes[i] = (hi << 4 | lo) & 255;
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return new _M0DTPC16result6ResultGRP36mizchi3bit6object8ObjectIdRP36mizchi3bit6object8GitErrorE2Ok(new _M0TP36mizchi3bit6object8ObjectId(bytes));
}
function _M0FP36mizchi3bit6object18int__to__hex__char(i) {
  return i < 10 ? i + 48 | 0 : (i - 10 | 0) + 97 | 0;
}
function _M0MP36mizchi3bit6object8ObjectId7to__hex(self) {
  const result = _M0MPB13StringBuilder11new_2einner(0);
  const _bind = self.bytes;
  const _bind$2 = _bind.length;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind$2) {
      const b = _bind[_];
      const hi = b >> 4 & 15;
      const lo = b & 15;
      _M0IPB13StringBuilderPB6Logger11write__char(result, _M0FP36mizchi3bit6object18int__to__hex__char(hi));
      _M0IPB13StringBuilderPB6Logger11write__char(result, _M0FP36mizchi3bit6object18int__to__hex__char(lo));
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return result.val;
}
function _M0MP36mizchi3bit6object10ObjectType10to__string(self) {
  switch (self) {
    case 0: {
      return "blob";
    }
    case 1: {
      return "tree";
    }
    case 2: {
      return "commit";
    }
    default: {
      return "tag";
    }
  }
}
function _M0MP36mizchi3bit6object9TreeEntry3new(mode, name, id) {
  return new _M0TP36mizchi3bit6object9TreeEntry(mode, name, id);
}
function _M0MP36mizchi3bit6object6Commit11new_2einner(tree, parents, author, author_time, author_tz, committer, commit_time, committer_tz, message, encoding, verbatim_message) {
  return new _M0TP36mizchi3bit6object6Commit(tree, parents, author, author_time, author_tz, committer, commit_time, committer_tz, message, encoding, verbatim_message);
}
function _M0MP36mizchi3bit6object9Sha1State6finish(self) {
  return _M0MP36mizchi3bit6object8ObjectId3new(_M0MP36mizchi3bit4hash9Sha1State11finish__raw(self.inner));
}
function _M0MP36mizchi3bit6object9Sha1State3new() {
  return new _M0TP36mizchi3bit6object9Sha1State(_M0MP36mizchi3bit4hash9Sha1State3new());
}
function _M0MP36mizchi3bit6object9Sha1State6update(self, data) {
  _M0MP36mizchi3bit4hash9Sha1State6update(self.inner, data);
}
function _M0MP36mizchi3bit6object9Sha1State14update__string(self, s) {
  _M0MP36mizchi3bit4hash9Sha1State14update__string(self.inner, s);
}
function _M0FP36mizchi3bit6object21hash__object__content(obj_type, content) {
  const state = _M0MP36mizchi3bit6object9Sha1State3new();
  const header = `${_M0MP36mizchi3bit6object10ObjectType10to__string(obj_type)} ${_M0IP016_24default__implPB4Show10to__stringGiE(content.length)}\u0000`;
  _M0MP36mizchi3bit6object9Sha1State14update__string(state, header);
  _M0MP36mizchi3bit6object9Sha1State6update(state, content);
  return _M0MP36mizchi3bit6object9Sha1State6finish(state);
}
function _M0MP36mizchi3bit6object10PackObject3new(obj_type, data) {
  const id = _M0FP36mizchi3bit6object21hash__object__content(obj_type, data);
  return new _M0TP36mizchi3bit6object10PackObject(obj_type, data, id, -1, 0);
}
function _M0MP36mizchi3bit6object10PackObject14with__metadata(obj_type, data, id, offset, crc32) {
  return new _M0TP36mizchi3bit6object10PackObject(obj_type, data, id, offset, crc32);
}
function _M0MP36mizchi3bit6object11Sha256State3new() {
  return new _M0TP36mizchi3bit6object11Sha256State(_M0MP36mizchi3bit4hash11Sha256State3new());
}
function _M0MP36mizchi3bit6object11Sha256State6update(self, data) {
  _M0MP36mizchi3bit4hash11Sha256State6update(self.inner, data);
}
function _M0MP36mizchi3bit6object11Sha256State14update__string(self, s) {
  _M0MP36mizchi3bit4hash11Sha256State14update__string(self.inner, s);
}
function _M0MP36mizchi3bit6object11Sha256State6finish(self) {
  return _M0MP36mizchi3bit6object8ObjectId3new(_M0MP36mizchi3bit4hash11Sha256State11finish__raw(self.inner));
}
function _M0FP36mizchi3bit6object4sha1(data) {
  return _M0MP36mizchi3bit6object8ObjectId3new(_M0FP36mizchi3bit4hash9sha1__raw(data));
}
function _M0FP36mizchi3bit6object16array__to__bytes(arr) {
  return _M0MPC15bytes5Bytes10from__iter(_M0MPC15array5Array4iterGyE(arr));
}
function _M0FP36mizchi3bit6object23string__to__byte__array(s) {
  const arr = [];
  const _it = _M0MPC16string6String4iter(s);
  while (true) {
    const _bind = _M0MPB4Iter4nextGcE(_it);
    if (_bind === -1) {
      break;
    } else {
      const _Some = _bind;
      const _c = _Some;
      _M0MPC15array5Array4pushGyE(arr, _c & 255);
      continue;
    }
  }
  return arr;
}
function _M0FP36mizchi3bit6object21object__append__bytes(out, data) {
  const _bind = data.length;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind) {
      const b = data[_];
      _M0MPC15array5Array4pushGyE(out, b);
      _tmp = _ + 1 | 0;
      continue;
    } else {
      return;
    }
  }
}
function _M0FP36mizchi3bit6object28object__append__utf8__string(out, s) {
  _M0FP36mizchi3bit6object21object__append__bytes(out, _M0FPC28encoding4utf814encode_2einner(new _M0TPC16string10StringView(s, 0, s.length), false));
}
function _M0FP36mizchi3bit6object33object__normalize__encoding__name(value) {
  const out = _M0MPB13StringBuilder11new_2einner(0);
  const _it = _M0MPC16string10StringView4iter(_M0MPC16string10StringView9to__lower(_M0MPC16string6String4trim(value, undefined)));
  while (true) {
    const _bind = _M0MPB4Iter4nextGcE(_it);
    if (_bind === -1) {
      break;
    } else {
      const _Some = _bind;
      const _c = _Some;
      if (_c === 45 || (_c === 95 || _c === 32)) {
        continue;
      }
      _M0IPB13StringBuilderPB6Logger11write__char(out, _c);
      continue;
    }
  }
  return out.val;
}
function _M0FP36mizchi3bit6object26object__is__utf8__encoding(encoding) {
  const normalized = _M0FP36mizchi3bit6object33object__normalize__encoding__name(encoding);
  return normalized === "" || normalized === "utf8";
}
function _M0FP36mizchi3bit6object34object__is__iso__8859__1__encoding(encoding) {
  const normalized = _M0FP36mizchi3bit6object33object__normalize__encoding__name(encoding);
  return normalized === "iso88591" || (normalized === "latin1" || normalized === "latin");
}
function _M0FP36mizchi3bit6object30object__commit__message__bytes(message, encoding) {
  if (_M0FP36mizchi3bit6object34object__is__iso__8859__1__encoding(encoding)) {
    const out = [];
    const _it = _M0MPC16string6String4iter(message);
    while (true) {
      const _bind = _M0MPB4Iter4nextGcE(_it);
      if (_bind === -1) {
        break;
      } else {
        const _Some = _bind;
        const _c = _Some;
        const code = _c;
        if (code <= 255) {
          _M0MPC15array5Array4pushGyE(out, code & 255);
        } else {
          const _bind$2 = _M0IPC14char4CharPB4Show10to__string(_c);
          _M0FP36mizchi3bit6object21object__append__bytes(out, _M0FPC28encoding4utf814encode_2einner(new _M0TPC16string10StringView(_bind$2, 0, _bind$2.length), false));
        }
        continue;
      }
    }
    return out;
  } else {
    return _M0MPC15bytes5Bytes9to__array(_M0FPC28encoding4utf814encode_2einner(new _M0TPC16string10StringView(message, 0, message.length), false));
  }
}
function _M0FP36mizchi3bit6object41object__serialize__commit__content__array(commit) {
  const content = [];
  _M0FP36mizchi3bit6object28object__append__utf8__string(content, "tree ");
  _M0FP36mizchi3bit6object28object__append__utf8__string(content, _M0MP36mizchi3bit6object8ObjectId7to__hex(commit.tree));
  _M0MPC15array5Array4pushGyE(content, 10);
  const _bind = commit.parents;
  const _bind$2 = _bind.length;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind$2) {
      const parent = _bind[_];
      _M0FP36mizchi3bit6object28object__append__utf8__string(content, "parent ");
      _M0FP36mizchi3bit6object28object__append__utf8__string(content, _M0MP36mizchi3bit6object8ObjectId7to__hex(parent));
      _M0MPC15array5Array4pushGyE(content, 10);
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  _M0FP36mizchi3bit6object28object__append__utf8__string(content, "author ");
  _M0FP36mizchi3bit6object28object__append__utf8__string(content, commit.author);
  _M0FP36mizchi3bit6object28object__append__utf8__string(content, " ");
  _M0FP36mizchi3bit6object28object__append__utf8__string(content, _M0MPC15int645Int6418to__string_2einner(commit.author_time, 10));
  _M0FP36mizchi3bit6object28object__append__utf8__string(content, " ");
  _M0FP36mizchi3bit6object28object__append__utf8__string(content, commit.author_tz);
  _M0MPC15array5Array4pushGyE(content, 10);
  _M0FP36mizchi3bit6object28object__append__utf8__string(content, "committer ");
  _M0FP36mizchi3bit6object28object__append__utf8__string(content, commit.committer);
  _M0FP36mizchi3bit6object28object__append__utf8__string(content, " ");
  _M0FP36mizchi3bit6object28object__append__utf8__string(content, _M0MPC15int645Int6418to__string_2einner(commit.commit_time, 10));
  _M0FP36mizchi3bit6object28object__append__utf8__string(content, " ");
  _M0FP36mizchi3bit6object28object__append__utf8__string(content, commit.committer_tz);
  _M0MPC15array5Array4pushGyE(content, 10);
  if (commit.encoding.length > 0 && !_M0FP36mizchi3bit6object26object__is__utf8__encoding(commit.encoding)) {
    _M0FP36mizchi3bit6object28object__append__utf8__string(content, "encoding ");
    _M0FP36mizchi3bit6object28object__append__utf8__string(content, commit.encoding);
    _M0MPC15array5Array4pushGyE(content, 10);
  }
  _M0MPC15array5Array4pushGyE(content, 10);
  const msg_bytes = _M0FP36mizchi3bit6object30object__commit__message__bytes(commit.message, commit.encoding);
  _M0MPC15array5Array6appendGyE(content, new _M0TPB9ArrayViewGyE(msg_bytes, 0, msg_bytes.length));
  if (!commit.verbatim_message) {
    if (msg_bytes.length === 0 || _M0MPC15array5Array2atGyE(msg_bytes, msg_bytes.length - 1 | 0) !== 10) {
      _M0MPC15array5Array4pushGyE(content, 10);
    }
  }
  return content;
}
function _M0FP36mizchi3bit6object14format__object(obj_type, content) {
  const header = `${_M0MP36mizchi3bit6object10ObjectType10to__string(obj_type)} ${_M0IP016_24default__implPB4Show10to__stringGiE(content.length)}\u0000`;
  const result = [];
  const _it = _M0MPC16string6String4iter(header);
  while (true) {
    const _bind = _M0MPB4Iter4nextGcE(_it);
    if (_bind === -1) {
      break;
    } else {
      const _Some = _bind;
      const _c = _Some;
      _M0MPC15array5Array4pushGyE(result, _c & 255);
      continue;
    }
  }
  const _bind = content.length;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind) {
      const b = content[_];
      _M0MPC15array5Array4pushGyE(result, b);
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return _M0FP36mizchi3bit6object16array__to__bytes(result);
}
function _M0FP36mizchi3bit6object14create__object(obj_type, content) {
  const raw = _M0FP36mizchi3bit6object14format__object(obj_type, content);
  const id = _M0FP36mizchi3bit6object4sha1(raw);
  const compressed = _M0FP26mizchi4zlib14zlib__compress(raw);
  return { _0: id, _1: compressed };
}
function _M0FP36mizchi3bit6object12create__blob(content) {
  return _M0FP36mizchi3bit6object14create__object(0, content);
}
function _M0FP36mizchi3bit6object20create__blob__string(content) {
  return _M0FP36mizchi3bit6object12create__blob(_M0FP36mizchi3bit6object16array__to__bytes(_M0FP36mizchi3bit6object23string__to__byte__array(content)));
}
function _M0FP36mizchi3bit6object26serialize__commit__content(commit) {
  return _M0FP36mizchi3bit6object16array__to__bytes(_M0FP36mizchi3bit6object41object__serialize__commit__content__array(commit));
}
function _M0FP36mizchi3bit6object15serialize__tree(entries) {
  const content = [];
  const _bind = entries.length;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind) {
      const entry = entries[_];
      const _it = _M0MPC16string6String4iter(entry.mode);
      while (true) {
        const _bind$2 = _M0MPB4Iter4nextGcE(_it);
        if (_bind$2 === -1) {
          break;
        } else {
          const _Some = _bind$2;
          const _c = _Some;
          _M0MPC15array5Array4pushGyE(content, _c & 255);
          continue;
        }
      }
      _M0MPC15array5Array4pushGyE(content, 32);
      _M0FP36mizchi3bit6object28object__append__utf8__string(content, entry.name);
      _M0MPC15array5Array4pushGyE(content, 0);
      const _bind$2 = entry.id.bytes;
      const _bind$3 = _bind$2.length;
      let _tmp$2 = 0;
      while (true) {
        const _$2 = _tmp$2;
        if (_$2 < _bind$3) {
          const b = _bind$2[_$2];
          _M0MPC15array5Array4pushGyE(content, b);
          _tmp$2 = _$2 + 1 | 0;
          continue;
        } else {
          break;
        }
      }
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return _M0FP36mizchi3bit6object16array__to__bytes(content);
}
function _M0MP36mizchi3bit6object9HashState3new(algo) {
  if (algo === 0) {
    return new _M0DTP36mizchi3bit6object9HashState3HS1(_M0MP36mizchi3bit6object9Sha1State3new());
  } else {
    return new _M0DTP36mizchi3bit6object9HashState5HS256(_M0MP36mizchi3bit6object11Sha256State3new());
  }
}
function _M0MP36mizchi3bit6object9HashState6update(self, data) {
  if (self.$tag === 0) {
    const _HS1 = self;
    const _s = _HS1._0;
    _M0MP36mizchi3bit6object9Sha1State6update(_s, data);
    return;
  } else {
    const _HS256 = self;
    const _s = _HS256._0;
    _M0MP36mizchi3bit6object11Sha256State6update(_s, data);
    return;
  }
}
function _M0MP36mizchi3bit6object9HashState14update__string(self, s) {
  if (self.$tag === 0) {
    const _HS1 = self;
    const _st = _HS1._0;
    _M0MP36mizchi3bit6object9Sha1State14update__string(_st, s);
    return;
  } else {
    const _HS256 = self;
    const _st = _HS256._0;
    _M0MP36mizchi3bit6object11Sha256State14update__string(_st, s);
    return;
  }
}
function _M0MP36mizchi3bit6object9HashState6finish(self) {
  if (self.$tag === 0) {
    const _HS1 = self;
    const _s = _HS1._0;
    return _M0MP36mizchi3bit6object9Sha1State6finish(_s);
  } else {
    const _HS256 = self;
    const _s = _HS256._0;
    return _M0MP36mizchi3bit6object11Sha256State6finish(_s);
  }
}
function _M0FP36mizchi3bit6object33hash__object__content__with__algo(algo, obj_type, content) {
  const state = _M0MP36mizchi3bit6object9HashState3new(algo);
  const header = `${_M0MP36mizchi3bit6object10ObjectType10to__string(obj_type)} ${_M0IP016_24default__implPB4Show10to__stringGiE(content.length)}\u0000`;
  _M0MP36mizchi3bit6object9HashState14update__string(state, header);
  _M0MP36mizchi3bit6object9HashState6update(state, content);
  return _M0MP36mizchi3bit6object9HashState6finish(state);
}
function _M0MP36mizchi3bit2io11EnvProvider4none() {
  return new _M0TP36mizchi3bit2io11EnvProvider((_discard_) => undefined, () => undefined);
}
function _M0FP36mizchi3bit2io8env__get(name) {
  const _func = _M0FP36mizchi3bit2io18env__provider__box.value.get;
  return _func(name);
}
function _M0FP36mizchi3bit4repo13parse__commit(content) {
  const text = _M0FPC28encoding4utf821decode__lossy_2einner(_M0MPC15bytes5Bytes12view_2einner(content, 0, content.length), false);
  let tree_id = undefined;
  const parents = [];
  const _it = _M0MPC16string6String5split(text, new _M0TPC16string10StringView(_M0FP36mizchi3bit4repo13parse__commitN7_2abindS189, 0, _M0FP36mizchi3bit4repo13parse__commitN7_2abindS189.length));
  while (true) {
    const _bind = _M0MPB4Iter4nextGRPC16string10StringViewE(_it);
    if (_bind === undefined) {
      break;
    } else {
      const _Some = _bind;
      const _line_view = _Some;
      const line = _M0IPC16string10StringViewPB4Show10to__string(_line_view);
      if (line.length === 0) {
        break;
      }
      if (_M0MPC16string6String11has__prefix(line, new _M0TPC16string10StringView(_M0FP36mizchi3bit4repo13parse__commitN7_2abindS177, 0, _M0FP36mizchi3bit4repo13parse__commitN7_2abindS177.length))) {
        const hex = line.substring(5, line.length);
        const _bind$2 = _M0MP36mizchi3bit6object8ObjectId9from__hex(hex);
        let _tmp;
        if (_bind$2.$tag === 1) {
          const _ok = _bind$2;
          _tmp = _ok._0;
        } else {
          return _bind$2;
        }
        tree_id = _tmp;
      } else {
        if (_M0MPC16string6String11has__prefix(line, new _M0TPC16string10StringView(_M0FP36mizchi3bit4repo13parse__commitN7_2abindS178, 0, _M0FP36mizchi3bit4repo13parse__commitN7_2abindS178.length))) {
          const hex = line.substring(7, line.length);
          const _bind$2 = _M0MP36mizchi3bit6object8ObjectId9from__hex(hex);
          let _tmp;
          if (_bind$2.$tag === 1) {
            const _ok = _bind$2;
            _tmp = _ok._0;
          } else {
            return _bind$2;
          }
          _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(parents, _tmp);
        }
      }
      continue;
    }
  }
  const _bind = tree_id;
  if (_bind === undefined) {
    return new _M0DTPC16result6ResultGRP36mizchi3bit4repo10CommitInfoRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject("Missing tree in commit"));
  } else {
    const _Some = _bind;
    const _tree = _Some;
    return new _M0DTPC16result6ResultGRP36mizchi3bit4repo10CommitInfoRP36mizchi3bit6object8GitErrorE2Ok(new _M0TP36mizchi3bit4repo10CommitInfo(_tree, parents));
  }
}
function _M0FP36mizchi3bit4repo28parse__tree__mode__is__octal(mode) {
  if (mode.length === 0) {
    return false;
  }
  const _it = _M0MPC16string6String4iter(mode);
  while (true) {
    const _bind = _M0MPB4Iter4nextGcE(_it);
    if (_bind === -1) {
      break;
    } else {
      const _Some = _bind;
      const _c = _Some;
      if (_c < 48 || _c > 55) {
        return false;
      }
      continue;
    }
  }
  return true;
}
function _M0FP36mizchi3bit4repo29parse__tree__with__hash__size(content, hash_size) {
  const entries = [];
  let i = 0;
  while (true) {
    if (i < content.length) {
      const mode_buf = _M0MPB13StringBuilder11new_2einner(0);
      while (true) {
        let _tmp;
        if (i < content.length) {
          const _tmp$2 = i;
          $bound_check(content, _tmp$2);
          _tmp = content[_tmp$2] !== 32;
        } else {
          _tmp = false;
        }
        if (_tmp) {
          const _tmp$2 = i;
          $bound_check(content, _tmp$2);
          _M0IPB13StringBuilderPB6Logger11write__char(mode_buf, content[_tmp$2]);
          i = i + 1 | 0;
          continue;
        } else {
          break;
        }
      }
      if (i >= content.length) {
        return new _M0DTPC16result6ResultGRPB5ArrayGRP36mizchi3bit6object9TreeEntryERP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject("Truncated tree entry mode"));
      }
      const mode = mode_buf.val;
      if (!_M0FP36mizchi3bit4repo28parse__tree__mode__is__octal(mode)) {
        return new _M0DTPC16result6ResultGRPB5ArrayGRP36mizchi3bit6object9TreeEntryERP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject("Invalid tree entry mode"));
      }
      i = i + 1 | 0;
      const name_start = i;
      while (true) {
        let _tmp;
        if (i < content.length) {
          const _tmp$2 = i;
          $bound_check(content, _tmp$2);
          _tmp = content[_tmp$2] !== 0;
        } else {
          _tmp = false;
        }
        if (_tmp) {
          i = i + 1 | 0;
          continue;
        } else {
          break;
        }
      }
      if (i >= content.length) {
        return new _M0DTPC16result6ResultGRPB5ArrayGRP36mizchi3bit6object9TreeEntryERP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject("Truncated tree entry name"));
      }
      const name_len = i - name_start | 0;
      let name_bytes;
      if (name_len <= 0) {
        name_bytes = new Uint8Array([]);
      } else {
        const _p = 0;
        const _tmp = name_start + _p | 0;
        $bound_check(content, _tmp);
        const _p$2 = $makebytes(name_len, content[_tmp]);
        let _tmp$2 = 1;
        while (true) {
          const _p$3 = _tmp$2;
          if (_p$3 < name_len) {
            const _tmp$3 = name_start + _p$3 | 0;
            $bound_check(content, _tmp$3);
            $bound_check(_p$2, _p$3);
            _p$2[_p$3] = content[_tmp$3];
            _tmp$2 = _p$3 + 1 | 0;
            continue;
          } else {
            break;
          }
        }
        name_bytes = _p$2;
      }
      const _bind = _M0MPC15bytes5Bytes11from__array(new _M0TPB9ArrayViewGyE(name_bytes, 0, name_bytes.length));
      const name = _M0FPC28encoding4utf821decode__lossy_2einner(_M0MPC15bytes5Bytes12view_2einner(_bind, 0, _bind.length), false);
      i = i + 1 | 0;
      if ((i + hash_size | 0) > content.length) {
        return new _M0DTPC16result6ResultGRPB5ArrayGRP36mizchi3bit6object9TreeEntryERP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject("Truncated tree entry id"));
      }
      const id = _M0MP36mizchi3bit6object8ObjectId23from__bytes__at_2einner(content, i, hash_size);
      i = i + hash_size | 0;
      _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(entries, _M0MP36mizchi3bit6object9TreeEntry3new(mode, name, id));
      continue;
    } else {
      break;
    }
  }
  return new _M0DTPC16result6ResultGRPB5ArrayGRP36mizchi3bit6object9TreeEntryERP36mizchi3bit6object8GitErrorE2Ok(entries);
}
function _M0FP36mizchi3bit4repo11parse__tree(content) {
  if (content.length === 0) {
    return new _M0DTPC16result6ResultGRPB5ArrayGRP36mizchi3bit6object9TreeEntryERP36mizchi3bit6object8GitErrorE2Ok([]);
  }
  let _bind;
  let _try_err;
  _L: {
    _L$2: {
      const _bind$2 = _M0FP36mizchi3bit4repo29parse__tree__with__hash__size(content, 20);
      let _tmp;
      if (_bind$2.$tag === 1) {
        const _ok = _bind$2;
        _tmp = _ok._0;
      } else {
        const _err = _bind$2;
        _try_err = _err._0;
        break _L$2;
      }
      _bind = new _M0DTPC16result6ResultGRPB5ArrayGRP36mizchi3bit6object9TreeEntryERP36mizchi3bit6object8GitErrorE2Ok(_tmp);
      break _L;
    }
    _bind = new _M0DTPC16result6ResultGRPB5ArrayGRP36mizchi3bit6object9TreeEntryERP36mizchi3bit6object8GitErrorE3Err(_try_err);
  }
  let _bind$2;
  let _try_err$2;
  _L$2: {
    _L$3: {
      const _bind$3 = _M0FP36mizchi3bit4repo29parse__tree__with__hash__size(content, 32);
      let _tmp;
      if (_bind$3.$tag === 1) {
        const _ok = _bind$3;
        _tmp = _ok._0;
      } else {
        const _err = _bind$3;
        _try_err$2 = _err._0;
        break _L$3;
      }
      _bind$2 = new _M0DTPC16result6ResultGRPB5ArrayGRP36mizchi3bit6object9TreeEntryERP36mizchi3bit6object8GitErrorE2Ok(_tmp);
      break _L$2;
    }
    _bind$2 = new _M0DTPC16result6ResultGRPB5ArrayGRP36mizchi3bit6object9TreeEntryERP36mizchi3bit6object8GitErrorE3Err(_try_err$2);
  }
  if (_bind.$tag === 1) {
    const _Ok = _bind;
    const _entries = _Ok._0;
    if (_bind$2.$tag === 0) {
      return new _M0DTPC16result6ResultGRPB5ArrayGRP36mizchi3bit6object9TreeEntryERP36mizchi3bit6object8GitErrorE2Ok(_entries);
    } else {
      return new _M0DTPC16result6ResultGRPB5ArrayGRP36mizchi3bit6object9TreeEntryERP36mizchi3bit6object8GitErrorE2Ok(_entries);
    }
  } else {
    if (_bind$2.$tag === 1) {
      const _Ok = _bind$2;
      const _entries = _Ok._0;
      return new _M0DTPC16result6ResultGRPB5ArrayGRP36mizchi3bit6object9TreeEntryERP36mizchi3bit6object8GitErrorE2Ok(_entries);
    } else {
      return new _M0DTPC16result6ResultGRPB5ArrayGRP36mizchi3bit6object9TreeEntryERP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject("Invalid tree object"));
    }
  }
}
function _M0FP36mizchi3bit4pack17read__delta__size(data, start) {
  let offset = start;
  let size = 0;
  let shift = 0;
  while (true) {
    if (offset >= data.length) {
      return new _M0DTPC16result6ResultGUiiERP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2ePackfileError("Unexpected end of delta data"));
    }
    const _tmp = offset;
    $bound_check(data, _tmp);
    const b = data[_tmp];
    offset = offset + 1 | 0;
    size = size | (b & 127) << shift;
    if ((b & 128) === 0) {
      break;
    }
    shift = shift + 7 | 0;
    continue;
  }
  return new _M0DTPC16result6ResultGUiiERP36mizchi3bit6object8GitErrorE2Ok({ _0: size, _1: offset });
}
function _M0FP36mizchi3bit4pack12apply__delta(base, delta) {
  let offset = 0;
  const _bind = _M0FP36mizchi3bit4pack17read__delta__size(delta, offset);
  let _bind$2;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    _bind$2 = _ok._0;
  } else {
    return _bind;
  }
  const _base_size = _bind$2._0;
  const _off1 = _bind$2._1;
  offset = _off1;
  if (_base_size !== base.length) {
    return new _M0DTPC16result6ResultGzRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2ePackfileError("Delta base size mismatch"));
  }
  const _bind$3 = _M0FP36mizchi3bit4pack17read__delta__size(delta, offset);
  let _bind$4;
  if (_bind$3.$tag === 1) {
    const _ok = _bind$3;
    _bind$4 = _ok._0;
  } else {
    return _bind$3;
  }
  const _result_size = _bind$4._0;
  const _off2 = _bind$4._1;
  offset = _off2;
  const out = $makebytes(_result_size, 0);
  let out_pos = 0;
  while (true) {
    if (offset < delta.length) {
      const _tmp = offset;
      $bound_check(delta, _tmp);
      const opcode = delta[_tmp];
      offset = offset + 1 | 0;
      if ((opcode & 128) !== 0) {
        let cp_off = 0;
        let cp_size = 0;
        if ((opcode & 1) !== 0) {
          const _tmp$2 = cp_off;
          const _tmp$3 = offset;
          $bound_check(delta, _tmp$3);
          cp_off = _tmp$2 | delta[_tmp$3];
          offset = offset + 1 | 0;
        }
        if ((opcode & 2) !== 0) {
          const _tmp$2 = cp_off;
          const _tmp$3 = offset;
          $bound_check(delta, _tmp$3);
          cp_off = _tmp$2 | delta[_tmp$3] << 8;
          offset = offset + 1 | 0;
        }
        if ((opcode & 4) !== 0) {
          const _tmp$2 = cp_off;
          const _tmp$3 = offset;
          $bound_check(delta, _tmp$3);
          cp_off = _tmp$2 | delta[_tmp$3] << 16;
          offset = offset + 1 | 0;
        }
        if ((opcode & 8) !== 0) {
          const _tmp$2 = cp_off;
          const _tmp$3 = offset;
          $bound_check(delta, _tmp$3);
          cp_off = _tmp$2 | delta[_tmp$3] << 24;
          offset = offset + 1 | 0;
        }
        if ((opcode & 16) !== 0) {
          const _tmp$2 = cp_size;
          const _tmp$3 = offset;
          $bound_check(delta, _tmp$3);
          cp_size = _tmp$2 | delta[_tmp$3];
          offset = offset + 1 | 0;
        }
        if ((opcode & 32) !== 0) {
          const _tmp$2 = cp_size;
          const _tmp$3 = offset;
          $bound_check(delta, _tmp$3);
          cp_size = _tmp$2 | delta[_tmp$3] << 8;
          offset = offset + 1 | 0;
        }
        if ((opcode & 64) !== 0) {
          const _tmp$2 = cp_size;
          const _tmp$3 = offset;
          $bound_check(delta, _tmp$3);
          cp_size = _tmp$2 | delta[_tmp$3] << 16;
          offset = offset + 1 | 0;
        }
        if (cp_size === 0) {
          cp_size = 65536;
        }
        if (cp_off < 0 || (cp_off + cp_size | 0) > base.length) {
          return new _M0DTPC16result6ResultGzRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2ePackfileError("Delta copy out of range"));
        }
        const _bind$5 = cp_size;
        let _tmp$2 = 0;
        while (true) {
          const i = _tmp$2;
          if (i < _bind$5) {
            const _tmp$3 = out_pos;
            const _tmp$4 = cp_off + i | 0;
            $bound_check(base, _tmp$4);
            $bound_check(out, _tmp$3);
            out[_tmp$3] = base[_tmp$4];
            out_pos = out_pos + 1 | 0;
            _tmp$2 = i + 1 | 0;
            continue;
          } else {
            break;
          }
        }
      } else {
        const literal_len = opcode & 127;
        if (literal_len === 0) {
          return new _M0DTPC16result6ResultGzRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2ePackfileError("Invalid delta opcode"));
        }
        if ((offset + literal_len | 0) > delta.length) {
          return new _M0DTPC16result6ResultGzRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2ePackfileError("Delta literal out of range"));
        }
        let _tmp$2 = 0;
        while (true) {
          const i = _tmp$2;
          if (i < literal_len) {
            const _tmp$3 = out_pos;
            const _tmp$4 = offset + i | 0;
            $bound_check(delta, _tmp$4);
            $bound_check(out, _tmp$3);
            out[_tmp$3] = delta[_tmp$4];
            out_pos = out_pos + 1 | 0;
            _tmp$2 = i + 1 | 0;
            continue;
          } else {
            break;
          }
        }
        offset = offset + literal_len | 0;
      }
      continue;
    } else {
      break;
    }
  }
  if (out_pos !== _result_size) {
    return new _M0DTPC16result6ResultGzRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2ePackfileError("Delta result size mismatch"));
  }
  return new _M0DTPC16result6ResultGzRP36mizchi3bit6object8GitErrorE2Ok(_M0MPC15bytes5Bytes11from__array(new _M0TPB9ArrayViewGyE(out, 0, out.length)));
}
function _M0FP36mizchi3bit4pack27decode__type__and__size__at(data, start) {
  if (start < 0 || start >= data.length) {
    return new _M0DTPC16result6ResultGUiiiERP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2ePackfileError("Unexpected end of packfile header"));
  }
  $bound_check(data, start);
  const first = data[start];
  let size = first & 15;
  const type_id = first >> 4 & 7;
  let shift = 4;
  let offset = start + 1 | 0;
  let has_more = (first & 128) !== 0;
  while (true) {
    if (has_more) {
      if (offset >= data.length) {
        return new _M0DTPC16result6ResultGUiiiERP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2ePackfileError("Unexpected end of packfile size"));
      }
      const _tmp = offset;
      $bound_check(data, _tmp);
      const b = data[_tmp];
      offset = offset + 1 | 0;
      size = size | (b & 127) << shift;
      shift = shift + 7 | 0;
      has_more = (b & 128) !== 0;
      continue;
    } else {
      break;
    }
  }
  return new _M0DTPC16result6ResultGUiiiERP36mizchi3bit6object8GitErrorE2Ok({ _0: type_id, _1: size, _2: offset });
}
function _M0FP36mizchi3bit4pack32packfile__type__to__object__type(type_id) {
  switch (type_id) {
    case 1: {
      return new _M0DTPC16result6ResultGRP36mizchi3bit6object10ObjectTypeRP36mizchi3bit6object8GitErrorE2Ok(2);
    }
    case 2: {
      return new _M0DTPC16result6ResultGRP36mizchi3bit6object10ObjectTypeRP36mizchi3bit6object8GitErrorE2Ok(1);
    }
    case 3: {
      return new _M0DTPC16result6ResultGRP36mizchi3bit6object10ObjectTypeRP36mizchi3bit6object8GitErrorE2Ok(0);
    }
    case 4: {
      return new _M0DTPC16result6ResultGRP36mizchi3bit6object10ObjectTypeRP36mizchi3bit6object8GitErrorE2Ok(3);
    }
    default: {
      return new _M0DTPC16result6ResultGRP36mizchi3bit6object10ObjectTypeRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2ePackfileError(`Unknown packfile object type: ${_M0IP016_24default__implPB4Show10to__stringGiE(type_id)}`));
    }
  }
}
function _M0FP36mizchi3bit4pack24read__ofs__delta__offset(data, start) {
  if (start >= data.length) {
    return new _M0DTPC16result6ResultGUiiERP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2ePackfileError("Unexpected end of packfile delta"));
  }
  let offset = start;
  const _tmp = offset;
  $bound_check(data, _tmp);
  let c = data[_tmp];
  offset = offset + 1 | 0;
  let val = c & 127;
  while (true) {
    if ((c & 128) !== 0) {
      if (offset >= data.length) {
        return new _M0DTPC16result6ResultGUiiERP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2ePackfileError("Unexpected end of packfile delta"));
      }
      const _tmp$2 = offset;
      $bound_check(data, _tmp$2);
      c = data[_tmp$2];
      offset = offset + 1 | 0;
      val = val + 1 << 7;
      val = val | c & 127;
      continue;
    } else {
      break;
    }
  }
  return new _M0DTPC16result6ResultGUiiERP36mizchi3bit6object8GitErrorE2Ok({ _0: val, _1: offset });
}
function _M0FP36mizchi3bit4pack28read__ref__delta__id_2einner(data, start, hash_size) {
  if ((start + hash_size | 0) > data.length) {
    return new _M0DTPC16result6ResultGUsiERP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2ePackfileError("Unexpected end of packfile delta"));
  }
  const bytes = $makebytes(hash_size, 0);
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < hash_size) {
      const _tmp$2 = start + i | 0;
      $bound_check(data, _tmp$2);
      $bound_check(bytes, i);
      bytes[i] = data[_tmp$2];
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const id = _M0MP36mizchi3bit6object8ObjectId3new(bytes);
  return new _M0DTPC16result6ResultGUsiERP36mizchi3bit6object8GitErrorE2Ok({ _0: _M0MP36mizchi3bit6object8ObjectId7to__hex(id), _1: start + hash_size | 0 });
}
function _M0FP36mizchi3bit8reftable19build__crc32__table() {
  const table = $make_array_len_and_init(256, 0);
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < 256) {
      let crc = i;
      let _tmp$2 = 0;
      while (true) {
        const _j = _tmp$2;
        if (_j < 8) {
          if ((crc & 1) !== 0) {
            crc = crc >>> 1 ^ -306674912;
          } else {
            crc = crc >>> 1 | 0;
          }
          _tmp$2 = _j + 1 | 0;
          continue;
        } else {
          break;
        }
      }
      $bound_check(table, i);
      table[i] = crc;
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return table;
}
function _M0FP36mizchi3bit8reftable17bytes__to__string(data, start, len) {
  const buf = _M0MPB13StringBuilder11new_2einner(0);
  let _tmp = start;
  while (true) {
    const i = _tmp;
    if (i < (start + len | 0)) {
      $bound_check(data, i);
      _M0IPB13StringBuilderPB6Logger11write__char(buf, data[i]);
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return buf.val;
}
function _M0FP36mizchi3bit8reftable12split__lines(s) {
  const lines = [];
  const buf = _M0MPB13StringBuilder11new_2einner(0);
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < s.length) {
      $bound_check(s, i);
      const ch = s.charCodeAt(i);
      if (ch === 10) {
        const line = buf.val;
        if (line.length > 0) {
          _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(lines, line);
        }
        _M0MPB13StringBuilder5reset(buf);
      } else {
        _M0IPB13StringBuilderPB6Logger11write__char(buf, ch);
      }
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const last = buf.val;
  if (last.length > 0) {
    _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(lines, last);
  }
  return lines;
}
function _M0FP36mizchi3bit8reftable18read__tables__list(fs, git_dir) {
  const path = `${git_dir}/reftable/tables.list`;
  if (!fs.method_table.method_3(fs.self, path)) {
    return new _M0DTPC16result6ResultGRPB5ArrayGsERP36mizchi3bit6object8GitErrorE2Ok([]);
  }
  const _bind = fs.method_table.method_0(fs.self, path);
  let data;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    data = _ok._0;
  } else {
    return _bind;
  }
  const content = _M0FP36mizchi3bit8reftable17bytes__to__string(data, 0, data.length);
  return new _M0DTPC16result6ResultGRPB5ArrayGsERP36mizchi3bit6object8GitErrorE2Ok(_M0FP36mizchi3bit8reftable12split__lines(content));
}
function _M0FP36mizchi3bit8reftable12load__tables(fs, git_dir) {
  const _bind = _M0FP36mizchi3bit8reftable18read__tables__list(fs, git_dir);
  let names;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    names = _ok._0;
  } else {
    return _bind;
  }
  const tables = [];
  const reftable_dir = `${git_dir}/reftable`;
  const _bind$2 = names.length;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind$2) {
      const name = names[_];
      const path = `${reftable_dir}/${name}`;
      if (fs.method_table.method_3(fs.self, path)) {
        const _bind$3 = fs.method_table.method_0(fs.self, path);
        let _tmp$2;
        if (_bind$3.$tag === 1) {
          const _ok = _bind$3;
          _tmp$2 = _ok._0;
        } else {
          return _bind$3;
        }
        _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(tables, _tmp$2);
      }
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return new _M0DTPC16result6ResultGRPB5ArrayGzERP36mizchi3bit6object8GitErrorE2Ok(tables);
}
function _M0FP36mizchi3bit8reftable14decode__varint(data, pos) {
  let val = $0L;
  let i = pos;
  while (true) {
    const _tmp = i;
    $bound_check(data, _tmp);
    const b = data[_tmp];
    val = _M0IPC16uint646UInt64PB5BitOr3lor(_M0IPC16uint646UInt64PB3Shl3shl(val, 7), _M0MPC13int3Int10to__uint64(b & 127));
    i = i + 1 | 0;
    if ((b & 128) === 0) {
      break;
    }
    val = _M0IPC16uint646UInt64PB3Add3add(val, $1L);
    continue;
  }
  return { _0: val, _1: i - pos | 0 };
}
function _M0FP36mizchi3bit8reftable19decode__ref__record(data, pos, prev_key, header) {
  if (pos >= data.length) {
    return undefined;
  }
  let offset = pos;
  const _bind = _M0FP36mizchi3bit8reftable14decode__varint(data, offset);
  const _prefix_len = _bind._0;
  const _n1 = _bind._1;
  offset = offset + _n1 | 0;
  const _bind$2 = _M0FP36mizchi3bit8reftable14decode__varint(data, offset);
  const _suffix_and_type = _bind$2._0;
  const _n2 = _bind$2._1;
  offset = offset + _n2 | 0;
  const value_type = _M0MPC16uint646UInt647to__int(_M0IPC16uint646UInt64PB6BitAnd4land(_suffix_and_type, $7L));
  const suffix_len = _M0MPC16uint646UInt647to__int(_M0IPC16uint646UInt64PB3Shr3shr(_suffix_and_type, 3));
  const prefix_len_int = _M0MPC16uint646UInt647to__int(_prefix_len);
  const key_buf = _M0MPB13StringBuilder11new_2einner(0);
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < prefix_len_int) {
      if (i < prev_key.length) {
        $bound_check(prev_key, i);
        _M0IPB13StringBuilderPB6Logger11write__char(key_buf, prev_key.charCodeAt(i));
      }
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  let _tmp$2 = 0;
  while (true) {
    const i = _tmp$2;
    if (i < suffix_len) {
      const _tmp$3 = offset + i | 0;
      $bound_check(data, _tmp$3);
      _M0IPB13StringBuilderPB6Logger11write__char(key_buf, data[_tmp$3]);
      _tmp$2 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  offset = offset + suffix_len | 0;
  const refname = key_buf.val;
  const _bind$3 = _M0FP36mizchi3bit8reftable14decode__varint(data, offset);
  const _update_index_delta = _bind$3._0;
  const _n3 = _bind$3._1;
  offset = offset + _n3 | 0;
  const update_index = _M0IPC16uint646UInt64PB3Add3add(header.min_update_index, _update_index_delta);
  let value;
  switch (value_type) {
    case 0: {
      value = _M0DTP36mizchi3bit8reftable8RefValue8Deletion__;
      break;
    }
    case 1: {
      const oid = _M0MP36mizchi3bit6object8ObjectId23from__bytes__at_2einner(data, offset, 20);
      offset = offset + 20 | 0;
      value = new _M0DTP36mizchi3bit8reftable8RefValue4Val1(oid);
      break;
    }
    case 2: {
      const oid1 = _M0MP36mizchi3bit6object8ObjectId23from__bytes__at_2einner(data, offset, 20);
      offset = offset + 20 | 0;
      const oid2 = _M0MP36mizchi3bit6object8ObjectId23from__bytes__at_2einner(data, offset, 20);
      offset = offset + 20 | 0;
      value = new _M0DTP36mizchi3bit8reftable8RefValue4Val2(oid1, oid2);
      break;
    }
    case 3: {
      const _bind$4 = _M0FP36mizchi3bit8reftable14decode__varint(data, offset);
      const _sym_len = _bind$4._0;
      const _n4 = _bind$4._1;
      offset = offset + _n4 | 0;
      const sym = _M0FP36mizchi3bit8reftable17bytes__to__string(data, offset, _M0MPC16uint646UInt647to__int(_sym_len));
      offset = offset + _M0MPC16uint646UInt647to__int(_sym_len) | 0;
      value = new _M0DTP36mizchi3bit8reftable8RefValue6Symref(sym);
      break;
    }
    default: {
      return undefined;
    }
  }
  return { _0: new _M0TP36mizchi3bit8reftable9RefRecord(refname, update_index, value), _1: offset - pos | 0 };
}
function _M0FP36mizchi3bit8reftable12crc32__bytes(data, start, end) {
  let crc = -1;
  let _tmp = start;
  while (true) {
    const i = _tmp;
    if (i < end) {
      const _tmp$2 = crc;
      $bound_check(data, i);
      const idx = (_tmp$2 ^ data[i]) & 255;
      const _tmp$3 = crc >>> 8 | 0;
      $bound_check(_M0FP36mizchi3bit8reftable12crc32__table, idx);
      crc = _tmp$3 ^ _M0FP36mizchi3bit8reftable12crc32__table[idx];
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return crc ^ -1;
}
function _M0FP36mizchi3bit8reftable13read__be__u24(data, pos) {
  $bound_check(data, pos);
  const _tmp = data[pos] << 16;
  const _tmp$2 = pos + 1 | 0;
  $bound_check(data, _tmp$2);
  const _tmp$3 = _tmp | data[_tmp$2] << 8;
  const _tmp$4 = pos + 2 | 0;
  $bound_check(data, _tmp$4);
  return _tmp$3 | data[_tmp$4];
}
function _M0FP36mizchi3bit8reftable13read__be__u32(data, pos) {
  $bound_check(data, pos);
  const _tmp = data[pos] << 24;
  const _tmp$2 = pos + 1 | 0;
  $bound_check(data, _tmp$2);
  const _tmp$3 = _tmp | data[_tmp$2] << 16;
  const _tmp$4 = pos + 2 | 0;
  $bound_check(data, _tmp$4);
  const _tmp$5 = _tmp$3 | data[_tmp$4] << 8;
  const _tmp$6 = pos + 3 | 0;
  $bound_check(data, _tmp$6);
  return _tmp$5 | data[_tmp$6];
}
function _M0FP36mizchi3bit8reftable13read__be__u64(data, pos) {
  const hi = _M0MPC14uint4UInt10to__uint64(_M0FP36mizchi3bit8reftable13read__be__u32(data, pos));
  const lo = _M0MPC14uint4UInt10to__uint64(_M0FP36mizchi3bit8reftable13read__be__u32(data, pos + 4 | 0));
  return _M0IPC16uint646UInt64PB5BitOr3lor(_M0IPC16uint646UInt64PB3Shl3shl(hi, 32), lo);
}
function _M0FP36mizchi3bit8reftable13parse__header(data) {
  if (data.length < 24) {
    return undefined;
  }
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < 4) {
      $bound_check(data, i);
      const _tmp$2 = data[i];
      $bound_check(_M0FP36mizchi3bit8reftable15reftable__magic, i);
      if (_tmp$2 !== _M0FP36mizchi3bit8reftable15reftable__magic[i]) {
        return undefined;
      }
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  $bound_check(data, 4);
  const version = data[4];
  if (version !== 1) {
    return undefined;
  }
  const block_size = _M0FP36mizchi3bit8reftable13read__be__u24(data, 5);
  const min_update_index = _M0FP36mizchi3bit8reftable13read__be__u64(data, 8);
  const max_update_index = _M0FP36mizchi3bit8reftable13read__be__u64(data, 16);
  return new _M0TP36mizchi3bit8reftable14ReftableHeader(version, block_size, min_update_index, max_update_index);
}
function _M0EPC15bytes5BytesP36mizchi3bit8reftable4blit(self, start, end) {
  const len = end - start | 0;
  let _bind;
  if (len <= 0) {
    _bind = new Uint8Array([]);
  } else {
    const _p = 0;
    const _tmp = start + _p | 0;
    $bound_check(self, _tmp);
    const _p$2 = $makebytes(len, self[_tmp]);
    let _tmp$2 = 1;
    while (true) {
      const _p$3 = _tmp$2;
      if (_p$3 < len) {
        const _tmp$3 = start + _p$3 | 0;
        $bound_check(self, _tmp$3);
        $bound_check(_p$2, _p$3);
        _p$2[_p$3] = self[_tmp$3];
        _tmp$2 = _p$3 + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    _bind = _p$2;
  }
  return _M0MPC15bytes5Bytes11from__array(new _M0TPB9ArrayViewGyE(_bind, 0, _bind.length));
}
function _M0FP36mizchi3bit8reftable13parse__footer(data) {
  const len = data.length;
  if (len < 68) {
    return undefined;
  }
  const footer_start = len - 68 | 0;
  const footer = _M0EPC15bytes5BytesP36mizchi3bit8reftable4blit(data, footer_start, len);
  const _bind = _M0FP36mizchi3bit8reftable13parse__header(footer);
  let header;
  if (_bind === undefined) {
    return undefined;
  } else {
    const _Some = _bind;
    header = _Some;
  }
  const ref_index_offset = _M0FP36mizchi3bit8reftable13read__be__u64(footer, 24);
  const obj_offset_raw = _M0FP36mizchi3bit8reftable13read__be__u64(footer, 32);
  const obj_index_offset = _M0FP36mizchi3bit8reftable13read__be__u64(footer, 40);
  const log_offset = _M0FP36mizchi3bit8reftable13read__be__u64(footer, 48);
  const log_index_offset = _M0FP36mizchi3bit8reftable13read__be__u64(footer, 56);
  const crc32 = _M0FP36mizchi3bit8reftable13read__be__u32(footer, 64);
  const computed_crc = _M0FP36mizchi3bit8reftable12crc32__bytes(footer, 0, 64);
  if (computed_crc !== crc32) {
    return undefined;
  }
  return new _M0TP36mizchi3bit8reftable14ReftableFooter(header, ref_index_offset, obj_offset_raw, obj_index_offset, log_offset, log_index_offset, crc32);
}
function _M0FP36mizchi3bit8reftable13read__be__u16(data, pos) {
  $bound_check(data, pos);
  const _tmp = data[pos] << 8;
  const _tmp$2 = pos + 1 | 0;
  $bound_check(data, _tmp$2);
  return _tmp | data[_tmp$2];
}
function _M0FP36mizchi3bit8reftable10read__refs(data) {
  const _bind = _M0FP36mizchi3bit8reftable13parse__header(data);
  let header;
  if (_bind === undefined) {
    return _M0DTPC16option6OptionGRPB5ArrayGRP36mizchi3bit8reftable9RefRecordEE4None__;
  } else {
    const _Some = _bind;
    header = _Some;
  }
  const block_size = header.block_size === 0 ? data.length : header.block_size;
  const records = [];
  let block_offset = 24;
  const _bind$2 = _M0FP36mizchi3bit8reftable13parse__footer(data);
  let footer;
  if (_bind$2 === undefined) {
    return _M0DTPC16option6OptionGRPB5ArrayGRP36mizchi3bit8reftable9RefRecordEE4None__;
  } else {
    const _Some = _bind$2;
    footer = _Some;
  }
  const ref_end = _M0IP016_24default__implPB7Compare6op__gtGmE(footer.log_offset, $0L) ? _M0MPC16uint646UInt647to__int(footer.log_offset) : data.length - 68 | 0;
  while (true) {
    if (block_offset < ref_end) {
      if ((block_offset + 4 | 0) > data.length) {
        break;
      }
      const _tmp = block_offset;
      $bound_check(data, _tmp);
      const block_type = data[_tmp];
      if (block_type !== 114) {
        break;
      }
      const block_len = _M0FP36mizchi3bit8reftable13read__be__u24(data, block_offset + 1 | 0);
      if (block_len === 0) {
        break;
      }
      const restart_count = _M0FP36mizchi3bit8reftable13read__be__u16(data, (block_offset + block_len | 0) - 2 | 0);
      const restarts_start = ((block_offset + block_len | 0) - 2 | 0) - (Math.imul(restart_count, 3) | 0) | 0;
      let rec_pos = block_offset + 4 | 0;
      let prev_key = "";
      while (true) {
        if (rec_pos < restarts_start) {
          const _bind$3 = _M0FP36mizchi3bit8reftable19decode__ref__record(data, rec_pos, prev_key, header);
          if (_bind$3 === undefined) {
            break;
          } else {
            const _Some = _bind$3;
            const _x = _Some;
            const _rec = _x._0;
            const _consumed = _x._1;
            prev_key = _rec.refname;
            _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(records, _rec);
            rec_pos = rec_pos + _consumed | 0;
          }
          continue;
        } else {
          break;
        }
      }
      if (block_size > 0 && header.block_size > 0) {
        block_offset = block_offset + block_size | 0;
      } else {
        break;
      }
      continue;
    } else {
      break;
    }
  }
  return new _M0DTPC16option6OptionGRPB5ArrayGRP36mizchi3bit8reftable9RefRecordEE4Some(records);
}
function _M0FP36mizchi3bit8reftable11lookup__ref(data, refname) {
  const _bind = _M0FP36mizchi3bit8reftable10read__refs(data);
  if (_bind.$tag === 1) {
    const _Some = _bind;
    const _refs = _Some._0;
    const _bind$2 = _refs.length;
    let _tmp = 0;
    while (true) {
      const _ = _tmp;
      if (_ < _bind$2) {
        const r = _refs[_];
        if (r.refname === refname) {
          return r;
        }
        _tmp = _ + 1 | 0;
        continue;
      } else {
        return undefined;
      }
    }
  } else {
    return undefined;
  }
}
function _M0FP36mizchi3bit8reftable22lookup__ref__in__stack(tables, refname) {
  let _tmp = tables.length - 1 | 0;
  while (true) {
    const i = _tmp;
    if (i >= 0) {
      _L: {
        const _bind = _M0FP36mizchi3bit8reftable11lookup__ref(_M0MPC15array5Array2atGUiiEE(tables, i), refname);
        if (_bind === undefined) {
          break _L;
        } else {
          const _Some = _bind;
          const _rec = _Some;
          return _rec;
        }
      }
      _tmp = i - 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return undefined;
}
function _M0FP36mizchi3bit8reftable26resolve__ref__from__tables(tables, refname, depth) {
  let _tmp = refname;
  let _tmp$2 = depth;
  _L: while (true) {
    const refname$2 = _tmp;
    const depth$2 = _tmp$2;
    if (depth$2 > 8) {
      return undefined;
    }
    const _bind = _M0FP36mizchi3bit8reftable22lookup__ref__in__stack(tables, refname$2);
    if (_bind === undefined) {
      return undefined;
    } else {
      const _Some = _bind;
      const _rec = _Some;
      const _bind$2 = _rec.value;
      switch (_bind$2.$tag) {
        case 1: {
          const _Val1 = _bind$2;
          const _oid = _Val1._0;
          return _oid;
        }
        case 2: {
          const _Val2 = _bind$2;
          const _oid$2 = _Val2._0;
          return _oid$2;
        }
        case 3: {
          const _Symref = _bind$2;
          const _target = _Symref._0;
          _tmp = _target;
          _tmp$2 = depth$2 + 1 | 0;
          continue _L;
        }
        default: {
          return undefined;
        }
      }
    }
  }
}
function _M0FP36mizchi3bit8reftable22resolve__ref__reftable(fs, git_dir, refname) {
  const _bind = _M0FP36mizchi3bit8reftable12load__tables(fs, git_dir);
  let tables;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    tables = _ok._0;
  } else {
    return _bind;
  }
  return new _M0DTPC16result6ResultGORP36mizchi3bit6object8ObjectIdRP36mizchi3bit6object8GitErrorE2Ok(_M0FP36mizchi3bit8reftable26resolve__ref__from__tables(tables, refname, 0));
}
function _M0FP36mizchi3bit6remote20decode__bytes__lossy(data) {
  return _M0FPC28encoding4utf821decode__lossy_2einner(_M0MPC15bytes5Bytes12view_2einner(data, 0, data.length), false);
}
function _M0FP36mizchi3bit6remote22trim__string__internal(s) {
  let start = 0;
  let end = s.length;
  while (true) {
    if (start < end) {
      const c = s.charCodeAt(start);
      let _tmp;
      const _p = 32;
      if (c === _p) {
        _tmp = true;
      } else {
        let _tmp$2;
        const _p$2 = 9;
        if (c === _p$2) {
          _tmp$2 = true;
        } else {
          let _tmp$3;
          const _p$3 = 10;
          if (c === _p$3) {
            _tmp$3 = true;
          } else {
            const _p$4 = 13;
            _tmp$3 = c === _p$4;
          }
          _tmp$2 = _tmp$3;
        }
        _tmp = _tmp$2;
      }
      if (_tmp) {
        start = start + 1 | 0;
      } else {
        break;
      }
      continue;
    } else {
      break;
    }
  }
  while (true) {
    if (end > start) {
      const c = s.charCodeAt(end - 1 | 0);
      let _tmp;
      const _p = 32;
      if (c === _p) {
        _tmp = true;
      } else {
        let _tmp$2;
        const _p$2 = 9;
        if (c === _p$2) {
          _tmp$2 = true;
        } else {
          let _tmp$3;
          const _p$3 = 10;
          if (c === _p$3) {
            _tmp$3 = true;
          } else {
            const _p$4 = 13;
            _tmp$3 = c === _p$4;
          }
          _tmp$2 = _tmp$3;
        }
        _tmp = _tmp$2;
      }
      if (_tmp) {
        end = end - 1 | 0;
      } else {
        break;
      }
      continue;
    } else {
      break;
    }
  }
  return start === 0 && end === s.length ? s : s.substring(start, end);
}
function _M0FP36mizchi3bit6remote15resolve__gitdir(fs, bit_path) {
  if (fs.method_table.method_2(fs.self, bit_path)) {
    return bit_path;
  }
  let content;
  let _try_err;
  _L: {
    _L$2: {
      const _bind = fs.method_table.method_0(fs.self, bit_path);
      let _tmp;
      if (_bind.$tag === 1) {
        const _ok = _bind;
        _tmp = _ok._0;
      } else {
        const _err = _bind;
        _try_err = _err._0;
        break _L$2;
      }
      content = _M0FP36mizchi3bit6remote20decode__bytes__lossy(_tmp);
      break _L;
    }
    return bit_path;
  }
  const trimmed = _M0FP36mizchi3bit6remote22trim__string__internal(content);
  if (_M0MPC16string6String11has__prefix(trimmed, new _M0TPC16string10StringView(_M0FP36mizchi3bit6remote15resolve__gitdirN7_2abindS326, 0, _M0FP36mizchi3bit6remote15resolve__gitdirN7_2abindS326.length))) {
    const target = trimmed.substring(8, trimmed.length);
    if (!_M0MPC16string6String11has__prefix(target, new _M0TPC16string10StringView(_M0FP36mizchi3bit6remote15resolve__gitdirN7_2abindS327, 0, _M0FP36mizchi3bit6remote15resolve__gitdirN7_2abindS327.length))) {
      const _bind = _M0MPC16string6String9rev__find(bit_path, new _M0TPC16string10StringView(_M0FP36mizchi3bit6remote15resolve__gitdirN7_2abindS328, 0, _M0FP36mizchi3bit6remote15resolve__gitdirN7_2abindS328.length));
      let parent;
      if (_bind === undefined) {
        parent = ".";
      } else {
        const _Some = _bind;
        const _i = _Some;
        parent = bit_path.substring(0, _i);
      }
      return `${parent}/${target}`;
    }
    return target;
  }
  return bit_path;
}
function _M0FP36mizchi3bit3lib10join__path(root, path) {
  return root.length === 0 || root === "/" ? (_M0MPC16string6String11has__prefix(path, new _M0TPC16string10StringView(_M0FP36mizchi3bit3lib10join__pathN7_2abindS8089, 0, _M0FP36mizchi3bit3lib10join__pathN7_2abindS8089.length)) ? path : `/${path}`) : _M0MPC16string6String11has__suffix(root, new _M0TPC16string10StringView(_M0FP36mizchi3bit3lib10join__pathN7_2abindS8090, 0, _M0FP36mizchi3bit3lib10join__pathN7_2abindS8090.length)) ? `${root}${path}` : `${root}/${path}`;
}
function _M0FP36mizchi3bit3lib15normalize__path(path) {
  const parts = [];
  const _it = _M0MPC16string6String5split(path, new _M0TPC16string10StringView(_M0FP36mizchi3bit3lib15normalize__pathN7_2abindS8113, 0, _M0FP36mizchi3bit3lib15normalize__pathN7_2abindS8113.length));
  while (true) {
    const _bind = _M0MPB4Iter4nextGRPC16string10StringViewE(_it);
    if (_bind === undefined) {
      break;
    } else {
      const _Some = _bind;
      const _part_view = _Some;
      const part = _M0IPC16string10StringViewPB4Show10to__string(_part_view);
      if (part === "" || part === ".") {
        continue;
      } else {
        if (part === "..") {
          let _tmp;
          if (parts.length > 0) {
            const _p = _M0MPC15array5Array2atGUiiEE(parts, parts.length - 1 | 0);
            const _p$2 = "..";
            _tmp = !(_p === _p$2);
          } else {
            _tmp = false;
          }
          if (_tmp) {
            _M0MPC15array5Array3popGsE(parts);
          } else {
            if (!_M0MPC16string6String11has__prefix(path, new _M0TPC16string10StringView(_M0FP36mizchi3bit3lib15normalize__pathN7_2abindS8102, 0, _M0FP36mizchi3bit3lib15normalize__pathN7_2abindS8102.length))) {
              _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(parts, part);
            }
          }
        } else {
          _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(parts, part);
        }
      }
      continue;
    }
  }
  const result = _M0MPC15array5Array4joinGsE(parts, new _M0TPC16string10StringView(_M0FP36mizchi3bit3lib15normalize__pathN7_2abindS8115, 0, _M0FP36mizchi3bit3lib15normalize__pathN7_2abindS8115.length));
  return _M0MPC16string6String11has__prefix(path, new _M0TPC16string10StringView(_M0FP36mizchi3bit3lib15normalize__pathN7_2abindS8114, 0, _M0FP36mizchi3bit3lib15normalize__pathN7_2abindS8114.length)) ? `/${result}` : result;
}
function _M0FP36mizchi3bit3lib31normalize__repo__path__internal(path) {
  const parts = [];
  const _it = _M0MPC16string6String5split(path, new _M0TPC16string10StringView(_M0FP36mizchi3bit3lib31normalize__repo__path__internalN7_2abindS8130, 0, _M0FP36mizchi3bit3lib31normalize__repo__path__internalN7_2abindS8130.length));
  while (true) {
    const _bind = _M0MPB4Iter4nextGRPC16string10StringViewE(_it);
    if (_bind === undefined) {
      break;
    } else {
      const _Some = _bind;
      const _part_view = _Some;
      const part = _M0IPC16string10StringViewPB4Show10to__string(_part_view);
      if (part === "" || part === ".") {
        continue;
      } else {
        if (part === "..") {
          let _tmp;
          if (parts.length > 0) {
            const _p = _M0MPC15array5Array2atGUiiEE(parts, parts.length - 1 | 0);
            const _p$2 = "..";
            _tmp = !(_p === _p$2);
          } else {
            _tmp = false;
          }
          if (_tmp) {
            _M0MPC15array5Array3popGsE(parts);
          } else {
            if (!_M0MPC16string6String11has__prefix(path, new _M0TPC16string10StringView(_M0FP36mizchi3bit3lib31normalize__repo__path__internalN7_2abindS8119, 0, _M0FP36mizchi3bit3lib31normalize__repo__path__internalN7_2abindS8119.length))) {
              _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(parts, part);
            }
          }
        } else {
          _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(parts, part);
        }
      }
      continue;
    }
  }
  const result = _M0MPC15array5Array4joinGsE(parts, new _M0TPC16string10StringView(_M0FP36mizchi3bit3lib31normalize__repo__path__internalN7_2abindS8132, 0, _M0FP36mizchi3bit3lib31normalize__repo__path__internalN7_2abindS8132.length));
  return _M0MPC16string6String11has__prefix(path, new _M0TPC16string10StringView(_M0FP36mizchi3bit3lib31normalize__repo__path__internalN7_2abindS8131, 0, _M0FP36mizchi3bit3lib31normalize__repo__path__internalN7_2abindS8131.length)) ? (result.length === 0 ? "/" : `/${result}`) : result.length === 0 ? "." : result;
}
function _M0FP36mizchi3bit3lib21normalize__repo__path(path) {
  const normalized = _M0FP36mizchi3bit3lib31normalize__repo__path__internal(path);
  const stripped = _M0MPC16string6String11has__prefix(normalized, new _M0TPC16string10StringView(_M0FP36mizchi3bit3lib21normalize__repo__pathN7_2abindS8134, 0, _M0FP36mizchi3bit3lib21normalize__repo__pathN7_2abindS8134.length)) && normalized.length > 1 ? normalized.substring(1, normalized.length) : normalized;
  if (stripped === "." || (stripped === "/" || stripped.length === 0)) {
    return new _M0DTPC16result6ResultGsRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject("path required"));
  }
  if (stripped === ".." || _M0MPC16string6String11has__prefix(stripped, new _M0TPC16string10StringView(_M0FP36mizchi3bit3lib21normalize__repo__pathN7_2abindS8133, 0, _M0FP36mizchi3bit3lib21normalize__repo__pathN7_2abindS8133.length))) {
    return new _M0DTPC16result6ResultGsRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject("path must not traverse outside repository"));
  }
  return new _M0DTPC16result6ResultGsRP36mizchi3bit6object8GitErrorE2Ok(stripped);
}
function _M0FP36mizchi3bit3lib22parse__ref__object__id(hex) {
  if (hex.length !== 40 && hex.length !== 64) {
    return new _M0DTPC16result6ResultGORP36mizchi3bit6object8ObjectIdRP36mizchi3bit6object8GitErrorE2Ok(undefined);
  }
  const _bind = _M0MP36mizchi3bit6object8ObjectId9from__hex(hex);
  let _tmp;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    _tmp = _ok._0;
  } else {
    return _bind;
  }
  return new _M0DTPC16result6ResultGORP36mizchi3bit6object8ObjectIdRP36mizchi3bit6object8GitErrorE2Ok(_tmp);
}
function _M0FP36mizchi3bit3lib10trim__line(line) {
  let s = line;
  if (_M0MPC16string6String11has__suffix(s, new _M0TPC16string10StringView(_M0FP36mizchi3bit3lib10trim__lineN7_2abindS8135, 0, _M0FP36mizchi3bit3lib10trim__lineN7_2abindS8135.length))) {
    s = s.substring(0, s.length - 1 | 0);
  }
  return s;
}
function _M0FP36mizchi3bit3lib15read__ref__line(fs, path) {
  const _bind = fs.method_table.method_0(fs.self, path);
  let _bind$2;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    _bind$2 = _ok._0;
  } else {
    return _bind;
  }
  const text = _M0FPC28encoding4utf821decode__lossy_2einner(_M0MPC15bytes5Bytes12view_2einner(_bind$2, 0, _bind$2.length), false);
  const _it = _M0MPC16string6String5split(text, new _M0TPC16string10StringView(_M0FP36mizchi3bit3lib15read__ref__lineN7_2abindS8148, 0, _M0FP36mizchi3bit3lib15read__ref__lineN7_2abindS8148.length));
  while (true) {
    const _bind$3 = _M0MPB4Iter4nextGRPC16string10StringViewE(_it);
    if (_bind$3 === undefined) {
      break;
    } else {
      const _Some = _bind$3;
      const _line_view = _Some;
      const line = _M0FP36mizchi3bit3lib10trim__line(_M0IPC16string10StringViewPB4Show10to__string(_line_view));
      if (line.length > 0) {
        return new _M0DTPC16result6ResultGsRP36mizchi3bit6object8GitErrorE2Ok(line);
      }
      continue;
    }
  }
  return new _M0DTPC16result6ResultGsRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject(`Empty ref: ${path}`));
}
function _M0FP36mizchi3bit3lib20resolve__packed__ref(fs, packed_path, refname) {
  const _bind = fs.method_table.method_0(fs.self, packed_path);
  let _bind$2;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    _bind$2 = _ok._0;
  } else {
    return _bind;
  }
  const text = _M0FPC28encoding4utf821decode__lossy_2einner(_M0MPC15bytes5Bytes12view_2einner(_bind$2, 0, _bind$2.length), false);
  const _it = _M0MPC16string6String5split(text, new _M0TPC16string10StringView(_M0FP36mizchi3bit3lib20resolve__packed__refN7_2abindS8169, 0, _M0FP36mizchi3bit3lib20resolve__packed__refN7_2abindS8169.length));
  while (true) {
    const _bind$3 = _M0MPB4Iter4nextGRPC16string10StringViewE(_it);
    if (_bind$3 === undefined) {
      break;
    } else {
      const _Some = _bind$3;
      const _line_view = _Some;
      const line = _M0FP36mizchi3bit3lib10trim__line(_M0IPC16string10StringViewPB4Show10to__string(_line_view));
      if (line.length === 0) {
        continue;
      }
      if (_M0MPC16string6String11has__prefix(line, new _M0TPC16string10StringView(_M0FP36mizchi3bit3lib20resolve__packed__refN7_2abindS8152, 0, _M0FP36mizchi3bit3lib20resolve__packed__refN7_2abindS8152.length)) || _M0MPC16string6String11has__prefix(line, new _M0TPC16string10StringView(_M0FP36mizchi3bit3lib20resolve__packed__refN7_2abindS8153, 0, _M0FP36mizchi3bit3lib20resolve__packed__refN7_2abindS8153.length))) {
        continue;
      }
      const space = _M0MPC16string6String4find(line, new _M0TPC16string10StringView(_M0FP36mizchi3bit3lib20resolve__packed__refN7_2abindS8158, 0, _M0FP36mizchi3bit3lib20resolve__packed__refN7_2abindS8158.length));
      if (space === undefined) {
        continue;
      } else {
        const _Some$2 = space;
        const _idx = _Some$2;
        if ((_idx + 1 | 0) >= line.length) {
          continue;
        }
        const id_hex = line.substring(0, _idx);
        const name = line.substring(_idx + 1 | 0, line.length);
        if (name === refname) {
          const _bind$4 = _M0FP36mizchi3bit3lib22parse__ref__object__id(id_hex);
          let _tmp;
          if (_bind$4.$tag === 1) {
            const _ok = _bind$4;
            _tmp = _ok._0;
          } else {
            return _bind$4;
          }
          return new _M0DTPC16result6ResultGORP36mizchi3bit6object8ObjectIdRP36mizchi3bit6object8GitErrorE2Ok(_tmp);
        }
      }
      continue;
    }
  }
  return new _M0DTPC16result6ResultGORP36mizchi3bit6object8ObjectIdRP36mizchi3bit6object8GitErrorE2Ok(undefined);
}
function _M0FP36mizchi3bit3lib23resolve__ref__commondir(fs, git_dir) {
  const commondir_path = _M0FP36mizchi3bit3lib10join__path(git_dir, "commondir");
  if (!fs.method_table.method_3(fs.self, commondir_path)) {
    return undefined;
  }
  let rel;
  let _try_err;
  _L: {
    _L$2: {
      const _bind = _M0FP36mizchi3bit3lib15read__ref__line(fs, commondir_path);
      if (_bind.$tag === 1) {
        const _ok = _bind;
        rel = _ok._0;
      } else {
        const _err = _bind;
        _try_err = _err._0;
        break _L$2;
      }
      break _L;
    }
    rel = "";
  }
  if (rel.length === 0) {
    return undefined;
  }
  if (_M0MPC16string6String11has__prefix(rel, new _M0TPC16string10StringView(_M0FP36mizchi3bit3lib23resolve__ref__commondirN7_2abindS8171, 0, _M0FP36mizchi3bit3lib23resolve__ref__commondirN7_2abindS8171.length))) {
    return _M0FP36mizchi3bit3lib15normalize__path(rel);
  }
  return _M0FP36mizchi3bit3lib15normalize__path(_M0FP36mizchi3bit3lib10join__path(git_dir, rel));
}
function _M0FP36mizchi3bit3lib19resolve__ref__inner(fs, git_dir, refname, depth) {
  let _tmp = refname;
  let _tmp$2 = depth;
  while (true) {
    const refname$2 = _tmp;
    const depth$2 = _tmp$2;
    let refname$3;
    let _try_err;
    _L: {
      _L$2: {
        const _bind = _M0FP36mizchi3bit3lib21normalize__repo__path(refname$2);
        if (_bind.$tag === 1) {
          const _ok = _bind;
          refname$3 = _ok._0;
        } else {
          const _err = _bind;
          _try_err = _err._0;
          break _L$2;
        }
        break _L;
      }
      return new _M0DTPC16result6ResultGORP36mizchi3bit6object8ObjectIdRP36mizchi3bit6object8GitErrorE2Ok(undefined);
    }
    if (depth$2 > 8) {
      return new _M0DTPC16result6ResultGORP36mizchi3bit6object8ObjectIdRP36mizchi3bit6object8GitErrorE2Ok(undefined);
    }
    const path = _M0FP36mizchi3bit3lib10join__path(git_dir, refname$3);
    if (fs.method_table.method_3(fs.self, path)) {
      const _bind = _M0FP36mizchi3bit3lib15read__ref__line(fs, path);
      let line;
      if (_bind.$tag === 1) {
        const _ok = _bind;
        line = _ok._0;
      } else {
        return _bind;
      }
      if (_M0MPC16string6String11has__prefix(line, new _M0TPC16string10StringView(_M0FP36mizchi3bit3lib19resolve__ref__innerN7_2abindS8175, 0, _M0FP36mizchi3bit3lib19resolve__ref__innerN7_2abindS8175.length))) {
        const target = line.substring(5, line.length);
        _tmp = target;
        _tmp$2 = depth$2 + 1 | 0;
        continue;
      }
      const _bind$2 = _M0FP36mizchi3bit3lib22parse__ref__object__id(line);
      let _tmp$3;
      if (_bind$2.$tag === 1) {
        const _ok = _bind$2;
        _tmp$3 = _ok._0;
      } else {
        return _bind$2;
      }
      return new _M0DTPC16result6ResultGORP36mizchi3bit6object8ObjectIdRP36mizchi3bit6object8GitErrorE2Ok(_tmp$3);
    }
    const _bind = _M0FP36mizchi3bit3lib23resolve__ref__commondir(fs, git_dir);
    if (_bind === undefined) {
    } else {
      const _Some = _bind;
      const _common_git_dir = _Some;
      if (!(_common_git_dir === git_dir)) {
        const _bind$2 = _M0FP36mizchi3bit3lib19resolve__ref__inner(fs, _common_git_dir, refname$3, depth$2 + 1 | 0);
        let _bind$3;
        if (_bind$2.$tag === 1) {
          const _ok = _bind$2;
          _bind$3 = _ok._0;
        } else {
          return _bind$2;
        }
        if (_bind$3 === undefined) {
        } else {
          const _Some$2 = _bind$3;
          const _id = _Some$2;
          return new _M0DTPC16result6ResultGORP36mizchi3bit6object8ObjectIdRP36mizchi3bit6object8GitErrorE2Ok(_id);
        }
      }
    }
    const packed = _M0FP36mizchi3bit3lib10join__path(git_dir, "packed-refs");
    if (fs.method_table.method_3(fs.self, packed)) {
      const _bind$2 = _M0FP36mizchi3bit3lib20resolve__packed__ref(fs, packed, refname$3);
      let _tmp$3;
      if (_bind$2.$tag === 1) {
        const _ok = _bind$2;
        _tmp$3 = _ok._0;
      } else {
        return _bind$2;
      }
      return new _M0DTPC16result6ResultGORP36mizchi3bit6object8ObjectIdRP36mizchi3bit6object8GitErrorE2Ok(_tmp$3);
    }
    return new _M0DTPC16result6ResultGORP36mizchi3bit6object8ObjectIdRP36mizchi3bit6object8GitErrorE2Ok(undefined);
  }
}
function _M0FP36mizchi3bit3lib12resolve__ref(fs, git_dir, refname) {
  if (fs.method_table.method_2(fs.self, _M0FP36mizchi3bit3lib10join__path(git_dir, "reftable"))) {
    const _bind = _M0FP36mizchi3bit8reftable22resolve__ref__reftable(fs, git_dir, refname);
    let _bind$2;
    if (_bind.$tag === 1) {
      const _ok = _bind;
      _bind$2 = _ok._0;
    } else {
      return _bind;
    }
    if (_bind$2 === undefined) {
    } else {
      const _Some = _bind$2;
      const _oid = _Some;
      return new _M0DTPC16result6ResultGORP36mizchi3bit6object8ObjectIdRP36mizchi3bit6object8GitErrorE2Ok(_oid);
    }
  }
  let normalized;
  let _try_err;
  _L: {
    _L$2: {
      const _bind = _M0FP36mizchi3bit3lib21normalize__repo__path(refname);
      if (_bind.$tag === 1) {
        const _ok = _bind;
        normalized = _ok._0;
      } else {
        const _err = _bind;
        _try_err = _err._0;
        break _L$2;
      }
      break _L;
    }
    return new _M0DTPC16result6ResultGORP36mizchi3bit6object8ObjectIdRP36mizchi3bit6object8GitErrorE2Ok(undefined);
  }
  return _M0FP36mizchi3bit3lib19resolve__ref__inner(fs, git_dir, normalized, 0);
}
function _M0FP36mizchi3bit3lib20cgraph__compare__oid(data, offset, target, len) {
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < len) {
      const _tmp$2 = offset + i | 0;
      $bound_check(data, _tmp$2);
      const a = data[_tmp$2];
      $bound_check(target, i);
      const b = target[i];
      if (a < b) {
        return -1;
      }
      if (a > b) {
        return 1;
      }
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return 0;
}
function _M0FP36mizchi3bit3lib17cgraph__read__u32(data, offset) {
  $bound_check(data, offset);
  const _tmp = data[offset] << 24;
  const _tmp$2 = offset + 1 | 0;
  $bound_check(data, _tmp$2);
  const _tmp$3 = _tmp | data[_tmp$2] << 16;
  const _tmp$4 = offset + 2 | 0;
  $bound_check(data, _tmp$4);
  const _tmp$5 = _tmp$3 | data[_tmp$4] << 8;
  const _tmp$6 = offset + 3 | 0;
  $bound_check(data, _tmp$6);
  return _tmp$5 | data[_tmp$6];
}
function _M0MP36mizchi3bit3lib15CommitGraphFile12find__commit(self, id) {
  const hex_bytes = id.bytes;
  $bound_check(hex_bytes, 0);
  const first_byte = hex_bytes[0];
  const lo = first_byte === 0 ? 0 : _M0FP36mizchi3bit3lib17cgraph__read__u32(self.data, self.oidf_offset + (Math.imul(first_byte - 1 | 0, 4) | 0) | 0);
  const hi = _M0FP36mizchi3bit3lib17cgraph__read__u32(self.data, self.oidf_offset + (Math.imul(first_byte, 4) | 0) | 0);
  let left = lo;
  let right = hi;
  while (true) {
    if (left < right) {
      const mid = (left + right | 0) / 2 | 0;
      const cmp = _M0FP36mizchi3bit3lib20cgraph__compare__oid(self.data, self.oidl_offset + (Math.imul(mid, self.hash_size) | 0) | 0, hex_bytes, self.hash_size);
      if (cmp < 0) {
        left = mid + 1 | 0;
      } else {
        if (cmp > 0) {
          right = mid;
        } else {
          return mid;
        }
      }
      continue;
    } else {
      break;
    }
  }
  return -1;
}
function _M0MP36mizchi3bit3lib15CommitGraphFile8get__oid(self, pos) {
  const offset = self.oidl_offset + (Math.imul(pos, self.hash_size) | 0) | 0;
  if ((offset + self.hash_size | 0) > self.data.length) {
    return _M0MP36mizchi3bit6object8ObjectId4zero(undefined);
  }
  return _M0MP36mizchi3bit6object8ObjectId23from__bytes__at_2einner(self.data, offset, self.hash_size);
}
function _M0MP36mizchi3bit3lib15CommitGraphFile12read__commit(self, pos) {
  const entry = self.cdat_offset + (Math.imul(pos, self.hash_size + 16 | 0) | 0) | 0;
  if (((entry + self.hash_size | 0) + 16 | 0) > self.data.length) {
    return { _0: _M0MP36mizchi3bit6object8ObjectId4zero(undefined), _1: [], _2: $0L };
  }
  const tree_oid = _M0MP36mizchi3bit6object8ObjectId23from__bytes__at_2einner(self.data, entry, self.hash_size);
  const parent1_raw = _M0FP36mizchi3bit3lib17cgraph__read__u32(self.data, entry + self.hash_size | 0);
  const parent2_raw = _M0FP36mizchi3bit3lib17cgraph__read__u32(self.data, (entry + self.hash_size | 0) + 4 | 0);
  const gen_and_date = _M0FP36mizchi3bit3lib17cgraph__read__u32(self.data, (entry + self.hash_size | 0) + 8 | 0);
  const date_low = _M0FP36mizchi3bit3lib17cgraph__read__u32(self.data, (entry + self.hash_size | 0) + 12 | 0);
  const date_hi = gen_and_date >> 30 & 3;
  const timestamp = _M0IPC15int645Int64PB5BitOr3lor(_M0IPC15int645Int64PB3Shl3shl(_M0MPC13int3Int9to__int64(date_hi), 32), _M0IPC15int645Int64PB6BitAnd4land(_M0MPC13int3Int9to__int64(date_low), $4294967295L));
  const parents = [];
  if (parent1_raw !== 1879048192 && parent1_raw < self.num_commits) {
    _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(parents, _M0MP36mizchi3bit3lib15CommitGraphFile8get__oid(self, parent1_raw));
  }
  if (parent2_raw === 1879048192) {
  } else {
    if ((parent2_raw & -2147483648) !== 0) {
      const edge_pos = parent2_raw & 2147483647;
      if (self.edge_offset > 0) {
        let ei = edge_pos;
        const max_edges = (self.data.length - self.edge_offset | 0) / 4 | 0;
        while (true) {
          if (ei < max_edges) {
            const edge_val = _M0FP36mizchi3bit3lib17cgraph__read__u32(self.data, self.edge_offset + (Math.imul(ei, 4) | 0) | 0);
            const parent_pos = edge_val & 1073741823;
            if (parent_pos < self.num_commits) {
              _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(parents, _M0MP36mizchi3bit3lib15CommitGraphFile8get__oid(self, parent_pos));
            }
            if ((edge_val & -2147483648) !== 0) {
              break;
            }
            ei = ei + 1 | 0;
            continue;
          } else {
            break;
          }
        }
      }
    } else {
      if (parent2_raw < self.num_commits) {
        _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(parents, _M0MP36mizchi3bit3lib15CommitGraphFile8get__oid(self, parent2_raw));
      }
    }
  }
  return { _0: tree_oid, _1: parents, _2: timestamp };
}
function _M0MP36mizchi3bit3lib15CommitGraphFile26synthesize__commit__object(self, pos, id) {
  const _bind = _M0MP36mizchi3bit3lib15CommitGraphFile12read__commit(self, pos);
  const _tree_oid = _bind._0;
  const _parents = _bind._1;
  const _timestamp = _bind._2;
  const buf = _M0MPB13StringBuilder11new_2einner(0);
  _M0IPB13StringBuilderPB6Logger13write__string(buf, "tree ");
  _M0IPB13StringBuilderPB6Logger13write__string(buf, _M0MP36mizchi3bit6object8ObjectId7to__hex(_tree_oid));
  _M0IPB13StringBuilderPB6Logger13write__string(buf, "\n");
  const _bind$2 = _parents.length;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind$2) {
      const parent = _parents[_];
      _M0IPB13StringBuilderPB6Logger13write__string(buf, "parent ");
      _M0IPB13StringBuilderPB6Logger13write__string(buf, _M0MP36mizchi3bit6object8ObjectId7to__hex(parent));
      _M0IPB13StringBuilderPB6Logger13write__string(buf, "\n");
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  _M0IPB13StringBuilderPB6Logger13write__string(buf, "author Unknown <unknown> ");
  _M0IPB13StringBuilderPB6Logger13write__string(buf, _M0MPC15int645Int6418to__string_2einner(_timestamp, 10));
  _M0IPB13StringBuilderPB6Logger13write__string(buf, " +0000\n");
  _M0IPB13StringBuilderPB6Logger13write__string(buf, "committer Unknown <unknown> ");
  _M0IPB13StringBuilderPB6Logger13write__string(buf, _M0MPC15int645Int6418to__string_2einner(_timestamp, 10));
  _M0IPB13StringBuilderPB6Logger13write__string(buf, " +0000\n");
  _M0IPB13StringBuilderPB6Logger13write__string(buf, "\ncommit-graph synthesized\n");
  const content_str = buf.val;
  const content_bytes = _M0FPC28encoding4utf814encode_2einner(new _M0TPC16string10StringView(content_str, 0, content_str.length), false);
  return _M0MP36mizchi3bit6object10PackObject14with__metadata(2, content_bytes, id, -1, 0);
}
function _M0FP36mizchi3bit3lib24get__from__commit__graph(db, id) {
  const _bind = db.commit_graph;
  if (_bind === undefined) {
    return undefined;
  } else {
    const _Some = _bind;
    const _graph = _Some;
    const pos = _M0MP36mizchi3bit3lib15CommitGraphFile12find__commit(_graph, id);
    return pos >= 0 ? _M0MP36mizchi3bit3lib15CommitGraphFile26synthesize__commit__object(_graph, pos, id) : undefined;
  }
}
function _M0FP36mizchi3bit3lib18evict__pack__cache(db) {
  if (db.pack_cache_limit <= 0) {
    return undefined;
  }
  while (true) {
    if (db.pack_cache_order.length > db.pack_cache_limit) {
      const evict = _M0MPC15array5Array6removeGsE(db.pack_cache_order, 0);
      _M0MPB3Map6removeGszE(db.pack_cache, evict);
      continue;
    } else {
      return;
    }
  }
}
function _M0FP36mizchi3bit3lib18touch__pack__cache(db, pack_path) {
  const _bind = _M0MPC15array5Array6searchGsE(db.pack_cache_order, pack_path);
  if (_bind === undefined) {
  } else {
    const _Some = _bind;
    const _idx = _Some;
    _M0MPC15array5Array6removeGsE(db.pack_cache_order, _idx);
  }
  _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(db.pack_cache_order, pack_path);
}
function _M0FP36mizchi3bit3lib16get__pack__bytes(db, fs, pack_path) {
  if (db.pack_cache_limit === 0) {
    const _bind = fs.method_table.method_0(fs.self, pack_path);
    let _tmp;
    if (_bind.$tag === 1) {
      const _ok = _bind;
      _tmp = _ok._0;
    } else {
      return _bind;
    }
    return new _M0DTPC16result6ResultGzRP36mizchi3bit6object8GitErrorE2Ok(_tmp);
  }
  const _bind = _M0MPB3Map3getGszE(db.pack_cache, pack_path);
  if (_bind === undefined) {
    const _bind$2 = fs.method_table.method_0(fs.self, pack_path);
    let data;
    if (_bind$2.$tag === 1) {
      const _ok = _bind$2;
      data = _ok._0;
    } else {
      return _bind$2;
    }
    _M0MPB3Map3setGszE(db.pack_cache, pack_path, data);
    _M0FP36mizchi3bit3lib18touch__pack__cache(db, pack_path);
    _M0FP36mizchi3bit3lib18evict__pack__cache(db);
    return new _M0DTPC16result6ResultGzRP36mizchi3bit6object8GitErrorE2Ok(data);
  } else {
    const _Some = _bind;
    const _data = _Some;
    _M0FP36mizchi3bit3lib18touch__pack__cache(db, pack_path);
    return new _M0DTPC16result6ResultGzRP36mizchi3bit6object8GitErrorE2Ok(_data);
  }
}
function _M0FP36mizchi3bit3lib26object__type__from__string(s) {
  if (s === "blob") {
    return new _M0DTPC16result6ResultGRP36mizchi3bit6object10ObjectTypeRP36mizchi3bit6object8GitErrorE2Ok(0);
  } else {
    if (s === "tree") {
      return new _M0DTPC16result6ResultGRP36mizchi3bit6object10ObjectTypeRP36mizchi3bit6object8GitErrorE2Ok(1);
    } else {
      if (s === "commit") {
        return new _M0DTPC16result6ResultGRP36mizchi3bit6object10ObjectTypeRP36mizchi3bit6object8GitErrorE2Ok(2);
      } else {
        if (s === "tag") {
          return new _M0DTPC16result6ResultGRP36mizchi3bit6object10ObjectTypeRP36mizchi3bit6object8GitErrorE2Ok(3);
        } else {
          return new _M0DTPC16result6ResultGRP36mizchi3bit6object10ObjectTypeRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject(`Unknown object type: ${s}`));
        }
      }
    }
  }
}
function _M0FP36mizchi3bit3lib20parse__loose__object(data) {
  const len = data.length;
  if (len === 0) {
    return new _M0DTPC16result6ResultGRP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject("Empty loose object"));
  }
  const type_buf = _M0MPB13StringBuilder11new_2einner(0);
  const i = new _M0TPB8MutLocalGiE(0);
  while (true) {
    let _tmp;
    if (i.val < len) {
      const _tmp$2 = i.val;
      $bound_check(data, _tmp$2);
      _tmp = data[_tmp$2] !== 32;
    } else {
      _tmp = false;
    }
    if (_tmp) {
      const _tmp$2 = i.val;
      $bound_check(data, _tmp$2);
      _M0IPB13StringBuilderPB6Logger11write__char(type_buf, data[_tmp$2]);
      i.val = i.val + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  let _tmp;
  if (i.val >= len) {
    _tmp = true;
  } else {
    const _tmp$2 = i.val;
    $bound_check(data, _tmp$2);
    _tmp = data[_tmp$2] !== 32;
  }
  if (_tmp) {
    return new _M0DTPC16result6ResultGRP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject("Invalid loose object header"));
  }
  i.val = i.val + 1 | 0;
  let size = 0;
  while (true) {
    let _tmp$2;
    if (i.val < len) {
      const _tmp$3 = i.val;
      $bound_check(data, _tmp$3);
      _tmp$2 = data[_tmp$3] !== 0;
    } else {
      _tmp$2 = false;
    }
    if (_tmp$2) {
      const _tmp$3 = i.val;
      $bound_check(data, _tmp$3);
      const b = data[_tmp$3];
      if (b < 48 || b > 57) {
        return new _M0DTPC16result6ResultGRP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject("Invalid loose object size"));
      }
      size = (Math.imul(size, 10) | 0) + (b - 48 | 0) | 0;
      i.val = i.val + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  let _tmp$2;
  if (i.val >= len) {
    _tmp$2 = true;
  } else {
    const _tmp$3 = i.val;
    $bound_check(data, _tmp$3);
    _tmp$2 = data[_tmp$3] !== 0;
  }
  if (_tmp$2) {
    return new _M0DTPC16result6ResultGRP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject("Invalid loose object header"));
  }
  i.val = i.val + 1 | 0;
  const content_len = len - i.val | 0;
  if (content_len !== size) {
    return new _M0DTPC16result6ResultGRP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject(`Loose object size mismatch: expected=${_M0IP016_24default__implPB4Show10to__stringGiE(size)}, got=${_M0IP016_24default__implPB4Show10to__stringGiE(content_len)}`));
  }
  let _bind;
  if (content_len <= 0) {
    _bind = new Uint8Array([]);
  } else {
    const _p = 0;
    const _tmp$3 = i.val + _p | 0;
    $bound_check(data, _tmp$3);
    const _p$2 = $makebytes(content_len, data[_tmp$3]);
    let _tmp$4 = 1;
    while (true) {
      const _p$3 = _tmp$4;
      if (_p$3 < content_len) {
        const _tmp$5 = i.val + _p$3 | 0;
        $bound_check(data, _tmp$5);
        $bound_check(_p$2, _p$3);
        _p$2[_p$3] = data[_tmp$5];
        _tmp$4 = _p$3 + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    _bind = _p$2;
  }
  const content = _M0MPC15bytes5Bytes11from__array(new _M0TPB9ArrayViewGyE(_bind, 0, _bind.length));
  const _bind$2 = _M0FP36mizchi3bit3lib26object__type__from__string(type_buf.val);
  let obj_type;
  if (_bind$2.$tag === 1) {
    const _ok = _bind$2;
    obj_type = _ok._0;
  } else {
    return _bind$2;
  }
  return new _M0DTPC16result6ResultGRP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE2Ok(_M0MP36mizchi3bit6object10PackObject3new(obj_type, content));
}
function _M0FP36mizchi3bit3lib15offset__to__int(offset) {
  if (_M0IP016_24default__implPB7Compare6op__ltGlE(offset, $0L) || _M0IP016_24default__implPB7Compare6op__gtGlE(offset, $2147483647L)) {
    return new _M0DTPC16result6ResultGiRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject("Pack offset exceeds Int range"));
  }
  return new _M0DTPC16result6ResultGiRP36mizchi3bit6object8GitErrorE2Ok(_M0MPC15int645Int647to__int(offset));
}
function _M0MP36mizchi3bit3lib9PackIndex20find__id__by__offset(self, offset) {
  const _bind = self.offsets.length;
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < _bind) {
      if (_M0IPC15int645Int64PB2Eq5equal(_M0MPC15array5Array2atGUiiEE(self.offsets, i), offset)) {
        return _M0MPC15array5Array2atGUiiEE(self.ids, i);
      }
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return undefined;
}
function _M0MP36mizchi3bit3lib9PackIndex17find__offset__hex(self, hex) {
  let lo = 0;
  let hi = self.ids.length;
  while (true) {
    if (lo < hi) {
      const mid = (lo + hi | 0) / 2 | 0;
      const cmp = _M0IPC16string6StringPB7Compare7compare(_M0MPC15array5Array2atGUiiEE(self.ids, mid), hex);
      if (cmp === 0) {
        return _M0MPC15array5Array2atGUiiEE(self.offsets, mid);
      } else {
        if (cmp < 0) {
          lo = mid + 1 | 0;
        } else {
          hi = mid;
        }
      }
      continue;
    } else {
      break;
    }
  }
  return undefined;
}
function _M0FP36mizchi3bit3lib19read__u32__be__at64(data, start) {
  if ((start + 4 | 0) > data.length) {
    return new _M0DTPC16result6ResultGlRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject("Unexpected end of index data"));
  }
  $bound_check(data, start);
  const b0 = _M0MPC14byte4Byte9to__int64(data[start]);
  const _tmp = start + 1 | 0;
  $bound_check(data, _tmp);
  const b1 = _M0MPC14byte4Byte9to__int64(data[_tmp]);
  const _tmp$2 = start + 2 | 0;
  $bound_check(data, _tmp$2);
  const b2 = _M0MPC14byte4Byte9to__int64(data[_tmp$2]);
  const _tmp$3 = start + 3 | 0;
  $bound_check(data, _tmp$3);
  const b3 = _M0MPC14byte4Byte9to__int64(data[_tmp$3]);
  return new _M0DTPC16result6ResultGlRP36mizchi3bit6object8GitErrorE2Ok(_M0IPC15int645Int64PB5BitOr3lor(_M0IPC15int645Int64PB5BitOr3lor(_M0IPC15int645Int64PB5BitOr3lor(_M0IPC15int645Int64PB3Shl3shl(b0, 24), _M0IPC15int645Int64PB3Shl3shl(b1, 16)), _M0IPC15int645Int64PB3Shl3shl(b2, 8)), b3));
}
function _M0FP36mizchi3bit3lib30parse__pack__index__v1_2einner(data, pack_path, hash_size) {
  if (data.length < 1024) {
    return new _M0DTPC16result6ResultGRP36mizchi3bit3lib9PackIndexRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject("Index file too short"));
  }
  let offset = 0;
  const fanout = [];
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < 256) {
      const _bind = _M0FP36mizchi3bit3lib19read__u32__be__at64(data, offset);
      let _tmp$2;
      if (_bind.$tag === 1) {
        const _ok = _bind;
        _tmp$2 = _ok._0;
      } else {
        return _bind;
      }
      _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(fanout, _tmp$2);
      offset = offset + 4 | 0;
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const count64 = _M0MPC15array5Array2atGUiiEE(fanout, 255);
  if (_M0IP016_24default__implPB7Compare6op__gtGlE(count64, $2147483647L)) {
    return new _M0DTPC16result6ResultGRP36mizchi3bit3lib9PackIndexRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject("Too many objects in index"));
  }
  const count = _M0MPC15int645Int647to__int(count64);
  const entries_start = offset;
  const entry_size = 4 + hash_size | 0;
  const expected_len = (entries_start + (Math.imul(count, entry_size) | 0) | 0) + hash_size | 0;
  if (data.length < expected_len) {
    return new _M0DTPC16result6ResultGRP36mizchi3bit3lib9PackIndexRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject("Index file truncated (v1)"));
  }
  const ids = [];
  const offsets = [];
  let _tmp$2 = 0;
  while (true) {
    const i = _tmp$2;
    if (i < count) {
      const base = entries_start + (Math.imul(i, entry_size) | 0) | 0;
      const _bind = _M0FP36mizchi3bit3lib19read__u32__be__at64(data, base);
      let off;
      if (_bind.$tag === 1) {
        const _ok = _bind;
        off = _ok._0;
      } else {
        return _bind;
      }
      _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(offsets, off);
      const bytes = $makebytes(hash_size, 0);
      let _tmp$3 = 0;
      while (true) {
        const j = _tmp$3;
        if (j < hash_size) {
          const _tmp$4 = (base + 4 | 0) + j | 0;
          $bound_check(data, _tmp$4);
          $bound_check(bytes, j);
          bytes[j] = data[_tmp$4];
          _tmp$3 = j + 1 | 0;
          continue;
        } else {
          break;
        }
      }
      _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(ids, _M0MP36mizchi3bit6object8ObjectId7to__hex(_M0MP36mizchi3bit6object8ObjectId3new(bytes)));
      _tmp$2 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return new _M0DTPC16result6ResultGRP36mizchi3bit3lib9PackIndexRP36mizchi3bit6object8GitErrorE2Ok(new _M0TP36mizchi3bit3lib9PackIndex(pack_path, ids, offsets, 1));
}
function _M0FP36mizchi3bit3lib19read__u64__be__at64(data, start) {
  if ((start + 8 | 0) > data.length) {
    return new _M0DTPC16result6ResultGlRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject("Unexpected end of index data"));
  }
  const _bind = _M0FP36mizchi3bit3lib19read__u32__be__at64(data, start);
  let hi;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    hi = _ok._0;
  } else {
    return _bind;
  }
  const _bind$2 = _M0FP36mizchi3bit3lib19read__u32__be__at64(data, start + 4 | 0);
  let lo;
  if (_bind$2.$tag === 1) {
    const _ok = _bind$2;
    lo = _ok._0;
  } else {
    return _bind$2;
  }
  return new _M0DTPC16result6ResultGlRP36mizchi3bit6object8GitErrorE2Ok(_M0IPC15int645Int64PB5BitOr3lor(_M0IPC15int645Int64PB3Shl3shl(hi, 32), lo));
}
function _M0FP36mizchi3bit3lib26parse__pack__index_2einner(data, pack_path, hash_size) {
  if (data.length < 8) {
    return new _M0DTPC16result6ResultGRP36mizchi3bit3lib9PackIndexRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject("Index file too short"));
  }
  const _bind = _M0FP36mizchi3bit3lib19read__u32__be__at64(data, 0);
  let magic;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    magic = _ok._0;
  } else {
    return _bind;
  }
  if (_M0IP016_24default__implPB2Eq10not__equalGlE(magic, $4285812579L)) {
    const _bind$2 = _M0FP36mizchi3bit3lib30parse__pack__index__v1_2einner(data, pack_path, hash_size);
    let _tmp;
    if (_bind$2.$tag === 1) {
      const _ok = _bind$2;
      _tmp = _ok._0;
    } else {
      return _bind$2;
    }
    return new _M0DTPC16result6ResultGRP36mizchi3bit3lib9PackIndexRP36mizchi3bit6object8GitErrorE2Ok(_tmp);
  }
  const _bind$2 = _M0FP36mizchi3bit3lib19read__u32__be__at64(data, 4);
  let version;
  if (_bind$2.$tag === 1) {
    const _ok = _bind$2;
    version = _ok._0;
  } else {
    return _bind$2;
  }
  if (_M0IP016_24default__implPB2Eq10not__equalGlE(version, $2L)) {
    return new _M0DTPC16result6ResultGRP36mizchi3bit3lib9PackIndexRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject(`Unsupported pack index version: ${_M0IP016_24default__implPB4Show10to__stringGlE(version)}`));
  }
  let offset = 8;
  const fanout = [];
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < 256) {
      const _bind$3 = _M0FP36mizchi3bit3lib19read__u32__be__at64(data, offset);
      let _tmp$2;
      if (_bind$3.$tag === 1) {
        const _ok = _bind$3;
        _tmp$2 = _ok._0;
      } else {
        return _bind$3;
      }
      _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(fanout, _tmp$2);
      offset = offset + 4 | 0;
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const count64 = _M0MPC15array5Array2atGUiiEE(fanout, 255);
  if (_M0IP016_24default__implPB7Compare6op__gtGlE(count64, $2147483647L)) {
    return new _M0DTPC16result6ResultGRP36mizchi3bit3lib9PackIndexRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject("Too many objects in index"));
  }
  const count = _M0MPC15int645Int647to__int(count64);
  const ids = [];
  let _tmp$2 = 0;
  while (true) {
    const _ = _tmp$2;
    if (_ < count) {
      if ((offset + hash_size | 0) > data.length) {
        return new _M0DTPC16result6ResultGRP36mizchi3bit3lib9PackIndexRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject("Index file truncated (ids)"));
      }
      const bytes = $makebytes(hash_size, 0);
      let _tmp$3 = 0;
      while (true) {
        const i = _tmp$3;
        if (i < hash_size) {
          const _tmp$4 = offset + i | 0;
          $bound_check(data, _tmp$4);
          $bound_check(bytes, i);
          bytes[i] = data[_tmp$4];
          _tmp$3 = i + 1 | 0;
          continue;
        } else {
          break;
        }
      }
      offset = offset + hash_size | 0;
      _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(ids, _M0MP36mizchi3bit6object8ObjectId7to__hex(_M0MP36mizchi3bit6object8ObjectId3new(bytes)));
      _tmp$2 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  offset = offset + (Math.imul(count, 4) | 0) | 0;
  if ((offset + (Math.imul(count, 4) | 0) | 0) > data.length) {
    return new _M0DTPC16result6ResultGRP36mizchi3bit3lib9PackIndexRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject("Index file truncated (offsets)"));
  }
  const offsets = [];
  const large_indices = [];
  let _tmp$3 = 0;
  while (true) {
    const i = _tmp$3;
    if (i < count) {
      const _bind$3 = _M0FP36mizchi3bit3lib19read__u32__be__at64(data, offset);
      let v;
      if (_bind$3.$tag === 1) {
        const _ok = _bind$3;
        v = _ok._0;
      } else {
        return _bind$3;
      }
      offset = offset + 4 | 0;
      if (_M0IP016_24default__implPB2Eq10not__equalGlE(_M0IPC15int645Int64PB6BitAnd4land(v, $2147483648L), $0L)) {
        _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(offsets, _M0IPC15int645Int64PB6BitAnd4land(v, $2147483647L));
        _M0MPC15array5Array4pushGiE(large_indices, i);
      } else {
        _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(offsets, v);
      }
      _tmp$3 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  if (large_indices.length > 0) {
    let large_idx = 0;
    while (true) {
      if (large_idx < large_indices.length) {
        if ((offset + 8 | 0) > data.length) {
          return new _M0DTPC16result6ResultGRP36mizchi3bit3lib9PackIndexRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject("Index file truncated (large offsets)"));
        }
        const _bind$3 = _M0FP36mizchi3bit3lib19read__u64__be__at64(data, offset);
        let v;
        if (_bind$3.$tag === 1) {
          const _ok = _bind$3;
          v = _ok._0;
        } else {
          return _bind$3;
        }
        offset = offset + 8 | 0;
        const pos = _M0MPC15array5Array2atGiE(large_indices, large_idx);
        _M0MPC15array5Array3setGlE(offsets, pos, v);
        large_idx = large_idx + 1 | 0;
        continue;
      } else {
        break;
      }
    }
  }
  return new _M0DTPC16result6ResultGRP36mizchi3bit3lib9PackIndexRP36mizchi3bit6object8GitErrorE2Ok(new _M0TP36mizchi3bit3lib9PackIndex(pack_path, ids, offsets, 2));
}
function _M0MP36mizchi3bit3lib13LazyPackIndex3get(self, fs) {
  const _bind = self.loaded;
  if (_bind === undefined) {
    const _bind$2 = fs.method_table.method_0(fs.self, self.idx_path);
    let data;
    if (_bind$2.$tag === 1) {
      const _ok = _bind$2;
      data = _ok._0;
    } else {
      return _bind$2;
    }
    const _bind$3 = _M0FP36mizchi3bit3lib26parse__pack__index_2einner(data, self.pack_path, 20);
    let idx;
    if (_bind$3.$tag === 1) {
      const _ok = _bind$3;
      idx = _ok._0;
    } else {
      return _bind$3;
    }
    self.loaded = idx;
    return new _M0DTPC16result6ResultGRP36mizchi3bit3lib9PackIndexRP36mizchi3bit6object8GitErrorE2Ok(idx);
  } else {
    const _Some = _bind;
    const _idx = _Some;
    return new _M0DTPC16result6ResultGRP36mizchi3bit3lib9PackIndexRP36mizchi3bit6object8GitErrorE2Ok(_idx);
  }
}
function _M0MP36mizchi3bit3lib13LazyPackIndex17find__offset__hex(self, fs, hex) {
  const _bind = _M0MP36mizchi3bit3lib13LazyPackIndex3get(self, fs);
  let idx;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    idx = _ok._0;
  } else {
    return _bind;
  }
  return new _M0DTPC16result6ResultGOlRP36mizchi3bit6object8GitErrorE2Ok(_M0MP36mizchi3bit3lib9PackIndex17find__offset__hex(idx, hex));
}
function _M0FP36mizchi3bit3lib16get__from__packs(db, fs, hex, seen) {
  let last_error = undefined;
  const _bind = db.packs;
  const _bind$2 = _bind.length;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind$2) {
      const pack = _bind[_];
      const _bind$3 = _M0MP36mizchi3bit3lib9PackIndex17find__offset__hex(pack, hex);
      if (_bind$3 === undefined) {
      } else {
        const _Some = _bind$3;
        const _offset = _Some;
        let _try_err;
        _L: {
          const _bind$4 = _M0FP36mizchi3bit3lib16get__pack__bytes(db, fs, pack.pack_path);
          let data;
          if (_bind$4.$tag === 1) {
            const _ok = _bind$4;
            data = _ok._0;
          } else {
            const _err = _bind$4;
            _try_err = _err._0;
            break _L;
          }
          const _bind$5 = _M0FP36mizchi3bit3lib22read__pack__object__at(data, pack, _offset, db, fs, seen);
          let obj;
          if (_bind$5.$tag === 1) {
            const _ok = _bind$5;
            obj = _ok._0;
          } else {
            const _err = _bind$5;
            _try_err = _err._0;
            break _L;
          }
          if (!db.skip_verify) {
            const computed = _M0MP36mizchi3bit6object8ObjectId7to__hex(obj.id);
            if (!(computed === hex)) {
              if (pack.version === 1) {
                db.saw_corrupt_pack = true;
                return new _M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE2Ok(obj);
              }
              _try_err = new _M0DTPC15error5Error47mizchi_2fbit_2fobject_2eGitError_2eHashMismatch(computed, hex);
              break _L;
            }
          }
          return new _M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE2Ok(obj);
        }
        last_error = _try_err;
      }
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const _bind$3 = db.lazy_packs;
  const _bind$4 = _bind$3.length;
  let _tmp$2 = 0;
  while (true) {
    const _ = _tmp$2;
    if (_ < _bind$4) {
      const lazy_pack = _bind$3[_];
      let _try_err;
      _L: {
        _L$2: {
          const _bind$5 = _M0MP36mizchi3bit3lib13LazyPackIndex17find__offset__hex(lazy_pack, fs, hex);
          let _bind$6;
          if (_bind$5.$tag === 1) {
            const _ok = _bind$5;
            _bind$6 = _ok._0;
          } else {
            const _err = _bind$5;
            _try_err = _err._0;
            break _L$2;
          }
          if (_bind$6 === undefined) {
          } else {
            const _Some = _bind$6;
            const _offset = _Some;
            const _bind$7 = _M0MP36mizchi3bit3lib13LazyPackIndex3get(lazy_pack, fs);
            let pack;
            if (_bind$7.$tag === 1) {
              const _ok = _bind$7;
              pack = _ok._0;
            } else {
              const _err = _bind$7;
              _try_err = _err._0;
              break _L$2;
            }
            const _bind$8 = _M0FP36mizchi3bit3lib16get__pack__bytes(db, fs, pack.pack_path);
            let data;
            if (_bind$8.$tag === 1) {
              const _ok = _bind$8;
              data = _ok._0;
            } else {
              const _err = _bind$8;
              _try_err = _err._0;
              break _L$2;
            }
            const _bind$9 = _M0FP36mizchi3bit3lib22read__pack__object__at(data, pack, _offset, db, fs, seen);
            let obj;
            if (_bind$9.$tag === 1) {
              const _ok = _bind$9;
              obj = _ok._0;
            } else {
              const _err = _bind$9;
              _try_err = _err._0;
              break _L$2;
            }
            if (!db.skip_verify) {
              const computed = _M0MP36mizchi3bit6object8ObjectId7to__hex(obj.id);
              if (!(computed === hex)) {
                if (pack.version === 1) {
                  db.saw_corrupt_pack = true;
                  return new _M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE2Ok(obj);
                }
                _try_err = new _M0DTPC15error5Error47mizchi_2fbit_2fobject_2eGitError_2eHashMismatch(computed, hex);
                break _L$2;
              }
            }
            return new _M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE2Ok(obj);
          }
          break _L;
        }
        last_error = _try_err;
      }
      _tmp$2 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const _bind$5 = last_error;
  if (_bind$5 === undefined) {
    return new _M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE2Ok(undefined);
  } else {
    const _Some = _bind$5;
    const _e = _Some;
    return new _M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err(_e);
  }
}
function _M0FP36mizchi3bit3lib22read__pack__object__at(data, pack, offset, db, fs, seen) {
  const _bind = _M0FP36mizchi3bit3lib15offset__to__int(offset);
  let offset_i;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    offset_i = _ok._0;
  } else {
    return _bind;
  }
  const _bind$2 = _M0FP36mizchi3bit4pack27decode__type__and__size__at(data, offset_i);
  let _bind$3;
  if (_bind$2.$tag === 1) {
    const _ok = _bind$2;
    _bind$3 = _ok._0;
  } else {
    return _bind$2;
  }
  const _type_id = _bind$3._0;
  const _size = _bind$3._1;
  const _next_offset = _bind$3._2;
  _L: {
    switch (_type_id) {
      case 1: {
        break _L;
      }
      case 2: {
        break _L;
      }
      case 3: {
        break _L;
      }
      case 4: {
        break _L;
      }
      case 6: {
        const _bind$4 = _M0FP36mizchi3bit4pack24read__ofs__delta__offset(data, _next_offset);
        let _bind$5;
        if (_bind$4.$tag === 1) {
          const _ok = _bind$4;
          _bind$5 = _ok._0;
        } else {
          return _bind$4;
        }
        const _back_offset = _bind$5._0;
        const _after_ref = _bind$5._1;
        const base_offset = offset_i - _back_offset | 0;
        if (base_offset < 0) {
          return new _M0DTPC16result6ResultGRP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2ePackfileError("Invalid OFS_DELTA base offset"));
        }
        let _bind$6;
        let _try_err;
        _L$2: {
          _L$3: {
            const _bind$7 = _M0FP26mizchi4zlib20zlib__decompress__at(data, _after_ref);
            if (_bind$7.$tag === 1) {
              const _ok = _bind$7;
              _bind$6 = _ok._0;
            } else {
              const _err = _bind$7;
              _try_err = _err._0;
              break _L$3;
            }
            break _L$2;
          }
          return new _M0DTPC16result6ResultGRP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2ePackfileError(`Zlib error: ${_M0IP016_24default__implPB4Show10to__stringGRP26mizchi4zlib9ZlibErrorE(_try_err)}`));
        }
        const _delta = _bind$6._0;
        if (_delta.length !== _size) {
          return new _M0DTPC16result6ResultGRP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2ePackfileError(`Delta size mismatch: expected=${_M0IP016_24default__implPB4Show10to__stringGiE(_size)}, got=${_M0IP016_24default__implPB4Show10to__stringGiE(_delta.length)}`));
        }
        let base;
        let _try_err$2;
        _L$3: {
          _L$4: {
            const _bind$7 = _M0FP36mizchi3bit3lib22read__pack__object__at(data, pack, _M0MPC13int3Int9to__int64(base_offset), db, fs, seen);
            if (_bind$7.$tag === 1) {
              const _ok = _bind$7;
              base = _ok._0;
            } else {
              const _err = _bind$7;
              _try_err$2 = _err._0;
              break _L$4;
            }
            break _L$3;
          }
          const _bind$7 = _M0MP36mizchi3bit3lib9PackIndex20find__id__by__offset(pack, _M0MPC13int3Int9to__int64(base_offset));
          if (_bind$7 === undefined) {
            return new _M0DTPC16result6ResultGRP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err(_try_err$2);
          } else {
            const _Some = _bind$7;
            const _base_hex = _Some;
            const _bind$8 = _M0FP36mizchi3bit3lib12get__by__hex(db, fs, _base_hex, seen);
            let _bind$9;
            if (_bind$8.$tag === 1) {
              const _ok = _bind$8;
              _bind$9 = _ok._0;
            } else {
              return _bind$8;
            }
            if (_bind$9 === undefined) {
              return new _M0DTPC16result6ResultGRP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err(_try_err$2);
            } else {
              const _Some$2 = _bind$9;
              base = _Some$2;
            }
          }
        }
        const _bind$7 = _M0FP36mizchi3bit4pack12apply__delta(base.data, _delta);
        let content;
        if (_bind$7.$tag === 1) {
          const _ok = _bind$7;
          content = _ok._0;
        } else {
          return _bind$7;
        }
        const id = _M0FP36mizchi3bit6object21hash__object__content(base.obj_type, content);
        return new _M0DTPC16result6ResultGRP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE2Ok(_M0MP36mizchi3bit6object10PackObject14with__metadata(base.obj_type, content, id, offset_i, 0));
      }
      case 7: {
        const _bind$8 = _M0FP36mizchi3bit4pack28read__ref__delta__id_2einner(data, _next_offset, 20);
        let _bind$9;
        if (_bind$8.$tag === 1) {
          const _ok = _bind$8;
          _bind$9 = _ok._0;
        } else {
          return _bind$8;
        }
        const _base_hex = _bind$9._0;
        const _after_ref$2 = _bind$9._1;
        let _bind$10;
        let _try_err$3;
        _L$4: {
          _L$5: {
            const _bind$11 = _M0FP26mizchi4zlib20zlib__decompress__at(data, _after_ref$2);
            if (_bind$11.$tag === 1) {
              const _ok = _bind$11;
              _bind$10 = _ok._0;
            } else {
              const _err = _bind$11;
              _try_err$3 = _err._0;
              break _L$5;
            }
            break _L$4;
          }
          return new _M0DTPC16result6ResultGRP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2ePackfileError(`Zlib error: ${_M0IP016_24default__implPB4Show10to__stringGRP26mizchi4zlib9ZlibErrorE(_try_err$3)}`));
        }
        const _delta$2 = _bind$10._0;
        if (_delta$2.length !== _size) {
          return new _M0DTPC16result6ResultGRP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2ePackfileError(`Delta size mismatch: expected=${_M0IP016_24default__implPB4Show10to__stringGiE(_size)}, got=${_M0IP016_24default__implPB4Show10to__stringGiE(_delta$2.length)}`));
        }
        const _bind$11 = _M0MP36mizchi3bit3lib9PackIndex17find__offset__hex(pack, _base_hex);
        let base$2;
        if (_bind$11 === undefined) {
          const _bind$12 = _M0FP36mizchi3bit3lib12get__by__hex(db, fs, _base_hex, seen);
          let _bind$13;
          if (_bind$12.$tag === 1) {
            const _ok = _bind$12;
            _bind$13 = _ok._0;
          } else {
            return _bind$12;
          }
          if (_bind$13 === undefined) {
            return new _M0DTPC16result6ResultGRP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2ePackfileError("Missing base object for REF_DELTA"));
          } else {
            const _Some = _bind$13;
            base$2 = _Some;
          }
        } else {
          const _Some = _bind$11;
          const _base_offset = _Some;
          let _try_err$4;
          _L$5: {
            _L$6: {
              const _bind$12 = _M0FP36mizchi3bit3lib22read__pack__object__at(data, pack, _base_offset, db, fs, seen);
              if (_bind$12.$tag === 1) {
                const _ok = _bind$12;
                base$2 = _ok._0;
              } else {
                const _err = _bind$12;
                _try_err$4 = _err._0;
                break _L$6;
              }
              break _L$5;
            }
            const _bind$12 = _M0FP36mizchi3bit3lib12get__by__hex(db, fs, _base_hex, seen);
            let _bind$13;
            if (_bind$12.$tag === 1) {
              const _ok = _bind$12;
              _bind$13 = _ok._0;
            } else {
              return _bind$12;
            }
            if (_bind$13 === undefined) {
              return new _M0DTPC16result6ResultGRP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2ePackfileError("Missing base object for REF_DELTA"));
            } else {
              const _Some$2 = _bind$13;
              base$2 = _Some$2;
            }
          }
        }
        const _bind$12 = _M0FP36mizchi3bit4pack12apply__delta(base$2.data, _delta$2);
        let content$2;
        if (_bind$12.$tag === 1) {
          const _ok = _bind$12;
          content$2 = _ok._0;
        } else {
          return _bind$12;
        }
        const id$2 = _M0FP36mizchi3bit6object21hash__object__content(base$2.obj_type, content$2);
        return new _M0DTPC16result6ResultGRP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE2Ok(_M0MP36mizchi3bit6object10PackObject14with__metadata(base$2.obj_type, content$2, id$2, offset_i, 0));
      }
      default: {
        return new _M0DTPC16result6ResultGRP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2ePackfileError(`Unknown packfile object type: ${_M0IP016_24default__implPB4Show10to__stringGiE(_type_id)}`));
      }
    }
  }
  const _bind$4 = _M0FP36mizchi3bit4pack32packfile__type__to__object__type(_type_id);
  let obj_type;
  if (_bind$4.$tag === 1) {
    const _ok = _bind$4;
    obj_type = _ok._0;
  } else {
    return _bind$4;
  }
  let _bind$5;
  let _try_err;
  _L$2: {
    _L$3: {
      const _bind$6 = _M0FP26mizchi4zlib20zlib__decompress__at(data, _next_offset);
      if (_bind$6.$tag === 1) {
        const _ok = _bind$6;
        _bind$5 = _ok._0;
      } else {
        const _err = _bind$6;
        _try_err = _err._0;
        break _L$3;
      }
      break _L$2;
    }
    return new _M0DTPC16result6ResultGRP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2ePackfileError(`Zlib error: ${_M0IP016_24default__implPB4Show10to__stringGRP26mizchi4zlib9ZlibErrorE(_try_err)}`));
  }
  const _content = _bind$5._0;
  if (_content.length !== _size) {
    return new _M0DTPC16result6ResultGRP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2ePackfileError(`Object size mismatch: expected=${_M0IP016_24default__implPB4Show10to__stringGiE(_size)}, got=${_M0IP016_24default__implPB4Show10to__stringGiE(_content.length)}`));
  }
  const id = _M0FP36mizchi3bit6object21hash__object__content(obj_type, _content);
  return new _M0DTPC16result6ResultGRP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE2Ok(_M0MP36mizchi3bit6object10PackObject14with__metadata(obj_type, _content, id, offset_i, 0));
}
function _M0FP36mizchi3bit3lib12get__by__hex(db, fs, hex, seen) {
  if (_M0MPB3Map8containsGsbE(seen, hex)) {
    return new _M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject(`Delta cycle detected: ${hex}`));
  }
  _M0MPB3Map3setGsbE(seen, hex, true);
  if (db.prefer_packed) {
    const _bind = _M0FP36mizchi3bit3lib16get__from__packs(db, fs, hex, seen);
    let _bind$2;
    if (_bind.$tag === 1) {
      const _ok = _bind;
      _bind$2 = _ok._0;
    } else {
      return _bind;
    }
    if (_bind$2 === undefined) {
    } else {
      const _Some = _bind$2;
      const _obj = _Some;
      return new _M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE2Ok(_obj);
    }
  }
  const _bind = _M0MPB3Map3getGssE(db.loose_paths, hex);
  let loose_path;
  if (_bind === undefined) {
    if (hex.length === 40 || hex.length === 64) {
      const prefix = hex.substring(0, 2);
      const suffix = hex.substring(2, hex.length);
      const path = `${db.objects_dir}/${prefix}/${suffix}`;
      if (fs.method_table.method_3(fs.self, path)) {
        _M0MPB3Map3setGssE(db.loose_paths, hex, path);
        loose_path = path;
      } else {
        loose_path = undefined;
      }
    } else {
      loose_path = undefined;
    }
  } else {
    const _Some = _bind;
    const _path = _Some;
    loose_path = _path;
  }
  if (loose_path === undefined) {
  } else {
    const _Some = loose_path;
    const _path = _Some;
    const _bind$2 = fs.method_table.method_0(fs.self, _path);
    let compressed;
    if (_bind$2.$tag === 1) {
      const _ok = _bind$2;
      compressed = _ok._0;
    } else {
      return _bind$2;
    }
    let raw;
    let _try_err;
    _L: {
      _L$2: {
        const _bind$3 = _M0FP26mizchi4zlib16zlib__decompress(compressed);
        if (_bind$3.$tag === 1) {
          const _ok = _bind$3;
          raw = _ok._0;
        } else {
          const _err = _bind$3;
          _try_err = _err._0;
          break _L$2;
        }
        break _L;
      }
      return new _M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject(`Zlib error: ${_M0IP016_24default__implPB4Show10to__stringGRP26mizchi4zlib9ZlibErrorE(_try_err)}`));
    }
    const _bind$3 = _M0FP36mizchi3bit3lib20parse__loose__object(raw);
    let obj;
    if (_bind$3.$tag === 1) {
      const _ok = _bind$3;
      obj = _ok._0;
    } else {
      return _bind$3;
    }
    if (!db.skip_verify) {
      const verify_algo = hex.length === 64 ? 1 : 0;
      const computed = _M0MP36mizchi3bit6object8ObjectId7to__hex(_M0FP36mizchi3bit6object33hash__object__content__with__algo(verify_algo, obj.obj_type, obj.data));
      if (!(computed === hex)) {
        return new _M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error47mizchi_2fbit_2fobject_2eGitError_2eHashMismatch(computed, hex));
      }
    }
    return new _M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE2Ok(obj);
  }
  if (!db.prefer_packed) {
    const _bind$2 = _M0FP36mizchi3bit3lib16get__from__packs(db, fs, hex, seen);
    let _tmp;
    if (_bind$2.$tag === 1) {
      const _ok = _bind$2;
      _tmp = _ok._0;
    } else {
      return _bind$2;
    }
    return new _M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE2Ok(_tmp);
  }
  return new _M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE2Ok(undefined);
}
function _M0FP36mizchi3bit3lib19get__loose__by__hex(db, fs, hex) {
  const _bind = _M0MPB3Map3getGssE(db.loose_paths, hex);
  let loose_path;
  if (_bind === undefined) {
    if (hex.length === 40 || hex.length === 64) {
      const prefix = hex.substring(0, 2);
      const suffix = hex.substring(2, hex.length);
      const path = `${db.objects_dir}/${prefix}/${suffix}`;
      if (fs.method_table.method_3(fs.self, path)) {
        _M0MPB3Map3setGssE(db.loose_paths, hex, path);
        loose_path = path;
      } else {
        loose_path = undefined;
      }
    } else {
      loose_path = undefined;
    }
  } else {
    const _Some = _bind;
    const _path = _Some;
    loose_path = _path;
  }
  if (loose_path === undefined) {
    return new _M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE2Ok(undefined);
  } else {
    const _Some = loose_path;
    const _path = _Some;
    const _bind$2 = fs.method_table.method_0(fs.self, _path);
    let compressed;
    if (_bind$2.$tag === 1) {
      const _ok = _bind$2;
      compressed = _ok._0;
    } else {
      return _bind$2;
    }
    let raw;
    let _try_err;
    _L: {
      _L$2: {
        const _bind$3 = _M0FP26mizchi4zlib16zlib__decompress(compressed);
        if (_bind$3.$tag === 1) {
          const _ok = _bind$3;
          raw = _ok._0;
        } else {
          const _err = _bind$3;
          _try_err = _err._0;
          break _L$2;
        }
        break _L;
      }
      return new _M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject(`Zlib error: ${_M0IP016_24default__implPB4Show10to__stringGRP26mizchi4zlib9ZlibErrorE(_try_err)}`));
    }
    const _bind$3 = _M0FP36mizchi3bit3lib20parse__loose__object(raw);
    let obj;
    if (_bind$3.$tag === 1) {
      const _ok = _bind$3;
      obj = _ok._0;
    } else {
      return _bind$3;
    }
    if (!db.skip_verify) {
      const verify_algo = hex.length === 64 ? 1 : 0;
      const computed = _M0MP36mizchi3bit6object8ObjectId7to__hex(_M0FP36mizchi3bit6object33hash__object__content__with__algo(verify_algo, obj.obj_type, obj.data));
      if (!(computed === hex)) {
        return new _M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error47mizchi_2fbit_2fobject_2eGitError_2eHashMismatch(computed, hex));
      }
    }
    return new _M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE2Ok(obj);
  }
}
function _M0MP36mizchi3bit3lib8ObjectDb3get(self, fs, id) {
  const hex = _M0MP36mizchi3bit6object8ObjectId7to__hex(id);
  if (!self.prefer_packed) {
    const _bind = _M0FP36mizchi3bit3lib19get__loose__by__hex(self, fs, hex);
    let _bind$2;
    if (_bind.$tag === 1) {
      const _ok = _bind;
      _bind$2 = _ok._0;
    } else {
      return _bind;
    }
    if (_bind$2 === undefined) {
    } else {
      const _Some = _bind$2;
      const _obj = _Some;
      return new _M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE2Ok(_obj);
    }
  }
  const _bind = [];
  const seen = _M0MPB3Map11from__arrayGsbE(new _M0TPB9ArrayViewGUsbEE(_bind, 0, 0));
  _M0MPB3Map3setGsbE(seen, hex, true);
  if (self.prefer_packed) {
    const _bind$2 = _M0FP36mizchi3bit3lib16get__from__packs(self, fs, hex, seen);
    let _bind$3;
    if (_bind$2.$tag === 1) {
      const _ok = _bind$2;
      _bind$3 = _ok._0;
    } else {
      return _bind$2;
    }
    if (_bind$3 === undefined) {
    } else {
      const _Some = _bind$3;
      const _obj = _Some;
      return new _M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE2Ok(_obj);
    }
    const _bind$4 = _M0FP36mizchi3bit3lib19get__loose__by__hex(self, fs, hex);
    let _bind$5;
    if (_bind$4.$tag === 1) {
      const _ok = _bind$4;
      _bind$5 = _ok._0;
    } else {
      return _bind$4;
    }
    if (_bind$5 === undefined) {
    } else {
      const _Some = _bind$5;
      const _obj = _Some;
      return new _M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE2Ok(_obj);
    }
  } else {
    const _bind$2 = _M0FP36mizchi3bit3lib16get__from__packs(self, fs, hex, seen);
    let _bind$3;
    if (_bind$2.$tag === 1) {
      const _ok = _bind$2;
      _bind$3 = _ok._0;
    } else {
      return _bind$2;
    }
    if (_bind$3 === undefined) {
    } else {
      const _Some = _bind$3;
      const _obj = _Some;
      return new _M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE2Ok(_obj);
    }
  }
  return new _M0DTPC16result6ResultGORP36mizchi3bit6object10PackObjectRP36mizchi3bit6object8GitErrorE2Ok(_M0FP36mizchi3bit3lib24get__from__commit__graph(self, id));
}
function _M0MP36mizchi3bit3lib15CommitGraphFile4load(rfs, git_dir) {
  const graph_path = _M0FP36mizchi3bit3lib10join__path(git_dir, "objects/info/commit-graph");
  if (!rfs.method_table.method_3(rfs.self, graph_path)) {
    return new _M0DTPC16result6ResultGORP36mizchi3bit3lib15CommitGraphFileRP36mizchi3bit6object8GitErrorE2Ok(undefined);
  }
  const _bind = rfs.method_table.method_0(rfs.self, graph_path);
  let data;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    data = _ok._0;
  } else {
    return _bind;
  }
  if (data.length < 8) {
    return new _M0DTPC16result6ResultGORP36mizchi3bit3lib15CommitGraphFileRP36mizchi3bit6object8GitErrorE2Ok(undefined);
  }
  const sig = _M0FP36mizchi3bit3lib17cgraph__read__u32(data, 0);
  if (sig !== 1128747080) {
    return new _M0DTPC16result6ResultGORP36mizchi3bit3lib15CommitGraphFileRP36mizchi3bit6object8GitErrorE2Ok(undefined);
  }
  $bound_check(data, 5);
  const hash_version = data[5];
  const hash_size = hash_version === 2 ? 32 : 20;
  $bound_check(data, 6);
  const num_chunks = data[6];
  let oidf_offset = 0;
  let oidl_offset = 0;
  let cdat_offset = 0;
  let edge_offset = 0;
  const chunk_offsets = [];
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i <= num_chunks) {
      const entry = 8 + (Math.imul(i, 12) | 0) | 0;
      if ((entry + 12 | 0) > data.length) {
        break;
      }
      const chunk_id = _M0FP36mizchi3bit3lib17cgraph__read__u32(data, entry);
      const offset = _M0FP36mizchi3bit3lib17cgraph__read__u32(data, entry + 8 | 0);
      _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(chunk_offsets, { _0: chunk_id, _1: offset });
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  let _tmp$2 = 0;
  while (true) {
    const i = _tmp$2;
    if (i < (chunk_offsets.length - 1 | 0)) {
      const _bind$2 = _M0MPC15array5Array2atGUiiEE(chunk_offsets, i);
      const _cid = _bind$2._0;
      const _off = _bind$2._1;
      switch (_cid) {
        case 1330201670: {
          oidf_offset = _off;
          break;
        }
        case 1330201676: {
          oidl_offset = _off;
          break;
        }
        case 1128546644: {
          cdat_offset = _off;
          break;
        }
        case 1162102597: {
          edge_offset = _off;
          break;
        }
      }
      _tmp$2 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  if (oidf_offset === 0 || (oidl_offset === 0 || cdat_offset === 0)) {
    return new _M0DTPC16result6ResultGORP36mizchi3bit3lib15CommitGraphFileRP36mizchi3bit6object8GitErrorE2Ok(undefined);
  }
  const num_commits = _M0FP36mizchi3bit3lib17cgraph__read__u32(data, oidf_offset + 1020 | 0);
  return new _M0DTPC16result6ResultGORP36mizchi3bit3lib15CommitGraphFileRP36mizchi3bit6object8GitErrorE2Ok(new _M0TP36mizchi3bit3lib15CommitGraphFile(data, hash_size, num_commits, oidf_offset, oidl_offset, cdat_offset, edge_offset));
}
function _M0FP36mizchi3bit3lib22object__db__parse__int(value) {
  return _M0FPC17strconv18parse__int_2einner(value, 0);
}
function _M0FP36mizchi3bit3lib29pack__cache__limit__from__env() {
  const _bind = _M0FP36mizchi3bit2io8env__get("BIT_PACK_CACHE_LIMIT");
  if (_bind === undefined) {
    return 2;
  } else {
    const _Some = _bind;
    const _v = _Some;
    let _try_err;
    _L: {
      const _bind$2 = _M0FP36mizchi3bit3lib22object__db__parse__int(new _M0TPC16string10StringView(_v, 0, _v.length));
      let _bind$3;
      if (_bind$2.$tag === 1) {
        const _ok = _bind$2;
        _bind$3 = _ok._0;
      } else {
        const _err = _bind$2;
        _try_err = _err._0;
        break _L;
      }
      return _bind$3 < 0 ? 0 : _bind$3;
    }
    return 2;
  }
}
function _M0FP36mizchi3bit3lib15resolve__gitdir(fs, bit_path) {
  return _M0FP36mizchi3bit6remote15resolve__gitdir(fs, bit_path);
}
function _M0MP36mizchi3bit3lib13LazyPackIndex3new(idx_path, pack_path) {
  return new _M0TP36mizchi3bit3lib13LazyPackIndex(idx_path, pack_path, undefined);
}
function _M0FP36mizchi3bit3lib28collect__lazy__pack__indexes(fs, pack_dir) {
  const result = [];
  const _bind = fs.method_table.method_1(fs.self, pack_dir);
  let entries;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    entries = _ok._0;
  } else {
    return _bind;
  }
  const _bind$2 = entries.length;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind$2) {
      const entry = entries[_];
      _L: {
        if (!_M0MPC16string6String11has__suffix(entry, new _M0TPC16string10StringView(_M0FP36mizchi3bit3lib28collect__lazy__pack__indexesN7_2abindS9785, 0, _M0FP36mizchi3bit3lib28collect__lazy__pack__indexesN7_2abindS9785.length))) {
          break _L;
        }
        const idx_path = _M0FP36mizchi3bit3lib10join__path(pack_dir, entry);
        if (!fs.method_table.method_3(fs.self, idx_path)) {
          break _L;
        }
        const base = entry.substring(0, entry.length - 4 | 0);
        const pack_path = _M0FP36mizchi3bit3lib10join__path(pack_dir, `${base}.pack`);
        if (!fs.method_table.method_3(fs.self, pack_path)) {
          break _L;
        }
        _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(result, _M0MP36mizchi3bit3lib13LazyPackIndex3new(idx_path, pack_path));
        break _L;
      }
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return new _M0DTPC16result6ResultGRPB5ArrayGRP36mizchi3bit3lib13LazyPackIndexERP36mizchi3bit6object8GitErrorE2Ok(result);
}
function _M0MP36mizchi3bit3lib8ObjectDb30load__lazy__from__objects__dir(fs, objects_dir) {
  let lazy_packs;
  if (fs.method_table.method_2(fs.self, objects_dir)) {
    const pack_dir = _M0FP36mizchi3bit3lib10join__path(objects_dir, "pack");
    if (fs.method_table.method_2(fs.self, pack_dir)) {
      const _bind = _M0FP36mizchi3bit3lib28collect__lazy__pack__indexes(fs, pack_dir);
      if (_bind.$tag === 1) {
        const _ok = _bind;
        lazy_packs = _ok._0;
      } else {
        return _bind;
      }
    } else {
      lazy_packs = [];
    }
  } else {
    lazy_packs = [];
  }
  const pack_cache_limit = _M0FP36mizchi3bit3lib29pack__cache__limit__from__env();
  const _bind = [];
  const _tmp = _M0MPB3Map11from__arrayGssE(new _M0TPB9ArrayViewGUssEE(_bind, 0, 0));
  const _tmp$2 = [];
  const _bind$2 = [];
  return new _M0DTPC16result6ResultGRP36mizchi3bit3lib8ObjectDbRP36mizchi3bit6object8GitErrorE2Ok(new _M0TP36mizchi3bit3lib8ObjectDb(objects_dir, _tmp, _tmp$2, lazy_packs, _M0MPB3Map11from__arrayGszE(new _M0TPB9ArrayViewGUszEE(_bind$2, 0, 0)), [], pack_cache_limit, false, false, false, undefined));
}
function _M0MP36mizchi3bit3lib8ObjectDb10load__lazy(fs, git_dir) {
  const _bind = _M0MP36mizchi3bit3lib8ObjectDb30load__lazy__from__objects__dir(fs, _M0FP36mizchi3bit3lib10join__path(git_dir, "objects"));
  let db;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    db = _ok._0;
  } else {
    return _bind;
  }
  let _tmp;
  let _try_err;
  _L: {
    _L$2: {
      const _bind$2 = _M0MP36mizchi3bit3lib15CommitGraphFile4load(fs, git_dir);
      if (_bind$2.$tag === 1) {
        const _ok = _bind$2;
        _tmp = _ok._0;
      } else {
        const _err = _bind$2;
        _try_err = _err._0;
        break _L$2;
      }
      break _L;
    }
    _tmp = undefined;
  }
  db.commit_graph = _tmp;
  return new _M0DTPC16result6ResultGRP36mizchi3bit3lib8ObjectDbRP36mizchi3bit6object8GitErrorE2Ok(db);
}
function _M0IP46mizchi3bit1x3hub12WorkItemKindPB2Eq5equal(_x_2018, _x_2019) {
  if (_x_2018 === 0) {
    if (_x_2019 === 0) {
      return true;
    } else {
      return false;
    }
  } else {
    if (_x_2019 === 1) {
      return true;
    } else {
      return false;
    }
  }
}
function _M0IP46mizchi3bit1x3hub13WorkItemStatePB2Eq5equal(_x_2014, _x_2015) {
  switch (_x_2014) {
    case 0: {
      if (_x_2015 === 0) {
        return true;
      } else {
        return false;
      }
    }
    case 1: {
      if (_x_2015 === 1) {
        return true;
      } else {
        return false;
      }
    }
    default: {
      if (_x_2015 === 2) {
        return true;
      } else {
        return false;
      }
    }
  }
}
function _M0IP46mizchi3bit1x3hub10IssueStatePB2Eq5equal(_x_2006, _x_2007) {
  if (_x_2006 === 0) {
    if (_x_2007 === 0) {
      return true;
    } else {
      return false;
    }
  } else {
    if (_x_2007 === 1) {
      return true;
    } else {
      return false;
    }
  }
}
function _M0FP46mizchi3bit1x3hub12parse__int64(s) {
  let result = $0L;
  const _it = _M0MPC16string6String4iter(s);
  while (true) {
    const _bind = _M0MPB4Iter4nextGcE(_it);
    if (_bind === -1) {
      break;
    } else {
      const _Some = _bind;
      const _c = _Some;
      if (_c >= 48 && _c <= 57) {
        result = _M0IPC15int645Int64PB3Add3add(_M0IPC15int645Int64PB3Mul3mul(result, $10L), _M0MPC13int3Int9to__int64(_c - 48 | 0));
      }
      continue;
    }
  }
  return result;
}
function _M0FP46mizchi3bit1x3hub24parse__work__item__state(s) {
  switch (s) {
    case "open": {
      return 0;
    }
    case "merged": {
      return 1;
    }
    case "closed": {
      return 2;
    }
    default: {
      return 0;
    }
  }
}
function _M0MP46mizchi3bit1x3hub8WorkItem11new_2einner(id, title, body, author, created_at, updated_at, state, labels, assignees, linked_prs, linked_issues, patch, parent_id) {
  return new _M0TP46mizchi3bit1x3hub8WorkItem(id, title, body, author, created_at, updated_at, state, labels, assignees, linked_prs, linked_issues, patch, parent_id);
}
function _M0MP46mizchi3bit1x3hub8WorkItem3new(id, title, body, author, created_at, updated_at, state, labels$46$opt, assignees$46$opt, linked_prs$46$opt, linked_issues$46$opt, patch$46$opt, parent_id$46$opt) {
  let labels;
  if (labels$46$opt.$tag === 1) {
    const _Some = labels$46$opt;
    labels = _Some._0;
  } else {
    labels = [];
  }
  let assignees;
  if (assignees$46$opt.$tag === 1) {
    const _Some = assignees$46$opt;
    assignees = _Some._0;
  } else {
    assignees = [];
  }
  let linked_prs;
  if (linked_prs$46$opt.$tag === 1) {
    const _Some = linked_prs$46$opt;
    linked_prs = _Some._0;
  } else {
    linked_prs = [];
  }
  let linked_issues;
  if (linked_issues$46$opt.$tag === 1) {
    const _Some = linked_issues$46$opt;
    linked_issues = _Some._0;
  } else {
    linked_issues = [];
  }
  let patch;
  if (patch$46$opt.$tag === 1) {
    const _Some = patch$46$opt;
    patch = _Some._0;
  } else {
    patch = undefined;
  }
  let parent_id;
  if (parent_id$46$opt.$tag === 1) {
    const _Some = parent_id$46$opt;
    parent_id = _Some._0;
  } else {
    parent_id = undefined;
  }
  return _M0MP46mizchi3bit1x3hub8WorkItem11new_2einner(id, title, body, author, created_at, updated_at, state, labels, assignees, linked_prs, linked_issues, patch, parent_id);
}
function _M0MP46mizchi3bit1x3hub13WorkItemPatch11new_2einner(source_branch, source_commit, target_branch, target_commit, closes_issues, merge_commit, source_repo, source_ref) {
  return new _M0TP46mizchi3bit1x3hub13WorkItemPatch(source_branch, source_repo, source_ref, source_commit, target_branch, target_commit, closes_issues, merge_commit);
}
function _M0FP46mizchi3bit1x3hub17parse__work__item(text) {
  let id = "";
  let title = "";
  let author = "";
  let created_at = $0L;
  let updated_at = $0L;
  let state = 0;
  const labels = [];
  const assignees = [];
  const linked_prs = [];
  const linked_issues = [];
  let source_branch = undefined;
  let source_repo = undefined;
  let source_ref = undefined;
  let source_commit_hex = undefined;
  let target_branch = undefined;
  let target_commit_hex = undefined;
  const closes_issues = [];
  let merge_commit = undefined;
  let parent_id = undefined;
  const body_lines = [];
  let in_body = false;
  const _it = _M0MPC16string6String5split(text, new _M0TPC16string10StringView(_M0FP46mizchi3bit1x3hub17parse__work__itemN7_2abindS2271, 0, _M0FP46mizchi3bit1x3hub17parse__work__itemN7_2abindS2271.length));
  while (true) {
    const _bind = _M0MPB4Iter4nextGRPC16string10StringViewE(_it);
    if (_bind === undefined) {
      break;
    } else {
      const _Some = _bind;
      const _line_view = _Some;
      const line = _M0IPC16string10StringViewPB4Show10to__string(_line_view);
      if (in_body) {
        _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(body_lines, line);
        continue;
      }
      if (line.length === 0) {
        in_body = true;
        continue;
      }
      const space = _M0MPC16string6String4find(line, new _M0TPC16string10StringView(_M0FP46mizchi3bit1x3hub17parse__work__itemN7_2abindS2260, 0, _M0FP46mizchi3bit1x3hub17parse__work__itemN7_2abindS2260.length));
      if (space === undefined) {
        continue;
      } else {
        const _Some$2 = space;
        const _idx = _Some$2;
        const key = line.substring(0, _idx);
        const value = line.substring(_idx + 1 | 0, line.length);
        switch (key) {
          case "work-item": {
            id = value;
            break;
          }
          case "title": {
            title = value;
            break;
          }
          case "author": {
            author = value;
            break;
          }
          case "created": {
            created_at = _M0FP46mizchi3bit1x3hub12parse__int64(value);
            break;
          }
          case "updated": {
            updated_at = _M0FP46mizchi3bit1x3hub12parse__int64(value);
            break;
          }
          case "state": {
            state = _M0FP46mizchi3bit1x3hub24parse__work__item__state(value);
            break;
          }
          case "label": {
            _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(labels, value);
            break;
          }
          case "assignee": {
            _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(assignees, value);
            break;
          }
          case "linked-pr": {
            _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(linked_prs, value);
            break;
          }
          case "linked-issue": {
            _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(linked_issues, value);
            break;
          }
          case "parent": {
            parent_id = value;
            break;
          }
          case "source": {
            source_branch = value;
            break;
          }
          case "source-repo": {
            source_repo = value;
            break;
          }
          case "source-ref": {
            source_ref = value;
            break;
          }
          case "source-commit": {
            source_commit_hex = value;
            break;
          }
          case "target": {
            target_branch = value;
            break;
          }
          case "target-commit": {
            target_commit_hex = value;
            break;
          }
          case "closes": {
            _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(closes_issues, value);
            break;
          }
          case "merge-commit": {
            let _tmp;
            let _try_err;
            _L: {
              _L$2: {
                const _bind$2 = _M0MP36mizchi3bit6object8ObjectId9from__hex(value);
                if (_bind$2.$tag === 1) {
                  const _ok = _bind$2;
                  _tmp = _ok._0;
                } else {
                  const _err = _bind$2;
                  _try_err = _err._0;
                  break _L$2;
                }
                break _L;
              }
              return new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub8WorkItemRP46mizchi3bit1x3hub7PrErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fx_2fhub_2ePrError_2eInvalidFormat("Invalid merge-commit hex"));
            }
            merge_commit = _tmp;
            break;
          }
        }
      }
      continue;
    }
  }
  if (id.length === 0) {
    return new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub8WorkItemRP46mizchi3bit1x3hub7PrErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fx_2fhub_2ePrError_2eInvalidFormat("Missing work item id"));
  }
  let patch;
  _L: {
    _L$2: {
      const _bind = source_branch;
      const _bind$2 = source_commit_hex;
      const _bind$3 = target_branch;
      const _bind$4 = target_commit_hex;
      if (_bind === undefined) {
        if (_bind$2 === undefined) {
          if (_bind$3 === undefined) {
            if (_bind$4 === undefined) {
              patch = undefined;
            } else {
              break _L$2;
            }
          } else {
            break _L$2;
          }
        } else {
          break _L$2;
        }
      } else {
        const _Some = _bind;
        const _src_branch = _Some;
        if (_bind$2 === undefined) {
          break _L$2;
        } else {
          const _Some$2 = _bind$2;
          const _src_hex = _Some$2;
          if (_bind$3 === undefined) {
            break _L$2;
          } else {
            const _Some$3 = _bind$3;
            const _tgt_branch = _Some$3;
            if (_bind$4 === undefined) {
              break _L$2;
            } else {
              const _Some$4 = _bind$4;
              const _tgt_hex = _Some$4;
              let source_commit;
              let _try_err;
              _L$3: {
                _L$4: {
                  const _bind$5 = _M0MP36mizchi3bit6object8ObjectId9from__hex(_src_hex);
                  if (_bind$5.$tag === 1) {
                    const _ok = _bind$5;
                    source_commit = _ok._0;
                  } else {
                    const _err = _bind$5;
                    _try_err = _err._0;
                    break _L$4;
                  }
                  break _L$3;
                }
                return new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub8WorkItemRP46mizchi3bit1x3hub7PrErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fx_2fhub_2ePrError_2eInvalidFormat("Invalid source-commit hex"));
              }
              let target_commit;
              let _try_err$2;
              _L$4: {
                _L$5: {
                  const _bind$5 = _M0MP36mizchi3bit6object8ObjectId9from__hex(_tgt_hex);
                  if (_bind$5.$tag === 1) {
                    const _ok = _bind$5;
                    target_commit = _ok._0;
                  } else {
                    const _err = _bind$5;
                    _try_err$2 = _err._0;
                    break _L$5;
                  }
                  break _L$4;
                }
                return new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub8WorkItemRP46mizchi3bit1x3hub7PrErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fx_2fhub_2ePrError_2eInvalidFormat("Invalid target-commit hex"));
              }
              patch = _M0MP46mizchi3bit1x3hub13WorkItemPatch11new_2einner(_src_branch, source_commit, _tgt_branch, target_commit, closes_issues, merge_commit, source_repo, source_ref);
            }
          }
        }
      }
      break _L;
    }
    return new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub8WorkItemRP46mizchi3bit1x3hub7PrErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fx_2fhub_2ePrError_2eInvalidFormat("Incomplete work item patch fields"));
  }
  return new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub8WorkItemRP46mizchi3bit1x3hub7PrErrorE2Ok(_M0MP46mizchi3bit1x3hub8WorkItem11new_2einner(id, title, _M0MPC15array5Array4joinGsE(body_lines, new _M0TPC16string10StringView(_M0FP46mizchi3bit1x3hub17parse__work__itemN7_2abindS2272, 0, _M0FP46mizchi3bit1x3hub17parse__work__itemN7_2abindS2272.length)), author, created_at, updated_at, state, labels, assignees, linked_prs, linked_issues, patch, parent_id));
}
function _M0FP46mizchi3bit1x3hub19key__to__target__id(key) {
  const _bind = _M0FP36mizchi3bit6object20create__blob__string(key);
  return _bind._0;
}
function _M0FP46mizchi3bit1x3hub12parse__clock(s) {
  const _bind = [];
  const result = _M0MPB3Map11from__arrayGslE(new _M0TPB9ArrayViewGUslEE(_bind, 0, 0));
  if (s.length === 0) {
    return result;
  }
  const _it = _M0MPC16string6String5split(s, new _M0TPC16string10StringView(_M0FP46mizchi3bit1x3hub12parse__clockN7_2abindS2317, 0, _M0FP46mizchi3bit1x3hub12parse__clockN7_2abindS2317.length));
  while (true) {
    const _bind$2 = _M0MPB4Iter4nextGRPC16string10StringViewE(_it);
    if (_bind$2 === undefined) {
      break;
    } else {
      const _Some = _bind$2;
      const _part_view = _Some;
      const part = _M0IPC16string10StringViewPB4Show10to__string(_part_view);
      if (part.length === 0) {
        continue;
      }
      const eq = _M0MPC16string6String4find(part, new _M0TPC16string10StringView(_M0FP46mizchi3bit1x3hub12parse__clockN7_2abindS2306, 0, _M0FP46mizchi3bit1x3hub12parse__clockN7_2abindS2306.length));
      if (eq === undefined) {
        continue;
      } else {
        const _Some$2 = eq;
        const _idx = _Some$2;
        const key = part.substring(0, _idx);
        const value = part.substring(_idx + 1 | 0, part.length);
        const parsed = _M0FP46mizchi3bit1x3hub12parse__int64(value);
        _M0MPB3Map3setGslE(result, key, parsed);
      }
      continue;
    }
  }
  return result;
}
function _M0FP46mizchi3bit1x3hub10parse__int(s) {
  let result = 0;
  const _it = _M0MPC16string6String4iter(s);
  while (true) {
    const _bind = _M0MPB4Iter4nextGcE(_it);
    if (_bind === -1) {
      break;
    } else {
      const _Some = _bind;
      const _c = _Some;
      if (_c >= 48 && _c <= 57) {
        result = (Math.imul(result, 10) | 0) + (_c - 48 | 0) | 0;
      }
      continue;
    }
  }
  return result;
}
function _M0MP46mizchi3bit1x3hub9HubRecord11new_2einner(key, kind, payload, node, timestamp, clock, deleted, version, signature) {
  return new _M0TP46mizchi3bit1x3hub9HubRecord(version, key, kind, clock, timestamp, node, deleted, signature, payload);
}
function _M0MP46mizchi3bit1x3hub9HubRecord3new(key, kind, payload, node, timestamp, clock$46$opt, deleted$46$opt, version$46$opt, signature$46$opt) {
  let clock;
  if (clock$46$opt === undefined) {
    const _bind = [];
    clock = _M0MPB3Map11from__arrayGslE(new _M0TPB9ArrayViewGUslEE(_bind, 0, 0));
  } else {
    const _Some = clock$46$opt;
    clock = _Some;
  }
  const deleted = deleted$46$opt === -1 ? false : deleted$46$opt;
  let version;
  if (version$46$opt === undefined) {
    version = 1;
  } else {
    const _Some = version$46$opt;
    version = _Some;
  }
  let signature;
  if (signature$46$opt.$tag === 1) {
    const _Some = signature$46$opt;
    signature = _Some._0;
  } else {
    signature = undefined;
  }
  return _M0MP46mizchi3bit1x3hub9HubRecord11new_2einner(key, kind, payload, node, timestamp, clock, deleted, version, signature);
}
function _M0FP46mizchi3bit1x3hub18parse__hub__record(text) {
  let version = 0;
  let key = "";
  let kind = "";
  const _bind = [];
  let clock = _M0MPB3Map11from__arrayGslE(new _M0TPB9ArrayViewGUslEE(_bind, 0, 0));
  let timestamp = $0L;
  let node = "";
  let deleted = false;
  let signature = undefined;
  const payload_lines = [];
  let in_body = false;
  const _it = _M0MPC16string6String5split(text, new _M0TPC16string10StringView(_M0FP46mizchi3bit1x3hub18parse__hub__recordN7_2abindS2380, 0, _M0FP46mizchi3bit1x3hub18parse__hub__recordN7_2abindS2380.length));
  while (true) {
    const _bind$2 = _M0MPB4Iter4nextGRPC16string10StringViewE(_it);
    if (_bind$2 === undefined) {
      break;
    } else {
      const _Some = _bind$2;
      const _line_view = _Some;
      const line = _M0IPC16string10StringViewPB4Show10to__string(_line_view);
      if (in_body) {
        _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(payload_lines, line);
        continue;
      }
      if (line.length === 0) {
        in_body = true;
        continue;
      }
      const space = _M0MPC16string6String4find(line, new _M0TPC16string10StringView(_M0FP46mizchi3bit1x3hub18parse__hub__recordN7_2abindS2369, 0, _M0FP46mizchi3bit1x3hub18parse__hub__recordN7_2abindS2369.length));
      if (space === undefined) {
        continue;
      } else {
        const _Some$2 = space;
        const _idx = _Some$2;
        const k = line.substring(0, _idx);
        const v = line.substring(_idx + 1 | 0, line.length);
        switch (k) {
          case "version": {
            version = _M0FP46mizchi3bit1x3hub10parse__int(v);
            break;
          }
          case "key": {
            key = v;
            break;
          }
          case "kind": {
            kind = v;
            break;
          }
          case "clock": {
            clock = _M0FP46mizchi3bit1x3hub12parse__clock(v);
            break;
          }
          case "timestamp": {
            timestamp = _M0FP46mizchi3bit1x3hub12parse__int64(v);
            break;
          }
          case "node": {
            node = v;
            break;
          }
          case "deleted": {
            deleted = v === "1" || (v === "true" || v === "yes");
            break;
          }
          case "signature": {
            signature = v;
            break;
          }
        }
      }
      continue;
    }
  }
  return _M0MP46mizchi3bit1x3hub9HubRecord11new_2einner(key, kind, _M0MPC15array5Array4joinGsE(payload_lines, new _M0TPC16string10StringView(_M0FP46mizchi3bit1x3hub18parse__hub__recordN7_2abindS2381, 0, _M0FP46mizchi3bit1x3hub18parse__hub__recordN7_2abindS2381.length)), node, timestamp, clock, deleted, version, signature);
}
function _M0FP46mizchi3bit1x3hub17clock__to__string(clock) {
  if (clock.size === 0) {
    return "";
  }
  const items = _M0MPB3Map9to__arrayGsRP36mizchi3bit6object8ObjectIdE(clock);
  _M0MPC15array5Array8sort__byGRP46mizchi3bit1x3hub12IssueCommentE(items, (a, b) => _M0IPC16string6StringPB7Compare7compare(a._0, b._0));
  const parts = [];
  const _bind = items.length;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind) {
      const item = items[_];
      const _key = item._0;
      const _value = item._1;
      _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(parts, `${_key}=${_M0MPC15int645Int6418to__string_2einner(_value, 10)}`);
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return _M0MPC15array5Array4joinGsE(parts, new _M0TPC16string10StringView(_M0FP46mizchi3bit1x3hub17clock__to__stringN7_2abindS2390, 0, _M0FP46mizchi3bit1x3hub17clock__to__stringN7_2abindS2390.length));
}
function _M0FP46mizchi3bit1x3hub22serialize__hub__record(record, signature) {
  const sb = _M0MPB13StringBuilder11new_2einner(0);
  _M0IPB13StringBuilderPB6Logger13write__string(sb, "version ");
  _M0IPB13StringBuilderPB6Logger13write__string(sb, _M0MPC13int3Int18to__string_2einner(record.version, 10));
  _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
  _M0IPB13StringBuilderPB6Logger13write__string(sb, "key ");
  _M0IPB13StringBuilderPB6Logger13write__string(sb, record.key);
  _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
  _M0IPB13StringBuilderPB6Logger13write__string(sb, "kind ");
  _M0IPB13StringBuilderPB6Logger13write__string(sb, record.kind);
  _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
  _M0IPB13StringBuilderPB6Logger13write__string(sb, "clock ");
  _M0IPB13StringBuilderPB6Logger13write__string(sb, _M0FP46mizchi3bit1x3hub17clock__to__string(record.clock));
  _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
  _M0IPB13StringBuilderPB6Logger13write__string(sb, "timestamp ");
  _M0IPB13StringBuilderPB6Logger13write__string(sb, _M0MPC15int645Int6418to__string_2einner(record.timestamp, 10));
  _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
  _M0IPB13StringBuilderPB6Logger13write__string(sb, "node ");
  _M0IPB13StringBuilderPB6Logger13write__string(sb, record.node);
  _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
  _M0IPB13StringBuilderPB6Logger13write__string(sb, "deleted ");
  _M0IPB13StringBuilderPB6Logger13write__string(sb, record.deleted ? "1" : "0");
  _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
  if (signature === undefined) {
  } else {
    const _Some = signature;
    const _sig = _Some;
    _M0IPB13StringBuilderPB6Logger13write__string(sb, "signature ");
    _M0IPB13StringBuilderPB6Logger13write__string(sb, _sig);
    _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
  }
  _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
  _M0IPB13StringBuilderPB6Logger13write__string(sb, record.payload);
  return sb.val;
}
function _M0FP46mizchi3bit1x3hub32serialize__hub__record__unsigned(record) {
  return _M0FP46mizchi3bit1x3hub22serialize__hub__record(record, undefined);
}
function _M0FP46mizchi3bit1x3hub26compute__record__signature(record, signing_key) {
  const state = _M0MP36mizchi3bit6object9Sha1State3new();
  _M0MP36mizchi3bit6object9Sha1State14update__string(state, _M0FP46mizchi3bit1x3hub32serialize__hub__record__unsigned(record));
  _M0MP36mizchi3bit6object9Sha1State14update__string(state, "\n--signing-key--\n");
  _M0MP36mizchi3bit6object9Sha1State14update__string(state, signing_key);
  return _M0MP36mizchi3bit6object8ObjectId7to__hex(_M0MP36mizchi3bit6object9Sha1State6finish(state));
}
function _M0FP46mizchi3bit1x3hub25verify__record__signature(record, signing_key) {
  const _bind = record.signature;
  if (_bind === undefined) {
    return false;
  } else {
    const _Some = _bind;
    const _sig = _Some;
    return _sig === _M0FP46mizchi3bit1x3hub26compute__record__signature(record, signing_key);
  }
}
function _M0FP46mizchi3bit1x3hub26verify__record__by__policy(store, record) {
  const _bind = store.signing_key;
  if (_bind === undefined) {
    return !store.require_signed;
  } else {
    const _Some = _bind;
    const _key = _Some;
    const _bind$2 = record.signature;
    return _bind$2 === undefined ? !store.require_signed : _M0FP46mizchi3bit1x3hub25verify__record__signature(record, _key);
  }
}
function _M0MP46mizchi3bit1x3hub8HubStore11get__record(self, objects, key) {
  const target_id = _M0FP46mizchi3bit1x3hub19key__to__target__id(key);
  const entry_name = _M0MP36mizchi3bit6object8ObjectId7to__hex(target_id);
  const blob_id = _M0MPB3Map3getGsRP36mizchi3bit6object8ObjectIdE(self.entries, entry_name);
  if (blob_id === undefined) {
    return undefined;
  } else {
    const _Some = blob_id;
    const _bid = _Some;
    let obj;
    let _try_err;
    _L: {
      _L$2: {
        const _bind = objects.method_table.method_0(objects.self, _bid);
        if (_bind.$tag === 1) {
          const _ok = _bind;
          obj = _ok._0;
        } else {
          const _err = _bind;
          _try_err = _err._0;
          break _L$2;
        }
        break _L;
      }
      obj = undefined;
    }
    if (obj === undefined) {
      return undefined;
    } else {
      const _Some$2 = obj;
      const _blob_obj = _Some$2;
      const _bind = _blob_obj.data;
      const text = _M0FPC28encoding4utf821decode__lossy_2einner(_M0MPC15bytes5Bytes12view_2einner(_bind, 0, _bind.length), false);
      const record = _M0FP46mizchi3bit1x3hub18parse__hub__record(text);
      return !_M0FP46mizchi3bit1x3hub26verify__record__by__policy(self, record) ? undefined : record.deleted ? undefined : record;
    }
  }
}
function _M0MP46mizchi3bit1x3hub3Hub15get__work__item(self, objects, work_item_id) {
  const record = _M0MP46mizchi3bit1x3hub8HubStore11get__record(self.store, objects, `${_M0FP46mizchi3bit1x3hub31work__item__meta__prefix__value}${work_item_id}/meta`);
  if (record === undefined) {
    return undefined;
  } else {
    const _Some = record;
    const _r = _Some;
    const _p = _r.kind;
    if (!(_p === _M0FP46mizchi3bit1x3hub42canonical__work__item__record__kind__value)) {
      return undefined;
    }
    let result;
    let _try_err;
    _L: {
      _L$2: {
        const _bind = _M0FP46mizchi3bit1x3hub17parse__work__item(_r.payload);
        let _tmp;
        if (_bind.$tag === 1) {
          const _ok = _bind;
          _tmp = _ok._0;
        } else {
          const _err = _bind;
          _try_err = _err._0;
          break _L$2;
        }
        result = new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub8WorkItemRP46mizchi3bit1x3hub7PrErrorE2Ok(_tmp);
        break _L;
      }
      result = new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub8WorkItemRP46mizchi3bit1x3hub7PrErrorE3Err(_try_err);
    }
    if (result.$tag === 1) {
      const _Ok = result;
      const _item = _Ok._0;
      return _item;
    } else {
      return undefined;
    }
  }
}
function _M0FP46mizchi3bit1x3hub13commit__notes(store, objects, refs, message, timestamp) {
  const tree_entries = [];
  const _bind = _M0MPB3Map9to__arrayGsRP36mizchi3bit6object8ObjectIdE(store.entries);
  const _bind$2 = _bind.length;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind$2) {
      const item = _bind[_];
      const _name = item._0;
      const _blob_id = item._1;
      _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(tree_entries, _M0MP36mizchi3bit6object9TreeEntry3new("100644", _name, _blob_id));
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  _M0MPC15array5Array8sort__byGRP46mizchi3bit1x3hub12IssueCommentE(tree_entries, (a, b) => _M0IPC16string6StringPB7Compare7compare(a.name, b.name));
  const tree_bytes = _M0FP36mizchi3bit6object15serialize__tree(tree_entries);
  const _bind$3 = objects.method_table.method_1(objects.self, 1, tree_bytes);
  let tree_id;
  if (_bind$3.$tag === 1) {
    const _ok = _bind$3;
    tree_id = _ok._0;
  } else {
    return _bind$3;
  }
  const _bind$4 = store.head;
  let parents;
  if (_bind$4 === undefined) {
    parents = [];
  } else {
    const _Some = _bind$4;
    const _p = _Some;
    parents = [_p];
  }
  const commit = _M0MP36mizchi3bit6object6Commit11new_2einner(tree_id, parents, "Hub <hub@local>", timestamp, "+0000", "Hub <hub@local>", timestamp, "+0000", `${message}\n`, "UTF-8", false);
  const commit_bytes = _M0FP36mizchi3bit6object26serialize__commit__content(commit);
  const _bind$5 = objects.method_table.method_1(objects.self, 2, commit_bytes);
  let commit_id;
  if (_bind$5.$tag === 1) {
    const _ok = _bind$5;
    commit_id = _ok._0;
  } else {
    return _bind$5;
  }
  store.head = commit_id;
  const _bind$6 = refs.method_table.method_1(refs.self, _M0FP46mizchi3bit1x3hub15hub__notes__ref, commit_id);
  if (_bind$6.$tag === 1) {
    const _ok = _bind$6;
    _ok._0;
  } else {
    return _bind$6;
  }
  return new _M0DTPC16result6ResultGRP36mizchi3bit6object8ObjectIdRP36mizchi3bit6object8GitErrorE2Ok(commit_id);
}
function _M0FP46mizchi3bit1x3hub36ensure__signature__ready__for__write(store) {
  if (store.require_signed) {
    const _bind = store.signing_key;
    if (_bind === undefined) {
      return new _M0DTPC16result6ResultGuRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject("Hub signing is required but signing key is not configured"));
    } else {
      return new _M0DTPC16result6ResultGuRP36mizchi3bit6object8GitErrorE2Ok(undefined);
    }
  } else {
    return new _M0DTPC16result6ResultGuRP36mizchi3bit6object8GitErrorE2Ok(undefined);
  }
}
function _M0FP46mizchi3bit1x3hub16increment__clock(clock, node) {
  const _p = _M0MPB3Map3getGslE(clock, node);
  const _p$2 = $0L;
  let current;
  if (_p === undefined) {
    current = _p$2;
  } else {
    const _p$3 = _p;
    current = _p$3;
  }
  _M0MPB3Map3setGslE(clock, node, _M0IPC15int645Int64PB3Add3add(current, $1L));
  return clock;
}
function _M0FP46mizchi3bit1x3hub12sign__record(record, signing_key) {
  const signature = _M0FP46mizchi3bit1x3hub26compute__record__signature(record, signing_key);
  return _M0MP46mizchi3bit1x3hub9HubRecord11new_2einner(record.key, record.kind, record.payload, record.node, record.timestamp, record.clock, record.deleted, record.version, signature);
}
function _M0MP46mizchi3bit1x3hub9HubRecord9serialize(self) {
  return _M0FP46mizchi3bit1x3hub22serialize__hub__record(self, self.signature);
}
function _M0MP46mizchi3bit1x3hub8HubStore11put__record(self, objects, refs, clock, key, kind, payload, node) {
  const _bind = _M0FP46mizchi3bit1x3hub36ensure__signature__ready__for__write(self);
  if (_bind.$tag === 1) {
    const _ok = _bind;
    _ok._0;
  } else {
    return _bind;
  }
  const timestamp = clock.method_table.method_0(clock.self);
  const existing = _M0MP46mizchi3bit1x3hub8HubStore11get__record(self, objects, key);
  let base_clock;
  if (existing === undefined) {
    const _bind$2 = [];
    base_clock = _M0MPB3Map11from__arrayGslE(new _M0TPB9ArrayViewGUslEE(_bind$2, 0, 0));
  } else {
    const _Some = existing;
    const _r = _Some;
    base_clock = _r.clock;
  }
  const next_clock = _M0FP46mizchi3bit1x3hub16increment__clock(base_clock, node);
  const unsigned_record = _M0MP46mizchi3bit1x3hub9HubRecord3new(key, kind, payload, node, timestamp, next_clock, _M0FP46mizchi3bit1x3hub27put__record_2econstr_2f4145, undefined, _M0DTPC16option6OptionGOsE4None__);
  const _bind$2 = self.signing_key;
  let record;
  if (_bind$2 === undefined) {
    record = unsigned_record;
  } else {
    const _Some = _bind$2;
    const _sign_key = _Some;
    record = _M0FP46mizchi3bit1x3hub12sign__record(unsigned_record, _sign_key);
  }
  const target_id = _M0FP46mizchi3bit1x3hub19key__to__target__id(key);
  const key_bytes = _M0FPC28encoding4utf814encode_2einner(new _M0TPC16string10StringView(key, 0, key.length), false);
  const _bind$3 = objects.method_table.method_1(objects.self, 0, key_bytes);
  if (_bind$3.$tag === 1) {
    const _ok = _bind$3;
    _ok._0;
  } else {
    return _bind$3;
  }
  const record_text = _M0MP46mizchi3bit1x3hub9HubRecord9serialize(record);
  const record_bytes = _M0FPC28encoding4utf814encode_2einner(new _M0TPC16string10StringView(record_text, 0, record_text.length), false);
  const _bind$4 = objects.method_table.method_1(objects.self, 0, record_bytes);
  let record_blob_id;
  if (_bind$4.$tag === 1) {
    const _ok = _bind$4;
    record_blob_id = _ok._0;
  } else {
    return _bind$4;
  }
  _M0MPB3Map3setGsRP36mizchi3bit6object8ObjectIdE(self.entries, _M0MP36mizchi3bit6object8ObjectId7to__hex(target_id), record_blob_id);
  const _bind$5 = _M0FP46mizchi3bit1x3hub13commit__notes(self, objects, refs, `Update ${kind}`, timestamp);
  if (_bind$5.$tag === 1) {
    const _ok = _bind$5;
    _ok._0;
  } else {
    return _bind$5;
  }
  return new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub9HubRecordRP36mizchi3bit6object8GitErrorE2Ok(record);
}
function _M0MP46mizchi3bit1x3hub8HubStore21list__records_2einner(self, objects, prefix, include_deleted) {
  const result = [];
  const _bind = _M0MPB3Map9to__arrayGsRP36mizchi3bit6object8ObjectIdE(self.entries);
  const _bind$2 = _bind.length;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind$2) {
      const item = _bind[_];
      _L: {
        const _blob_id = item._1;
        let obj;
        let _try_err;
        _L$2: {
          _L$3: {
            const _bind$3 = objects.method_table.method_0(objects.self, _blob_id);
            if (_bind$3.$tag === 1) {
              const _ok = _bind$3;
              obj = _ok._0;
            } else {
              const _err = _bind$3;
              _try_err = _err._0;
              break _L$3;
            }
            break _L$2;
          }
          obj = undefined;
        }
        if (obj === undefined) {
        } else {
          const _Some = obj;
          const _blob_obj = _Some;
          const _bind$3 = _blob_obj.data;
          const text = _M0FPC28encoding4utf821decode__lossy_2einner(_M0MPC15bytes5Bytes12view_2einner(_bind$3, 0, _bind$3.length), false);
          const record = _M0FP46mizchi3bit1x3hub18parse__hub__record(text);
          if (!_M0FP46mizchi3bit1x3hub26verify__record__by__policy(self, record)) {
            break _L;
          }
          if (!_M0MPC16string6String11has__prefix(record.key, new _M0TPC16string10StringView(prefix, 0, prefix.length))) {
            break _L;
          }
          if (!include_deleted && record.deleted) {
            break _L;
          }
          _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(result, record);
        }
        break _L;
      }
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return result;
}
function _M0FP46mizchi3bit1x3hub13include__kind(item_kind, kind) {
  if (kind === undefined) {
    return true;
  } else {
    const _Some = kind;
    const _value = _Some;
    return _M0IP46mizchi3bit1x3hub12WorkItemKindPB2Eq5equal(item_kind, _value);
  }
}
function _M0FP46mizchi3bit1x3hub14include__state(item_state, state) {
  if (state === undefined) {
    return true;
  } else {
    const _Some = state;
    const _value = _Some;
    return _M0IP46mizchi3bit1x3hub13WorkItemStatePB2Eq5equal(item_state, _value);
  }
}
function _M0MP46mizchi3bit1x3hub3Hub25list__work__items_2einner(self, objects, state, kind) {
  const result = [];
  const records = _M0MP46mizchi3bit1x3hub8HubStore21list__records_2einner(self.store, objects, _M0FP46mizchi3bit1x3hub31work__item__meta__prefix__value, false);
  const _bind = records.length;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind) {
      const record = records[_];
      _L: {
        if (!_M0MPC16string6String11has__suffix(record.key, new _M0TPC16string10StringView(_M0MP46mizchi3bit1x3hub3Hub25list__work__items_2einnerN7_2abindS2597, 0, _M0MP46mizchi3bit1x3hub3Hub25list__work__items_2einnerN7_2abindS2597.length))) {
          break _L;
        }
        const _p = record.kind;
        if (!(_p === _M0FP46mizchi3bit1x3hub42canonical__work__item__record__kind__value)) {
          break _L;
        }
        let parsed;
        let _try_err;
        _L$2: {
          _L$3: {
            const _bind$2 = _M0FP46mizchi3bit1x3hub17parse__work__item(record.payload);
            let _tmp$2;
            if (_bind$2.$tag === 1) {
              const _ok = _bind$2;
              _tmp$2 = _ok._0;
            } else {
              const _err = _bind$2;
              _try_err = _err._0;
              break _L$3;
            }
            parsed = new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub8WorkItemRP46mizchi3bit1x3hub7PrErrorE2Ok(_tmp$2);
            break _L$2;
          }
          parsed = new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub8WorkItemRP46mizchi3bit1x3hub7PrErrorE3Err(_try_err);
        }
        if (parsed.$tag === 1) {
          const _Ok = parsed;
          const _item = _Ok._0;
          const _p$2 = _item.patch;
          if (!_M0FP46mizchi3bit1x3hub13include__kind(_p$2 === undefined ? 0 : 1, kind)) {
            break _L;
          }
          if (!_M0FP46mizchi3bit1x3hub14include__state(_item.state, state)) {
            break _L;
          }
          _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(result, _item);
        } else {
          break _L;
        }
        break _L;
      }
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  _M0MPC15array5Array8sort__byGRP46mizchi3bit1x3hub12IssueCommentE(result, (a, b) => _M0IP016_24default__implPB7Compare6op__ltGlE(a.created_at, b.created_at) ? -1 : _M0IP016_24default__implPB7Compare6op__gtGlE(a.created_at, b.created_at) ? 1 : 0);
  return result;
}
function _M0MP46mizchi3bit1x3hub13WorkItemState10to__string(self) {
  switch (self) {
    case 0: {
      return "open";
    }
    case 1: {
      return "merged";
    }
    default: {
      return "closed";
    }
  }
}
function _M0MP46mizchi3bit1x3hub10IssueState21to__work__item__state(self) {
  if (self === 0) {
    return 0;
  } else {
    return 2;
  }
}
function _M0MP46mizchi3bit1x3hub13WorkItemState16to__issue__state(self) {
  switch (self) {
    case 0: {
      return _M0FP46mizchi3bit1x3hub32to__issue__state_2econstr_2f4222;
    }
    case 2: {
      return _M0FP46mizchi3bit1x3hub32to__issue__state_2econstr_2f4223;
    }
    default: {
      return undefined;
    }
  }
}
function _M0MP46mizchi3bit1x3hub5Issue11new_2einner(id, title, body, author, created_at, updated_at, state, labels, assignees, linked_prs, linked_issues, parent_id) {
  return new _M0TP46mizchi3bit1x3hub5Issue(id, title, body, author, created_at, updated_at, state, labels, assignees, linked_prs, linked_issues, parent_id);
}
function _M0MP46mizchi3bit1x3hub5Issue3new(id, title, body, author, created_at, updated_at, state, labels$46$opt, assignees$46$opt, linked_prs$46$opt, linked_issues$46$opt, parent_id$46$opt) {
  let labels;
  if (labels$46$opt.$tag === 1) {
    const _Some = labels$46$opt;
    labels = _Some._0;
  } else {
    labels = [];
  }
  let assignees;
  if (assignees$46$opt.$tag === 1) {
    const _Some = assignees$46$opt;
    assignees = _Some._0;
  } else {
    assignees = [];
  }
  let linked_prs;
  if (linked_prs$46$opt.$tag === 1) {
    const _Some = linked_prs$46$opt;
    linked_prs = _Some._0;
  } else {
    linked_prs = [];
  }
  let linked_issues;
  if (linked_issues$46$opt.$tag === 1) {
    const _Some = linked_issues$46$opt;
    linked_issues = _Some._0;
  } else {
    linked_issues = [];
  }
  let parent_id;
  if (parent_id$46$opt.$tag === 1) {
    const _Some = parent_id$46$opt;
    parent_id = _Some._0;
  } else {
    parent_id = undefined;
  }
  return _M0MP46mizchi3bit1x3hub5Issue11new_2einner(id, title, body, author, created_at, updated_at, state, labels, assignees, linked_prs, linked_issues, parent_id);
}
function _M0MP46mizchi3bit1x3hub8WorkItem9to__issue(self) {
  const _bind = self.patch;
  if (_bind === undefined) {
    const _bind$2 = _M0MP46mizchi3bit1x3hub13WorkItemState16to__issue__state(self.state);
    if (_bind$2 === undefined) {
      return undefined;
    } else {
      const _Some = _bind$2;
      const _issue_state = _Some;
      return _M0MP46mizchi3bit1x3hub5Issue11new_2einner(self.id, self.title, self.body, self.author, self.created_at, self.updated_at, _issue_state, self.labels, self.assignees, self.linked_prs, self.linked_issues, self.parent_id);
    }
  } else {
    return undefined;
  }
}
function _M0MP46mizchi3bit1x3hub5Issue14to__work__item(self) {
  return _M0MP46mizchi3bit1x3hub8WorkItem3new(self.id, self.title, self.body, self.author, self.created_at, self.updated_at, _M0MP46mizchi3bit1x3hub10IssueState21to__work__item__state(self.state), new _M0DTPC16option6OptionGRPB5ArrayGsEE4Some(self.labels), new _M0DTPC16option6OptionGRPB5ArrayGsEE4Some(self.assignees), new _M0DTPC16option6OptionGRPB5ArrayGsEE4Some(self.linked_prs), new _M0DTPC16option6OptionGRPB5ArrayGsEE4Some(self.linked_issues), _M0DTPC16option6OptionGORP46mizchi3bit1x3hub13WorkItemPatchE4None__, new _M0DTPC16option6OptionGOsE4Some(self.parent_id));
}
function _M0MP46mizchi3bit1x3hub12IssueComment11new_2einner(id, issue_id, author, body, created_at, reply_to) {
  return new _M0TP46mizchi3bit1x3hub12IssueComment(id, issue_id, author, body, created_at, reply_to);
}
function _M0MP46mizchi3bit1x3hub8HubStore12load_2einner(objects, refs, node_id, signing_key, require_signed) {
  const _bind = refs.method_table.method_0(refs.self, _M0FP46mizchi3bit1x3hub15hub__notes__ref);
  let commit;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    commit = _ok._0;
  } else {
    return _bind;
  }
  const _bind$2 = [];
  const entries = _M0MPB3Map11from__arrayGsRP36mizchi3bit6object8ObjectIdE(new _M0TPB9ArrayViewGUsRP36mizchi3bit6object8ObjectIdEE(_bind$2, 0, 0));
  let head;
  if (commit === undefined) {
    head = undefined;
  } else {
    const _Some = commit;
    const _cid = _Some;
    const _bind$3 = objects.method_table.method_0(objects.self, _cid);
    let obj;
    if (_bind$3.$tag === 1) {
      const _ok = _bind$3;
      obj = _ok._0;
    } else {
      return _bind$3;
    }
    if (obj === undefined) {
      head = undefined;
    } else {
      const _Some$2 = obj;
      const _commit_obj = _Some$2;
      const _bind$4 = _M0FP36mizchi3bit4repo13parse__commit(_commit_obj.data);
      let info;
      if (_bind$4.$tag === 1) {
        const _ok = _bind$4;
        info = _ok._0;
      } else {
        return _bind$4;
      }
      const _bind$5 = objects.method_table.method_0(objects.self, info.tree);
      let tree_obj;
      if (_bind$5.$tag === 1) {
        const _ok = _bind$5;
        tree_obj = _ok._0;
      } else {
        return _bind$5;
      }
      if (tree_obj === undefined) {
        head = undefined;
      } else {
        const _Some$3 = tree_obj;
        const _tobj = _Some$3;
        const _bind$6 = _M0FP36mizchi3bit4repo11parse__tree(_tobj.data);
        let tree_entries;
        if (_bind$6.$tag === 1) {
          const _ok = _bind$6;
          tree_entries = _ok._0;
        } else {
          return _bind$6;
        }
        const _bind$7 = tree_entries.length;
        let _tmp = 0;
        while (true) {
          const _ = _tmp;
          if (_ < _bind$7) {
            const entry = tree_entries[_];
            _M0MPB3Map3setGsRP36mizchi3bit6object8ObjectIdE(entries, entry.name, entry.id);
            _tmp = _ + 1 | 0;
            continue;
          } else {
            break;
          }
        }
        head = _cid;
      }
    }
  }
  return new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub8HubStoreRP36mizchi3bit6object8GitErrorE2Ok(new _M0TP46mizchi3bit1x3hub8HubStore(node_id, signing_key, require_signed, entries, head));
}
function _M0FP46mizchi3bit1x3hub19issue__comment__key(issue_id, comment_id) {
  return `hub/issue/${issue_id}/comment/${comment_id}`;
}
function _M0FP46mizchi3bit1x3hub10short__hex(hex, n) {
  return hex.length <= n ? hex : hex.substring(0, n);
}
function _M0FP46mizchi3bit1x3hub14short__hex__id(hex, n) {
  return hex.length <= n ? hex : hex.substring(0, n);
}
function _M0FP46mizchi3bit1x3hub20generate__entity__id(kind, author, timestamp, seed) {
  const base = `${kind}\n${author}\n${_M0MPC15int645Int6418to__string_2einner(timestamp, 10)}\n${seed}`;
  const _bind = _M0FP36mizchi3bit6object20create__blob__string(base);
  const _id = _bind._0;
  return _M0FP46mizchi3bit1x3hub14short__hex__id(_M0MP36mizchi3bit6object8ObjectId7to__hex(_id), 8);
}
function _M0MP46mizchi3bit1x3hub3Hub12load_2einner(objects, refs, node_id, signing_key, require_signed) {
  const _bind = _M0MP46mizchi3bit1x3hub8HubStore12load_2einner(objects, refs, node_id, signing_key, require_signed);
  let store;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    store = _ok._0;
  } else {
    return _bind;
  }
  return new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub3HubRP36mizchi3bit6object8GitErrorE2Ok(new _M0TP46mizchi3bit1x3hub3Hub(store));
}
function _M0MP46mizchi3bit1x3hub3Hub4load(objects, refs, node_id$46$opt, signing_key$46$opt, require_signed$46$opt) {
  let node_id;
  if (node_id$46$opt === undefined) {
    node_id = "local";
  } else {
    const _Some = node_id$46$opt;
    node_id = _Some;
  }
  let signing_key;
  if (signing_key$46$opt.$tag === 1) {
    const _Some = signing_key$46$opt;
    signing_key = _Some._0;
  } else {
    signing_key = undefined;
  }
  const require_signed = require_signed$46$opt === -1 ? false : require_signed$46$opt;
  return _M0MP46mizchi3bit1x3hub3Hub12load_2einner(objects, refs, node_id, signing_key, require_signed);
}
function _M0MP46mizchi3bit1x3hub8WorkItem9serialize(self) {
  const sb = _M0MPB13StringBuilder11new_2einner(0);
  _M0IPB13StringBuilderPB6Logger13write__string(sb, "work-item ");
  _M0IPB13StringBuilderPB6Logger13write__string(sb, self.id);
  _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
  _M0IPB13StringBuilderPB6Logger13write__string(sb, "title ");
  _M0IPB13StringBuilderPB6Logger13write__string(sb, self.title);
  _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
  _M0IPB13StringBuilderPB6Logger13write__string(sb, "author ");
  _M0IPB13StringBuilderPB6Logger13write__string(sb, self.author);
  _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
  _M0IPB13StringBuilderPB6Logger13write__string(sb, "created ");
  _M0IPB13StringBuilderPB6Logger13write__string(sb, _M0MPC15int645Int6418to__string_2einner(self.created_at, 10));
  _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
  _M0IPB13StringBuilderPB6Logger13write__string(sb, "updated ");
  _M0IPB13StringBuilderPB6Logger13write__string(sb, _M0MPC15int645Int6418to__string_2einner(self.updated_at, 10));
  _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
  _M0IPB13StringBuilderPB6Logger13write__string(sb, "state ");
  _M0IPB13StringBuilderPB6Logger13write__string(sb, _M0MP46mizchi3bit1x3hub13WorkItemState10to__string(self.state));
  _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
  const _bind = self.labels;
  const _bind$2 = _bind.length;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind$2) {
      const label = _bind[_];
      _M0IPB13StringBuilderPB6Logger13write__string(sb, "label ");
      _M0IPB13StringBuilderPB6Logger13write__string(sb, label);
      _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const _bind$3 = self.assignees;
  const _bind$4 = _bind$3.length;
  let _tmp$2 = 0;
  while (true) {
    const _ = _tmp$2;
    if (_ < _bind$4) {
      const assignee = _bind$3[_];
      _M0IPB13StringBuilderPB6Logger13write__string(sb, "assignee ");
      _M0IPB13StringBuilderPB6Logger13write__string(sb, assignee);
      _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
      _tmp$2 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const _bind$5 = self.linked_prs;
  const _bind$6 = _bind$5.length;
  let _tmp$3 = 0;
  while (true) {
    const _ = _tmp$3;
    if (_ < _bind$6) {
      const pr_id = _bind$5[_];
      _M0IPB13StringBuilderPB6Logger13write__string(sb, "linked-pr ");
      _M0IPB13StringBuilderPB6Logger13write__string(sb, pr_id);
      _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
      _tmp$3 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const _bind$7 = self.linked_issues;
  const _bind$8 = _bind$7.length;
  let _tmp$4 = 0;
  while (true) {
    const _ = _tmp$4;
    if (_ < _bind$8) {
      const issue_ref = _bind$7[_];
      _M0IPB13StringBuilderPB6Logger13write__string(sb, "linked-issue ");
      _M0IPB13StringBuilderPB6Logger13write__string(sb, issue_ref);
      _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
      _tmp$4 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const _bind$9 = self.parent_id;
  if (_bind$9 === undefined) {
  } else {
    const _Some = _bind$9;
    const _pid = _Some;
    _M0IPB13StringBuilderPB6Logger13write__string(sb, "parent ");
    _M0IPB13StringBuilderPB6Logger13write__string(sb, _pid);
    _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
  }
  const _bind$10 = self.patch;
  if (_bind$10 === undefined) {
  } else {
    const _Some = _bind$10;
    const _patch = _Some;
    _M0IPB13StringBuilderPB6Logger13write__string(sb, "source ");
    _M0IPB13StringBuilderPB6Logger13write__string(sb, _patch.source_branch);
    _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
    const _bind$11 = _patch.source_repo;
    if (_bind$11 === undefined) {
    } else {
      const _Some$2 = _bind$11;
      const _repo = _Some$2;
      _M0IPB13StringBuilderPB6Logger13write__string(sb, "source-repo ");
      _M0IPB13StringBuilderPB6Logger13write__string(sb, _repo);
      _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
    }
    const _bind$12 = _patch.source_ref;
    if (_bind$12 === undefined) {
    } else {
      const _Some$2 = _bind$12;
      const _source_ref = _Some$2;
      _M0IPB13StringBuilderPB6Logger13write__string(sb, "source-ref ");
      _M0IPB13StringBuilderPB6Logger13write__string(sb, _source_ref);
      _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
    }
    _M0IPB13StringBuilderPB6Logger13write__string(sb, "source-commit ");
    _M0IPB13StringBuilderPB6Logger13write__string(sb, _M0MP36mizchi3bit6object8ObjectId7to__hex(_patch.source_commit));
    _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
    _M0IPB13StringBuilderPB6Logger13write__string(sb, "target ");
    _M0IPB13StringBuilderPB6Logger13write__string(sb, _patch.target_branch);
    _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
    _M0IPB13StringBuilderPB6Logger13write__string(sb, "target-commit ");
    _M0IPB13StringBuilderPB6Logger13write__string(sb, _M0MP36mizchi3bit6object8ObjectId7to__hex(_patch.target_commit));
    _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
    const _bind$13 = _patch.closes_issues;
    const _bind$14 = _bind$13.length;
    let _tmp$5 = 0;
    while (true) {
      const _ = _tmp$5;
      if (_ < _bind$14) {
        const issue_id = _bind$13[_];
        _M0IPB13StringBuilderPB6Logger13write__string(sb, "closes ");
        _M0IPB13StringBuilderPB6Logger13write__string(sb, issue_id);
        _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
        _tmp$5 = _ + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    const _bind$15 = _patch.merge_commit;
    if (_bind$15 === undefined) {
    } else {
      const _Some$2 = _bind$15;
      const _mc = _Some$2;
      _M0IPB13StringBuilderPB6Logger13write__string(sb, "merge-commit ");
      _M0IPB13StringBuilderPB6Logger13write__string(sb, _M0MP36mizchi3bit6object8ObjectId7to__hex(_mc));
      _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
    }
  }
  _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
  _M0IPB13StringBuilderPB6Logger13write__string(sb, self.body);
  return sb.val;
}
function _M0FP46mizchi3bit1x3hub19hub__make__host__fs(host_id) {
  return new _M0TP46mizchi3bit1x3hub11HubJsHostFs(host_id);
}
function _M0FP46mizchi3bit1x3hub18bytes__from__array(arr) {
  return _M0MPC15bytes5Bytes10from__iter(_M0MPC15array5Array4iterGyE(arr));
}
function _M0IP46mizchi3bit1x3hub11HubJsHostFsP36mizchi3bit5types10FileSystem8mkdir__p(self, path) {
  const _bind = _M0FP46mizchi3bit1x3hub23hub__js__host__mkdir__p(self.host_id, path);
  if (_bind === undefined) {
    return new _M0DTPC16result6ResultGuRP36mizchi3bit6object8GitErrorE2Ok(undefined);
  } else {
    const _Some = _bind;
    const _e = _Some;
    return new _M0DTPC16result6ResultGuRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error42mizchi_2fbit_2fobject_2eGitError_2eIoError(_e));
  }
}
function _M0IP46mizchi3bit1x3hub11HubJsHostFsP36mizchi3bit5types10FileSystem11write__file(self, path, content) {
  const arr = _M0MPC15array5Array11new_2einnerGyE(content.length);
  const _bind = content.length;
  let _tmp = 0;
  while (true) {
    const i = _tmp;
    if (i < _bind) {
      $bound_check(content, i);
      _M0MPC15array5Array4pushGyE(arr, content[i]);
      _tmp = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const _bind$2 = _M0FP46mizchi3bit1x3hub26hub__js__host__write__file(self.host_id, path, arr);
  if (_bind$2 === undefined) {
    return new _M0DTPC16result6ResultGuRP36mizchi3bit6object8GitErrorE2Ok(undefined);
  } else {
    const _Some = _bind$2;
    const _e = _Some;
    return new _M0DTPC16result6ResultGuRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error42mizchi_2fbit_2fobject_2eGitError_2eIoError(_e));
  }
}
function _M0IP46mizchi3bit1x3hub11HubJsHostFsP36mizchi3bit5types10FileSystem13write__string(self, path, content) {
  const _bind = _M0FP46mizchi3bit1x3hub28hub__js__host__write__string(self.host_id, path, content);
  if (_bind === undefined) {
    return new _M0DTPC16result6ResultGuRP36mizchi3bit6object8GitErrorE2Ok(undefined);
  } else {
    const _Some = _bind;
    const _e = _Some;
    return new _M0DTPC16result6ResultGuRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error42mizchi_2fbit_2fobject_2eGitError_2eIoError(_e));
  }
}
function _M0IP46mizchi3bit1x3hub11HubJsHostFsP36mizchi3bit5types10FileSystem12remove__file(_self, _path) {
  return new _M0DTPC16result6ResultGuRP36mizchi3bit6object8GitErrorE2Ok(undefined);
}
function _M0IP46mizchi3bit1x3hub11HubJsHostFsP36mizchi3bit5types10FileSystem11remove__dir(_self, _path) {
  return new _M0DTPC16result6ResultGuRP36mizchi3bit6object8GitErrorE2Ok(undefined);
}
function _M0IP46mizchi3bit1x3hub11HubJsHostFsP36mizchi3bit5types14RepoFileSystem10read__file(self, path) {
  const _bind = _M0FP46mizchi3bit1x3hub25hub__js__host__read__file(self.host_id, path);
  if (_bind.$tag === 1) {
    const _Some = _bind;
    const _arr = _Some._0;
    return new _M0DTPC16result6ResultGzRP36mizchi3bit6object8GitErrorE2Ok(_M0FP46mizchi3bit1x3hub18bytes__from__array(_arr));
  } else {
    return new _M0DTPC16result6ResultGzRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error42mizchi_2fbit_2fobject_2eGitError_2eIoError(_M0FP46mizchi3bit1x3hub26hub__js__host__last__error()));
  }
}
function _M0IP46mizchi3bit1x3hub11HubJsHostFsP36mizchi3bit5types14RepoFileSystem7readdir(self, path) {
  const _bind = _M0FP46mizchi3bit1x3hub22hub__js__host__readdir(self.host_id, path);
  if (_bind.$tag === 1) {
    const _Some = _bind;
    const _arr = _Some._0;
    return new _M0DTPC16result6ResultGRPB5ArrayGsERP36mizchi3bit6object8GitErrorE2Ok(_arr);
  } else {
    return new _M0DTPC16result6ResultGRPB5ArrayGsERP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error42mizchi_2fbit_2fobject_2eGitError_2eIoError(_M0FP46mizchi3bit1x3hub26hub__js__host__last__error()));
  }
}
function _M0IP46mizchi3bit1x3hub11HubJsHostFsP36mizchi3bit5types14RepoFileSystem7is__dir(self, path) {
  return _M0FP46mizchi3bit1x3hub22hub__js__host__is__dir(self.host_id, path);
}
function _M0IP46mizchi3bit1x3hub11HubJsHostFsP36mizchi3bit5types14RepoFileSystem8is__file(self, path) {
  return _M0FP46mizchi3bit1x3hub23hub__js__host__is__file(self.host_id, path);
}
function _M0FP46mizchi3bit1x3hub16hub__wrap__errorGuE(f) {
  let _try_err;
  _L: {
    const _bind = f();
    if (_bind.$tag === 1) {
      const _ok = _bind;
      _ok._0;
    } else {
      const _err = _bind;
      _try_err = _err._0;
      break _L;
    }
    return new _M0DTPC16result6ResultGusE2Ok(undefined);
  }
  switch (_try_err.$tag) {
    case 0: {
      const _IoError = _try_err;
      const _e = _IoError._0;
      return new _M0DTPC16result6ResultGusE3Err(_e);
    }
    case 4: {
      const _InvalidObject = _try_err;
      const _e$2 = _InvalidObject._0;
      return new _M0DTPC16result6ResultGusE3Err(_e$2);
    }
    case 3: {
      const _HashMismatch = _try_err;
      const _expected = _HashMismatch._0;
      const _actual = _HashMismatch._1;
      return new _M0DTPC16result6ResultGusE3Err(`hash mismatch: ${_expected} vs ${_actual}`);
    }
    case 2: {
      const _PackfileError = _try_err;
      const _e$3 = _PackfileError._0;
      return new _M0DTPC16result6ResultGusE3Err(`packfile error: ${_e$3}`);
    }
    default: {
      const _ProtocolError = _try_err;
      const _e$4 = _ProtocolError._0;
      return new _M0DTPC16result6ResultGusE3Err(`protocol error: ${_e$4}`);
    }
  }
}
function _M0FP46mizchi3bit1x3hub16hub__wrap__errorGRPB5ArrayGRP46mizchi3bit1x3hub5IssueEE(f) {
  let _try_err;
  _L: {
    const _bind = f();
    let _tmp;
    if (_bind.$tag === 1) {
      const _ok = _bind;
      _tmp = _ok._0;
    } else {
      const _err = _bind;
      _try_err = _err._0;
      break _L;
    }
    return new _M0DTPC16result6ResultGRPB5ArrayGRP46mizchi3bit1x3hub5IssueEsE2Ok(_tmp);
  }
  switch (_try_err.$tag) {
    case 0: {
      const _IoError = _try_err;
      const _e = _IoError._0;
      return new _M0DTPC16result6ResultGRPB5ArrayGRP46mizchi3bit1x3hub5IssueEsE3Err(_e);
    }
    case 4: {
      const _InvalidObject = _try_err;
      const _e$2 = _InvalidObject._0;
      return new _M0DTPC16result6ResultGRPB5ArrayGRP46mizchi3bit1x3hub5IssueEsE3Err(_e$2);
    }
    case 3: {
      const _HashMismatch = _try_err;
      const _expected = _HashMismatch._0;
      const _actual = _HashMismatch._1;
      return new _M0DTPC16result6ResultGRPB5ArrayGRP46mizchi3bit1x3hub5IssueEsE3Err(`hash mismatch: ${_expected} vs ${_actual}`);
    }
    case 2: {
      const _PackfileError = _try_err;
      const _e$3 = _PackfileError._0;
      return new _M0DTPC16result6ResultGRPB5ArrayGRP46mizchi3bit1x3hub5IssueEsE3Err(`packfile error: ${_e$3}`);
    }
    default: {
      const _ProtocolError = _try_err;
      const _e$4 = _ProtocolError._0;
      return new _M0DTPC16result6ResultGRPB5ArrayGRP46mizchi3bit1x3hub5IssueEsE3Err(`protocol error: ${_e$4}`);
    }
  }
}
function _M0FP46mizchi3bit1x3hub16hub__wrap__errorGRP46mizchi3bit1x3hub5IssueE(f) {
  let _try_err;
  _L: {
    const _bind = f();
    let _tmp;
    if (_bind.$tag === 1) {
      const _ok = _bind;
      _tmp = _ok._0;
    } else {
      const _err = _bind;
      _try_err = _err._0;
      break _L;
    }
    return new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub5IssuesE2Ok(_tmp);
  }
  switch (_try_err.$tag) {
    case 0: {
      const _IoError = _try_err;
      const _e = _IoError._0;
      return new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub5IssuesE3Err(_e);
    }
    case 4: {
      const _InvalidObject = _try_err;
      const _e$2 = _InvalidObject._0;
      return new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub5IssuesE3Err(_e$2);
    }
    case 3: {
      const _HashMismatch = _try_err;
      const _expected = _HashMismatch._0;
      const _actual = _HashMismatch._1;
      return new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub5IssuesE3Err(`hash mismatch: ${_expected} vs ${_actual}`);
    }
    case 2: {
      const _PackfileError = _try_err;
      const _e$3 = _PackfileError._0;
      return new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub5IssuesE3Err(`packfile error: ${_e$3}`);
    }
    default: {
      const _ProtocolError = _try_err;
      const _e$4 = _ProtocolError._0;
      return new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub5IssuesE3Err(`protocol error: ${_e$4}`);
    }
  }
}
function _M0IP46mizchi3bit1x3hub16HubJsObjectStoreP36mizchi3bit3lib11ObjectStore3get(self, id) {
  const _bind = _M0MP36mizchi3bit3lib8ObjectDb10load__lazy({ self: self.fs, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsHostFs_24as_24_40mizchi_2fbit_2ftypes_2eRepoFileSystem }, self.git_dir);
  let db;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    db = _ok._0;
  } else {
    return _bind;
  }
  return _M0MP36mizchi3bit3lib8ObjectDb3get(db, { self: self.fs, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsHostFs_24as_24_40mizchi_2fbit_2ftypes_2eRepoFileSystem }, id);
}
function _M0IP46mizchi3bit1x3hub16HubJsObjectStoreP36mizchi3bit3lib11ObjectStore3put(self, obj_type, content) {
  const _bind = _M0FP36mizchi3bit6object14create__object(obj_type, content);
  const _id = _bind._0;
  const _compressed = _bind._1;
  const hex = _M0MP36mizchi3bit6object8ObjectId7to__hex(_id);
  const dir = `${self.git_dir}/objects/${hex.substring(0, 2)}`;
  const path = `${dir}/${hex.substring(2, 40)}`;
  const _tmp = { self: self.fs, method_table: _M0FP080mizchi_2fbit_2fx_2fhub_2fHubJsHostFs_24as_24_40mizchi_2fbit_2ftypes_2eFileSystem };
  const _bind$2 = _tmp.method_table.method_0(_tmp.self, dir);
  if (_bind$2.$tag === 1) {
    const _ok = _bind$2;
    _ok._0;
  } else {
    return _bind$2;
  }
  const _tmp$2 = { self: self.fs, method_table: _M0FP080mizchi_2fbit_2fx_2fhub_2fHubJsHostFs_24as_24_40mizchi_2fbit_2ftypes_2eFileSystem };
  const _bind$3 = _tmp$2.method_table.method_1(_tmp$2.self, path, _compressed);
  if (_bind$3.$tag === 1) {
    const _ok = _bind$3;
    _ok._0;
  } else {
    return _bind$3;
  }
  return new _M0DTPC16result6ResultGRP36mizchi3bit6object8ObjectIdRP36mizchi3bit6object8GitErrorE2Ok(_id);
}
function _M0IP46mizchi3bit1x3hub16HubJsObjectStoreP36mizchi3bit3lib11ObjectStore3has(self, id) {
  const _bind = _M0MP36mizchi3bit3lib8ObjectDb10load__lazy({ self: self.fs, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsHostFs_24as_24_40mizchi_2fbit_2ftypes_2eRepoFileSystem }, self.git_dir);
  let db;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    db = _ok._0;
  } else {
    return _bind;
  }
  const _bind$2 = _M0MP36mizchi3bit3lib8ObjectDb3get(db, { self: self.fs, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsHostFs_24as_24_40mizchi_2fbit_2ftypes_2eRepoFileSystem }, id);
  let obj;
  if (_bind$2.$tag === 1) {
    const _ok = _bind$2;
    obj = _ok._0;
  } else {
    return _bind$2;
  }
  return new _M0DTPC16result6ResultGbRP36mizchi3bit6object8GitErrorE2Ok(!(obj === undefined));
}
function _M0IP46mizchi3bit1x3hub13HubJsRefStoreP36mizchi3bit3lib8RefStore7resolve(self, ref_name) {
  return _M0FP36mizchi3bit3lib12resolve__ref({ self: self.fs, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsHostFs_24as_24_40mizchi_2fbit_2ftypes_2eRepoFileSystem }, self.git_dir, ref_name);
}
function _M0FP46mizchi3bit1x3hub17hub__parent__path(path) {
  const _bind = _M0MPC16string6String9rev__find(path, new _M0TPC16string10StringView(_M0FP46mizchi3bit1x3hub17hub__parent__pathN7_2abindS3881, 0, _M0FP46mizchi3bit1x3hub17hub__parent__pathN7_2abindS3881.length));
  if (_bind === undefined) {
    return ".";
  } else {
    const _Some = _bind;
    const _x = _Some;
    if (_x === 0) {
      return "/";
    } else {
      return path.substring(0, _x);
    }
  }
}
function _M0IP46mizchi3bit1x3hub13HubJsRefStoreP36mizchi3bit3lib8RefStore6update(self, ref_name, id) {
  if (id === undefined) {
    return new _M0DTPC16result6ResultGuRP36mizchi3bit6object8GitErrorE2Ok(undefined);
  } else {
    const _Some = id;
    const _commit_id = _Some;
    const ref_path = `${self.git_dir}/${ref_name}`;
    const dir = _M0FP46mizchi3bit1x3hub17hub__parent__path(ref_path);
    const _tmp = { self: self.fs, method_table: _M0FP080mizchi_2fbit_2fx_2fhub_2fHubJsHostFs_24as_24_40mizchi_2fbit_2ftypes_2eFileSystem };
    const _bind = _tmp.method_table.method_0(_tmp.self, dir);
    if (_bind.$tag === 1) {
      const _ok = _bind;
      _ok._0;
    } else {
      return _bind;
    }
    const _tmp$2 = { self: self.fs, method_table: _M0FP080mizchi_2fbit_2fx_2fhub_2fHubJsHostFs_24as_24_40mizchi_2fbit_2ftypes_2eFileSystem };
    return _tmp$2.method_table.method_2(_tmp$2.self, ref_path, `${_M0MP36mizchi3bit6object8ObjectId7to__hex(_commit_id)}\n`);
  }
}
function _M0FP46mizchi3bit1x3hub18hub__collect__refs(fs, dir, prefix, filter, result) {
  let entries;
  let _try_err;
  _L: {
    _L$2: {
      const _tmp = { self: fs, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsHostFs_24as_24_40mizchi_2fbit_2ftypes_2eRepoFileSystem };
      const _bind = _tmp.method_table.method_1(_tmp.self, dir);
      if (_bind.$tag === 1) {
        const _ok = _bind;
        entries = _ok._0;
      } else {
        const _err = _bind;
        _try_err = _err._0;
        break _L$2;
      }
      break _L;
    }
    return undefined;
  }
  const _bind = entries.length;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind) {
      const entry = entries[_];
      const full = `${dir}/${entry}`;
      const ref_name = `${prefix}/${entry}`;
      const _tmp$2 = { self: fs, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsHostFs_24as_24_40mizchi_2fbit_2ftypes_2eRepoFileSystem };
      if (_tmp$2.method_table.method_2(_tmp$2.self, full)) {
        _M0FP46mizchi3bit1x3hub18hub__collect__refs(fs, full, ref_name, filter, result);
      } else {
        if (_M0MPC16string6String11has__prefix(ref_name, new _M0TPC16string10StringView(filter, 0, filter.length))) {
          _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(result, ref_name);
        }
      }
      _tmp = _ + 1 | 0;
      continue;
    } else {
      return;
    }
  }
}
function _M0IP46mizchi3bit1x3hub13HubJsRefStoreP36mizchi3bit3lib8RefStore4list(self, prefix) {
  const result = [];
  const refs_dir = `${self.git_dir}/refs`;
  _M0FP46mizchi3bit1x3hub18hub__collect__refs(self.fs, refs_dir, "refs", prefix, result);
  return new _M0DTPC16result6ResultGRPB5ArrayGsERP36mizchi3bit6object8GitErrorE2Ok(result);
}
function _M0IP46mizchi3bit1x3hub10HubJsClockP36mizchi3bit3lib5Clock3now(self) {
  return self.timestamp;
}
function _M0FP46mizchi3bit1x3hub22hub__resolve__git__dir(fs, root) {
  const git_path = `${root}/.git`;
  let _tmp;
  const _tmp$2 = { self: fs, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsHostFs_24as_24_40mizchi_2fbit_2ftypes_2eRepoFileSystem };
  if (_tmp$2.method_table.method_3(_tmp$2.self, git_path)) {
    _tmp = _M0FP36mizchi3bit3lib15resolve__gitdir({ self: fs, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsHostFs_24as_24_40mizchi_2fbit_2ftypes_2eRepoFileSystem }, git_path);
  } else {
    _tmp = git_path;
  }
  return new _M0DTPC16result6ResultGsRP36mizchi3bit6object8GitErrorE2Ok(_tmp);
}
function _M0FP46mizchi3bit1x3hub17hub__make__stores(host_id, root) {
  const fs = _M0FP46mizchi3bit1x3hub19hub__make__host__fs(host_id);
  const _bind = _M0FP46mizchi3bit1x3hub22hub__resolve__git__dir(fs, root);
  let git_dir;
  if (_bind.$tag === 1) {
    const _ok = _bind;
    git_dir = _ok._0;
  } else {
    return _bind;
  }
  const objects = new _M0TP46mizchi3bit1x3hub16HubJsObjectStore(fs, git_dir);
  const refs = new _M0TP46mizchi3bit1x3hub13HubJsRefStore(fs, git_dir);
  const now = _M0IPC15int645Int64PB3Div3div(_M0MPC16double6Double9to__int64(_M0FP46mizchi3bit1x3hub18hub__js__date__now()), $1000L);
  const clock = new _M0TP46mizchi3bit1x3hub10HubJsClock(now);
  return new _M0DTPC16result6ResultGURP46mizchi3bit1x3hub16HubJsObjectStoreRP46mizchi3bit1x3hub13HubJsRefStoreRP46mizchi3bit1x3hub10HubJsClockERP36mizchi3bit6object8GitErrorE2Ok({ _0: objects, _1: refs, _2: clock });
}
function _M0MP46mizchi3bit1x3hub3Hub12init_2einner(objects, refs, node_id, signing_key, require_signed) {
  return _M0MP46mizchi3bit1x3hub3Hub12load_2einner(objects, refs, node_id, signing_key, require_signed);
}
function _M0MP46mizchi3bit1x3hub3Hub4init(objects, refs, node_id$46$opt, signing_key$46$opt, require_signed$46$opt) {
  let node_id;
  if (node_id$46$opt === undefined) {
    node_id = "local";
  } else {
    const _Some = node_id$46$opt;
    node_id = _Some;
  }
  let signing_key;
  if (signing_key$46$opt.$tag === 1) {
    const _Some = signing_key$46$opt;
    signing_key = _Some._0;
  } else {
    signing_key = undefined;
  }
  const require_signed = require_signed$46$opt === -1 ? false : require_signed$46$opt;
  return _M0MP46mizchi3bit1x3hub3Hub12init_2einner(objects, refs, node_id, signing_key, require_signed);
}
function _M0FP46mizchi3bit1x3hub20js__hub__issue__init(host_id, root) {
  return _M0FP46mizchi3bit1x3hub16hub__wrap__errorGuE(() => {
    const _bind = _M0FP46mizchi3bit1x3hub17hub__make__stores(host_id, root);
    let _bind$2;
    if (_bind.$tag === 1) {
      const _ok = _bind;
      _bind$2 = _ok._0;
    } else {
      return _bind;
    }
    const _objects = _bind$2._0;
    const _refs = _bind$2._1;
    const _bind$3 = _M0MP46mizchi3bit1x3hub3Hub4init({ self: _objects, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsObjectStore_24as_24_40mizchi_2fbit_2flib_2eObjectStore }, { self: _refs, method_table: _M0FP078mizchi_2fbit_2fx_2fhub_2fHubJsRefStore_24as_24_40mizchi_2fbit_2flib_2eRefStore }, undefined, _M0DTPC16option6OptionGOsE4None__, -1);
    if (_bind$3.$tag === 1) {
      const _ok = _bind$3;
      _ok._0;
    } else {
      return _bind$3;
    }
    return new _M0DTPC16result6ResultGuRP36mizchi3bit6object8GitErrorE2Ok(undefined);
  });
}
function _M0MP46mizchi3bit1x3hub3Hub20list__issues_2einner(self, objects, state) {
  let item_state;
  if (state === undefined) {
    item_state = undefined;
  } else {
    const _Some = state;
    const _s = _Some;
    item_state = _M0MP46mizchi3bit1x3hub10IssueState21to__work__item__state(_s);
  }
  const items = _M0MP46mizchi3bit1x3hub3Hub25list__work__items_2einner(self, objects, item_state, _M0FP46mizchi3bit1x3hub36list__issues_2einner_2econstr_2f4572);
  const result = [];
  const _bind = items.length;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind) {
      const item = items[_];
      const _bind$2 = _M0MP46mizchi3bit1x3hub8WorkItem9to__issue(item);
      if (_bind$2 === undefined) {
      } else {
        const _Some = _bind$2;
        const _issue = _Some;
        _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(result, _issue);
      }
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return result;
}
function _M0FP46mizchi3bit1x3hub20js__hub__issue__list(host_id, root, state) {
  return _M0FP46mizchi3bit1x3hub16hub__wrap__errorGRPB5ArrayGRP46mizchi3bit1x3hub5IssueEE(() => {
    const _bind = _M0FP46mizchi3bit1x3hub17hub__make__stores(host_id, root);
    let _bind$2;
    if (_bind.$tag === 1) {
      const _ok = _bind;
      _bind$2 = _ok._0;
    } else {
      return _bind;
    }
    const _objects = _bind$2._0;
    const _refs = _bind$2._1;
    const _bind$3 = _M0MP46mizchi3bit1x3hub3Hub4load({ self: _objects, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsObjectStore_24as_24_40mizchi_2fbit_2flib_2eObjectStore }, { self: _refs, method_table: _M0FP078mizchi_2fbit_2fx_2fhub_2fHubJsRefStore_24as_24_40mizchi_2fbit_2flib_2eRefStore }, undefined, _M0DTPC16option6OptionGOsE4None__, -1);
    let hub;
    if (_bind$3.$tag === 1) {
      const _ok = _bind$3;
      hub = _ok._0;
    } else {
      return _bind$3;
    }
    let filter;
    switch (state) {
      case "open": {
        filter = _M0FP46mizchi3bit1x3hub36js__hub__issue__list_2econstr_2f4588;
        break;
      }
      case "closed": {
        filter = _M0FP46mizchi3bit1x3hub36js__hub__issue__list_2econstr_2f4589;
        break;
      }
      default: {
        filter = undefined;
      }
    }
    return new _M0DTPC16result6ResultGRPB5ArrayGRP46mizchi3bit1x3hub5IssueERP36mizchi3bit6object8GitErrorE2Ok(_M0MP46mizchi3bit1x3hub3Hub20list__issues_2einner(hub, { self: _objects, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsObjectStore_24as_24_40mizchi_2fbit_2flib_2eObjectStore }, filter));
  });
}
function _M0MP46mizchi3bit1x3hub3Hub10get__issue(self, objects, issue_id) {
  const work_item = _M0MP46mizchi3bit1x3hub3Hub15get__work__item(self, objects, issue_id);
  if (work_item === undefined) {
    return undefined;
  } else {
    const _Some = work_item;
    const _item = _Some;
    return _M0MP46mizchi3bit1x3hub8WorkItem9to__issue(_item);
  }
}
function _M0FP46mizchi3bit1x3hub19js__hub__issue__get(host_id, root, issue_id) {
  return _M0FP46mizchi3bit1x3hub16hub__wrap__errorGRPB5ArrayGRP46mizchi3bit1x3hub5IssueEE(() => {
    const _bind = _M0FP46mizchi3bit1x3hub17hub__make__stores(host_id, root);
    let _bind$2;
    if (_bind.$tag === 1) {
      const _ok = _bind;
      _bind$2 = _ok._0;
    } else {
      return _bind;
    }
    const _objects = _bind$2._0;
    const _refs = _bind$2._1;
    const _bind$3 = _M0MP46mizchi3bit1x3hub3Hub4load({ self: _objects, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsObjectStore_24as_24_40mizchi_2fbit_2flib_2eObjectStore }, { self: _refs, method_table: _M0FP078mizchi_2fbit_2fx_2fhub_2fHubJsRefStore_24as_24_40mizchi_2fbit_2flib_2eRefStore }, undefined, _M0DTPC16option6OptionGOsE4None__, -1);
    let hub;
    if (_bind$3.$tag === 1) {
      const _ok = _bind$3;
      hub = _ok._0;
    } else {
      return _bind$3;
    }
    return new _M0DTPC16result6ResultGORP46mizchi3bit1x3hub5IssueRP36mizchi3bit6object8GitErrorE2Ok(_M0MP46mizchi3bit1x3hub3Hub10get__issue(hub, { self: _objects, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsObjectStore_24as_24_40mizchi_2fbit_2flib_2eObjectStore }, issue_id));
  });
}
function _M0MP46mizchi3bit1x3hub3Hub21create__issue_2einner(self, objects, refs, clock, title, body, author, labels, assignees, parent_id) {
  const timestamp = clock.method_table.method_0(clock.self);
  const issue_id = _M0FP46mizchi3bit1x3hub20generate__entity__id("issue", author, timestamp, `${title}\n${body}`);
  const issue = _M0MP46mizchi3bit1x3hub5Issue3new(issue_id, title, body, author, timestamp, timestamp, 0, new _M0DTPC16option6OptionGRPB5ArrayGsEE4Some(labels), new _M0DTPC16option6OptionGRPB5ArrayGsEE4Some(assignees), _M0DTPC16option6OptionGRPB5ArrayGsEE4None__, _M0DTPC16option6OptionGRPB5ArrayGsEE4None__, new _M0DTPC16option6OptionGOsE4Some(parent_id));
  const _bind = _M0MP46mizchi3bit1x3hub8HubStore11put__record(self.store, objects, refs, clock, `${_M0FP46mizchi3bit1x3hub31work__item__meta__prefix__value}${issue_id}/meta`, _M0FP46mizchi3bit1x3hub42canonical__work__item__record__kind__value, _M0MP46mizchi3bit1x3hub8WorkItem9serialize(_M0MP46mizchi3bit1x3hub5Issue14to__work__item(issue)), author);
  if (_bind.$tag === 1) {
    const _ok = _bind;
    _ok._0;
  } else {
    return _bind;
  }
  return new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub5IssueRP36mizchi3bit6object8GitErrorE2Ok(issue);
}
function _M0MP46mizchi3bit1x3hub3Hub13create__issue(self, objects, refs, clock, title, body, author, labels$46$opt, assignees$46$opt, parent_id$46$opt) {
  let labels;
  if (labels$46$opt.$tag === 1) {
    const _Some = labels$46$opt;
    labels = _Some._0;
  } else {
    labels = [];
  }
  let assignees;
  if (assignees$46$opt.$tag === 1) {
    const _Some = assignees$46$opt;
    assignees = _Some._0;
  } else {
    assignees = [];
  }
  let parent_id;
  if (parent_id$46$opt.$tag === 1) {
    const _Some = parent_id$46$opt;
    parent_id = _Some._0;
  } else {
    parent_id = undefined;
  }
  return _M0MP46mizchi3bit1x3hub3Hub21create__issue_2einner(self, objects, refs, clock, title, body, author, labels, assignees, parent_id);
}
function _M0FP46mizchi3bit1x3hub22js__hub__issue__create(host_id, root, title, body, author, labels, parent_id) {
  return _M0FP46mizchi3bit1x3hub16hub__wrap__errorGRP46mizchi3bit1x3hub5IssueE(() => {
    const _bind = _M0FP46mizchi3bit1x3hub17hub__make__stores(host_id, root);
    let _bind$2;
    if (_bind.$tag === 1) {
      const _ok = _bind;
      _bind$2 = _ok._0;
    } else {
      return _bind;
    }
    const _objects = _bind$2._0;
    const _refs = _bind$2._1;
    const _clock = _bind$2._2;
    const _bind$3 = _M0MP46mizchi3bit1x3hub3Hub4load({ self: _objects, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsObjectStore_24as_24_40mizchi_2fbit_2flib_2eObjectStore }, { self: _refs, method_table: _M0FP078mizchi_2fbit_2fx_2fhub_2fHubJsRefStore_24as_24_40mizchi_2fbit_2flib_2eRefStore }, undefined, _M0DTPC16option6OptionGOsE4None__, -1);
    let hub;
    if (_bind$3.$tag === 1) {
      const _ok = _bind$3;
      hub = _ok._0;
    } else {
      return _bind$3;
    }
    const pid = parent_id.length > 0 ? parent_id : undefined;
    return _M0MP46mizchi3bit1x3hub3Hub13create__issue(hub, { self: _objects, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsObjectStore_24as_24_40mizchi_2fbit_2flib_2eObjectStore }, { self: _refs, method_table: _M0FP078mizchi_2fbit_2fx_2fhub_2fHubJsRefStore_24as_24_40mizchi_2fbit_2flib_2eRefStore }, { self: _clock, method_table: _M0FP072mizchi_2fbit_2fx_2fhub_2fHubJsClock_24as_24_40mizchi_2fbit_2flib_2eClock }, title, body, author, new _M0DTPC16option6OptionGRPB5ArrayGsEE4Some(labels), _M0DTPC16option6OptionGRPB5ArrayGsEE4None__, new _M0DTPC16option6OptionGOsE4Some(pid));
  });
}
function _M0MP46mizchi3bit1x3hub3Hub21update__issue_2einner(self, objects, refs, clock, issue_id, title, body, labels, assignees) {
  const issue = _M0MP46mizchi3bit1x3hub3Hub10get__issue(self, objects, issue_id);
  if (issue === undefined) {
    return new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub5IssueRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject(`Issue not found: ${issue_id}`));
  } else {
    const _Some = issue;
    const _existing = _Some;
    let new_title;
    if (title === undefined) {
      new_title = _existing.title;
    } else {
      const _Some$2 = title;
      new_title = _Some$2;
    }
    let new_body;
    if (body === undefined) {
      new_body = _existing.body;
    } else {
      const _Some$2 = body;
      new_body = _Some$2;
    }
    let new_labels;
    if (labels.$tag === 1) {
      const _Some$2 = labels;
      new_labels = _Some$2._0;
    } else {
      new_labels = _existing.labels;
    }
    let new_assignees;
    if (assignees.$tag === 1) {
      const _Some$2 = assignees;
      new_assignees = _Some$2._0;
    } else {
      new_assignees = _existing.assignees;
    }
    const updated = _M0MP46mizchi3bit1x3hub5Issue3new(_existing.id, new_title, new_body, _existing.author, _existing.created_at, clock.method_table.method_0(clock.self), _existing.state, new _M0DTPC16option6OptionGRPB5ArrayGsEE4Some(new_labels), new _M0DTPC16option6OptionGRPB5ArrayGsEE4Some(new_assignees), new _M0DTPC16option6OptionGRPB5ArrayGsEE4Some(_existing.linked_prs), _M0DTPC16option6OptionGRPB5ArrayGsEE4None__, new _M0DTPC16option6OptionGOsE4Some(_existing.parent_id));
    const _bind = _M0MP46mizchi3bit1x3hub8HubStore11put__record(self.store, objects, refs, clock, `${_M0FP46mizchi3bit1x3hub31work__item__meta__prefix__value}${issue_id}/meta`, _M0FP46mizchi3bit1x3hub42canonical__work__item__record__kind__value, _M0MP46mizchi3bit1x3hub8WorkItem9serialize(_M0MP46mizchi3bit1x3hub5Issue14to__work__item(updated)), _existing.author);
    if (_bind.$tag === 1) {
      const _ok = _bind;
      _ok._0;
    } else {
      return _bind;
    }
    return new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub5IssueRP36mizchi3bit6object8GitErrorE2Ok(updated);
  }
}
function _M0MP46mizchi3bit1x3hub3Hub13update__issue(self, objects, refs, clock, issue_id, title$46$opt, body$46$opt, labels$46$opt, assignees$46$opt) {
  let title;
  if (title$46$opt.$tag === 1) {
    const _Some = title$46$opt;
    title = _Some._0;
  } else {
    title = undefined;
  }
  let body;
  if (body$46$opt.$tag === 1) {
    const _Some = body$46$opt;
    body = _Some._0;
  } else {
    body = undefined;
  }
  let labels;
  if (labels$46$opt === undefined) {
    labels = _M0DTPC16option6OptionGRPB5ArrayGsEE4None__;
  } else {
    const _Some = labels$46$opt;
    labels = _Some;
  }
  let assignees;
  if (assignees$46$opt === undefined) {
    assignees = _M0DTPC16option6OptionGRPB5ArrayGsEE4None__;
  } else {
    const _Some = assignees$46$opt;
    assignees = _Some;
  }
  return _M0MP46mizchi3bit1x3hub3Hub21update__issue_2einner(self, objects, refs, clock, issue_id, title, body, labels, assignees);
}
function _M0FP46mizchi3bit1x3hub22js__hub__issue__update(host_id, root, issue_id, title, body, labels) {
  return _M0FP46mizchi3bit1x3hub16hub__wrap__errorGRP46mizchi3bit1x3hub5IssueE(() => {
    const _bind = _M0FP46mizchi3bit1x3hub17hub__make__stores(host_id, root);
    let _bind$2;
    if (_bind.$tag === 1) {
      const _ok = _bind;
      _bind$2 = _ok._0;
    } else {
      return _bind;
    }
    const _objects = _bind$2._0;
    const _refs = _bind$2._1;
    const _clock = _bind$2._2;
    const _bind$3 = _M0MP46mizchi3bit1x3hub3Hub4load({ self: _objects, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsObjectStore_24as_24_40mizchi_2fbit_2flib_2eObjectStore }, { self: _refs, method_table: _M0FP078mizchi_2fbit_2fx_2fhub_2fHubJsRefStore_24as_24_40mizchi_2fbit_2flib_2eRefStore }, undefined, _M0DTPC16option6OptionGOsE4None__, -1);
    let hub;
    if (_bind$3.$tag === 1) {
      const _ok = _bind$3;
      hub = _ok._0;
    } else {
      return _bind$3;
    }
    const t = title.length > 0 ? title : undefined;
    const b = body.length > 0 ? body : undefined;
    const l = labels.length > 0 ? new _M0DTPC16option6OptionGRPB5ArrayGsEE4Some(labels) : _M0DTPC16option6OptionGRPB5ArrayGsEE4None__;
    return _M0MP46mizchi3bit1x3hub3Hub13update__issue(hub, { self: _objects, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsObjectStore_24as_24_40mizchi_2fbit_2flib_2eObjectStore }, { self: _refs, method_table: _M0FP078mizchi_2fbit_2fx_2fhub_2fHubJsRefStore_24as_24_40mizchi_2fbit_2flib_2eRefStore }, { self: _clock, method_table: _M0FP072mizchi_2fbit_2fx_2fhub_2fHubJsClock_24as_24_40mizchi_2fbit_2flib_2eClock }, issue_id, new _M0DTPC16option6OptionGOsE4Some(t), new _M0DTPC16option6OptionGOsE4Some(b), l, undefined);
  });
}
function _M0MP46mizchi3bit1x3hub3Hub12close__issue(self, objects, refs, clock, issue_id) {
  const issue = _M0MP46mizchi3bit1x3hub3Hub10get__issue(self, objects, issue_id);
  if (issue === undefined) {
    return new _M0DTPC16result6ResultGuRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject(`Issue not found: ${issue_id}`));
  } else {
    const _Some = issue;
    const _existing = _Some;
    if (_M0IP016_24default__implPB2Eq10not__equalGRP46mizchi3bit1x3hub10IssueStateE(_existing.state, 0)) {
      return new _M0DTPC16result6ResultGuRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject(`Issue is not open: ${issue_id}`));
    }
    const updated = _M0MP46mizchi3bit1x3hub5Issue3new(_existing.id, _existing.title, _existing.body, _existing.author, _existing.created_at, clock.method_table.method_0(clock.self), 1, new _M0DTPC16option6OptionGRPB5ArrayGsEE4Some(_existing.labels), new _M0DTPC16option6OptionGRPB5ArrayGsEE4Some(_existing.assignees), new _M0DTPC16option6OptionGRPB5ArrayGsEE4Some(_existing.linked_prs), _M0DTPC16option6OptionGRPB5ArrayGsEE4None__, new _M0DTPC16option6OptionGOsE4Some(_existing.parent_id));
    const _bind = _M0MP46mizchi3bit1x3hub8HubStore11put__record(self.store, objects, refs, clock, `${_M0FP46mizchi3bit1x3hub31work__item__meta__prefix__value}${issue_id}/meta`, _M0FP46mizchi3bit1x3hub42canonical__work__item__record__kind__value, _M0MP46mizchi3bit1x3hub8WorkItem9serialize(_M0MP46mizchi3bit1x3hub5Issue14to__work__item(updated)), _existing.author);
    if (_bind.$tag === 1) {
      const _ok = _bind;
      _ok._0;
    } else {
      return _bind;
    }
    return new _M0DTPC16result6ResultGuRP36mizchi3bit6object8GitErrorE2Ok(undefined);
  }
}
function _M0FP46mizchi3bit1x3hub21js__hub__issue__close(host_id, root, issue_id) {
  return _M0FP46mizchi3bit1x3hub16hub__wrap__errorGuE(() => {
    const _bind = _M0FP46mizchi3bit1x3hub17hub__make__stores(host_id, root);
    let _bind$2;
    if (_bind.$tag === 1) {
      const _ok = _bind;
      _bind$2 = _ok._0;
    } else {
      return _bind;
    }
    const _objects = _bind$2._0;
    const _refs = _bind$2._1;
    const _clock = _bind$2._2;
    const _bind$3 = _M0MP46mizchi3bit1x3hub3Hub4load({ self: _objects, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsObjectStore_24as_24_40mizchi_2fbit_2flib_2eObjectStore }, { self: _refs, method_table: _M0FP078mizchi_2fbit_2fx_2fhub_2fHubJsRefStore_24as_24_40mizchi_2fbit_2flib_2eRefStore }, undefined, _M0DTPC16option6OptionGOsE4None__, -1);
    let hub;
    if (_bind$3.$tag === 1) {
      const _ok = _bind$3;
      hub = _ok._0;
    } else {
      return _bind$3;
    }
    return _M0MP46mizchi3bit1x3hub3Hub12close__issue(hub, { self: _objects, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsObjectStore_24as_24_40mizchi_2fbit_2flib_2eObjectStore }, { self: _refs, method_table: _M0FP078mizchi_2fbit_2fx_2fhub_2fHubJsRefStore_24as_24_40mizchi_2fbit_2flib_2eRefStore }, { self: _clock, method_table: _M0FP072mizchi_2fbit_2fx_2fhub_2fHubJsClock_24as_24_40mizchi_2fbit_2flib_2eClock }, issue_id);
  });
}
function _M0MP46mizchi3bit1x3hub3Hub13reopen__issue(self, objects, refs, clock, issue_id) {
  const issue = _M0MP46mizchi3bit1x3hub3Hub10get__issue(self, objects, issue_id);
  if (issue === undefined) {
    return new _M0DTPC16result6ResultGuRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject(`Issue not found: ${issue_id}`));
  } else {
    const _Some = issue;
    const _existing = _Some;
    if (_M0IP016_24default__implPB2Eq10not__equalGRP46mizchi3bit1x3hub10IssueStateE(_existing.state, 1)) {
      return new _M0DTPC16result6ResultGuRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject(`Issue is not closed: ${issue_id}`));
    }
    const updated = _M0MP46mizchi3bit1x3hub5Issue3new(_existing.id, _existing.title, _existing.body, _existing.author, _existing.created_at, clock.method_table.method_0(clock.self), 0, new _M0DTPC16option6OptionGRPB5ArrayGsEE4Some(_existing.labels), new _M0DTPC16option6OptionGRPB5ArrayGsEE4Some(_existing.assignees), new _M0DTPC16option6OptionGRPB5ArrayGsEE4Some(_existing.linked_prs), _M0DTPC16option6OptionGRPB5ArrayGsEE4None__, new _M0DTPC16option6OptionGOsE4Some(_existing.parent_id));
    const _bind = _M0MP46mizchi3bit1x3hub8HubStore11put__record(self.store, objects, refs, clock, `${_M0FP46mizchi3bit1x3hub31work__item__meta__prefix__value}${issue_id}/meta`, _M0FP46mizchi3bit1x3hub42canonical__work__item__record__kind__value, _M0MP46mizchi3bit1x3hub8WorkItem9serialize(_M0MP46mizchi3bit1x3hub5Issue14to__work__item(updated)), _existing.author);
    if (_bind.$tag === 1) {
      const _ok = _bind;
      _ok._0;
    } else {
      return _bind;
    }
    return new _M0DTPC16result6ResultGuRP36mizchi3bit6object8GitErrorE2Ok(undefined);
  }
}
function _M0FP46mizchi3bit1x3hub22js__hub__issue__reopen(host_id, root, issue_id) {
  return _M0FP46mizchi3bit1x3hub16hub__wrap__errorGuE(() => {
    const _bind = _M0FP46mizchi3bit1x3hub17hub__make__stores(host_id, root);
    let _bind$2;
    if (_bind.$tag === 1) {
      const _ok = _bind;
      _bind$2 = _ok._0;
    } else {
      return _bind;
    }
    const _objects = _bind$2._0;
    const _refs = _bind$2._1;
    const _clock = _bind$2._2;
    const _bind$3 = _M0MP46mizchi3bit1x3hub3Hub4load({ self: _objects, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsObjectStore_24as_24_40mizchi_2fbit_2flib_2eObjectStore }, { self: _refs, method_table: _M0FP078mizchi_2fbit_2fx_2fhub_2fHubJsRefStore_24as_24_40mizchi_2fbit_2flib_2eRefStore }, undefined, _M0DTPC16option6OptionGOsE4None__, -1);
    let hub;
    if (_bind$3.$tag === 1) {
      const _ok = _bind$3;
      hub = _ok._0;
    } else {
      return _bind$3;
    }
    return _M0MP46mizchi3bit1x3hub3Hub13reopen__issue(hub, { self: _objects, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsObjectStore_24as_24_40mizchi_2fbit_2flib_2eObjectStore }, { self: _refs, method_table: _M0FP078mizchi_2fbit_2fx_2fhub_2fHubJsRefStore_24as_24_40mizchi_2fbit_2flib_2eRefStore }, { self: _clock, method_table: _M0FP072mizchi_2fbit_2fx_2fhub_2fHubJsClock_24as_24_40mizchi_2fbit_2flib_2eClock }, issue_id);
  });
}
function _M0FP46mizchi3bit1x3hub21parse__issue__comment(text) {
  let id = "";
  let issue_id = "";
  let author = "";
  let created_at = $0L;
  let reply_to = undefined;
  const body_lines = [];
  let in_body = false;
  const _it = _M0MPC16string6String5split(text, new _M0TPC16string10StringView(_M0FP46mizchi3bit1x3hub21parse__issue__commentN7_2abindS4069, 0, _M0FP46mizchi3bit1x3hub21parse__issue__commentN7_2abindS4069.length));
  while (true) {
    const _bind = _M0MPB4Iter4nextGRPC16string10StringViewE(_it);
    if (_bind === undefined) {
      break;
    } else {
      const _Some = _bind;
      const _line_view = _Some;
      const line = _M0IPC16string10StringViewPB4Show10to__string(_line_view);
      if (in_body) {
        _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(body_lines, line);
        continue;
      }
      if (line.length === 0) {
        in_body = true;
        continue;
      }
      const space = _M0MPC16string6String4find(line, new _M0TPC16string10StringView(_M0FP46mizchi3bit1x3hub21parse__issue__commentN7_2abindS4058, 0, _M0FP46mizchi3bit1x3hub21parse__issue__commentN7_2abindS4058.length));
      if (space === undefined) {
        continue;
      } else {
        const _Some$2 = space;
        const _idx = _Some$2;
        const key = line.substring(0, _idx);
        const value = line.substring(_idx + 1 | 0, line.length);
        switch (key) {
          case "comment": {
            id = value;
            break;
          }
          case "issue": {
            issue_id = value;
            break;
          }
          case "author": {
            author = value;
            break;
          }
          case "created": {
            created_at = _M0FP46mizchi3bit1x3hub12parse__int64(value);
            break;
          }
          case "reply-to": {
            reply_to = value;
            break;
          }
        }
      }
      continue;
    }
  }
  if (id.length === 0) {
    return new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub12IssueCommentRP46mizchi3bit1x3hub7PrErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fx_2fhub_2ePrError_2eInvalidFormat("Missing comment id"));
  }
  return new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub12IssueCommentRP46mizchi3bit1x3hub7PrErrorE2Ok(_M0MP46mizchi3bit1x3hub12IssueComment11new_2einner(id, issue_id, author, _M0MPC15array5Array4joinGsE(body_lines, new _M0TPC16string10StringView(_M0FP46mizchi3bit1x3hub21parse__issue__commentN7_2abindS4070, 0, _M0FP46mizchi3bit1x3hub21parse__issue__commentN7_2abindS4070.length)), created_at, reply_to));
}
function _M0MP46mizchi3bit1x3hub3Hub21list__issue__comments(self, objects, issue_id) {
  const result = [];
  const records = _M0MP46mizchi3bit1x3hub8HubStore21list__records_2einner(self.store, objects, `hub/issue/${issue_id}/comment/`, false);
  const _bind = records.length;
  let _tmp = 0;
  while (true) {
    const _ = _tmp;
    if (_ < _bind) {
      const record = records[_];
      _L: {
        const _p = record.kind;
        const _p$2 = "issue.comment";
        if (!(_p === _p$2)) {
          break _L;
        }
        let comment;
        let _try_err;
        _L$2: {
          _L$3: {
            const _bind$2 = _M0FP46mizchi3bit1x3hub21parse__issue__comment(record.payload);
            if (_bind$2.$tag === 1) {
              const _ok = _bind$2;
              comment = _ok._0;
            } else {
              const _err = _bind$2;
              _try_err = _err._0;
              break _L$3;
            }
            break _L$2;
          }
          break _L;
        }
        _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(result, comment);
        break _L;
      }
      _tmp = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  _M0MPC15array5Array8sort__byGRP46mizchi3bit1x3hub12IssueCommentE(result, (a, b) => _M0IP016_24default__implPB7Compare6op__ltGlE(a.created_at, b.created_at) ? -1 : _M0IP016_24default__implPB7Compare6op__gtGlE(a.created_at, b.created_at) ? 1 : 0);
  return result;
}
function _M0FP46mizchi3bit1x3hub29js__hub__issue__comment__list(host_id, root, issue_id) {
  return _M0FP46mizchi3bit1x3hub16hub__wrap__errorGRPB5ArrayGRP46mizchi3bit1x3hub5IssueEE(() => {
    const _bind = _M0FP46mizchi3bit1x3hub17hub__make__stores(host_id, root);
    let _bind$2;
    if (_bind.$tag === 1) {
      const _ok = _bind;
      _bind$2 = _ok._0;
    } else {
      return _bind;
    }
    const _objects = _bind$2._0;
    const _refs = _bind$2._1;
    const _bind$3 = _M0MP46mizchi3bit1x3hub3Hub4load({ self: _objects, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsObjectStore_24as_24_40mizchi_2fbit_2flib_2eObjectStore }, { self: _refs, method_table: _M0FP078mizchi_2fbit_2fx_2fhub_2fHubJsRefStore_24as_24_40mizchi_2fbit_2flib_2eRefStore }, undefined, _M0DTPC16option6OptionGOsE4None__, -1);
    let hub;
    if (_bind$3.$tag === 1) {
      const _ok = _bind$3;
      hub = _ok._0;
    } else {
      return _bind$3;
    }
    return new _M0DTPC16result6ResultGRPB5ArrayGRP46mizchi3bit1x3hub12IssueCommentERP36mizchi3bit6object8GitErrorE2Ok(_M0MP46mizchi3bit1x3hub3Hub21list__issue__comments(hub, { self: _objects, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsObjectStore_24as_24_40mizchi_2fbit_2flib_2eObjectStore }, issue_id));
  });
}
function _M0MP46mizchi3bit1x3hub12IssueComment9serialize(self) {
  const sb = _M0MPB13StringBuilder11new_2einner(0);
  _M0IPB13StringBuilderPB6Logger13write__string(sb, "comment ");
  _M0IPB13StringBuilderPB6Logger13write__string(sb, self.id);
  _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
  _M0IPB13StringBuilderPB6Logger13write__string(sb, "issue ");
  _M0IPB13StringBuilderPB6Logger13write__string(sb, self.issue_id);
  _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
  _M0IPB13StringBuilderPB6Logger13write__string(sb, "author ");
  _M0IPB13StringBuilderPB6Logger13write__string(sb, self.author);
  _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
  _M0IPB13StringBuilderPB6Logger13write__string(sb, "created ");
  _M0IPB13StringBuilderPB6Logger13write__string(sb, _M0MPC15int645Int6418to__string_2einner(self.created_at, 10));
  _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
  const _bind = self.reply_to;
  if (_bind === undefined) {
  } else {
    const _Some = _bind;
    const _r = _Some;
    _M0IPB13StringBuilderPB6Logger13write__string(sb, "reply-to ");
    _M0IPB13StringBuilderPB6Logger13write__string(sb, _r);
    _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
  }
  _M0IPB13StringBuilderPB6Logger11write__char(sb, 10);
  _M0IPB13StringBuilderPB6Logger13write__string(sb, self.body);
  return sb.val;
}
function _M0MP46mizchi3bit1x3hub3Hub27add__issue__comment_2einner(self, objects, refs, clock, issue_id, author, body, reply_to) {
  const issue = _M0MP46mizchi3bit1x3hub3Hub10get__issue(self, objects, issue_id);
  if (issue === undefined) {
    return new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub12IssueCommentRP36mizchi3bit6object8GitErrorE3Err(new _M0DTPC15error5Error48mizchi_2fbit_2fobject_2eGitError_2eInvalidObject(`Issue not found: ${issue_id}`));
  } else {
    const timestamp = clock.method_table.method_0(clock.self);
    const comment = _M0MP46mizchi3bit1x3hub12IssueComment11new_2einner("", issue_id, author, body, timestamp, reply_to);
    const comment_data = _M0MP46mizchi3bit1x3hub12IssueComment9serialize(comment);
    const _bind = _M0FP36mizchi3bit6object20create__blob__string(comment_data);
    const _blob_id = _bind._0;
    const comment_id = _M0FP46mizchi3bit1x3hub10short__hex(_M0MP36mizchi3bit6object8ObjectId7to__hex(_blob_id), 8);
    const final_comment = _M0MP46mizchi3bit1x3hub12IssueComment11new_2einner(comment_id, issue_id, author, body, timestamp, reply_to);
    const _bind$2 = _M0MP46mizchi3bit1x3hub8HubStore11put__record(self.store, objects, refs, clock, _M0FP46mizchi3bit1x3hub19issue__comment__key(issue_id, comment_id), "issue.comment", _M0MP46mizchi3bit1x3hub12IssueComment9serialize(final_comment), author);
    if (_bind$2.$tag === 1) {
      const _ok = _bind$2;
      _ok._0;
    } else {
      return _bind$2;
    }
    return new _M0DTPC16result6ResultGRP46mizchi3bit1x3hub12IssueCommentRP36mizchi3bit6object8GitErrorE2Ok(final_comment);
  }
}
function _M0MP46mizchi3bit1x3hub3Hub19add__issue__comment(self, objects, refs, clock, issue_id, author, body, reply_to$46$opt) {
  let reply_to;
  if (reply_to$46$opt.$tag === 1) {
    const _Some = reply_to$46$opt;
    reply_to = _Some._0;
  } else {
    reply_to = undefined;
  }
  return _M0MP46mizchi3bit1x3hub3Hub27add__issue__comment_2einner(self, objects, refs, clock, issue_id, author, body, reply_to);
}
function _M0FP46mizchi3bit1x3hub28js__hub__issue__comment__add(host_id, root, issue_id, author, body) {
  return _M0FP46mizchi3bit1x3hub16hub__wrap__errorGRP46mizchi3bit1x3hub5IssueE(() => {
    const _bind = _M0FP46mizchi3bit1x3hub17hub__make__stores(host_id, root);
    let _bind$2;
    if (_bind.$tag === 1) {
      const _ok = _bind;
      _bind$2 = _ok._0;
    } else {
      return _bind;
    }
    const _objects = _bind$2._0;
    const _refs = _bind$2._1;
    const _clock = _bind$2._2;
    const _bind$3 = _M0MP46mizchi3bit1x3hub3Hub4load({ self: _objects, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsObjectStore_24as_24_40mizchi_2fbit_2flib_2eObjectStore }, { self: _refs, method_table: _M0FP078mizchi_2fbit_2fx_2fhub_2fHubJsRefStore_24as_24_40mizchi_2fbit_2flib_2eRefStore }, undefined, _M0DTPC16option6OptionGOsE4None__, -1);
    let hub;
    if (_bind$3.$tag === 1) {
      const _ok = _bind$3;
      hub = _ok._0;
    } else {
      return _bind$3;
    }
    return _M0MP46mizchi3bit1x3hub3Hub19add__issue__comment(hub, { self: _objects, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsObjectStore_24as_24_40mizchi_2fbit_2flib_2eObjectStore }, { self: _refs, method_table: _M0FP078mizchi_2fbit_2fx_2fhub_2fHubJsRefStore_24as_24_40mizchi_2fbit_2flib_2eRefStore }, { self: _clock, method_table: _M0FP072mizchi_2fbit_2fx_2fhub_2fHubJsClock_24as_24_40mizchi_2fbit_2flib_2eClock }, issue_id, author, body, _M0DTPC16option6OptionGOsE4None__);
  });
}
function _M0FP46mizchi3bit1x3hub22js__hub__issue__search(host_id, root, query, state) {
  return _M0FP46mizchi3bit1x3hub16hub__wrap__errorGRPB5ArrayGRP46mizchi3bit1x3hub5IssueEE(() => {
    const _bind = _M0FP46mizchi3bit1x3hub17hub__make__stores(host_id, root);
    let _bind$2;
    if (_bind.$tag === 1) {
      const _ok = _bind;
      _bind$2 = _ok._0;
    } else {
      return _bind;
    }
    const _objects = _bind$2._0;
    const _refs = _bind$2._1;
    const _bind$3 = _M0MP46mizchi3bit1x3hub3Hub4load({ self: _objects, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsObjectStore_24as_24_40mizchi_2fbit_2flib_2eObjectStore }, { self: _refs, method_table: _M0FP078mizchi_2fbit_2fx_2fhub_2fHubJsRefStore_24as_24_40mizchi_2fbit_2flib_2eRefStore }, undefined, _M0DTPC16option6OptionGOsE4None__, -1);
    let hub;
    if (_bind$3.$tag === 1) {
      const _ok = _bind$3;
      hub = _ok._0;
    } else {
      return _bind$3;
    }
    let filter;
    switch (state) {
      case "open": {
        filter = _M0FP46mizchi3bit1x3hub38js__hub__issue__search_2econstr_2f4821;
        break;
      }
      case "closed": {
        filter = _M0FP46mizchi3bit1x3hub38js__hub__issue__search_2econstr_2f4822;
        break;
      }
      default: {
        filter = undefined;
      }
    }
    const all = _M0MP46mizchi3bit1x3hub3Hub20list__issues_2einner(hub, { self: _objects, method_table: _M0FP084mizchi_2fbit_2fx_2fhub_2fHubJsObjectStore_24as_24_40mizchi_2fbit_2flib_2eObjectStore }, filter);
    const q = _M0MPC16string6String9to__lower(query);
    const result = [];
    const _bind$4 = all.length;
    let _tmp = 0;
    while (true) {
      const _ = _tmp;
      if (_ < _bind$4) {
        const issue = all[_];
        if (_M0MPC16string6String8contains(_M0MPC16string6String9to__lower(issue.title), new _M0TPC16string10StringView(q, 0, q.length)) || _M0MPC16string6String8contains(_M0MPC16string6String9to__lower(issue.body), new _M0TPC16string10StringView(q, 0, q.length))) {
          _M0MPC15array5Array4pushGRP46mizchi3bit1x3hub5IssueE(result, issue);
        }
        _tmp = _ + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    return new _M0DTPC16result6ResultGRPB5ArrayGRP46mizchi3bit1x3hub5IssueERP36mizchi3bit6object8GitErrorE2Ok(result);
  });
}
export { _M0FP46mizchi3bit1x3hub20js__hub__issue__init as hubIssueInit, _M0FP46mizchi3bit1x3hub20js__hub__issue__list as hubIssueList, _M0FP46mizchi3bit1x3hub19js__hub__issue__get as hubIssueGet, _M0FP46mizchi3bit1x3hub22js__hub__issue__create as hubIssueCreate, _M0FP46mizchi3bit1x3hub22js__hub__issue__update as hubIssueUpdate, _M0FP46mizchi3bit1x3hub21js__hub__issue__close as hubIssueClose, _M0FP46mizchi3bit1x3hub22js__hub__issue__reopen as hubIssueReopen, _M0FP46mizchi3bit1x3hub29js__hub__issue__comment__list as hubIssueCommentList, _M0FP46mizchi3bit1x3hub28js__hub__issue__comment__add as hubIssueCommentAdd, _M0FP46mizchi3bit1x3hub22js__hub__issue__search as hubIssueSearch }
