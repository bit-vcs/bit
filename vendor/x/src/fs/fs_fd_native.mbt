///|
/// `@types.Fd` has the ABI of the OS handle (an `int` on Unix).
fn file_fd_to_int(fd : @types.Fd) -> Int32 = "%identity"
