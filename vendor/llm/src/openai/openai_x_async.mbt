///|
/// Build an OpenAI-compatible non-streaming completion request.
fn build_openai_body_nonstream(
  model : String,
  max_tokens : Int,
  system_prompt : String,
  messages : Array[@llm.Message],
  tools : Array[@llm.ToolDef],
) -> Json {
  let body : Map[String, Json] = Map([])
  body["model"] = ToJson::to_json(model)
  body["max_tokens"] = Json::number(max_tokens.to_double())
  body["stream"] = Json::boolean(false)
  let msgs : Array[Json] = []
  if !system_prompt.is_empty() {
    msgs.push(@llm.Message::system(system_prompt).to_openai_json())
  }
  for msg in messages {
    msgs.push(msg.to_openai_json())
  }
  body["messages"] = Json::array(msgs)
  if !tools.is_empty() {
    body["tools"] = Json::array(tools.map(@llm.ToolDef::to_openai_json))
  }
  Json::object(body)
}

///|
fn parse_openai_collect_text_response(response_text : String) -> String {
  let response = @json.parse(response_text) catch { _ => return "" }
  let choices = match @llm.json_get_array(response, "choices") {
    Some(value) => value
    None => return ""
  }
  if choices.is_empty() {
    return ""
  }
  let message = match @llm.json_get_object(choices[0], "message") {
    Some(value) => value
    None => return ""
  }
  @llm.json_get_string(message, "content").unwrap_or("")
}

///|
/// Cross-target async non-streaming completion backed by `mizchi/x/http`.
/// Returns an empty string for transport, HTTP, or response parsing errors.
pub async fn OpenAIProvider::collect_text(
  self : OpenAIProvider,
  messages : Array[@llm.Message],
  tools? : Array[@llm.ToolDef] = [],
) -> String {
  let path = match self.endpoint {
    Cloudflare(..) => "/run/" + self.config.model
    _ => "/v1/chat/completions"
  }
  let url = self.config.base_url + path
  let headers = build_openai_headers(self.config.api_key, self.endpoint)
  let body = build_openai_body_nonstream(
    self.config.model,
    self.config.max_tokens,
    self.config.system_prompt,
    messages,
    tools,
  )
  let (status, response_text) = @ffi.fetch_async(
    url,
    "POST",
    headers.stringify(),
    body.stringify(),
    self.config.timeout_sec,
  ) catch {
    _ => return ""
  }
  if status < 200 || status >= 300 {
    return ""
  }
  parse_openai_collect_text_response(response_text)
}
