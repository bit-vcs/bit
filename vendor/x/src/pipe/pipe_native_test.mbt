///|
async test "@pipe.pipe redirects process stdio" {
  @async.with_task_group(group => {
    let (child_stdin, writer) = @pipe.pipe()
    let (reader, child_stdout) = @pipe.pipe()
    let child = @process.spawn(
      group,
      "node",
      ["-e", "process.stdin.pipe(process.stdout)"],
      stdin=child_stdin,
      stdout=child_stdout,
    )
    child_stdin.close()
    child_stdout.close()
    writer.write(b"@pipe.pipe redirect")
    writer.close()
    inspect(reader.read_all().text(), content="@pipe.pipe redirect")
    reader.close()
    inspect(child.wait(), content="0")
  })
}
