///|
pub fn get_env_var(name : String) -> String? {
  @env.get_env_var(name)
}

///|
pub fn get_env_vars() -> Map[String, String] {
  @env.get_env_vars()
}

///|
pub fn get_cli_args() -> Array[String] {
  @env.args()
}

///|
pub fn set_env_var(name : String, value : String) -> Unit {
  @env.set_env_var(name, value)
}

///|
pub fn unset_env_var(name : String) -> Unit {
  @env.unset_env_var(name)
}

///|
fn wasi_proc_exit(code : Int32) = "wasi_snapshot_preview1" "proc_exit"

///|
pub fn exit(code : Int32) -> Unit {
  wasi_proc_exit(code)
}
