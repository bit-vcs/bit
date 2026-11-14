///|
fn tool_actions_test_json_get_field(obj : Json, key : String) -> Json? {
  match obj {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn tool_actions_test_json_get_string(obj : Json, key : String) -> String? {
  match tool_actions_test_json_get_field(obj, key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
test "runtime tool context mutates channel/chat_id" {
  let ctx = RuntimeToolContext::new(channel="cli", chat_id="direct")
  assert_eq(ctx.channel, "cli")
  assert_eq(ctx.chat_id, "direct")
  ctx.set("telegram", "42")
  assert_eq(ctx.channel, "telegram")
  assert_eq(ctx.chat_id, "42")
}

///|
test "tool defs keep expected names and required fields" {
  let msg = message_tool_def()
  let spawn = spawn_tool_def()
  let cron = cron_tool_def()
  assert_eq(msg.name, "message")
  assert_eq(spawn.name, "spawn")
  assert_eq(cron.name, "cron")
  @debug.debug_inspect(
    tool_actions_test_json_get_string(msg.input_schema, "type"),
    content="Some(\"object\")",
  )
}

///|
test "resolve_message_tool validates and applies fallback" {
  let ctx = RuntimeToolContext::new(channel="telegram", chat_id="42")
  match resolve_message_tool({ "content": ToJson::to_json("hello") }, ctx) {
    Ok(plan) => {
      assert_eq(plan.content, "hello")
      assert_eq(plan.channel, "telegram")
      assert_eq(plan.chat_id, "42")
    }
    Err(_) => assert_true(false)
  }
  match resolve_message_tool({}, ctx) {
    Ok(_) => assert_true(false)
    Err(err) => assert_eq(err, "Error: content is required")
  }
}

///|
test "resolve_spawn_tool validates and sets default origin" {
  let ctx = RuntimeToolContext::new()
  match resolve_spawn_tool({ "task": ToJson::to_json("collect logs") }, ctx) {
    Ok(plan) => {
      assert_eq(plan.task, "collect logs")
      @debug.debug_inspect(plan.label, content="None")
      assert_eq(plan.origin_channel, "cli")
      assert_eq(plan.origin_chat_id, "direct")
    }
    Err(_) => assert_true(false)
  }
  match resolve_spawn_tool({}, ctx) {
    Ok(_) => assert_true(false)
    Err(err) => assert_eq(err, "Error: task is required")
  }
}

///|
test "resolve_cron_tool validates action and parameters" {
  let ctx = RuntimeToolContext::new(channel="telegram", chat_id="42")
  match
    resolve_cron_tool(
      {
        "action": ToJson::to_json("add"),
        "message": ToJson::to_json("daily reminder"),
        "every_seconds": ToJson::to_json((60)),
      },
      ctx,
    ) {
    Ok(Add(name~, schedule~, message~, channel~, chat_id~)) => {
      assert_eq(name, "daily reminder")
      assert_eq(message, "daily reminder")
      assert_eq(channel, "telegram")
      assert_eq(chat_id, "42")
      @debug.debug_inspect(schedule.every_ms, content="Some(60000)")
    }
    _ => assert_true(false)
  }
  match resolve_cron_tool({ "action": ToJson::to_json("list") }, ctx) {
    Ok(List) => ()
    _ => assert_true(false)
  }
  match
    resolve_cron_tool(
      { "action": ToJson::to_json("remove"), "job_id": ToJson::to_json("job-1") },
      ctx,
    ) {
    Ok(Remove(job_id~)) => assert_eq(job_id, "job-1")
    _ => assert_true(false)
  }
  match resolve_cron_tool({ "action": ToJson::to_json("noop") }, ctx) {
    Ok(_) => assert_true(false)
    Err(err) => assert_eq(err, "Unknown action: noop")
  }
  match resolve_cron_tool({ "action": ToJson::to_json("add") }, ctx) {
    Ok(_) => assert_true(false)
    Err(err) => assert_eq(err, "Error: message is required for add")
  }
}

///|
test "formatters keep existing agent_tools messages" {
  assert_eq(
    format_message_tool_result("telegram", "42"),
    "Message sent to telegram:42",
  )
  assert_eq(format_cron_remove_result("job-1", true), "Removed job job-1")
  assert_eq(format_cron_remove_result("job-1", false), "Job job-1 not found")
  let cron = CronService::new()
  assert_eq(format_cron_list(cron.list_jobs()), "No scheduled jobs.")
  let job = cron.add_job("daily", CronSchedule::every(60_000), "daily")
  let out = format_cron_list(cron.list_jobs())
  assert_true(out.contains("Scheduled jobs:"))
  assert_true(out.contains(job.id))
}
