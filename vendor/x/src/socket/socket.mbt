///|
#derive(@debug.Debug)
pub suberror InvalidAddr

///|
#derive(@debug.Debug)
pub suberror ResolveHostnameError {
  ResolveHostnameError(String)
}

///|
#derive(@debug.Debug)
pub(all) enum IpProtocolPreference {
  OnlyV4
  OnlyV6
  FavorV4
  FavorV6
  NoPreference
}

///|
#derive(Eq, Compare, Hash)
pub struct Addr {
  priv host : String
  priv port : Int32
  priv ip : UInt32
  priv is_ipv6 : Bool
}

///|
fn ipv4_part(ip : UInt32, shift : Int32) -> String {
  ((ip >> shift) & 0xffU).to_string()
}

///|
fn ipv4_host_from_ip(ip : UInt32) -> String {
  ipv4_part(ip, 24) +
  "." +
  ipv4_part(ip, 16) +
  "." +
  ipv4_part(ip, 8) +
  "." +
  ipv4_part(ip, 0)
}

///|
fn parse_port(raw : StringView) -> Int32 raise InvalidAddr {
  let port = @string.parse_int(raw, radix=10) catch { _ => raise InvalidAddr }
  guard 0 <= port && port < 65536 else { raise InvalidAddr }
  port
}

///|
fn parse_ipv4_host(raw : StringView) -> UInt32 raise InvalidAddr {
  let parts = raw.split(".").collect()
  guard parts.length() == 4 else { raise InvalidAddr }
  let mut ip = 0U
  for part in parts {
    let value = @string.parse_int(part, radix=10) catch {
      _ => raise InvalidAddr
    }
    guard 0 <= value && value <= 255 else { raise InvalidAddr }
    ip = (ip << 8) | value.reinterpret_as_uint()
  }
  ip
}

///|
fn parse_ipv6(src : String) -> Addr raise InvalidAddr {
  let mut close = -1
  for i = 1; i < src.length(); i = i + 1 {
    if src[i] == ']' {
      close = i
      break
    }
  }
  guard close > 1 && close + 1 < src.length() && src[close + 1] == ':' else {
    raise InvalidAddr
  }
  let host = src[1:close].to_owned()
  let port = parse_port(src[close + 2:])
  Addr::{ host, port, ip: 0U, is_ipv6: true, }
}

///|
pub fn Addr::new(ip : UInt32, port : Int32) -> Addr {
  Addr::{ host: ipv4_host_from_ip(ip), port, ip, is_ipv6: false, }
}

///|
pub fn Addr::parse(src : String) -> Addr raise InvalidAddr {
  if src.has_prefix("[") {
    parse_ipv6(src)
  } else {
    let parts = src.split(":").collect()
    guard parts.length() == 2 else { raise InvalidAddr }
    let ip = parse_ipv4_host(parts[0])
    let port = parse_port(parts[1])
    Addr::{ host: parts[0].to_owned(), port, ip, is_ipv6: false, }
  }
}

///|
pub fn Addr::ip(self : Addr) -> UInt32 {
  self.ip
}

///|
pub fn Addr::port(self : Addr) -> Int32 {
  self.port
}

///|
pub fn Addr::is_ipv6(self : Addr) -> Bool {
  self.is_ipv6
}

///|
pub fn Addr::is_multicast(self : Addr) -> Bool {
  if self.is_ipv6 {
    self.host.to_lower().has_prefix("ff")
  } else {
    let first = ((self.ip >> 24) & 0xffU).reinterpret_as_int()
    224 <= first && first <= 239
  }
}

///|
pub impl Show for Addr with fn output(self, logger) {
  if self.is_ipv6 {
    logger
    ..write_char('[')
    ..write_string(self.host)
    ..write_char(']')
    ..write_char(':')
    .write_object(self.port)
  } else {
    logger..write_string(self.host)..write_char(':').write_object(self.port)
  }
}

///|
pub extend InvalidAddr with @debug.Debug::{to_repr}

///|
pub extend ResolveHostnameError with @debug.Debug::{to_repr}

///|
pub extend IpProtocolPreference with @debug.Debug::{to_repr}

///|
pub extend Addr with Eq::{not_equal, equal}

///|
pub extend Addr with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend Addr with Hash::{hash, hash_combine}

///|
pub extend Addr with Show::{to_string, output}
