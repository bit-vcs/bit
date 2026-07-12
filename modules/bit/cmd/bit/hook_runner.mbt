///| Hook runner: read `hook.<name>.command` / `hook.<name>.parallel`
/// from .git/config and execute. Optional parallel execution mirrors
/// upstream git 2.55. Falls back to running `.git/hooks/<name>` when
/// no config commands are present.

///|
priv struct HookConfig {
  commands : Array[String]
  parallel : Bool
}

///|
/// Pull `hook.<name>.command` (multi-valued, in declaration order)
/// and `hook.<name>.parallel` from .git/config. Returns an empty
/// commands list when the section is absent.
fn read_hook_config(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  hook_name : String,
) -> HookConfig {
  let commands : Array[String] = []
  let mut parallel = false
  let config_path = git_dir + "/config"
  if !rfs.is_file(config_path) {
    return { commands, parallel }
  }
  let raw = rfs.read_file(config_path) catch {
    _ => return { commands, parallel }
  }
  let content = decode_bytes(raw)
  let blocks = @bitlib.parse_config_blocks(content)
  let lower_name = hook_name.to_lower()
  for block in blocks {
    let section_match = block.section is Some(s) && s == "hook"
    let name_match = block.name is Some(n) && n.to_lower() == lower_name
    if !(section_match && name_match) {
      continue
    }
    for line in block.lines {
      match @bitlib.parse_config_kv(line) {
        Some((k, v)) =>
          if k == "command" {
            commands.push(v)
          } else if k == "parallel" {
            parallel = is_truthy_config_value(v)
          }
        None => ()
      }
    }
  }
  { commands, parallel }
}

///|
/// `true` / `yes` / `on` / `1` are truthy. Anything else falls through
/// to `false`. Matches git's stricter subset of `git_config_bool`.
fn is_truthy_config_value(value : String) -> Bool {
  let lower = value.to_lower()
  lower == "true" || lower == "yes" || lower == "on" || lower == "1"
}

///|
/// Live-streaming execution: stdout/stderr go straight to the
/// caller's terminal. Used for sequential hook execution and the
/// single legacy-file path.
async fn run_hook_command_streaming(
  command : String,
  args : Array[String],
  cwd : String,
) -> Int {
  @process.run(command, args, inherit_env=true, cwd~) catch {
    _ => 1
  }
}

///|
/// Buffered execution: stdout and stderr are merged and captured.
/// Used for parallel hook execution so concurrent children don't
/// interleave their output on the terminal — the captured bytes
/// are replayed in command-list order after the batch completes.
async fn run_hook_command_buffered(
  command : String,
  args : Array[String],
  cwd : String,
) -> (Int, Bytes) {
  let result = try? @process.collect_output_merged(
    command,
    args,
    inherit_env=true,
    cwd~,
  )
  match result {
    Ok((code, data)) => (code, data.binary())
    Err(_) => (1, b"")
  }
}

///|
/// Run all hooks registered for `hook_name` and the legacy
/// `<hooks_dir>/<hook_name>` file. Returns the first non-zero exit
/// code (matching git: any failure aborts the operation).
///
/// Sequential execution when `parallel = false`. When `true`, every
/// command is spawned concurrently via `@async.with_task_group`; the
/// caller blocks until they all return. In parallel mode each child's
/// stdout+stderr is captured to a buffer (via
/// `@process.collect_output_merged`) and replayed in command-list
/// order after the batch — preventing interleaved output on the
/// terminal. Mirrors upstream git 2.55's buffered parallel hook
/// behavior.
///
/// `args` is passed verbatim to every command, matching upstream:
/// e.g. `pre-push` hooks receive `<remote-name> <remote-url>`
/// positionally and all configured commands see the same args.
///
/// If `hook.<name>.command` is set, the legacy file at
/// `<hooks_dir>/<name>` is NOT additionally run (upstream prefers the
/// config form). If no config commands exist, the legacy file is run
/// as before.
async fn run_hook(
  rfs : &@bitcore.RepoFileSystem,
  root : String,
  git_dir : String,
  hook_name : String,
  cwd : String,
  args? : Array[String] = [],
) -> Int {
  let cfg = read_hook_config(rfs, git_dir, hook_name)
  if cfg.commands.length() == 0 {
    let hooks_dir = resolve_hooks_dir(rfs, root, git_dir)
    let hook_path = hooks_dir + "/" + hook_name
    if !rfs.is_file(hook_path) {
      return 0
    }
    return run_hook_command_streaming(hook_path, args, cwd)
  }
  if !cfg.parallel {
    for command in cfg.commands {
      let code = run_hook_command_streaming(command, args, cwd)
      if code != 0 {
        return code
      }
    }
    return 0
  }
  // Parallel: spawn every command in a task group with captured
  // output, then replay each child's bytes in declaration order so
  // the user still sees a deterministic stream.
  let codes : Array[Int] = Array::make(cfg.commands.length(), 0)
  let outputs : Array[Bytes] = Array::make(cfg.commands.length(), b"")
  @async.with_task_group(group => {
    for i, command in cfg.commands {
      let _ = group.spawn(() => {
        let (code, out) = run_hook_command_buffered(command, args, cwd)
        codes[i] = code
        outputs[i] = out
      })
    }
  })
  for out in outputs {
    if out.length() > 0 {
      @stdio.stdout.write(out)
    }
  }
  for code in codes {
    if code != 0 {
      return code
    }
  }
  0
}
