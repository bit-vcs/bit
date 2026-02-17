///|
async fn handle_shortlog(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let git_dir = root + "/.git"
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  // Parse options
  let mut numbered = false
  let mut summary = false
  let mut email = false
  let mut max_count = -1
  for arg in args {
    match arg {
      "-n" | "--numbered" => numbered = true
      "-s" | "--summary" => summary = true
      "-e" | "--email" => email = true
      _ if arg.has_prefix("-") && not(arg.has_prefix("--")) => {
        // Could be -N for count
        let num_str = String::unsafe_substring(arg, start=1, end=arg.length())
        let n = parse_int(num_str)
        if n > 0 {
          max_count = n
        }
      }
      _ => ()
    }
  }
  // Collect commits and group by author
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  let head = @bitrepo.rev_parse(rfs, git_dir, "HEAD")
  guard head is Some(h) else { return }
  let author_commits : Map[String, Array[String]] = {}
  let visited : Map[String, Bool] = {}
  let queue : Array[@bitcore.ObjectId] = [h]
  let mut count = 0
  while queue.length() > 0 {
    if max_count > 0 && count >= max_count {
      break
    }
    let current = queue.pop()
    guard current is Some(cid) else { break }
    let hex = cid.to_hex()
    if visited.get(hex).unwrap_or(false) {
      continue
    }
    visited[hex] = true
    count += 1
    let obj = db.get(rfs, cid)
    match obj {
      Some(o) => {
        let commit_text = decode_bytes(o.data)
        let author_line = extract_author_line(commit_text)
        let author_key = if email {
          author_line
        } else {
          // Extract just name
          match author_line.find("<") {
            Some(idx) =>
              trim_string(
                String::unsafe_substring(author_line, start=0, end=idx),
              )
            None => author_line
          }
        }
        let message = extract_commit_message(o.data)
        let subject = get_first_line(message)
        if author_commits.get(author_key) is Some(arr) {
          arr.push(subject)
        } else {
          author_commits[author_key] = [subject]
        }
        let info = @bitcore.parse_commit(o.data)
        for p in info.parents {
          queue.push(p)
        }
      }
      None => ()
    }
  }
  // Sort authors
  let authors : Array[(String, Array[String])] = []
  for author, commits in author_commits {
    authors.push((author, commits))
  }
  if numbered {
    // Sort by commit count descending
    authors.sort_by((a, b) => b.1.length().compare(a.1.length()))
  } else {
    // Sort alphabetically
    authors.sort_by((a, b) => a.0.compare(b.0))
  }
  // Output
  for entry in authors {
    let (author, commits) = entry
    print_line("\{author} (\{commits.length()}):")
    if not(summary) {
      for commit in commits {
        print_line("      \{commit}")
      }
      print_line("")
    }
  }
}

///|
/// Handle git blame command
