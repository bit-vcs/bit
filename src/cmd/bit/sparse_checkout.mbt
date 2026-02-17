///|
async fn handle_sparse_checkout(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let git_dir = root + "/.git"
  let fs = OsFs::new()
  if args.length() == 0 {
    raise @bitcore.GitError::InvalidObject(
      "usage: git sparse-checkout <init|set|add|list|disable>",
    )
  }
  let subcmd = args[0]
  let rest : Array[String] = []
  for i in 1..<args.length() {
    rest.push(args[i])
  }
  match subcmd {
    "init" => {
      let cone = rest.contains("--cone")
      @bitlib.sparse_checkout_init(fs, fs, root, cone~)
      print_line("Sparse checkout initialized")
    }
    "set" => {
      let patterns = rest
        .iter()
        .filter(arg => not(arg.has_prefix("-")))
        .collect()
      if patterns.length() == 0 {
        raise @bitcore.GitError::InvalidObject("patterns required for set")
      }
      @bitlib.sparse_checkout_set(fs, fs, root, patterns)
      print_line("Sparse checkout patterns set")
    }
    "add" => {
      let patterns = rest
        .iter()
        .filter(arg => not(arg.has_prefix("-")))
        .collect()
      if patterns.length() == 0 {
        raise @bitcore.GitError::InvalidObject("patterns required for add")
      }
      @bitlib.sparse_checkout_add(fs, fs, root, patterns)
      print_line("Sparse checkout patterns added")
    }
    "list" => {
      let patterns = @bitlib.read_sparse_patterns(fs, git_dir)
      for p in patterns {
        print_line(p)
      }
    }
    "disable" => {
      @bitlib.sparse_checkout_disable(fs, fs, root)
      print_line("Sparse checkout disabled")
    }
    _ =>
      raise @bitcore.GitError::InvalidObject(
        "unknown sparse-checkout subcommand: \{subcmd}",
      )
  }
}

///|
