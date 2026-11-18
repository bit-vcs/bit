///|
async fn read_text_if_exists(path : String) -> String? {
  let data = @fs.read_file(path) catch { _ => return None }
  let text = data.text() catch { _ => return None }
  Some(text)
}

///|
async fn remove_if_exists(path : String) -> Unit {
  try @fs.remove(path) catch {
    _ => ()
  } noraise {
    _ => ()
  }
}

///|
async fn wait_for_file_text(
  path : String,
  expected : String,
  timeout_ms : UInt64,
) -> Unit {
  let deadline = @env.now() + timeout_ms
  while @env.now() < deadline {
    match read_text_if_exists(path) {
      Some(text) => if text == expected { return }
      None => ()
    }
    @async.sleep(20)
  }
  inspect(read_text_if_exists(path).unwrap_or("<missing>"), content=expected)
}

///|
async test "run exit code 0" {
  let code = @process.run("node", ["-e", "process.exit(0)"])
  inspect(code, content="0")
}

///|
async test "run exit code 42" {
  let code = @process.run("node", ["-e", "process.exit(42)"])
  inspect(code, content="42")
}

///|
async test "collect_stdout" {
  let (code, stdout) = @process.collect_stdout("node", [
    "-e", "console.log('hello')",
  ])
  inspect(code, content="0")
  inspect(stdout.text().trim_end(), content="hello")
}

///|
async test "collect_error" {
  let (code, stderr) = @process.collect_stderr("node", [
    "-e", "console.error('oops')",
  ])
  inspect(code, content="0")
  inspect(stderr.text().trim_end(), content="oops")
}

///|
async test "collect_output" {
  let (code, stdout, stderr) = @process.collect_output("node", [
    "-e", "console.log('out'); console.error('err')",
  ])
  inspect(code, content="0")
  inspect(stdout.text().trim_end(), content="out")
  inspect(stderr.text().trim_end(), content="err")
}

///|
async test "collect_output_merged" {
  let (code, output) = @process.collect_output_merged("node", [
    "-e", "console.log('merged_out')",
  ])
  inspect(code, content="0")
  inspect(output.text().trim_end(), content="merged_out")
}

///|
async test "collect_output blocked" {
  let script = "const chunk=Buffer.alloc(1024);let i=0;function write(){while(i<1024){i++;if(!process.stderr.write(chunk)){process.stderr.once('drain',write);return}}}write()"
  let result = try
    @async.with_timeout(3000, () => {
      let (code, stdout, stderr) = @process.collect_output("node", [
        "-e", script,
      ])
      inspect(code, content="0")
      inspect(stdout.text(), content="")
      inspect(stderr.binary().length(), content="1048576")
    })
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  if result is Err(err) {
    fail("collect_output blocked: \{err}")
  }
}

///|
async test "basic_ls" {
  let (code, stdout) = @process.collect_stdout(
    "node",
    ["-e", "require('fs').readdirSync('.').sort().forEach(f=>console.log(f))"],
    cwd="/tmp",
  )
  inspect(code, content="0")
  inspect(stdout.text().length() > 0, content="true")
}

///|
async test "basic_cat" {
  @async.with_task_group(group => {
    let (cat_read, we_write) = @process.write_to_process()
    let (we_read, cat_write) = @process.read_from_process()
    @process.spawn(
      group,
      "node",
      ["-e", "process.stdin.pipe(process.stdout)"],
      stdin=cat_read,
      stdout=cat_write,
    )
    |> ignore
    group.spawn_bg(() => {
      defer we_write.close()
      we_write.write(b"abcd")
      @async.sleep(50)
      we_write.write(b"efgh")
    })
    group.spawn_bg(() => {
      defer we_read.close()
      inspect(we_read.read_all().text(), content="abcdefgh")
    })
  })
}

///|
async test "basic wait" {
  let code = @process.run("node", ["-e", "setTimeout(()=>process.exit(0),40)"])
  inspect(code, content="0")
}

///|
async test "wait exitcode" {
  let code = @process.run("node", ["-e", "process.exit(42)"])
  inspect(code, content="42")
}

///|
async test "set cwd" {
  let (code, stdout) = @process.collect_stdout(
    "node",
    ["-e", "console.log(require('path').basename(process.cwd()))"],
    cwd="/tmp",
  )
  inspect(code, content="0")
  inspect(stdout.text().trim_end(), content="tmp")
}

///|
async test "set_env" {
  let (code, stdout) = @process.collect_stdout(
    "node",
    ["-e", "console.log(process.env.MAGIC_VAR)"],
    extra_env={ "MAGIC_VAR": "MAGIC_VALUE" },
  )
  inspect(code, content="0")
  inspect(stdout.text().trim_end(), content="MAGIC_VALUE")
}

///|
async test "set_env no inherit" {
  let (code, stdout) = @process.collect_stdout(
    "node",
    [
      "-e", "const e=process.env;const ks=Object.keys(e).filter(k=>k.startsWith('MAGIC_')).sort();ks.forEach(k=>console.log(k+'='+e[k]))",
    ],
    extra_env={ "MAGIC_VAR_1": "MAGIC_VALUE_1", "MAGIC_VAR_2": "MAGIC_VALUE_2" },
    inherit_env=false,
  )
  inspect(code, content="0")
  inspect(
    stdout.text().trim_end(),
    content="MAGIC_VAR_1=MAGIC_VALUE_1\nMAGIC_VAR_2=MAGIC_VALUE_2",
  )
}

///|
async test "redirect stdin and stdout files" {
  let input = "/tmp/mizchi_x_process_redirect_in.txt"
  let output = "/tmp/mizchi_x_process_redirect_out.txt"
  remove_if_exists(input)
  remove_if_exists(output)
  @fs.write_file(input, "redirected", create_mode=CreateOrTruncate)

  let code = @process.run(
    "node",
    ["-e", "process.stdin.pipe(process.stdout)"],
    stdin=@process.redirect_from_file(input),
    stdout=@process.redirect_to_file(output, create_mode=CreateOrTruncate),
  )
  inspect(code, content="0")
  inspect(@fs.read_file(output).text(), content="redirected")

  @fs.remove(input)
  @fs.remove(output)
}

///|
async test "redirect to file" {
  let input = "/tmp/mizchi_x_process_redirect_exact_in.txt"
  let output = "/tmp/mizchi_x_process_redirect_exact_out.txt"
  remove_if_exists(input)
  remove_if_exists(output)
  @fs.write_file(input, "abcd", create_mode=CreateOrTruncate)

  let code = @process.run(
    "node",
    ["-e", "process.stdin.pipe(process.stdout)"],
    stdin=@process.redirect_from_file(input),
    stdout=@process.redirect_to_file(output, create_mode=CreateOrTruncate),
  )
  inspect(code, content="0")
  inspect(@fs.read_file(output).text(), content="abcd")

  @fs.remove(input)
  @fs.remove(output)
}

///|
async test "write_to_process feeds stdin" {
  let (stdin, writer) = @process.write_to_process()
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @process.collect_stdout(
        "node",
        [
          "-e", "let s=''; process.stdin.on('data', c=>s+=c); process.stdin.on('end',()=>console.log(s.toUpperCase()))",
        ],
        stdin~,
      )
    })
    writer.write(b"abc")
    writer.close()
    let (code, stdout) = task.wait()
    inspect(code, content="0")
    inspect(stdout.text().trim_end(), content="ABC")
  })
}

///|
async test "merge multiple" {
  let output = "/tmp/mizchi_x_process_merge_multiple.txt"
  remove_if_exists(output)
  @async.with_task_group(group => {
    @process.spawn(
      group,
      "node",
      ["-e", "setTimeout(()=>console.log('abcd'),10)"],
      stdout=@process.redirect_to_file(
        output,
        append=true,
        create_mode=CreateOrTruncate,
      ),
    )
    |> ignore
    @process.spawn(
      group,
      "node",
      ["-e", "setTimeout(()=>console.log('efgh'),40)"],
      stdout=@process.redirect_to_file(
        output,
        append=true,
        create_mode=OpenOrCreate,
      ),
    )
    |> ignore
  })
  let text = @fs.read_file(output).text()
  assert_true(text.contains("abcd\n"))
  assert_true(text.contains("efgh\n"))
  @fs.remove(output)
}

///|
async test "merge stdout and stderr" {
  @async.with_task_group(group => {
    let (r, w) = @process.read_from_process()
    defer r.close()
    @process.spawn(
      group,
      "node",
      ["-e", "process.stdout.write('abcd');process.stderr.write('efgh')"],
      stdout=w,
      stderr=w,
    )
    |> ignore
    let output = r.read_all().text()
    assert_true(output.contains("abcd"))
    assert_true(output.contains("efgh"))
  })
}

///|
async test "spawn wait and try_wait" {
  @async.with_task_group(group => {
    let proc = @process.spawn(group, "node", [
      "-e", "setTimeout(()=>process.exit(7),40)",
    ])
    assert_true(proc.pid > 0)
    assert_true(proc.try_wait() is None)
    inspect(proc.wait(), content="7")
  })
}

///|
async test "spawn_in_group wait" {
  let t0 = @env.now()
  @async.with_task_group(group => {
    @process.spawn(group, "node", ["-e", "setTimeout(()=>process.exit(0),100)"])
    |> ignore
    @async.sleep(30)
  })
  let elapsed = @env.now() - t0
  assert_true(elapsed >= 80)
}

///|
async test "spawn_in_group cancel" {
  let marker = "/tmp/mizchi_x_process_spawn_group_cancel.txt"
  remove_if_exists(marker)
  let script = "const fs=require('fs');process.on('SIGTERM',()=>{fs.writeFileSync(process.argv[1],'term');process.exit(0)});fs.writeFileSync(process.argv[1],'ready');setInterval(()=>{},1000)"
  @async.with_task_group(group => {
    @process.spawn(group, "node", ["-e", script, marker], no_wait=true)
    |> ignore
    wait_for_file_text(marker, "ready", 1000)
  })
  wait_for_file_text(marker, "term", 1000)
  @fs.remove(marker)
}

///|
async test "Process::wait" {
  @async.with_task_group(group => {
    let child = @process.spawn(group, "node", [
      "-e", "setTimeout(()=>process.exit(42),40)",
    ])
    inspect(child.wait(), content="42")
    inspect(child.wait(), content="42")
  })
}

///|
async test "Process::try_wait" {
  @async.with_task_group(group => {
    let child = @process.spawn(group, "node", [
      "-e", "setTimeout(()=>process.exit(42),80)",
    ])
    @async.sleep(20)
    debug_inspect(child.try_wait(), content="None")
    let deadline = @env.now() + 1000
    while @env.now() < deadline {
      match child.try_wait() {
        Some(code) => {
          debug_inspect(Some(code), content="Some(42)")
          return
        }
        None => @async.sleep(20)
      }
    }
    debug_inspect(child.try_wait(), content="Some(42)")
  })
}

///|
async test "Process:cancel" {
  let marker = "/tmp/mizchi_x_process_method_cancel.txt"
  remove_if_exists(marker)
  let script = "const fs=require('fs');process.on('SIGTERM',()=>{fs.writeFileSync(process.argv[1],'term');process.exit(0)});fs.writeFileSync(process.argv[1],'ready');setInterval(()=>{},1000)"
  @async.with_task_group(group => {
    let child = @process.spawn(group, "node", ["-e", script, marker])
    wait_for_file_text(marker, "ready", 1000)
    child.cancel()
  })
  wait_for_file_text(marker, "term", 1000)
  @fs.remove(marker)
}

///|
async test "wait_pid" {
  let pid = @process.spawn_orphan("node", [
    "-e", "setTimeout(()=>process.exit(7),25)",
  ])
  assert_true(pid > 0)
  inspect(@process.wait_pid(pid), content="7")
}

///|
async test "orphan process" {
  let marker = "/tmp/mizchi_x_process_orphan.txt"
  remove_if_exists(marker)
  let script = "const fs=require('fs');fs.writeFileSync(process.argv[1],'first');setTimeout(()=>{fs.writeFileSync(process.argv[1],'second');process.exit(0)},90)"
  let pid = @process.spawn_orphan("node", ["-e", script, marker])
  let result = try @async.with_timeout(40, () => @process.wait_pid(pid)) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  assert_true(result is Err(_))
  wait_for_file_text(marker, "second", 500)
  try @async.with_timeout(300, () => @process.wait_pid(pid)) catch {
    _ => ()
  } noraise {
    _ => ()
  }
  @fs.remove(marker)
}

///|
async test "cancel process" {
  let marker = "/tmp/mizchi_x_process_cancel_signal.txt"
  remove_if_exists(marker)
  let script = "const fs=require('fs');process.on('SIGTERM',()=>{fs.writeFileSync(process.argv[1],'term');process.exit(0)});setInterval(()=>{},1000)"
  let result = try
    @async.with_timeout(500, () => {
      @process.run(
        "node",
        ["-e", script, marker],
        cancel_handler=@process.graceful_cancel(
          timeout=120,
          signal=@signal.SIGTERM,
        ),
      )
    })
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  assert_true(result is Err(_))
  wait_for_file_text(marker, "term", 1000)
  @fs.remove(marker)
}

///|
async test "cancel process timeout" {
  let marker = "/tmp/mizchi_x_process_cancel_timeout_signal.txt"
  remove_if_exists(marker)
  let script = "const fs=require('fs');process.on('SIGTERM',()=>{fs.writeFileSync(process.argv[1],'term')});fs.writeFileSync(process.argv[1],'ready');setInterval(()=>{},1000)"
  let mut t0 = @env.now()
  let result = try
    @async.with_task_group(group => {
      group.spawn_bg(() => {
        ignore(
          @process.run(
            "node",
            ["-e", script, marker],
            cancel_handler=@process.graceful_cancel(
              timeout=60,
              signal=@signal.SIGTERM,
            ),
          ),
        )
      })
      wait_for_file_text(marker, "ready", 5000)
      t0 = @env.now()
      @async.with_timeout(120, () => @async.sleep(1000))
    })
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  let elapsed = @env.now() - t0
  assert_true(result is Err(_))
  assert_true(elapsed >= 160UL, msg="elapsed: \{elapsed} ms")
  wait_for_file_text(marker, "term", 1000)
  @fs.remove(marker)
}

///|
async test "cancel process hard" {
  let marker = "/tmp/mizchi_x_process_hard_cancel_signal.txt"
  remove_if_exists(marker)
  let script = "const fs=require('fs');process.on('SIGTERM',()=>{fs.writeFileSync(process.argv[1],'term');process.exit(0)});setInterval(()=>{},1000)"
  let result = try
    @async.with_timeout(120, () => {
      @process.run(
        "node",
        ["-e", script, marker],
        cancel_handler=@process.hard_cancel(),
      )
    })
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  assert_true(result is Err(_))
  @async.sleep(50)
  assert_false(@fs.exists(marker))
}

///|
async test "do not kill orphan children on hard cancel" {
  let marker = "/tmp/mizchi_x_process_orphan_child.txt"
  remove_if_exists(marker)
  let child_script = "const fs=require('fs');setTimeout(()=>{fs.writeFileSync(process.argv[1],'after sleep');process.exit(0)},180)"
  let parent_script = "const {spawn}=require('node:child_process');const child=spawn(process.execPath,['-e',process.argv[1],process.argv[2]],{detached:true,stdio:'ignore'});child.unref();setInterval(()=>{},1000)"
  let result = try
    @async.with_timeout(500, () => {
      @process.run(
        "node",
        ["-e", parent_script, child_script, marker],
        cancel_handler=@process.hard_cancel(),
      )
    })
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  assert_true(result is Err(_))
  wait_for_file_text(marker, "after sleep", 1500)
  @fs.remove(marker)
}

///|
test "graceful_cancel accepts signal" {
  let handler = @process.graceful_cancel(timeout=5000, signal=@signal.SIGTERM)
  ignore(handler)
}
