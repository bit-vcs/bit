///|
/// Pure tool definitions + argument resolution extracted from nanobot agent_tools.

///|
pub struct RuntimeToolContext {
  mut channel : String
  mut chat_id : String
}

///|
pub fn RuntimeToolContext::new(
  channel? : String = "",
  chat_id? : String = "",
) -> RuntimeToolContext {
  { channel, chat_id }
}

///|
pub fn RuntimeToolContext::set(
  self : RuntimeToolContext,
  channel : String,
  chat_id : String,
) -> Unit {
  self.channel = channel
  self.chat_id = chat_id
}

///|
pub struct MessageToolPlan {
  channel : String
  chat_id : String
  content : String
}

///|
pub struct SpawnToolPlan {
  task : String
  label : String?
  origin_channel : String
  origin_chat_id : String
}

///|
pub enum CronToolPlan {
  Add(
    name~ : String,
    schedule~ : CronSchedule,
    message~ : String,
    channel~ : String,
    chat_id~ : String
  )
  List
  Remove(job_id~ : String)
}

///|
pub fn message_tool_def() -> @llm.ToolDef {
  @llm.ToolDef::new(
    "message",
    "Send a message to the user. Use this when you want to communicate something.",
    {
      "type": ToJson::to_json("object"),
      "properties": {
        "content": {
          "type": ToJson::to_json("string"),
          "description": ToJson::to_json("The message content to send"),
        },
        "channel": {
          "type": ToJson::to_json("string"),
          "description": ToJson::to_json("Optional: target channel (telegram, discord, etc.)"),
        },
        "chat_id": {
          "type": ToJson::to_json("string"),
          "description": ToJson::to_json("Optional: target chat/user ID"),
        },
      },
      "required": Json::array([ToJson::to_json("content")]),
    },
  )
}

///|
pub fn spawn_tool_def() -> @llm.ToolDef {
  @llm.ToolDef::new(
    "spawn",
    "Spawn a subagent to handle a task in the background. The subagent will complete the task and report back when done.",
    {
      "type": ToJson::to_json("object"),
      "properties": {
        "task": {
          "type": ToJson::to_json("string"),
          "description": ToJson::to_json("The task for the subagent to complete"),
        },
        "label": {
          "type": ToJson::to_json("string"),
          "description": ToJson::to_json("Optional short label for the task (for display)"),
        },
      },
      "required": Json::array([ToJson::to_json("task")]),
    },
  )
}

///|
pub fn cron_tool_def() -> @llm.ToolDef {
  @llm.ToolDef::new(
    "cron",
    "Schedule reminders and recurring tasks. Actions: add, list, remove.",
    {
      "type": ToJson::to_json("object"),
      "properties": {
        "action": {
          "type": ToJson::to_json("string"),
          "enum": Json::array([
            ToJson::to_json("add"),
            ToJson::to_json("list"),
            ToJson::to_json("remove"),
          ]),
          "description": ToJson::to_json("Action to perform"),
        },
        "message": {
          "type": ToJson::to_json("string"),
          "description": ToJson::to_json("Reminder message (for add)"),
        },
        "every_seconds": {
          "type": ToJson::to_json("integer"),
          "description": ToJson::to_json("Interval in seconds (for recurring tasks)"),
        },
        "cron_expr": {
          "type": ToJson::to_json("string"),
          "description": ToJson::to_json("Cron expression like '0 9 * * *' (for scheduled tasks)"),
        },
        "job_id": {
          "type": ToJson::to_json("string"),
          "description": ToJson::to_json("Job ID (for remove)"),
        },
      },
      "required": Json::array([ToJson::to_json("action")]),
    },
  )
}

///|
pub fn resolve_message_tool(
  params : Json,
  context : RuntimeToolContext,
) -> Result[MessageToolPlan, String] {
  let content = tool_required_string(params, "content")
  match content {
    Some(text) => {
      let channel = resolve_target(
        tool_optional_string(params, "channel"),
        context.channel,
      )
      let chat_id = resolve_target(
        tool_optional_string(params, "chat_id"),
        context.chat_id,
      )
      if channel.is_empty() || chat_id.is_empty() {
        Err("Error: No target channel/chat specified")
      } else {
        Ok({ channel, chat_id, content: text })
      }
    }
    None => Err("Error: content is required")
  }
}

///|
pub fn format_message_tool_result(channel : String, chat_id : String) -> String {
  "Message sent to " + channel + ":" + chat_id
}

///|
pub fn resolve_spawn_tool(
  params : Json,
  context : RuntimeToolContext,
) -> Result[SpawnToolPlan, String] {
  let task = tool_required_string(params, "task")
  let label = tool_optional_string(params, "label")
  match task {
    Some(task) =>
      Ok({
        task,
        label,
        origin_channel: fallback_origin(context.channel),
        origin_chat_id: fallback_chat_id(context.chat_id),
      })
    None => Err("Error: task is required")
  }
}

///|
pub fn resolve_cron_tool(
  params : Json,
  context : RuntimeToolContext,
) -> Result[CronToolPlan, String] {
  let action = tool_required_string(params, "action")
  match action {
    Some("add") => resolve_cron_add(params, context)
    Some("list") => Ok(List)
    Some("remove") => {
      let job_id = tool_required_string(params, "job_id")
      match job_id {
        Some(id) => Ok(Remove(job_id=id))
        None => Err("Error: job_id is required for remove")
      }
    }
    Some(value) => Err("Unknown action: " + value)
    None => Err("Error: action is required")
  }
}

///|
pub fn format_cron_add_result(name : String, job_id : String) -> String {
  "Created job '" + name + "' (id: " + job_id + ")"
}

///|
pub fn format_cron_list(jobs : Array[CronJob]) -> String {
  if jobs.is_empty() {
    return "No scheduled jobs."
  }
  let lines : Array[String] = []
  for job in jobs {
    lines.push(
      "- " +
      job.name +
      " (id: " +
      job.id +
      ", " +
      cron_kind_label(job.schedule.kind) +
      ")",
    )
  }
  "Scheduled jobs:\n" + lines.join("\n")
}

///|
pub fn format_cron_remove_result(job_id : String, removed : Bool) -> String {
  if removed {
    "Removed job " + job_id
  } else {
    "Job " + job_id + " not found"
  }
}

///|
fn resolve_cron_add(
  params : Json,
  context : RuntimeToolContext,
) -> Result[CronToolPlan, String] {
  let message = tool_required_string(params, "message")
  let every_seconds = tool_optional_int(params, "every_seconds")
  let cron_expr = tool_optional_string(params, "cron_expr")
  let channel = context.channel
  let chat_id = context.chat_id
  match message {
    Some(msg) => {
      if msg.is_empty() {
        return Err("Error: message is required for add")
      }
      if channel.is_empty() || chat_id.is_empty() {
        return Err("Error: no session context (channel/chat_id)")
      }
      let schedule = match (every_seconds, cron_expr) {
        (Some(seconds), _) =>
          if seconds > 0 {
            Some(CronSchedule::every(seconds * 1000))
          } else {
            None
          }
        (None, Some(expr)) =>
          if expr.is_empty() {
            None
          } else {
            Some(CronSchedule::cron(expr))
          }
        _ => None
      }
      match schedule {
        Some(schedule) =>
          Ok(
            Add(
              name=crop_name(msg, 30),
              schedule~,
              message=msg,
              channel~,
              chat_id~,
            ),
          )
        None => Err("Error: either every_seconds or cron_expr is required")
      }
    }
    None => Err("Error: message is required for add")
  }
}

///|
fn cron_kind_label(kind : CronScheduleKind) -> String {
  match kind {
    At => "at"
    Every => "every"
    Cron => "cron"
  }
}

///|
fn resolve_target(explicit : String?, fallback : String) -> String {
  match explicit {
    Some(value) => if value.is_empty() { fallback } else { value }
    None => fallback
  }
}

///|
fn fallback_origin(channel : String) -> String {
  if channel.is_empty() {
    "cli"
  } else {
    channel
  }
}

///|
fn fallback_chat_id(chat_id : String) -> String {
  if chat_id.is_empty() {
    "direct"
  } else {
    chat_id
  }
}

///|
fn crop_name(text : String, max_len : Int) -> String {
  if text.length() <= max_len {
    text
  } else {
    text.unsafe_substring(start=0, end=max_len)
  }
}

///|
fn tool_required_string(obj : Json, key : String) -> String? {
  match obj {
    Object(map) =>
      match map.get(key) {
        Some(String(s)) => Some(s)
        _ => None
      }
    _ => None
  }
}

///|
fn tool_optional_string(obj : Json, key : String) -> String? {
  tool_required_string(obj, key)
}

///|
fn tool_optional_int(obj : Json, key : String) -> Int? {
  match obj {
    Object(map) =>
      match map.get(key) {
        Some(Number(n, ..)) => Some(n.to_int())
        _ => None
      }
    _ => None
  }
}
