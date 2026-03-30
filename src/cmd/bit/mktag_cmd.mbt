///| git mktag - create a tag object with validation

///|
async fn handle_mktag(args : Array[String]) -> Unit raise Error {
  for arg in args {
    match arg {
      "-h" | "--help" => {
        show_simple_command_help(
          "git mktag",
          summary="Create a tag object with extra validation.\nReads a tag object from stdin and writes it to the object database.",
        )
        return
      }
      "--strict" => () // default behavior
      _ if arg.has_prefix("-") => warn_unimplemented_arg("mktag", arg)
      _ => ()
    }
  }
  let input = read_all_stdin()
  let content = decode_bytes(input)
  // Validate the tag object content
  mktag_validate(content)
  // Write the tag object
  let fs = OsFs::new()
  let git_dir = find_git_dir(fs)
  let oid = @bitlib.write_loose_object(
    fs,
    git_dir,
    @bitcore.ObjectType::Tag,
    input,
  )
  print_line(oid.to_hex())
}

///|
async fn mktag_validate(content : String) -> Unit {
  // Must have "object <hex>\n"
  let lines : Array[String] = []
  for line_view in content.split("\n") {
    lines.push(line_view.to_string())
  }
  if lines.length() < 4 {
    eprint_line("error: missingObject: tag missing 'object' line")
    @sys.exit(1)
  }
  // Line 0: object <hex>
  let line0 = lines[0]
  if !(line0.has_prefix("object ")) {
    eprint_line("error: missingObject: tag missing 'object' line")
    @sys.exit(1)
  }
  let hex = String::unsafe_substring(line0, start=7, end=line0.length())
  if hex.length() != 40 || !(mktag_is_hex(hex)) {
    eprint_line("error: badObjectSha1: tag has too-short object SHA-1")
    @sys.exit(1)
  }
  // Line 1: type <type>
  let line1 = lines[1]
  if !(line1.has_prefix("type ")) {
    eprint_line("error: missingTypeEntry: tag missing 'type' line")
    @sys.exit(1)
  }
  let type_str = String::unsafe_substring(line1, start=5, end=line1.length())
  match type_str {
    "commit" | "tree" | "blob" | "tag" => ()
    _ => {
      eprint_line("error: badType: tag has invalid type '\{type_str}'")
      @sys.exit(1)
    }
  }
  // Line 2: tag <name>
  let line2 = lines[2]
  if !(line2.has_prefix("tag ")) {
    eprint_line("error: missingTagEntry: tag missing 'tag' line")
    @sys.exit(1)
  }
  let tag_name = String::unsafe_substring(line2, start=4, end=line2.length())
  if tag_name.length() == 0 {
    eprint_line("error: badTagName: tag has empty tag name")
    @sys.exit(1)
  }
  // Line 3: tagger <ident>
  let line3 = lines[3]
  if !(line3.has_prefix("tagger ")) {
    eprint_line("error: missingTaggerEntry: tag missing 'tagger' line")
    @sys.exit(1)
  }
}

///|
fn mktag_is_hex(s : String) -> Bool {
  @bithash.is_hex_string(s)
}
