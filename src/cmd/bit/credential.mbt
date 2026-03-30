///| git credential - credential helper protocol

///|
async fn handle_credential(args : Array[String]) -> Unit raise Error {
  let positional : Array[String] = []
  for arg in args {
    match arg {
      "-h" | "--help" => {
        show_simple_command_help(
          "git credential <fill|approve|reject>",
          summary="Retrieve and store user credentials.",
        )
        return
      }
      _ if !(arg.has_prefix("-")) => positional.push(arg)
      _ => ()
    }
  }
  if positional.length() == 0 {
    eprint_line("usage: git credential <fill|approve|reject>")
    @sys.exit(129)
    return
  }
  let action = positional[0]
  match action {
    "fill" => credential_fill()
    "approve" => ()
    "reject" => ()
    _ => {
      eprint_line("usage: git credential <fill|approve|reject>")
      @sys.exit(129)
    }
  }
}

///|
async fn credential_fill() -> Unit raise Error {
  // Parse credential request from stdin
  let input = decode_bytes(read_all_stdin())
  let mut protocol = ""
  let mut host = ""
  let mut path = ""
  let mut username = ""
  let mut password = ""
  for line_view in input.split("\n") {
    let line = trim_string(line_view.to_string())
    if line.length() == 0 {
      continue
    }
    match line.find("=") {
      Some(idx) => {
        let key = String::unsafe_substring(line, start=0, end=idx)
        let value = String::unsafe_substring(
          line,
          start=idx + 1,
          end=line.length(),
        )
        match key {
          "protocol" => protocol = value
          "host" => host = value
          "path" => path = value
          "username" => username = value
          "password" => password = value
          _ => ()
        }
      }
      None => ()
    }
  }
  // Try GIT_ASKPASS or SSH_ASKPASS
  if username.length() == 0 || password.length() == 0 {
    let askpass = match @sys.get_env_var("GIT_ASKPASS") {
      Some(v) if v.length() > 0 => Some(v)
      _ =>
        match @sys.get_env_var("SSH_ASKPASS") {
          Some(v) if v.length() > 0 => Some(v)
          _ => None
        }
    }
    match askpass {
      Some(prog) => {
        if username.length() == 0 {
          let (code, stdout_data, _) = @process.collect_output(prog, [
            "Username for '\{protocol}://\{host}': ",
          ])
          if code == 0 {
            username = trim_string(decode_bytes(stdout_data.binary()))
          }
        }
        if password.length() == 0 {
          let (code, stdout_data, _) = @process.collect_output(prog, [
            "Password for '\{protocol}://\{username}@\{host}': ",
          ])
          if code == 0 {
            password = trim_string(decode_bytes(stdout_data.binary()))
          }
        }
      }
      None => ()
    }
  }
  // Output credential response
  if protocol.length() > 0 {
    print_line("protocol=\{protocol}")
  }
  if host.length() > 0 {
    print_line("host=\{host}")
  }
  if path.length() > 0 {
    print_line("path=\{path}")
  }
  if username.length() > 0 {
    print_line("username=\{username}")
  }
  if password.length() > 0 {
    print_line("password=\{password}")
  }
  print_str("\n")
}

///|
