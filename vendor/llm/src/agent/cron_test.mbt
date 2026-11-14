///|
test "compute_next_run handles at and every schedules" {
  let at_future = compute_next_run(CronSchedule::at(1200), 1000)
  let at_past = compute_next_run(CronSchedule::at(900), 1000)
  let every = compute_next_run(CronSchedule::every(5000), 1000)
  @debug.debug_inspect(at_future, content="Some(1200)")
  @debug.debug_inspect(at_past, content="None")
  @debug.debug_inspect(every, content="Some(6000)")
}

///|
test "cron service runs due every job and updates state" {
  let now = Ref(1000)
  let executed : Array[String] = []
  let service = CronService::new(
    clock=fn() { now.val },
    on_job=Some(fn(job) {
      executed.push(job.payload.message)
      Some("ok")
    }),
  )
  let job = service.add_job("tick", CronSchedule::every(1000), "ping")
  @debug.debug_inspect(job.state.next_run_at_ms, content="Some(2000)")
  now.val = 2500
  let count = service.run_due()
  assert_eq(count, 1)
  @debug.debug_inspect(executed, content="[\"ping\"]")
  let jobs = service.list_jobs()
  assert_eq(jobs.length(), 1)
  @debug.debug_inspect(jobs[0].state.last_status, content="Some(\"ok\")")
  @debug.debug_inspect(jobs[0].state.last_error, content="None")
}

///|
test "cron service removes one-shot job when delete_after_run is true" {
  let now = Ref(1000)
  let service = CronService::new(clock=fn() { now.val })
  let job = service.add_job(
    "once",
    CronSchedule::at(1500),
    "one",
    delete_after_run=true,
  )
  assert_eq(job.delete_after_run, true)
  now.val = 2000
  ignore(service.run_due())
  let all = service.list_jobs(include_disabled=true)
  assert_eq(all.length(), 0)
}

///|
test "cron service enable and remove" {
  let now = Ref(1000)
  let service = CronService::new(clock=fn() { now.val })
  let job = service.add_job("job", CronSchedule::every(1000), "hi")
  let disabled = service.enable_job(job.id, enabled=false)
  match disabled {
    Some(j) => assert_eq(j.enabled, false)
    None => assert_true(false)
  }
  assert_eq(service.list_jobs().length(), 0)
  assert_true(service.remove_job(job.id))
  assert_true(!service.remove_job(job.id))
}
