///| PR workflow records and merge-gate integration.

///|
pub(all) enum PrWorkflowStatus {
  Pending
  Running
  Success
  Failed
} derive(Eq)

///|
pub fn PrWorkflowStatus::to_string(self : PrWorkflowStatus) -> String {
  match self {
    Pending => "pending"
    Running => "running"
    Success => "success"
    Failed => "failed"
  }
}

///|
pub impl Show for PrWorkflowStatus with output(self, logger) {
  logger.write_string(self.to_string())
}

///|
pub fn parse_pr_workflow_status(value : String) -> PrWorkflowStatus? {
  match value.to_lower() {
    "pending" => Some(PrWorkflowStatus::Pending)
    "running" => Some(PrWorkflowStatus::Running)
    "success" | "passed" => Some(PrWorkflowStatus::Success)
    "failed" | "failure" => Some(PrWorkflowStatus::Failed)
    _ => None
  }
}

///|
pub struct PrWorkflowResult {
  pr_id : String
  task : String
  status : PrWorkflowStatus
  workspace_fingerprint : String
  txn_id : String?
  author : String
  updated_at : Int64
  summary : String
}

///|
pub fn PrWorkflowResult::new(
  pr_id : String,
  task : String,
  status : PrWorkflowStatus,
  workspace_fingerprint : String,
  author : String,
  updated_at : Int64,
  txn_id? : String? = None,
  summary? : String = "",
) -> PrWorkflowResult {
  {
    pr_id,
    task,
    status,
    workspace_fingerprint,
    txn_id,
    author,
    updated_at,
    summary,
  }
}

///|
pub fn PrWorkflowResult::pr_id(self : PrWorkflowResult) -> String {
  self.pr_id
}

///|
pub fn PrWorkflowResult::task(self : PrWorkflowResult) -> String {
  self.task
}

///|
pub fn PrWorkflowResult::status(self : PrWorkflowResult) -> PrWorkflowStatus {
  self.status
}

///|
pub fn PrWorkflowResult::workspace_fingerprint(
  self : PrWorkflowResult,
) -> String {
  self.workspace_fingerprint
}

///|
pub fn PrWorkflowResult::txn_id(self : PrWorkflowResult) -> String? {
  self.txn_id
}

///|
pub fn PrWorkflowResult::author(self : PrWorkflowResult) -> String {
  self.author
}

///|
pub fn PrWorkflowResult::updated_at(self : PrWorkflowResult) -> Int64 {
  self.updated_at
}

///|
pub fn PrWorkflowResult::summary(self : PrWorkflowResult) -> String {
  self.summary
}

///|
fn workflow_json_string(
  obj : Map[String, Json],
  key : String,
  fallback : String,
) -> String {
  match obj.get(key) {
    Some(Json::String(value)) => value
    _ => fallback
  }
}

///|
fn with_workflow_timestamp(
  workflow : PrWorkflowResult,
  updated_at : Int64,
) -> PrWorkflowResult {
  PrWorkflowResult::new(
    workflow.pr_id(),
    workflow.task(),
    workflow.status(),
    workflow.workspace_fingerprint(),
    workflow.author(),
    updated_at,
    txn_id=workflow.txn_id(),
    summary=workflow.summary(),
  )
}

///|
pub fn PrWorkflowResult::serialize(self : PrWorkflowResult) -> String {
  let obj : Map[String, Json] = {}
  obj["pr_id"] = Json::string(self.pr_id)
  obj["task"] = Json::string(self.task)
  obj["status"] = Json::string(self.status.to_string())
  obj["workspace_fingerprint"] = Json::string(self.workspace_fingerprint)
  obj["author"] = Json::string(self.author)
  obj["summary"] = Json::string(self.summary)
  match self.txn_id {
    Some(txn_id) => obj["txn_id"] = Json::string(txn_id)
    None => ()
  }
  Json::object(obj).stringify()
}

///|
pub fn parse_pr_workflow_result(
  text : String,
) -> PrWorkflowResult raise PrError {
  let parsed = @json.parse(text) catch {
    err =>
      raise PrError::InvalidFormat(
        "Invalid PR workflow payload JSON: \{err.to_string()}",
      )
  }
  guard parsed is Json::Object(obj) else {
    raise PrError::InvalidFormat("PR workflow payload must be JSON object")
  }
  let pr_id = workflow_json_string(obj, "pr_id", "")
  if pr_id.length() == 0 {
    raise PrError::InvalidFormat("Missing pr_id in PR workflow payload")
  }
  let task = workflow_json_string(obj, "task", "")
  if task.length() == 0 {
    raise PrError::InvalidFormat("Missing task in PR workflow payload")
  }
  let status_raw = workflow_json_string(obj, "status", "")
  guard parse_pr_workflow_status(status_raw) is Some(status) else {
    raise PrError::InvalidFormat("Unknown PR workflow status: \{status_raw}")
  }
  let workspace_fingerprint = workflow_json_string(
    obj, "workspace_fingerprint", "",
  )
  let author = workflow_json_string(obj, "author", "unknown")
  let txn_id = match obj.get("txn_id") {
    Some(Json::String(value)) =>
      if value.length() == 0 {
        None
      } else {
        Some(value)
      }
    _ => None
  }
  let summary = workflow_json_string(obj, "summary", "")
  PrWorkflowResult::new(
    pr_id,
    task,
    status,
    workspace_fingerprint,
    author,
    0L,
    txn_id~,
    summary~,
  )
}

///|
pub fn pr_workflow_prefix(pr_id : String) -> String {
  "hub/pr/" + pr_id + "/workflow/"
}

///|
fn workflow_task_key_suffix(task : String) -> String {
  let (id, _compressed) = @bit.create_blob_string("hub-pr-workflow:" + task)
  let hex = id.to_hex()
  String::unsafe_substring(hex, start=0, end=12)
}

///|
pub fn pr_workflow_key(pr_id : String, task : String) -> String {
  pr_workflow_prefix(pr_id) + workflow_task_key_suffix(task)
}

///|
pub fn Hub::record_pr_workflow(
  self : Hub,
  objects : &@lib.ObjectStore,
  refs : &@lib.RefStore,
  clock : &@lib.Clock,
  pr_id : String,
  task : String,
  status : PrWorkflowStatus,
  workspace_fingerprint : String,
  author : String,
  txn_id? : String? = None,
  summary? : String = "",
) -> PrWorkflowResult raise @bit.GitError {
  if task.length() == 0 {
    raise @bit.GitError::InvalidObject("PR workflow task is required")
  }
  if self.get_pr(objects, pr_id) is None {
    raise @bit.GitError::InvalidObject("PR not found: \{pr_id}")
  }
  let draft = PrWorkflowResult::new(
    pr_id,
    task,
    status,
    workspace_fingerprint,
    author,
    clock.now(),
    txn_id~,
    summary~,
  )
  let record = self.store.put_record(
    objects,
    refs,
    clock,
    pr_workflow_key(pr_id, task),
    "hub.pr.workflow",
    draft.serialize(),
    self.store.node_id(),
  )
  with_workflow_timestamp(draft, record.timestamp)
}

///|
pub fn Hub::list_pr_workflows(
  self : Hub,
  objects : &@lib.ObjectStore,
  pr_id : String,
) -> Array[PrWorkflowResult] {
  let prefix = pr_workflow_prefix(pr_id)
  let records = self.store.list_records(objects, prefix)
  let latest_by_task : Map[String, PrWorkflowResult] = {}
  for record in records {
    if record.kind != "hub.pr.workflow" {
      continue
    }
    let parsed = parse_pr_workflow_result(record.payload) catch {
      _ => continue
    }
    if parsed.pr_id() != pr_id {
      continue
    }
    let workflow = with_workflow_timestamp(parsed, record.timestamp)
    match latest_by_task.get(workflow.task()) {
      Some(previous) =>
        if previous.updated_at() <= workflow.updated_at() {
          latest_by_task[workflow.task()] = workflow
        }
      None => latest_by_task[workflow.task()] = workflow
    }
  }
  let out : Array[PrWorkflowResult] = []
  for _, workflow in latest_by_task {
    out.push(workflow)
  }
  out.sort_by(fn(a, b) {
    if a.task() < b.task() {
      -1
    } else if a.task() > b.task() {
      1
    } else {
      0
    }
  })
  out
}
