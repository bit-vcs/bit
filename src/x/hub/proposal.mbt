///|
/// Create a PR proposal record (notify-only event stream)
pub fn Hub::propose_pr(
  self : Hub,
  objects : &@lib.ObjectStore,
  refs : &@lib.RefStore,
  clock : &@lib.Clock,
  title : String,
  body : String,
  source_branch : String,
  target_branch : String,
  author : String,
  source_repo? : String? = None,
  source_ref? : String? = None,
  closes_issues? : Array[String] = [],
) -> PullRequest raise @bit.GitError {
  let timestamp = clock.now()
  let source_commit = refs.resolve(source_branch) catch {
    _ =>
      raise @bit.GitError::InvalidObject(
        "Cannot resolve source branch: \{source_branch}",
      )
  }
  guard source_commit is Some(src_id) else {
    raise @bit.GitError::InvalidObject(
      "Source branch not found: \{source_branch}",
    )
  }
  let target_commit = refs.resolve(target_branch) catch {
    _ =>
      raise @bit.GitError::InvalidObject(
        "Cannot resolve target branch: \{target_branch}",
      )
  }
  guard target_commit is Some(tgt_id) else {
    raise @bit.GitError::InvalidObject(
      "Target branch not found: \{target_branch}",
    )
  }
  let pr_id = generate_entity_id(
    "proposal-pr",
    author,
    timestamp,
    source_branch + "\n" + target_branch + "\n" + title + "\n" + body,
  )
  let pr = PullRequest::new(
    pr_id,
    title,
    body,
    source_branch,
    src_id,
    target_branch,
    tgt_id,
    author,
    timestamp,
    timestamp,
    PrState::Open,
    [],
    closes_issues~,
    source_repo~,
    source_ref~,
  )
  ignore(
    self.store.put_record(
      objects,
      refs,
      clock,
      pr_proposal_meta_key(pr_id),
      "pr-proposal",
      pr.serialize(),
      author,
    ),
  )
  pr
}

///|
/// Broadcast a feature completion notification (notify-only record)
pub fn Hub::broadcast_feature(
  self : Hub,
  objects : &@lib.ObjectStore,
  refs : &@lib.RefStore,
  clock : &@lib.Clock,
  branch_name : String,
  tip_commit : String,
  author : String,
  summary? : String = "",
  closes_issues? : Array[String] = [],
  session_url? : String? = None,
) -> Unit raise @bit.GitError {
  let timestamp = clock.now()
  let node_id = self.store.node_id()
  let key = "hub/broadcast/feature/" + branch_name + "/" + node_id
  // Build payload as serialized key-value text
  let sb = StringBuilder::new()
  sb.write_string("branch ")
  sb.write_string(branch_name)
  sb.write_char('\n')
  sb.write_string("commit ")
  sb.write_string(tip_commit)
  sb.write_char('\n')
  sb.write_string("author ")
  sb.write_string(author)
  sb.write_char('\n')
  if summary.length() > 0 {
    sb.write_string("summary ")
    sb.write_string(summary)
    sb.write_char('\n')
  }
  if closes_issues.length() > 0 {
    sb.write_string("closes ")
    sb.write_string(closes_issues.join(","))
    sb.write_char('\n')
  }
  match session_url {
    Some(url) => {
      sb.write_string("session_url ")
      sb.write_string(url)
      sb.write_char('\n')
    }
    None => ()
  }
  let payload = sb.to_string()
  ignore(
    self.store.put_record(
      objects,
      refs,
      clock,
      key,
      "feature-broadcast",
      payload,
      author,
    ),
  )
  ignore(timestamp)
}

///|
/// List feature broadcast records
pub fn Hub::list_feature_broadcasts(
  self : Hub,
  objects : &@lib.ObjectStore,
) -> Array[HubRecord] {
  self.store.list_records(objects, "hub/broadcast/feature/")
}

///|
/// Publish node heartbeat record for canonical node election.
/// Each node periodically publishes its metadata (commit count, last update time).
pub fn Hub::publish_node_heartbeat(
  self : Hub,
  objects : &@lib.ObjectStore,
  refs : &@lib.RefStore,
  clock : &@lib.Clock,
  node_id : String,
  commit_count? : Int = 0,
  main_tip? : String = "",
) -> Unit raise @bit.GitError {
  let timestamp = clock.now()
  let key = "hub/node/heartbeat/" + node_id
  let sb = StringBuilder::new()
  sb.write_string("node_id ")
  sb.write_string(node_id)
  sb.write_char('\n')
  sb.write_string("commit_count ")
  sb.write_string(commit_count.to_string())
  sb.write_char('\n')
  sb.write_string("main_tip ")
  sb.write_string(main_tip)
  sb.write_char('\n')
  sb.write_string("timestamp ")
  sb.write_string(timestamp.to_string())
  sb.write_char('\n')
  let payload = sb.to_string()
  ignore(
    self.store.put_record(
      objects,
      refs,
      clock,
      key,
      "node-heartbeat",
      payload,
      node_id,
    ),
  )
}

///|
/// Node metadata extracted from heartbeat records
pub struct NodeHeartbeat {
  node_id : String
  commit_count : Int
  main_tip : String
  timestamp : Int64
  clock : Map[String, Int64]
}

///|
/// List all node heartbeats and determine which node is canonical.
/// The canonical node is the one with the highest vector clock.
pub fn Hub::list_node_heartbeats(
  self : Hub,
  objects : &@lib.ObjectStore,
) -> Array[NodeHeartbeat] {
  let records = self.store.list_records(objects, "hub/node/heartbeat/")
  let result : Array[NodeHeartbeat] = []
  for record in records {
    if record.kind != "node-heartbeat" {
      continue
    }
    let mut node_id = ""
    let mut commit_count = 0
    let mut main_tip = ""
    let mut timestamp : Int64 = 0
    for line_view in record.payload.split("\n") {
      let line = line_view.to_string()
      match line.find(" ") {
        None => continue
        Some(idx) => {
          let k = String::unsafe_substring(line, start=0, end=idx)
          let v = String::unsafe_substring(
            line,
            start=idx + 1,
            end=line.length(),
          )
          match k {
            "node_id" => node_id = v
            "commit_count" =>
              commit_count = @strconv.parse_int(v) catch { _ => 0 }
            "main_tip" => main_tip = v
            "timestamp" =>
              timestamp = @strconv.parse_int64(v) catch { _ => 0L }
            _ => ()
          }
        }
      }
    }
    result.push(
      {
        node_id,
        commit_count,
        main_tip,
        timestamp,
        clock: record.clock,
      },
    )
  }
  result
}

///|
/// Determine the canonical node from heartbeat records.
/// Returns the node_id of the most active node (highest vector clock, then highest commit count).
pub fn Hub::find_canonical_node(
  self : Hub,
  objects : &@lib.ObjectStore,
) -> String? {
  let heartbeats = self.list_node_heartbeats(objects)
  if heartbeats.length() == 0 {
    return None
  }
  let mut best = heartbeats[0]
  for i in 1..<heartbeats.length() {
    let candidate = heartbeats[i]
    let cmp = compare_vector_clocks(candidate.clock, best.clock)
    if cmp > 0 {
      best = candidate
    } else if cmp == 0 {
      // Tie-break: higher commit count, then higher timestamp
      if candidate.commit_count > best.commit_count {
        best = candidate
      } else if candidate.commit_count == best.commit_count &&
        candidate.timestamp > best.timestamp {
        best = candidate
      }
    }
  }
  Some(best.node_id)
}

///|
pub fn Hub::list_pr_proposals(
  self : Hub,
  objects : &@lib.ObjectStore,
) -> Array[PullRequest] {
  let result : Array[PullRequest] = []
  let records = self.store.list_records(objects, pr_proposal_prefix())
  for record in records {
    if not(record.key.has_suffix("/meta")) || record.kind != "pr-proposal" {
      continue
    }
    let pr = parse_legacy_pull_request(record.payload) catch { _ => continue }
    result.push(pr)
  }
  result.sort_by(fn(a, b) {
    if a.created_at < b.created_at {
      -1
    } else if a.created_at > b.created_at {
      1
    } else {
      0
    }
  })
  result
}
