///|
test "pack-objects parser tracks unsupported options without delegation naming" {
  match parse_pack_objects_args(["--stdout", "--non-empty"]) {
    PackObjectsParse::Ok(cfg) => {
      assert_true(cfg.stdout)
      assert_true(cfg.has_unsupported_options)
    }
    _ => fail("expected pack-objects parse ok")
  }
}

///|
test "index-pack parser tracks unsupported options without delegation naming" {
  match parse_index_pack_args(["--stdin", "--strict"]) {
    IndexPackParse::Ok(cfg) => {
      assert_true(cfg.stdin)
      assert_true(cfg.strict)
      assert_true(cfg.has_unsupported_options)
    }
    _ => fail("expected index-pack parse ok")
  }
}
