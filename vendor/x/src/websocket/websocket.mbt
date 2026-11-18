///|
#derive(@debug.Debug)
pub(all) enum MessageKind {
  Binary
  Text
}

///|
pub impl Show for MessageKind with fn output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum CloseCode {
  Normal
  GoingAway
  ProtocolError
  UnsupportedData
  Abnormal
  InvalidFramePayload
  PolicyViolation
  MessageTooBig
  MissingExtension
  InternalError
  Other(UInt16)
}

///|
pub impl Show for CloseCode with fn output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
#derive(@debug.Debug)
pub suberror WebSocketError {
  ConnectionClosed(CloseCode, String?)
  InvalidHandshake(String)
  ProtocolError(String)
}

///|
pub impl Show for WebSocketError with fn output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
fn keep_websocket_error_constructors_used() -> Unit {
  ignore(WebSocketError::ConnectionClosed(Normal, None))
  ignore(WebSocketError::InvalidHandshake(""))
}

///|
pub(all) enum Message {
  Text(String)
  Binary(Bytes)
}

///|
fn close_code_from_int(code : Int32) -> CloseCode {
  match code {
    1000 => Normal
    1001 => GoingAway
    1002 => CloseCode::ProtocolError
    1003 => UnsupportedData
    1006 => Abnormal
    1007 => InvalidFramePayload
    1008 => PolicyViolation
    1009 => MessageTooBig
    1010 => MissingExtension
    1011 => InternalError
    _ => Other(code.to_uint16())
  }
}

///|
fn close_code_to_int(code : CloseCode) -> Int32 {
  match code {
    Normal => 1000
    GoingAway => 1001
    CloseCode::ProtocolError => 1002
    UnsupportedData => 1003
    Abnormal => 1006
    InvalidFramePayload => 1007
    PolicyViolation => 1008
    MessageTooBig => 1009
    MissingExtension => 1010
    InternalError => 1011
    Other(n) => n.to_int()
  }
}

///|

///|
pub extend MessageKind with @debug.Debug::{to_repr}

///|
pub extend MessageKind with Show::{to_string, output}

///|
pub extend CloseCode with Eq::{not_equal, equal}

///|
pub extend CloseCode with @debug.Debug::{to_repr}

///|
pub extend CloseCode with Show::{to_string, output}

///|
pub extend WebSocketError with @debug.Debug::{to_repr}

///|
pub extend WebSocketError with Show::{to_string, output}
