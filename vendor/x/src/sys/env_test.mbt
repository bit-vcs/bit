///|
test "environment access" {
  let key = "MIZCHI_X_ENV_TEST"
  let previous = @sys.get_env_var(key)
  @sys.set_env_var(key, "ok")
  assert_eq(@sys.get_env_var(key), Some("ok"))
  match previous {
    Some(value) => @sys.set_env_var(key, value)
    None => @sys.unset_env_var(key)
  }
}

///|
test "environment and arguments enumeration" {
  let _vars = @sys.get_env_vars()
  let _args = @sys.get_cli_args()
}
