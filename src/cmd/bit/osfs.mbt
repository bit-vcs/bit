///| OsFs - OS filesystem implementation for @bitcore.FileSystem and @bitcore.RepoFileSystem

///|
pub struct OsFs {
  dummy : Int
}

///|
pub fn OsFs::new() -> OsFs {
  { dummy: 0 }
}

///|
pub impl @bitcore.FileSystem for OsFs with mkdir_p(_self, path) {
  ensure_dir(path)
}

///|
pub impl @bitcore.FileSystem for OsFs with write_file(_self, path, content) {
  @fs.write_bytes_to_file(path, content) catch {
    err => raise io_error(err)
  }
}

///|
pub impl @bitcore.FileSystem for OsFs with write_string(_self, path, content) {
  @fs.write_string_to_file(path, content) catch {
    err => raise io_error(err)
  }
}

///|
pub impl @bitcore.FileSystem for OsFs with remove_file(_self, path) {
  @fs.remove_file(path) catch {
    err => raise io_error(err)
  }
}

///|
pub impl @bitcore.FileSystem for OsFs with remove_dir(_self, path) {
  @fs.remove_dir(path) catch {
    err => raise io_error(err)
  }
}

///|
pub impl @bitcore.RepoFileSystem for OsFs with read_file(_self, path) {
  @fs.read_file_to_bytes(path) catch {
    err => raise io_error(err)
  }
}

///|
pub impl @bitcore.RepoFileSystem for OsFs with readdir(_self, path) {
  @fs.read_dir(path) catch {
    err => raise io_error(err)
  }
}

///|
pub impl @bitcore.RepoFileSystem for OsFs with is_dir(_self, path) {
  @fs.is_dir(path) catch {
    _ => false
  }
}

///|
pub impl @bitcore.RepoFileSystem for OsFs with is_file(_self, path) {
  @fs.is_file(path) catch {
    _ => false
  }
}
