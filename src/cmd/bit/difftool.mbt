///| git difftool - launch external diff tool

///|
async fn handle_difftool(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let git_dir = find_git_dir(fs)
  let mut tool : String? = None
  let mut no_prompt = false
  let mut dir_diff = false
  let mut symlinks = true
  let mut trust_exit_code = false
  let mut extcmd : String? = None
  let positional : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-y" | "--no-prompt" => no_prompt = true
      "--prompt" => no_prompt = false
      "-d" | "--dir-diff" => dir_diff = true
      "--no-symlinks" => symlinks = false
      "--symlinks" => symlinks = true
      "--trust-exit-code" => trust_exit_code = true
      "--no-trust-exit-code" => trust_exit_code = false
      "-h" | "--help" => {
        show_simple_command_help(
          "git difftool [--tool=<tool>] [-y] [-d] [<commit>] [-- <path>...]",
          summary="Show changes using common diff tools.",
        )
        return
      }
      "-t" if i + 1 < args.length() => {
        i += 1
        tool = Some(args[i])
      }
      _ if arg.has_prefix("--tool=") => tool = Some(arg[7:].to_string())
      _ if arg.has_prefix("-t") && arg.length() > 2 =>
        tool = Some(arg[2:].to_string())
      _ if arg.has_prefix("--extcmd=") => extcmd = Some(arg[9:].to_string())
      _ if arg == "--" => {
        // Remaining args are paths
        let mut j = i + 1
        while j < args.length() {
          positional.push(args[j])
          j += 1
        }
        break
      }
      _ if !arg.has_prefix("-") => positional.push(arg)
      _ if arg.has_prefix("-") => warn_unimplemented_arg("difftool", arg)
      _ => ()
    }
    i += 1
  }
  // Resolve the diff tool
  let config_path = git_dir + "/config"
  let resolved_tool = match tool {
    Some(t) => t
    None =>
      match extcmd {
        Some(cmd) => cmd
        None => {
          // Try config: diff.tool, then merge.tool
          let config_tool = match
            @bitlib.read_config_value(fs, config_path, "diff", "tool") {
            Some(t) => Some(t)
            None => @bitlib.read_config_value(fs, config_path, "merge", "tool")
          }
          match config_tool {
            Some(t) => t
            None => "vimdiff"
          }
        }
      }
  }
  // Delegate to handle_diff for minimal implementation
  handle_diff(positional)
  ignore(resolved_tool)
  ignore(no_prompt)
  ignore(dir_diff)
  ignore(symlinks)
  ignore(trust_exit_code)
}

///|
