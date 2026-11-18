///|
async test "cond signal wakes waiter" {
  let cond = @cond_var.Cond()
  let log : Array[String] = []
  @async.with_task_group(group => {
    group.spawn_bg(() => {
      cond.wait()
      log.push("woken")
    })
    @async.sleep(20)
    cond.signal()
  })
  inspect(log.length(), content="1")
  inspect(log[0], content="woken")
}
