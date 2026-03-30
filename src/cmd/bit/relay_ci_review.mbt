///| Relay CI status and review commands.

///|
/// Push CI status to relay room.
/// Usage: bit relay ci push <owner/repo> --ref <ref> --status <pass|fail|pending> [--url <ci-url>]
/// Pull CI status: bit relay ci pull <owner/repo> [--ref <ref>]
async fn handle_relay_ci(args : Array[String]) -> Unit raise Error {
  if args.length() == 0 {
    eprint_line("Usage: bit relay ci <push|pull> <owner/repo> [options]")
    @sys.exit(1)
  }
  match args[0] {
    "push" => handle_relay_ci_push(collect_args(args, 1))
    "pull" => handle_relay_ci_pull(collect_args(args, 1))
    _ => {
      eprint_line("Usage: bit relay ci <push|pull> <owner/repo> [options]")
      @sys.exit(1)
    }
  }
}

///|
async fn handle_relay_ci_push(args : Array[String]) -> Unit raise Error {
  let mut room_arg = ""
  let mut ref_name = "HEAD"
  let mut status = ""
  let mut ci_url = ""
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--ref" if i + 1 < args.length() => {
        ref_name = args[i + 1]
        i += 2
        continue
      }
      "--status" | "-s" if i + 1 < args.length() => {
        status = args[i + 1]
        i += 2
        continue
      }
      "--url" if i + 1 < args.length() => {
        ci_url = args[i + 1]
        i += 2
        continue
      }
      _ if !(arg.has_prefix("-")) && room_arg.length() == 0 => room_arg = arg
      _ => ()
    }
    i += 1
  }
  if room_arg.length() == 0 || status.length() == 0 {
    eprint_line(
      "Usage: bit relay ci push <owner/repo> --status <pass|fail|pending> [--ref <ref>] [--url <url>]",
    )
    @sys.exit(1)
  }
  let (base_url, room) = relay_resolve_room_arg(room_arg)
  let sender = match @sys.get_env_var("BIT_RELAY_SENDER") {
    Some(s) => s
    None => "ci"
  }
  let payload : Map[String, Json] = {}
  payload["kind"] = Json::string("ci.status")
  payload["ref"] = Json::string(ref_name)
  payload["status"] = Json::string(status)
  if ci_url.length() > 0 {
    payload["url"] = Json::string(ci_url)
  }
  let id = "ci-\{ref_name}-\{status}"
  let publish_url = "\{base_url}/api/v1/publish?room=\{room}&sender=\{sender}&topic=ci.status&id=\{id}"
  let body = Json::object(payload).stringify()
  let (res, _) = @bitnative.native_http_post(
    publish_url,
    Bytes::from_array(@utf8.encode(body).to_array()),
    { "Content-Type": "application/json" },
  )
  if res.code == 200 {
    print_line("CI status '\{status}' pushed for \{ref_name}")
  } else {
    eprint_line("Failed to push CI status: HTTP \{res.code}")
    @sys.exit(1)
  }
}

///|
async fn handle_relay_ci_pull(args : Array[String]) -> Unit raise Error {
  let mut room_arg = ""
  let mut ref_filter = ""
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--ref" if i + 1 < args.length() => {
        ref_filter = args[i + 1]
        i += 2
        continue
      }
      _ if !(arg.has_prefix("-")) && room_arg.length() == 0 => room_arg = arg
      _ => ()
    }
    i += 1
  }
  if room_arg.length() == 0 {
    eprint_line("Usage: bit relay ci pull <owner/repo> [--ref <ref>]")
    @sys.exit(1)
  }
  let (base_url, room) = relay_resolve_room_arg(room_arg)
  let poll_url = "\{base_url}/api/v1/poll?room=\{room}&after=0&limit=200"
  let (res, data) = @bitnative.native_http_get(poll_url, {})
  if res.code != 200 {
    eprint_line("Failed to fetch CI status: HTTP \{res.code}")
    @sys.exit(1)
  }
  let text = @utf8.decode_lossy(data[:])
  let parsed = @json.parse(text) catch { _ => Json::null() }
  // Collect latest CI status per ref
  let ci_statuses : Map[String, (String, String)] = {} // ref → (status, url)
  match parsed {
    Object(obj) =>
      match obj.get("envelopes") {
        Some(Array(items)) =>
          for item in items {
            match item {
              Object(env) =>
                match env.get("topic") {
                  Some(String(t)) if t == "ci.status" =>
                    match env.get("payload") {
                      Some(Object(p)) => {
                        let r = match p.get("ref") {
                          Some(String(s)) => s
                          _ => continue
                        }
                        let s = match p.get("status") {
                          Some(String(s)) => s
                          _ => continue
                        }
                        let u = match p.get("url") {
                          Some(String(s)) => s
                          _ => ""
                        }
                        ci_statuses[r] = (s, u)
                      }
                      _ => ()
                    }
                  _ => ()
                }
              _ => ()
            }
          }
        _ => ()
      }
    _ => ()
  }
  if ci_statuses.length() == 0 {
    print_line("No CI status found")
    return
  }
  for ref_name, entry in ci_statuses {
    let (s, u) = entry
    if ref_filter.length() > 0 && ref_name != ref_filter {
      continue
    }
    let icon = match s {
      "pass" => "✓"
      "fail" => "✗"
      _ => "○"
    }
    if u.length() > 0 {
      print_line("\{icon} \{ref_name}: \{s} (\{u})")
    } else {
      print_line("\{icon} \{ref_name}: \{s}")
    }
  }
}

///|
/// Review request/submit via relay.
/// Usage: bit relay review request <owner/repo> --pr <pr-id> [--reviewer <name>]
///        bit relay review submit <owner/repo> --pr <pr-id> --verdict <approve|reject|comment>
///        bit relay review list <owner/repo> --pr <pr-id>
async fn handle_relay_review(args : Array[String]) -> Unit raise Error {
  if args.length() == 0 {
    eprint_line(
      "Usage: bit relay review <request|submit|list> <owner/repo> [options]",
    )
    @sys.exit(1)
  }
  match args[0] {
    "request" => handle_relay_review_request(collect_args(args, 1))
    "submit" => handle_relay_review_submit(collect_args(args, 1))
    "list" => handle_relay_review_list(collect_args(args, 1))
    _ => {
      eprint_line(
        "Usage: bit relay review <request|submit|list> <owner/repo> [options]",
      )
      @sys.exit(1)
    }
  }
}

///|
async fn handle_relay_review_request(args : Array[String]) -> Unit raise Error {
  let mut room_arg = ""
  let mut pr_id = ""
  let mut reviewer = ""
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--pr" if i + 1 < args.length() => {
        pr_id = args[i + 1]
        i += 2
        continue
      }
      "--reviewer" | "-r" if i + 1 < args.length() => {
        reviewer = args[i + 1]
        i += 2
        continue
      }
      _ if !(arg.has_prefix("-")) && room_arg.length() == 0 => room_arg = arg
      _ => ()
    }
    i += 1
  }
  if room_arg.length() == 0 || pr_id.length() == 0 {
    eprint_line(
      "Usage: bit relay review request <owner/repo> --pr <pr-id> [--reviewer <name>]",
    )
    @sys.exit(1)
  }
  let (base_url, room) = relay_resolve_room_arg(room_arg)
  let sender = relay_safe_sender()
  let payload : Map[String, Json] = {}
  payload["kind"] = Json::string("review.request")
  payload["pr_id"] = Json::string(pr_id)
  payload["requester"] = Json::string(sender)
  if reviewer.length() > 0 {
    payload["reviewer"] = Json::string(reviewer)
  }
  let id = "review-req-\{pr_id}"
  let publish_url = "\{base_url}/api/v1/publish?room=\{room}&sender=\{sender}&topic=review.request&id=\{id}"
  let body = Json::object(payload).stringify()
  let (res, _) = @bitnative.native_http_post(
    publish_url,
    Bytes::from_array(@utf8.encode(body).to_array()),
    { "Content-Type": "application/json" },
  )
  if res.code == 200 {
    if reviewer.length() > 0 {
      print_line("Review requested from \{reviewer} for PR \{pr_id}")
    } else {
      print_line("Review requested for PR \{pr_id}")
    }
  } else {
    eprint_line("Failed: HTTP \{res.code}")
    @sys.exit(1)
  }
}

///|
async fn handle_relay_review_submit(args : Array[String]) -> Unit raise Error {
  let mut room_arg = ""
  let mut pr_id = ""
  let mut verdict = ""
  let mut comment = ""
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--pr" if i + 1 < args.length() => {
        pr_id = args[i + 1]
        i += 2
        continue
      }
      "--verdict" | "-v" if i + 1 < args.length() => {
        verdict = args[i + 1]
        i += 2
        continue
      }
      "--comment" | "-m" if i + 1 < args.length() => {
        comment = args[i + 1]
        i += 2
        continue
      }
      _ if !(arg.has_prefix("-")) && room_arg.length() == 0 => room_arg = arg
      _ => ()
    }
    i += 1
  }
  if room_arg.length() == 0 || pr_id.length() == 0 || verdict.length() == 0 {
    eprint_line(
      "Usage: bit relay review submit <owner/repo> --pr <pr-id> --verdict <approve|reject|comment>",
    )
    @sys.exit(1)
  }
  let (base_url, room) = relay_resolve_room_arg(room_arg)
  let sender = relay_safe_sender()
  // Publish review as a relay message (avoids signature requirement on review API)
  let payload : Map[String, Json] = {}
  payload["kind"] = Json::string("review.verdict")
  payload["pr_id"] = Json::string(pr_id)
  payload["verdict"] = Json::string(verdict)
  payload["reviewer"] = Json::string(sender)
  if comment.length() > 0 {
    payload["comment"] = Json::string(comment)
  }
  let id = "review-\{pr_id}-\{verdict}"
  let publish_url = "\{base_url}/api/v1/publish?room=\{room}&sender=\{sender}&topic=review.verdict&id=\{id}"
  let body = Json::object(payload).stringify()
  let (res, _) = @bitnative.native_http_post(
    publish_url,
    Bytes::from_array(@utf8.encode(body).to_array()),
    { "Content-Type": "application/json" },
  )
  if res.code == 200 {
    print_line("Review '\{verdict}' submitted for PR \{pr_id}")
  } else {
    eprint_line("Failed: HTTP \{res.code}")
    @sys.exit(1)
  }
}

///|
async fn handle_relay_review_list(args : Array[String]) -> Unit raise Error {
  let mut room_arg = ""
  let mut pr_id = ""
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--pr" if i + 1 < args.length() => {
        pr_id = args[i + 1]
        i += 2
        continue
      }
      _ if !(arg.has_prefix("-")) && room_arg.length() == 0 => room_arg = arg
      _ => ()
    }
    i += 1
  }
  if room_arg.length() == 0 || pr_id.length() == 0 {
    eprint_line("Usage: bit relay review list <owner/repo> --pr <pr-id>")
    @sys.exit(1)
  }
  let (base_url, room) = relay_resolve_room_arg(room_arg)
  // Fetch reviews from poll API (review.verdict topic messages)
  let poll_url = "\{base_url}/api/v1/poll?room=\{room}&after=0&limit=200"
  let (res, data) = @bitnative.native_http_get(poll_url, {})
  if res.code != 200 {
    eprint_line("Failed: HTTP \{res.code}")
    @sys.exit(1)
  }
  let text = @utf8.decode_lossy(data[:])
  let parsed = @json.parse(text) catch { _ => Json::null() }
  let mut found = false
  match parsed {
    Object(obj) =>
      match obj.get("envelopes") {
        Some(Array(items)) =>
          for item in items {
            match item {
              Object(env) =>
                match env.get("topic") {
                  Some(String(t)) if t == "review.verdict" ||
                    t == "review.request" =>
                    match env.get("payload") {
                      Some(Object(p)) => {
                        let msg_pr = match p.get("pr_id") {
                          Some(String(s)) => s
                          _ => continue
                        }
                        if msg_pr != pr_id {
                          continue
                        }
                        let kind = match p.get("kind") {
                          Some(String(s)) => s
                          _ => continue
                        }
                        if kind == "review.verdict" {
                          let reviewer = match p.get("reviewer") {
                            Some(String(s)) => s
                            _ => "?"
                          }
                          let v = match p.get("verdict") {
                            Some(String(s)) => s
                            _ => "?"
                          }
                          let icon = match v {
                            "approve" => "✓"
                            "reject" | "deny" => "✗"
                            _ => "○"
                          }
                          print_line("\{icon} \{reviewer}: \{v}")
                          found = true
                        } else if kind == "review.request" {
                          let requester = match p.get("requester") {
                            Some(String(s)) => s
                            _ => "?"
                          }
                          let target = match p.get("reviewer") {
                            Some(String(s)) => " → " + s
                            _ => ""
                          }
                          print_line(
                            "⊕ \{requester} requested review\{target}",
                          )
                          found = true
                        }
                      }
                      _ => ()
                    }
                  _ => ()
                }
              _ => ()
            }
          }
        _ => ()
      }
    _ => ()
  }
  if !(found) {
    print_line("No reviews for PR \{pr_id}")
  }
}
