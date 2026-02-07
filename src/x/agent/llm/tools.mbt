///|
fn shell_escape(s : String) -> String {
  let buf = StringBuilder::new()
  buf.write_char('\'')
  for ch in s {
    if ch == '\'' {
      buf.write_string("'\\''")
    } else {
      buf.write_char(ch)
    }
  }
  buf.write_char('\'')
  buf.to_string()
}

///|
fn resolve_path(work_dir : String, path : String) -> String {
  if path.has_prefix("/") {
    path
  } else {
    work_dir + "/" + path
  }
}

///|
fn json_get_str(j : Json, field : String) -> String {
  match j {
    Object(m) =>
      match m.get(field) {
        Some(String(s)) => s
        _ => ""
      }
    _ => ""
  }
}

///|
fn json_get_int_opt(j : Json, field : String) -> Int? {
  match j {
    Object(m) =>
      match m.get(field) {
        Some(Number(n, ..)) => Some(n.to_int())
        _ => None
      }
    _ => None
  }
}

///|
fn exec(command : String) -> String {
  @ffi.exec_sync(command, 30000)
}

///|
fn exec_with_timeout(command : String, timeout_ms : Int) -> String {
  @ffi.exec_sync(command, timeout_ms)
}

///|
pub fn create_tool_registry(work_dir : String) -> @llmlib.ToolRegistry {
  let registry = @llmlib.ToolRegistry::new()

  // read_file
  registry.register(
    "read_file",
    "Read the contents of a file at the given path.",
    @llmlib.SchemaBuilder::new()
    .string(
      "path",
      "File path (relative to work_dir or absolute)",
      required=true,
    )
    .build(),
    fn(input) {
      let path = resolve_path(work_dir, json_get_str(input, "path"))
      exec("cat " + shell_escape(path))
    },
  )

  // write_file
  registry.register(
    "write_file",
    "Write content to a file. Creates or overwrites.",
    @llmlib.SchemaBuilder::new()
    .string(
      "path",
      "File path (relative to work_dir or absolute)",
      required=true,
    )
    .string("content", "Content to write to the file", required=true)
    .build(),
    fn(input) {
      let path = resolve_path(work_dir, json_get_str(input, "path"))
      let content = json_get_str(input, "content")
      ignore(
        exec(
          "printf '%s' " + shell_escape(content) + " > " + shell_escape(path),
        ),
      )
      "ok"
    },
  )

  // list_directory
  registry.register(
    "list_directory",
    "List files and directories in the given path.",
    @llmlib.SchemaBuilder::new()
    .string("path", "Directory path (default: work_dir)")
    .build(),
    fn(input) {
      let p = json_get_str(input, "path")
      let path = if p.is_empty() { work_dir } else { resolve_path(work_dir, p) }
      exec("ls -1a " + shell_escape(path))
    },
  )

  // list_files_recursive
  registry.register(
    "list_files_recursive",
    "Recursively list files (excluding hidden directories).",
    @llmlib.SchemaBuilder::new()
    .string("path", "Base directory (default: work_dir)")
    .integer("max_depth", "Max directory depth (default: 3)")
    .build(),
    fn(input) {
      let p = json_get_str(input, "path")
      let path = if p.is_empty() { work_dir } else { resolve_path(work_dir, p) }
      let depth = match json_get_int_opt(input, "max_depth") {
        Some(d) => d
        None => 3
      }
      let cmd = "find " +
        shell_escape(path) +
        " -maxdepth " +
        depth.to_string() +
        " -not -path '*/.*' | head -200"
      exec(cmd)
    },
  )

  // search_text
  registry.register(
    "search_text",
    "Search for a text pattern in files using ripgrep.",
    @llmlib.SchemaBuilder::new()
    .string("pattern", "Search pattern (regex)", required=true)
    .string("path", "Directory to search (default: work_dir)")
    .string("glob", "File glob pattern (e.g. '*.mbt')")
    .build(),
    fn(input) {
      let pattern = json_get_str(input, "pattern")
      let p = json_get_str(input, "path")
      let path = if p.is_empty() { work_dir } else { resolve_path(work_dir, p) }
      let glob = json_get_str(input, "glob")
      let mut cmd = "rg --no-heading -n " +
        shell_escape(pattern) +
        " " +
        shell_escape(path)
      if not(glob.is_empty()) {
        cmd = cmd + " -g " + shell_escape(glob)
      }
      cmd = cmd + " | head -100"
      exec(cmd)
    },
  )

  // run_command
  registry.register(
    "run_command",
    "Execute a shell command in the work directory.",
    @llmlib.SchemaBuilder::new()
    .string("command", "Shell command to execute", required=true)
    .integer("timeout_ms", "Timeout in milliseconds (default: 30000)")
    .build(),
    fn(input) {
      let command = json_get_str(input, "command")
      let t = match json_get_int_opt(input, "timeout_ms") {
        Some(ms) => ms
        None => 30000
      }
      exec_with_timeout("cd " + shell_escape(work_dir) + " && " + command, t)
    },
  )

  // remove_file
  registry.register(
    "remove_file",
    "Remove a file at the given path.",
    @llmlib.SchemaBuilder::new()
    .string("path", "File path to remove", required=true)
    .build(),
    fn(input) {
      let path = resolve_path(work_dir, json_get_str(input, "path"))
      ignore(exec("rm " + shell_escape(path)))
      "ok"
    },
  )
  registry
}
