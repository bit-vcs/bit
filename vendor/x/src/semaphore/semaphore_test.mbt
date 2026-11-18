///|
async test "semaphore acquire release" {
  let sem = @semaphore.Semaphore(1)
  assert_true(sem.try_acquire())
  assert_true(!sem.try_acquire())
  sem.release()
  sem.acquire()
  sem.release()
}
