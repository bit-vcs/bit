///|
async test "read_exactly" {
  let buf = StringBuilder()
  fn log(msg) {
    buf..write_string(msg).write_char('\n')
  }
  @async.with_task_group(root => {
    let (r, w) = @pipe.pipe()
    root.spawn_bg(() => {
      defer r.close()
      let msg1 = r.read_exactly(4) |> @utf8.decode
      log("first message: \{msg1}")
      let msg2 = r.read_exactly(4) |> @utf8.decode
      log("second message: \{msg2}")
      let msg3 = r.read_exactly(4) |> @utf8.decode
      log("third message: \{msg3}")
    })
    root.spawn_bg(() => {
      defer w.close()
      log("first message sent")
      w.write(b"abcdef")
      @async.sleep(100)
      log("second message sent")
      w.write(b"ghijkl")
    })
  })
  inspect(
    buf.to_string(),
    content=(
      #|first message sent
      #|first message: abcd
      #|second message sent
      #|second message: efgh
      #|third message: ijkl
      #|
    ),
  )
}

///|
async test "read_exactly failure" {
  let buf = StringBuilder()
  fn log(msg) {
    buf..write_string(msg).write_char('\n')
  }
  @async.with_task_group(root => {
    let (r, w) = @pipe.pipe()
    root.spawn_bg(() => {
      defer r.close()
      let msg1 = r.read_exactly(4) |> @utf8.decode
      log("first message: \{msg1}")
      let msg2 = r.read_exactly(4) |> @utf8.decode
      log("second message: \{msg2}")
      let msg3 = r.read_exactly(4) |> @utf8.decode
      log("third message: \{msg3}")
    })
    root.spawn_bg(() => {
      defer w.close()
      log("first message sent")
      w.write(b"abcdef")
    })
  }) catch {
    err => log(err.to_string())
  }
  inspect(
    buf.to_string(),
    content=(
      #|first message sent
      #|first message: abcd
      #|moonbitlang/core/async/io.ReaderError.UnexpectedEof
      #|
    ),
  )
}

///|
async test "reader closed" {
  let (r, w) = @pipe.pipe()
  r.close()
  @async.sleep(100)
  let result = try w.write(b"abcd") catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  assert_true(result is Err(_))
}

///|
async test "core binary traits share buffering with compatibility methods" {
  @async.with_timeout(5000, () => {
    @async.with_task_group(group => {
      let (reader, writer) = @pipe.pipe()
      defer reader.close()
      group.spawn_bg(() => {
        defer writer.close()
        @io.BinaryWriter::write(writer, b"core-stream\nnext")
      })
      assert_eq(@io.BinaryReader::peek_exactly(reader, 4).to_owned(), b"core")
      assert_eq(reader.read_exactly(5), b"core-")
      assert_eq(reader.read_some(max_len=2), Some(b"st"))
      assert_eq(reader.drop(1), 1)
      assert_eq(reader.read_until("\n"), Some("eam"))
      assert_eq(@io.BinaryReader::read_all(reader), b"next")
      assert_eq(reader.read_some(), None)
    })
  })
}
