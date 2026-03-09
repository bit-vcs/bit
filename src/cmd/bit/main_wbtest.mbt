///|
test "main: parse_global_options keeps raw -C path for diagnostics" {
  let opts = parse_global_options(["bit", "-C", "missing/repo", "init"])
  assert_eq(opts.cwd_raw, Some("missing/repo"))
  assert_true(opts.cwd is Some(_))
}

///|
test "main: missing_global_cwd_error uses raw -C path" {
  let fs = @bitcore.TestFs::new()
  fs.mkdir_p("/repo/existing")
  assert_eq(
    missing_global_cwd_error(fs, Some("/repo/existing"), Some("existing")),
    None,
  )
  assert_eq(
    missing_global_cwd_error(fs, Some("/repo/missing"), Some("missing")),
    Some("fatal: cannot change to 'missing': No such file or directory"),
  )
}
