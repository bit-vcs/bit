///|
extern "js" fn open_read_fixture() -> Int32 =
  #| () => {
  #|   const fs = require('node:fs');
  #|   const path = '/tmp/mizchi_x_raw_fd_read_js.txt';
  #|   try { fs.unlinkSync(path); } catch {}
  #|   fs.writeFileSync(path, 'rawfd');
  #|   return fs.openSync(path, 'r') | 0;
  #| }

///|
extern "js" fn open_write_fixture() -> Int32 =
  #| () => {
  #|   const fs = require('node:fs');
  #|   const path = '/tmp/mizchi_x_raw_fd_write_js.txt';
  #|   try { fs.unlinkSync(path); } catch {}
  #|   return fs.openSync(path, 'w') | 0;
  #| }

///|
let write_path = "/tmp/mizchi_x_raw_fd_write_js.txt"

///|
async fn remove_if_exists(path : String) -> Unit {
  try @fs.remove(path) catch {
    _ => ()
  } noraise {
    _ => ()
  }
}

///|
async test "read file descriptor" {
  let raw = @raw_fd.RawFd(open_read_fixture())
  let buf = FixedArray::make(16, b'\x00')
  let n = raw.read(buf)
  inspect(n, content="5")
  inspect(@utf8.decode(buf.unsafe_reinterpret_as_bytes()[:n]), content="rawfd")
  raw.close()
}

///|
async test "write file descriptor" {
  remove_if_exists(write_path)
  let raw = @raw_fd.RawFd(open_write_fixture())
  let n = raw.write(b"written")
  inspect(n, content="7")
  raw.close()
  inspect(@fs.read_file(write_path).text(), content="written")
  remove_if_exists(write_path)
}
