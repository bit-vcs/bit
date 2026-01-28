///| Test filesystem for git tests (in-memory)

///|
pub struct TestFs {
  files : Map[String, Bytes]
  dirs : Map[String, Bool]
}

///|
pub fn TestFs::new() -> TestFs {
  let fs : TestFs = { files: {}, dirs: {} }
  fs.dirs.set("/", true)
  fs
}

///|
pub fn TestFs::exists(self : TestFs, path : String) -> Bool {
  self.files.contains(path) || self.dirs.contains(path)
}

///|
pub fn TestFs::read_file(self : TestFs, path : String) -> Bytes raise GitError {
  match self.files.get(path) {
    Some(data) => data
    None => raise GitError::IoError("File not found: \{path}")
  }
}

///|
pub fn TestFs::read_string(self : TestFs, path : String) -> String raise GitError {
  let data = self.read_file(path)
  @utf8.decode_lossy(data[:])
}

///|
pub fn TestFs::mkdir_p(self : TestFs, path : String) -> Unit {
  if path.length() == 0 {
    return
  }
  self.dirs.set(path, true)
}

///|
pub fn TestFs::write_file(
  self : TestFs,
  path : String,
  content : Bytes,
) -> Unit {
  self.files.set(path, content)
}

///|
pub fn TestFs::write_string(
  self : TestFs,
  path : String,
  content : String,
) -> Unit {
  self.write_file(path, string_to_bytes(content))
}

///|
pub impl FileSystem for TestFs with mkdir_p(self, path) {
  TestFs::mkdir_p(self, path)
}

///|
pub impl FileSystem for TestFs with write_file(self, path, content) {
  TestFs::write_file(self, path, content)
}

///|
pub impl FileSystem for TestFs with write_string(self, path, content) {
  TestFs::write_string(self, path, content)
}

///|
fn string_to_bytes(s : String) -> Bytes {
  let out : Array[Byte] = []
  for c in s {
    out.push(c.to_int().to_byte())
  }
  Bytes::from_array(FixedArray::makei(out.length(), fn(i) { out[i] }))
}
