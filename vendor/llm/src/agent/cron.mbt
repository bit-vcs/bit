///|
/// Cron service core logic extracted from nanobot.

///|
pub enum CronScheduleKind {
  At
  Every
  Cron
} derive(Eq)

///|
pub struct CronSchedule {
  kind : CronScheduleKind
  at_ms : Int?
  every_ms : Int?
  expr : String?
  tz : String?
}

///|
pub fn CronSchedule::at(at_ms : Int) -> CronSchedule {
  { kind: At, at_ms: Some(at_ms), every_ms: None, expr: None, tz: None }
}

///|
pub fn CronSchedule::every(every_ms : Int) -> CronSchedule {
  { kind: Every, at_ms: None, every_ms: Some(every_ms), expr: None, tz: None }
}

///|
pub fn CronSchedule::cron(expr : String, tz? : String? = None) -> CronSchedule {
  { kind: Cron, at_ms: None, every_ms: None, expr: Some(expr), tz }
}

///|
pub struct CronPayload {
  kind : String
  message : String
  deliver : Bool
  channel : String?
  to : String?
}

///|
pub fn CronPayload::agent_turn(
  message : String,
  deliver? : Bool = false,
  channel? : String? = None,
  to? : String? = None,
) -> CronPayload {
  { kind: "agent_turn", message, deliver, channel, to }
}

///|
pub struct CronJobState {
  mut next_run_at_ms : Int?
  mut last_run_at_ms : Int?
  mut last_status : String?
  mut last_error : String?
}

///|
pub fn CronJobState::new(next_run_at_ms : Int?) -> CronJobState {
  { next_run_at_ms, last_run_at_ms: None, last_status: None, last_error: None }
}

///|
pub struct CronJob {
  id : String
  name : String
  mut enabled : Bool
  schedule : CronSchedule
  payload : CronPayload
  state : CronJobState
  created_at_ms : Int
  mut updated_at_ms : Int
  delete_after_run : Bool
}

///|
pub fn compute_next_run(schedule : CronSchedule, now_ms : Int) -> Int? {
  match schedule.kind {
    At =>
      match schedule.at_ms {
        Some(at_ms) => if at_ms > now_ms { Some(at_ms) } else { None }
        None => None
      }
    Every =>
      match schedule.every_ms {
        Some(interval) =>
          if interval > 0 {
            Some(now_ms + interval)
          } else {
            None
          }
        None => None
      }
    Cron => compute_next_run_cron(schedule.expr, now_ms)
  }
}

///|
pub struct CronService {
  jobs : Array[CronJob]
  clock : () -> Int
  mut on_job : ((CronJob) -> String?)?
  mut id_counter : Int
}

///|
fn cron_default_clock() -> Int {
  0
}

///|
pub fn CronService::new(
  clock? : () -> Int = cron_default_clock,
  on_job? : ((CronJob) -> String?)? = None,
) -> CronService {
  { jobs: [], clock, on_job, id_counter: 0 }
}

///|
pub fn CronService::set_on_job(
  self : CronService,
  on_job : ((CronJob) -> String?)?,
) -> Unit {
  self.on_job = on_job
}

///|
pub fn CronService::list_jobs(
  self : CronService,
  include_disabled? : Bool = false,
) -> Array[CronJob] {
  let out : Array[CronJob] = []
  for job in self.jobs {
    if include_disabled || job.enabled {
      out.push(job)
    }
  }
  out.sort_by(fn(a, b) {
    next_sort_key(a.state.next_run_at_ms) -
    next_sort_key(b.state.next_run_at_ms)
  })
  out
}

///|
pub fn CronService::add_job(
  self : CronService,
  name : String,
  schedule : CronSchedule,
  message : String,
  deliver? : Bool = false,
  channel? : String? = None,
  to? : String? = None,
  delete_after_run? : Bool = false,
) -> CronJob {
  self.id_counter = self.id_counter + 1
  let now = (self.clock)()
  let job_id = "job-" + self.id_counter.to_string()
  let job = {
    id: job_id,
    name,
    enabled: true,
    schedule,
    payload: CronPayload::agent_turn(message, deliver~, channel~, to~),
    state: CronJobState::new(compute_next_run(schedule, now)),
    created_at_ms: now,
    updated_at_ms: now,
    delete_after_run,
  }
  self.jobs.push(job)
  job
}

///|
pub fn CronService::remove_job(self : CronService, job_id : String) -> Bool {
  let before = self.jobs.length()
  self.jobs.retain(fn(job) { job.id != job_id })
  self.jobs.length() < before
}

///|
pub fn CronService::enable_job(
  self : CronService,
  job_id : String,
  enabled? : Bool = true,
) -> CronJob? {
  for i in 0..<self.jobs.length() {
    if self.jobs[i].id == job_id {
      let job = self.jobs[i]
      let now = (self.clock)()
      job.enabled = enabled
      job.updated_at_ms = now
      job.state.next_run_at_ms = if enabled {
        compute_next_run(job.schedule, now)
      } else {
        None
      }
      self.jobs[i] = job
      return Some(job)
    }
  }
  None
}

///|
pub fn CronService::run_job(
  self : CronService,
  job_id : String,
  force? : Bool = false,
) -> Bool {
  for i in 0..<self.jobs.length() {
    if self.jobs[i].id == job_id {
      if !force && !self.jobs[i].enabled {
        return false
      }
      self.execute_job_at_index(i)
      return true
    }
  }
  false
}

///|
pub fn CronService::run_due(self : CronService) -> Int {
  let now = (self.clock)()
  let due_ids : Array[String] = []
  for job in self.jobs {
    match job.state.next_run_at_ms {
      Some(next_run) =>
        if job.enabled && now >= next_run {
          due_ids.push(job.id)
        }
      None => ()
    }
  }
  let mut count = 0
  for id in due_ids {
    if self.run_job(id, force=true) {
      count = count + 1
    }
  }
  count
}

///|
pub fn CronService::status(self : CronService) -> Map[String, Json] {
  let out : Map[String, Json] = Map([])
  out["enabled"] = ToJson::to_json(true)
  out["jobs"] = ToJson::to_json(self.jobs.length())
  out["next_wake_at_ms"] = match self.next_wake_at_ms() {
    Some(v) => ToJson::to_json(v)
    None => Json::null()
  }
  out
}

///|
fn CronService::next_wake_at_ms(self : CronService) -> Int? {
  let mut min_next : Int? = None
  for job in self.jobs {
    if !job.enabled {
      continue
    }
    match job.state.next_run_at_ms {
      Some(next_run) =>
        min_next = match min_next {
          Some(current_min) =>
            if next_run < current_min {
              Some(next_run)
            } else {
              Some(current_min)
            }
          None => Some(next_run)
        }
      None => ()
    }
  }
  min_next
}

///|
fn CronService::execute_job_at_index(self : CronService, i : Int) -> Unit {
  if i < 0 || i >= self.jobs.length() {
    return
  }
  let job = self.jobs[i]
  let started_at = (self.clock)()
  match self.on_job {
    Some(cb) => {
      ignore(cb(job))
      job.state.last_status = Some("ok")
      job.state.last_error = None
    }
    None => {
      job.state.last_status = Some("ok")
      job.state.last_error = None
    }
  }
  job.state.last_run_at_ms = Some(started_at)
  job.updated_at_ms = (self.clock)()
  if job.schedule.kind == At {
    if job.delete_after_run {
      ignore(self.jobs.remove(i))
      return
    } else {
      job.enabled = false
      job.state.next_run_at_ms = None
    }
  } else {
    job.state.next_run_at_ms = compute_next_run(job.schedule, (self.clock)())
  }
  self.jobs[i] = job
}

///|
fn next_sort_key(next : Int?) -> Int {
  match next {
    Some(v) => v
    None => 2147483647
  }
}

///|
fn compute_next_run_cron(expr : String?, now_ms : Int) -> Int? {
  let raw = match expr {
    Some(e) => e.trim().to_owned()
    None => return None
  }
  if raw == "* * * * *" {
    return Some(now_ms + 60_000)
  }
  None
}
