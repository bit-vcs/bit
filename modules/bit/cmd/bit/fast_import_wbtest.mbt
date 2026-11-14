///|
test "fast-import: in-stream features that touch arbitrary files are unsafe" {
  for
    feature in [
      "import-marks=/etc/passwd", "import-marks-if-exists=marks", "export-marks=/home/u/.bashrc",
      "rewrite-submodules-from=sub:/tmp/marks", "rewrite-submodules-to=sub:/tmp/marks",
    ] {
    assert_true(fast_import_feature_is_unsafe(feature))
  }
  for feature in ["done", "date-format=raw", "force", "notes", "relative-marks"] {
    assert_false(fast_import_feature_is_unsafe(feature))
  }
  assert_eq(fast_import_feature_name("export-marks=/tmp/x"), "export-marks")
  assert_eq(fast_import_feature_name("done"), "done")
}
