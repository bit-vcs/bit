///|
pub fn init_env_provider() -> Unit {
  let provider = @bitio.EnvProvider::new(
    fn(name : String) { @env.get_env_var(name) },
    @env.current_dir,
  )
  @bitio.set_env_provider(provider)
}
