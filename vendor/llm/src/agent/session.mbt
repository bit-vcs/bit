///|
/// In-memory session manager extracted from nanobot.

///|
fn default_clock_ms() -> Int {
  0
}

///|
pub struct Session {
  key : String
  mut messages : Array[Json]
  created_at_ms : Int
  mut updated_at_ms : Int
  metadata : Map[String, Json]
  clock : () -> Int
}

///|
pub fn Session::new(
  key : String,
  created_at_ms : Int,
  clock : () -> Int,
) -> Session {
  {
    key,
    messages: [],
    created_at_ms,
    updated_at_ms: created_at_ms,
    metadata: {},
    clock,
  }
}

///|
pub fn Session::add_message(
  self : Session,
  role : String,
  content : String,
) -> Unit {
  let now = (self.clock)()
  let msg : Map[String, Json] = Map([])
  msg["role"] = ToJson::to_json(role)
  msg["content"] = ToJson::to_json(content)
  msg["timestamp"] = ToJson::to_json(now)
  self.messages.push(Json::object(msg))
  self.updated_at_ms = now
}

///|
pub fn Session::get_history(
  self : Session,
  max_messages? : Int = 50,
) -> Array[Json] {
  let start = if self.messages.length() > max_messages {
    self.messages.length() - max_messages
  } else {
    0
  }
  let out : Array[Json] = []
  for i in start..<self.messages.length() {
    let src = self.messages[i]
    let role = match session_get_string_field(src, "role") {
      Some(s) => s
      None => ""
    }
    let content = match session_get_string_field(src, "content") {
      Some(s) => s
      None => ""
    }
    out.push({ "role": ToJson::to_json(role), "content": ToJson::to_json(content) })
  }
  out
}

///|
pub fn Session::clear(self : Session) -> Unit {
  self.messages = []
  self.updated_at_ms = (self.clock)()
}

///|
pub struct SessionSummary {
  key : String
  created_at_ms : Int
  updated_at_ms : Int
}

///|
pub struct SessionManager {
  cache : Map[String, Session]
  clock : () -> Int
}

///|
pub fn SessionManager::new(
  clock? : () -> Int = default_clock_ms,
) -> SessionManager {
  { cache: {}, clock }
}

///|
pub fn SessionManager::get_or_create(
  self : SessionManager,
  key : String,
) -> Session {
  match self.cache.get(key) {
    Some(session) => session
    None => {
      let now = (self.clock)()
      let session = Session::new(key, now, self.clock)
      self.cache[key] = session
      session
    }
  }
}

///|
pub fn SessionManager::save(self : SessionManager, session : Session) -> Unit {
  self.cache[session.key] = session
}

///|
pub fn SessionManager::delete(self : SessionManager, key : String) -> Bool {
  let existed = self.cache.contains(key)
  self.cache.remove(key)
  existed
}

///|
pub fn SessionManager::list_sessions(
  self : SessionManager,
) -> Array[SessionSummary] {
  let out : Array[SessionSummary] = []
  for entry in self.cache.to_array() {
    let session = entry.1
    out.push({
      key: session.key,
      created_at_ms: session.created_at_ms,
      updated_at_ms: session.updated_at_ms,
    })
  }
  out.sort_by(fn(a, b) { b.updated_at_ms - a.updated_at_ms })
  out
}

///|
fn session_get_string_field(obj : Json, key : String) -> String? {
  match obj {
    Object(map) =>
      match map.get(key) {
        Some(String(s)) => Some(s)
        _ => None
      }
    _ => None
  }
}
