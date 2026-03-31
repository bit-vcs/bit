///|
fn component_impl_fixture_hex_char_val(c : Char) -> Int {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 'A'.to_int() + 10
  } else {
    0
  }
}

///|
fn component_impl_fixture_hex_to_bytes(hex : String) -> Bytes {
  let chars = hex.to_array()
  let len = hex.length()
  if len % 2 != 0 {
    return Bytes::from_array([])
  }
  let out : Array[Byte] = []
  for i in 0..<(len / 2) {
    let hi = component_impl_fixture_hex_char_val(chars[i * 2])
    let lo = component_impl_fixture_hex_char_val(chars[i * 2 + 1])
    out.push(((hi << 4) | lo).to_byte())
  }
  Bytes::from_array(FixedArray::makei(out.length(), i => out[i]))
}

///|
fn component_impl_fixture_bytes_to_string(bytes : Bytes) -> String {
  let sb = StringBuilder::new()
  for b in bytes {
    sb.write_char(b.to_int().unsafe_to_char())
  }
  sb.to_string()
}

///|
fn component_impl_fixture_string_to_bytes(text : String) -> Bytes {
  let bytes : Array[Byte] = []
  for c in text.to_array() {
    bytes.push(c.to_int().to_byte())
  }
  Bytes::from_array(FixedArray::makei(bytes.length(), i => bytes[i]))
}

///|
let component_impl_adv_v2_hex : String = "3030306576657273696f6e20320a303031636167656e743d6769742f322e35302e312d44617277696e0a303031336c732d726566733d756e626f726e0a3030323066657463683d7368616c6c6f7720776169742d666f722d646f6e650a303031327365727665722d6f7074696f6e0a303031376f626a6563742d666f726d61743d736861310a30303030"

///|
let component_impl_lsrefs_hex : String = "303035303330633966323038616363373630313737336132396165663339343135376164663936306431303420484541442073796d7265662d7461726765743a726566732f68656164732f6d61696e0a303033643330633966323038616363373630313737336132396165663339343135376164663936306431303420726566732f68656164732f6d61696e0a30303030"

///|
let component_impl_fetch_hex : String = "303030647061636b66696c650a30306435015041434b00000002000000039b09789c95cb310ac3300c40d1dda7f05e28b21ccb319492ab288ad208ea0682baf4f4cd15327d78f0fd508dccdc4874c1a57192512b4aa1194b66505cb58eb9e555e71af8ebdb7ec46e3fd92c3ece0e304cafcef6becbde9f31556a2513258c376800e1d46eee7a690af6310f7f8ae52e13a502789c33343030333151c848cdc9c9d72ba9286138c768a6caccbde2f64ab6ef61d3eae7cd593cc5cd0b00df740dbf36789ccb48cdc9c9e70200084b021f62c7bf336ea966f094470f354a76a0f737e13d30303036017a30303030"

///|
let component_impl_fixture_commit : String = "30c9f208acc7601773a29aef394157adf960d104"
