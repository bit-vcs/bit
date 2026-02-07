///| Tool environment abstraction for agent filesystem and command operations

///|
pub(open) trait ToolEnvironment {
  read_file(Self, path : String) -> String raise Error
  write_file(Self, path : String, content : String) -> Unit raise Error
  remove_file(Self, path : String) -> Unit raise Error
  list_directory(Self, path : String) -> String raise Error
  list_files_recursive(Self, path : String, max_depth : Int) -> String raise Error
  search_text(
    Self,
    pattern : String,
    path : String,
    glob : String,
    max_results : Int,
  ) -> String raise Error
  run_command(Self, command : String, work_dir : String, timeout_ms : Int) -> String raise Error
}

///|
priv struct NativeToolEnvironment {
  work_dir : String
}

///|
fn NativeToolEnvironment::new(work_dir : String) -> NativeToolEnvironment {
  { work_dir, }
}

///|
pub fn native_tool_env(work_dir : String) -> &ToolEnvironment {
  NativeToolEnvironment::new(work_dir)
}

///|
impl ToolEnvironment for NativeToolEnvironment with read_file(self, path) {
  exec("cat " + shell_escape(resolve_path(self.work_dir, path)))
}

///|
impl ToolEnvironment for NativeToolEnvironment with write_file(
  self,
  path,
  content,
) {
  let full_path = resolve_path(self.work_dir, path)
  ignore(
    exec(
      "printf '%s' " + shell_escape(content) + " > " + shell_escape(full_path),
    ),
  )
}

///|
impl ToolEnvironment for NativeToolEnvironment with remove_file(self, path) {
  let full_path = resolve_path(self.work_dir, path)
  ignore(exec("rm " + shell_escape(full_path)))
}

///|
impl ToolEnvironment for NativeToolEnvironment with list_directory(self, path) {
  let p = if path.is_empty() {
    self.work_dir
  } else {
    resolve_path(self.work_dir, path)
  }
  exec("ls -1a " + shell_escape(p))
}

///|
impl ToolEnvironment for NativeToolEnvironment with list_files_recursive(
  self,
  path,
  max_depth,
) {
  let p = if path.is_empty() {
    self.work_dir
  } else {
    resolve_path(self.work_dir, path)
  }
  let cmd = "find " +
    shell_escape(p) +
    " -maxdepth " +
    max_depth.to_string() +
    " -not -path '*/.*' | head -200"
  exec(cmd)
}

///|
impl ToolEnvironment for NativeToolEnvironment with search_text(
  self,
  pattern,
  path,
  glob,
  max_results,
) {
  let p = if path.is_empty() {
    self.work_dir
  } else {
    resolve_path(self.work_dir, path)
  }
  let mut cmd = "rg --no-heading -n " +
    shell_escape(pattern) +
    " " +
    shell_escape(p)
  if not(glob.is_empty()) {
    cmd = cmd + " -g " + shell_escape(glob)
  }
  cmd = cmd + " | head -" + max_results.to_string()
  exec(cmd)
}

///|
impl ToolEnvironment for NativeToolEnvironment with run_command(
  self,
  command,
  work_dir,
  timeout_ms,
) {
  let wd = if work_dir.is_empty() { self.work_dir } else { work_dir }
  exec_with_timeout("cd " + shell_escape(wd) + " && " + command, timeout_ms)
}
