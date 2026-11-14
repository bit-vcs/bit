///|
/// Lightweight subagent queue logic extracted from nanobot.

///|
pub struct SubagentTask {
  id : String
  label : String
  task : String
  origin_channel : String
  origin_chat_id : String
}

///|
pub struct SubagentRunResult {
  task : SubagentTask
  ok : Bool
  result : String
  announcement : String
}

///|
pub struct SubagentQueue {
  runner : (String) -> Result[String, String]
  mut id_counter : Int
  pending : Array[SubagentTask]
}

///|
pub fn SubagentQueue::new(
  runner : (String) -> Result[String, String],
) -> SubagentQueue {
  { runner, id_counter: 0, pending: [] }
}

///|
pub fn SubagentQueue::spawn(
  self : SubagentQueue,
  task : String,
  label? : String? = None,
  origin_channel? : String = "cli",
  origin_chat_id? : String = "direct",
) -> String {
  self.id_counter = self.id_counter + 1
  let task_id = "sub-" + self.id_counter.to_string()
  let display_label = match label {
    Some(l) => if l.is_empty() { task } else { l }
    None => task
  }
  self.pending.push({
    id: task_id,
    label: display_label,
    task,
    origin_channel,
    origin_chat_id,
  })
  "Subagent [" +
  display_label +
  "] started (id: " +
  task_id +
  "). I'll notify you when it completes."
}

///|
pub fn SubagentQueue::pending_count(self : SubagentQueue) -> Int {
  self.pending.length()
}

///|
pub fn SubagentQueue::run_next(self : SubagentQueue) -> SubagentRunResult? {
  if self.pending.is_empty() {
    return None
  }
  let task = self.pending.remove(0)
  let run = (self.runner)(task.task)
  let (result, ok) = match run {
    Ok(text) => (text, true)
    Err(err) => ("Error: " + err, false)
  }
  let announcement = build_announce_content(task, result, ok)
  Some({ task, ok, result, announcement })
}

///|
fn build_announce_content(
  task : SubagentTask,
  result : String,
  ok : Bool,
) -> String {
  let status = if ok { "completed successfully" } else { "failed" }
  "[Subagent '" +
  task.label +
  "' " +
  status +
  "]\n\nTask: " +
  task.task +
  "\n\nResult:\n" +
  result +
  "\n\nSummarize this naturally for the user. Keep it brief (1-2 sentences). Do not mention technical details like \"subagent\" or task IDs."
}
