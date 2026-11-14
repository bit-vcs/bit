///|
/// Route-free runtime turn core.

///|
pub(all) enum RuntimeTurnKind {
  UserInbound
  SystemInbound
} derive(Eq)

///|
pub struct RuntimeTurnRequest {
  kind : RuntimeTurnKind
  session_key : String
  channel : String
  chat_id : String
  sender_id : String
  content : String
  metadata : Map[String, Json]
}

///|
pub fn RuntimeTurnRequest::new(
  kind : RuntimeTurnKind,
  session_key : String,
  channel : String,
  chat_id : String,
  sender_id : String,
  content : String,
  metadata? : Map[String, Json] = Map([]),
) -> RuntimeTurnRequest {
  { kind, session_key, channel, chat_id, sender_id, content, metadata }
}

///|
pub struct RuntimeTurnResult {
  channel : String
  chat_id : String
  content : String
  metadata : Map[String, Json]
}

///|
pub fn run_runtime_turn(
  sessions : SessionManager,
  request : RuntimeTurnRequest,
  run_loop : (Array[Json], String, String, String) -> String,
) -> RuntimeTurnResult {
  let session = sessions.get_or_create(request.session_key)
  let reply = run_loop(
    session.get_history(),
    request.content,
    request.channel,
    request.chat_id,
  )
  let user_history_content = match request.kind {
    SystemInbound => "[System: " + request.sender_id + "] " + request.content
    UserInbound => request.content
  }
  session.add_message("user", user_history_content)
  session.add_message("assistant", reply)
  sessions.save(session)
  {
    channel: request.channel,
    chat_id: request.chat_id,
    content: reply,
    metadata: match request.kind {
      SystemInbound => {}
      UserInbound => request.metadata
    },
  }
}
