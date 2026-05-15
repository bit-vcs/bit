///| Relay watch, status, presence, and review commands.

///|
fn relay_safe_sender() -> String {
  match @sys.get_env_var("BIT_RELAY_SENDER") {
    Some(s) => s
    None => {
      // Extract name from git author config, URL-safe
      let author = get_author_string()
      let buf = StringBuilder::new()
      for c in author {
        if c == '<' {
          break
        }
        if c == ' ' || c == '@' || c == '>' {
          continue
        }
        buf.write_char(c)
      }
      let result = buf.to_string()
      if result.length() > 0 {
        result
      } else {
        "anonymous"
      }
    }
  }
}

///|
fn relay_default_base_url() -> String {
  match @sys.get_env_var("BIT_RELAY_URL") {
    Some(url) =>
      // Strip relay+ prefix if present
      if url.has_prefix("relay+") {
        String::unsafe_substring(url, start=6, end=url.length())
      } else {
        url
      }
    None => "https://bit-relay.mizchi.workers.dev"
  }
}

///|
fn relay_resolve_room_arg(arg : String) -> (String, String) {
  // Returns (base_url, room)
  if arg.has_prefix("relay+https://") || arg.has_prefix("relay+http://") {
    // Full URL with ?room= parameter
    let url = String::unsafe_substring(arg, start=6, end=arg.length())
    let room_idx = url.find("room=")
    match room_idx {
      Some(idx) => {
        let room_start = idx + 5
        let mut room_end = url.length()
        let chars = url.to_array()
        for i = room_start; i < chars.length(); i = i + 1 {
          if chars[i] == '&' {
            room_end = i
            break
          }
        }
        let room = String::unsafe_substring(url, start=room_start, end=room_end)
        let base_end = match url.find("?") {
          Some(i) => i
          None => url.length()
        }
        let base = String::unsafe_substring(url, start=0, end=base_end)
        (base, room)
      }
      None => (url, "default")
    }
  } else {
    // Namespace like "owner/repo"
    (relay_default_base_url(), arg)
  }
}

///|
/// Watch a relay room for real-time updates (poll-based).
async fn handle_relay_watch(args : Array[String]) -> Unit raise Error {
  let mut room_arg = if args.length() > 0 && !args[0].has_prefix("-") {
    args[0]
  } else {
    "."
  }
  let mut interval_sec = 3
  let start = if room_arg == "." { 0 } else { 1 }
  let mut i = start
  while i < args.length() {
    if (args[i] == "--interval" || args[i] == "-i") && i + 1 < args.length() {
      interval_sec = @string.parse_int(args[i + 1]) catch { _ => 3 }
      i += 2
      continue
    }
    i += 1
  }
  if room_arg == "." {
    // Derive from current repo
    let fs = OsFs::new()
    let root = get_work_root()
    let git_dir = resolve_git_dir(fs, root)
    room_arg = issue_derive_relay_room(fs, git_dir)
  }
  let (base_url, room) = relay_resolve_room_arg(room_arg)
  print_line("Watching room '\{room}' on \{base_url}")
  print_line("Press Ctrl-C to stop.\n")
  let mut cursor = 0
  // Initial fetch to get current position
  let init_url = "\{base_url}/api/v1/poll?room=\{room}&after=0&limit=100"
  let (init_res, init_data) = @bitnative.native_http_get(init_url, {})
  if init_res.code == 200 {
    let text = @utf8.decode_lossy(init_data[:])
    let parsed = @json.parse(text) catch { _ => Json::null() }
    match parsed {
      Object(obj) => {
        match obj.get("next_cursor") {
          Some(Number(n, ..)) => cursor = n.to_int()
          _ => ()
        }
        // Show recent messages
        match obj.get("envelopes") {
          Some(Array(items)) =>
            for item in items {
              relay_watch_print_envelope(item)
            }
          _ => ()
        }
      }
      _ => ()
    }
  }
  // Poll loop (uses interval as timeout for long-poll behavior)
  ignore(interval_sec)
  while true {
    let poll_url = "\{base_url}/api/v1/poll?room=\{room}&after=\{cursor}&limit=50"
    let (res, data) = @bitnative.native_http_get(poll_url, {})
    if res.code != 200 {
      continue
    }
    let text = @utf8.decode_lossy(data[:])
    let parsed = @json.parse(text) catch { _ => continue }
    match parsed {
      Object(obj) => {
        match obj.get("next_cursor") {
          Some(Number(n, ..)) => cursor = n.to_int()
          _ => ()
        }
        match obj.get("envelopes") {
          Some(Array(items)) =>
            for item in items {
              relay_watch_print_envelope(item)
            }
          _ => ()
        }
      }
      _ => ()
    }
  }
}

///|
fn relay_watch_print_envelope(item : Json) -> Unit {
  let obj = match item {
    Object(o) => o
    _ => return
  }
  let sender = match obj.get("sender") {
    Some(String(s)) => s
    _ => "?"
  }
  let topic = match obj.get("topic") {
    Some(String(s)) => s
    _ => "?"
  }
  let id = match obj.get("id") {
    Some(String(s)) => s
    _ => "?"
  }
  // Extract summary from payload
  let summary = match obj.get("payload") {
    Some(Object(payload)) =>
      match payload.get("kind") {
        Some(String(k)) =>
          if k == "hub.record" {
            relay_watch_summarize_hub_record(payload)
          } else {
            k
          }
        _ =>
          match payload.get("title") {
            Some(String(t)) => t
            _ => ""
          }
      }
    _ => ""
  }
  let short_id = if id.length() > 8 {
    String::unsafe_substring(id, start=0, end=8)
  } else {
    id
  }
  if summary.length() > 0 {
    println("[\{sender}] \{topic} \{short_id} — \{summary}")
  } else {
    println("[\{sender}] \{topic} \{short_id}")
  }
}

///|
fn relay_watch_summarize_hub_record(payload : Map[String, Json]) -> String {
  match payload.get("record") {
    Some(String(record_str)) => {
      // Extract title from work-item record
      let mut title = ""
      for line_view in record_str.split("\n") {
        let line = line_view.to_string()
        if line.has_prefix("title: ") {
          title = String::unsafe_substring(line, start=7, end=line.length())
          break
        }
      }
      if title.length() > 0 {
        title
      } else {
        "hub.record"
      }
    }
    _ => "hub.record"
  }
}

///|
/// Show who is active in a relay room.
async fn handle_relay_status(args : Array[String]) -> Unit raise Error {
  let mut room_arg = if args.length() > 0 && !args[0].has_prefix("-") {
    args[0]
  } else {
    "."
  }
  if room_arg == "." {
    let fs = OsFs::new()
    let root = get_work_root()
    let git_dir = resolve_git_dir(fs, root)
    room_arg = issue_derive_relay_room(fs, git_dir)
  }
  let (base_url, room) = relay_resolve_room_arg(room_arg)
  // Presence
  let presence_url = "\{base_url}/api/v1/presence?room=\{room}"
  let (pres_res, pres_data) = @bitnative.native_http_get(presence_url, {})
  if pres_res.code == 200 {
    let text = @utf8.decode_lossy(pres_data[:])
    let parsed = @json.parse(text) catch { _ => Json::null() }
    match parsed {
      Object(obj) =>
        match obj.get("participants") {
          Some(Array(items)) =>
            if items.length() == 0 {
              print_line("Room '\{room}': no active participants")
            } else {
              print_line("Room '\{room}': \{items.length()} participant(s)")
              for item in items {
                match item {
                  Object(p) => {
                    let pid = match p.get("participant_id") {
                      Some(String(s)) => s
                      _ => "?"
                    }
                    let status = match p.get("status") {
                      Some(String(s)) => s
                      _ => "unknown"
                    }
                    print_line("  \{pid} (\{status})")
                  }
                  _ => ()
                }
              }
            }
          _ => print_line("Room '\{room}': no presence data")
        }
      _ => eprint_line("Failed to fetch presence")
    }
  } else {
    eprint_line("Presence request failed: HTTP \{pres_res.code}")
  }
  // Recent activity summary
  let poll_url = "\{base_url}/api/v1/poll?room=\{room}&after=0&limit=5"
  let (poll_res, poll_data) = @bitnative.native_http_get(poll_url, {})
  if poll_res.code == 200 {
    let text = @utf8.decode_lossy(poll_data[:])
    let parsed = @json.parse(text) catch { _ => Json::null() }
    match parsed {
      Object(obj) =>
        match obj.get("envelopes") {
          Some(Array(items)) =>
            if items.length() > 0 {
              print_line("\nRecent activity:")
              for item in items {
                relay_watch_print_envelope(item)
              }
            }
          _ => ()
        }
      _ => ()
    }
  }
}
