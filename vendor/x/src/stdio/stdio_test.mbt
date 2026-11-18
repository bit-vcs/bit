///|
async fn remove_if_exists(path : String) -> Unit {
  try @fs.remove(path) catch {
    _ => ()
  } noraise {
    _ => ()
  }
}

///|
async test "redirect_file" {
  let in_file = "/tmp/mizchi_x_stdio_redirect_in.txt"
  let out_file = "/tmp/mizchi_x_stdio_redirect_out.txt"
  remove_if_exists(in_file)
  remove_if_exists(out_file)
  @fs.write_file(in_file, "stdio redirect\n", create_mode=CreateOrTruncate)
  let code = @process.run(
    "node",
    ["-e", "process.stdin.pipe(process.stdout)"],
    stdin=@process.redirect_from_file(in_file),
    stdout=@process.redirect_to_file(out_file, create_mode=CreateOrTruncate),
  )
  inspect(code, content="0")
  inspect(@fs.read_file(out_file).text(), content="stdio redirect\n")
  @fs.remove(in_file)
  @fs.remove(out_file)
}

///|
async test "redirect pipe" {
  @async.with_task_group(root => {
    let (cat_read, we_write) = @process.write_to_process()
    let (we_read, cat_write) = @process.read_from_process()
    root.spawn_bg(() => {
      let code = @process.run(
        "node",
        ["-e", "process.stdin.pipe(process.stdout)"],
        stdin=cat_read,
        stdout=cat_write,
      )
      inspect(code, content="0")
    })
    root.spawn_bg(() => {
      defer we_write.close()
      we_write.write(b"abcd\n")
      @async.sleep(50)
      we_write.write(b"defg\n")
    })
    defer we_read.close()
    inspect(
      we_read.read_all().text(),
      content=(
        #|abcd
        #|defg
        #|
      ),
    )
  })
}

///|
async test "stdio cancel" {
  @async.with_task_group(group => {
    let (cat_read, we_write) = @process.write_to_process()
    let (we_read, cat_write) = @process.read_from_process()
    group.spawn_bg(() => {
      let code = @process.run(
        "node",
        [
          "-e", "process.stdin.on('data',c=>process.stdout.write(c));setTimeout(()=>{process.stdout.write('TimeoutError\\n');process.exit(1)},100)",
        ],
        stdin=cat_read,
        stdout=cat_write,
      )
      inspect(code, content="1")
    })
    defer we_write.close()
    defer we_read.close()
    we_write.write(b"abcd")
    debug_inspect(
      we_read.read_some(),
      content=(
        #|Some(<Bytes: [0x61, 0x62, 0x63, 0x64]>)
      ),
    )
    inspect(
      we_read.read_all().text().trim(chars="\r\n"),
      content="TimeoutError",
    )
  })
}

///|
test "stdio implements process redirects" {
  let input : &@process.ProcessInput = @stdio.stdin
  let output : &@process.ProcessOutput = @stdio.stdout
  let error : &@process.ProcessOutput = @stdio.stderr
  ignore((input, output, error))
}
