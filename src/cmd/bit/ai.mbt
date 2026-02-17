///|
fn show_ai_command_help() -> Unit {
  show_simple_command_help(
    "bit ai <command> [<args>]",
    summary="AI helpers.\n\nSubcommands:\n  rebase   AI-assisted rebase conflict resolution\n  commit   AI-assisted commit message workflow",
  )
}

///|
fn trim_text(s : String) -> String {
  s.trim(chars=" \n\r\t").to_string()
}

fn read_file_text(
  fs : &@bitcore.RepoFileSystem,
  root : String,
  rel_path : String,
) -> String? {
  let path = root + "/" + rel_path
  if not(fs.is_file(path)) {
    return None
  }
  Some(@utf8.decode_lossy(fs.read_file(path)[:]))
}

fn collect_ai_context(
  fs : &@bitcore.RepoFileSystem,
  root : String,
  user_instructions : Array[String],
) -> String {
  let mut blocks : Array[String] = []
  match read_file_text(fs, root, "CLAUDE.md") {
    Some(content) => blocks.push("CLAUDE.md\n\n" + content)
    None => ()
  }
  match read_file_text(fs, root, "AGENTS.md") {
    Some(content) => blocks.push("AGENTS.md\n\n" + content)
    None => ()
  }
  if user_instructions.length() > 0 {
    blocks.push("Custom instructions:\n" + user_instructions.join("\n"))
  }
  blocks.join("\n\n")
}

fn diff_unit_name(path : String) -> String {
  match path.find("/") {
    Some(idx) => String::unsafe_substring(path, start=0, end=idx)
    None => path
  }
}

fn merge_index_and_worktree_diffs(
  index_diffs : Array[@bitdiff.DiffFile],
  worktree_diffs : Array[@bitdiff.DiffFile],
) -> Array[@bitdiff.DiffFile] {
  let merged : Map[String, @bitdiff.DiffFile] = {}
  for item in worktree_diffs {
    merged[item.path] = item
  }
  for item in index_diffs {
    if not(merged.contains(item.path)) {
      merged[item.path] = item
    }
  }
  let out : Array[@bitdiff.DiffFile] = []
  for pair in merged.to_array() {
    let (_, file) = pair
    out.push(file)
  }
  out.sort_by((a, b) => String::compare(a.path, b.path))
  out
}

fn build_diff_units_for_ai(diffs : Array[@bitdiff.DiffFile]) -> String {
  if diffs.length() == 0 {
    return ""
  }
  let mut current_unit = ""
  let out = StringBuilder::new()
  for item in diffs {
    let unit = diff_unit_name(item.path)
    if unit != current_unit {
      if current_unit.length() > 0 {
        out.write_string("\n")
      }
      out.write_string("## Logical unit: " + unit + "\n")
      current_unit = unit
    }
    out.write_string("### " + item.path + "\n")
    let segment = @bitdiff.diff_text([item]).join("\n")
    out.write_string(segment)
    out.write_string("\n")
  }
  out.to_string()
}

///|
struct AiCommitCommandOptions {
  model : String
  max_auto_rounds : Int
  use_agent_loop : Bool
  agent_max_steps : Int
}

fn parse_ai_commit_options(
  args : Array[String],
) -> (
  AiCommitCommandOptions,
  Array[String],
  Bool,
  Bool,
  Array[String],
) raise @bitcore.GitError {
  let mut model = ""
  let mut max_auto_rounds = 32
  let mut use_agent_loop = false
  let mut agent_max_steps = 16
  let mut commit_args : Array[String] = []
  let mut user_instructions : Array[String] = []
  let mut i = 0
  let mut should_generate_message = true
  let mut all_modified = false
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--model" if i + 1 < args.length() => {
        model = args[i + 1]
        i += 2
        continue
      }
      "--model" =>
        raise @bitcore.GitError::InvalidObject(
          "rebase-ai: --model requires a value",
        )
      "--max-ai-rounds" if i + 1 < args.length() => {
        max_auto_rounds = parse_rebase_ai_rounds(args[i + 1])
        i += 2
        continue
      }
      "--max-ai-rounds" =>
        raise @bitcore.GitError::InvalidObject(
          "rebase-ai: --max-ai-rounds requires a value",
        )
      "--agent-loop" => {
        use_agent_loop = true
        i += 1
        continue
      }
      "--agent-max-steps" if i + 1 < args.length() => {
        agent_max_steps = parse_rebase_ai_agent_steps(args[i + 1])
        i += 2
        continue
      }
      "--agent-max-steps" =>
        raise @bitcore.GitError::InvalidObject(
          "rebase-ai: --agent-max-steps requires a value",
        )
      "--" => {
        let mut j = i + 1
        while j < args.length() {
          user_instructions.push(args[j])
          j += 1
        }
        break
      }
      "--all" | "-a" => {
        all_modified = true
        commit_args.push(arg)
        i += 1
      }
      "--no-edit" => {
        should_generate_message = false
        commit_args.push(arg)
        i += 1
      }
      "-m" if i + 1 < args.length() => {
        should_generate_message = false
        commit_args.push(arg)
        commit_args.push(args[i + 1])
        i += 2
      }
      "--message" if i + 1 < args.length() => {
        should_generate_message = false
        commit_args.push(arg)
        commit_args.push(args[i + 1])
        i += 2
      }
      "--file" if i + 1 < args.length() => {
        should_generate_message = false
        commit_args.push(arg)
        commit_args.push(args[i + 1])
        i += 2
      }
      "-F" if i + 1 < args.length() => {
        should_generate_message = false
        commit_args.push(arg)
        commit_args.push(args[i + 1])
        i += 2
      }
      "-C" if i + 1 < args.length() => {
        should_generate_message = false
        commit_args.push(arg)
        commit_args.push(args[i + 1])
        i += 2
      }
      "-c" if i + 1 < args.length() => {
        should_generate_message = false
        commit_args.push(arg)
        commit_args.push(args[i + 1])
        i += 2
      }
      "--reuse-message" if i + 1 < args.length() => {
        should_generate_message = false
        commit_args.push(arg)
        commit_args.push(args[i + 1])
        i += 2
      }
      "--reedit-message" if i + 1 < args.length() => {
        should_generate_message = false
        commit_args.push(arg)
        commit_args.push(args[i + 1])
        i += 2
      }
      "-am" if i + 1 < args.length() => {
        all_modified = true
        should_generate_message = false
        commit_args.push(arg)
        commit_args.push(args[i + 1])
        i += 2
      }
      "-ma" if i + 1 < args.length() => {
        all_modified = true
        should_generate_message = false
        commit_args.push(arg)
        commit_args.push(args[i + 1])
        i += 2
      }
      _ if arg.has_prefix("-m") => {
        should_generate_message = false
        commit_args.push(arg)
        i += 1
      }
      _ if arg.has_prefix("--message=") => {
        should_generate_message = false
        commit_args.push(arg)
        i += 1
      }
      _ if arg.has_prefix("--file=") => {
        should_generate_message = false
        commit_args.push(arg)
        i += 1
      }
      _ if arg.has_prefix("-F") => {
        should_generate_message = false
        commit_args.push(arg)
        i += 1
      }
      _ if arg.has_prefix("-C") => {
        should_generate_message = false
        commit_args.push(arg)
        i += 1
      }
      _ if arg.has_prefix("-c") => {
        should_generate_message = false
        commit_args.push(arg)
        i += 1
      }
      _ if arg.has_prefix("--reuse-message=") => {
        should_generate_message = false
        commit_args.push(arg)
        i += 1
      }
      _ if arg.has_prefix("--reedit-message=") => {
        should_generate_message = false
        commit_args.push(arg)
        i += 1
      }
      _ if arg.has_prefix("-ma") => {
        all_modified = true
        should_generate_message = false
        commit_args.push(arg)
        i += 1
      }
      _ if arg.has_prefix("-am") => {
        all_modified = true
        should_generate_message = false
        commit_args.push(arg)
        i += 1
      }
      _ if arg.has_prefix("--model=") => {
        model = String::unsafe_substring(arg, start=8, end=arg.length())
        i += 1
      }
      _ if arg.has_prefix("--max-ai-rounds=") => {
        let raw = String::unsafe_substring(arg, start=16, end=arg.length())
        max_auto_rounds = parse_rebase_ai_rounds(raw)
        i += 1
      }
      _ if arg.has_prefix("--agent-max-steps=") => {
        let raw = String::unsafe_substring(arg, start=18, end=arg.length())
        agent_max_steps = parse_rebase_ai_agent_steps(raw)
        i += 1
      }
      _ => {
        commit_args.push(arg)
        i += 1
      }
    }
  }
  (
    {
      model,
      max_auto_rounds,
      use_agent_loop,
      agent_max_steps,
    },
    commit_args,
    should_generate_message,
    all_modified,
    user_instructions,
  )
}

///|
async fn handle_ai_commit(args : Array[String]) -> Unit raise Error {
  if args.length() == 0 {
    handle_commit([])
    return
  }
  match args[0] {
    "-h" | "--help" | "help" => {
      show_ai_commit_help()
      return
    }
    _ => ()
  }
  let (
    parsed,
    commit_args,
    generate_message,
    all_modified,
    user_instructions,
  ) = parse_ai_commit_options(args)
  if not(generate_message) {
    handle_commit(commit_args)
    return
  }
  let root = get_work_root()
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  let diff_index = @bitdiff.diff_index(rfs, root)
  let diff_files = if all_modified {
    merge_index_and_worktree_diffs(diff_index, @bitdiff.diff_worktree(rfs, root))
  } else {
    diff_index
  }
  let diff_units = build_diff_units_for_ai(diff_files)
  if trim_text(diff_units).length() == 0 {
    handle_commit(commit_args)
    return
  }
  let context = collect_ai_context(rfs, root, user_instructions)
  let ai_options = @rebase_ai.AiRebaseOptions::new(
    model=parsed.model,
    max_auto_rounds=parsed.max_auto_rounds,
    use_agent_loop=parsed.use_agent_loop,
    agent_max_steps=parsed.agent_max_steps,
  )
  let message = @rebase_ai.ai_generate_commit_message(
    rfs,
    root,
    diff_units,
    context,
    ai_options~,
  )
  let mut generated_commit_args : Array[String] = commit_args
  generated_commit_args.push("-m")
  generated_commit_args.push(message)
  handle_commit(generated_commit_args)
}

///|
async fn show_ai_commit_help() -> Unit {
  show_simple_command_help(
    "bit ai commit [<args>]",
    summary=
      "AI commit message workflow.\n"
      + "Accepted AI options: --model, --max-ai-rounds, --agent-loop, --agent-max-steps.\n"
      + "When no explicit commit-message option is provided, Bit auto-generates a\n"
      + "Conventional Commit message and passes it to `bit commit`.\n"
      + "Use commit options like -m, --no-edit, --file, --reuse-message, etc.\n"
      + "to use existing messages instead.",
  )
}

///|
async fn handle_ai(args : Array[String]) -> Unit raise Error {
  if args.length() == 0 {
    show_ai_command_help()
    return
  }
  let subcmd = args[0]
  if subcmd == "-h" || subcmd == "--help" || subcmd == "help" {
    show_ai_command_help()
    return
  }
  let subargs = collect_args(args, 1)
  match subcmd {
    "rebase" => handle_rebase_ai(subargs)
    "commit" => handle_ai_commit(subargs)
    _ =>
      raise @bitcore.GitError::InvalidObject(
        "bit ai supports `rebase` and `commit` subcommands",
      )
  }
}
