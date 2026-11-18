///|
fn to_async_mode(mode : Mode) -> @async_fs.Mode {
  match mode {
    ReadOnly => @async_fs.ReadOnly
    WriteOnly => @async_fs.WriteOnly
    ReadWrite => @async_fs.ReadWrite
  }
}

///|
fn to_async_sync_mode(sync : SyncMode) -> @async_fs.SyncMode {
  match sync {
    NoSync => @async_fs.NoSync
    Data => @async_fs.Data
    Full => @async_fs.Full
  }
}

///|
fn to_async_create_mode(create_mode : CreateMode) -> @async_fs.CreateMode {
  match create_mode {
    OpenExisting => @async_fs.OpenExisting
    TruncateExisting => @async_fs.TruncateExisting
    OpenOrCreate => @async_fs.OpenOrCreate
    CreateOrTruncate => @async_fs.CreateOrTruncate
    CreateNew => @async_fs.CreateNew
  }
}

///|
fn to_async_lock(lock : Lock) -> @async_fs.Lock {
  match lock {
    Shared => @async_fs.Shared
    Exclusive => @async_fs.Exclusive
  }
}

///|
fn default_open_create_mode(
  create_mode? : CreateMode,
  create? : Int32,
  truncate? : Bool,
) -> CreateMode {
  match create_mode {
    Some(mode) => mode
    None =>
      match (create is Some(_), truncate.unwrap_or(false)) {
        (true, true) => CreateOrTruncate
        (true, false) => OpenOrCreate
        (false, true) => TruncateExisting
        (false, false) => OpenExisting
      }
  }
}

///|
fn default_write_create_mode(
  create_mode? : CreateMode,
  create? : Int32,
  truncate? : Bool,
) -> CreateMode {
  match create_mode {
    Some(mode) => mode
    None =>
      match (create is Some(_), truncate.unwrap_or(true)) {
        (true, true) => CreateOrTruncate
        (true, false) => OpenOrCreate
        (false, true) => CreateOrTruncate
        (false, false) => OpenExisting
      }
  }
}

///|
fn permission_or_create(permission? : Int32, create? : Int32) -> Int32 {
  match permission {
    Some(p) => p
    None =>
      match create {
        Some(p) => p
        None => 0o644
      }
  }
}

///|
pub async fn read_file(
  path : StringView,
  sync_timestamp? : Bool,
) -> &@data.Data raise IOError {
  // Core no longer exposes `sync_timestamp`; it is accepted and ignored.
  ignore(sync_timestamp)
  @async_fs.read_binary(path) catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
pub async fn write_file(
  path : StringView,
  content : &@data.Data,
  create_mode? : CreateMode,
  permission? : Int32,
  sync? : SyncMode,
  append? : Bool,
  create? : Int32,
  truncate? : Bool,
) -> Unit raise IOError {
  let create_mode = to_async_create_mode(
    default_write_create_mode(create_mode?, create?, truncate?),
  )
  let permission = permission_or_create(permission?, create?)
  let sync = sync.map(to_async_sync_mode)
  @async_fs.write_binary(
    path,
    content.binary()[:],
    create_mode~,
    permission~,
    sync?,
    append?,
  ) catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
pub async fn exists(path : StringView) -> Bool {
  @async_fs.exists(path)
}

///|
pub async fn can_read(path : StringView) -> Bool {
  @async_fs.can_read(path)
}

///|
pub async fn can_write(path : StringView) -> Bool {
  @async_fs.can_write(path)
}

///|
pub async fn can_execute(path : StringView) -> Bool {
  @async_fs.can_execute(path)
}

///|
pub async fn chmod(path : StringView, permission : Int32) -> Unit raise IOError {
  @async_fs.chmod(path, permission) catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
pub async fn atime(
  path : StringView,
  follow_symlink? : Bool,
) -> (Int64, Int32) raise IOError {
  let time = @async_fs.atime(path, follow_symlink?) catch {
    err => raise IOError::IOError(err.to_string())
  }
  (time.sec(), time.nsec())
}

///|
pub async fn mtime(
  path : StringView,
  follow_symlink? : Bool,
) -> (Int64, Int32) raise IOError {
  let time = @async_fs.mtime(path, follow_symlink?) catch {
    err => raise IOError::IOError(err.to_string())
  }
  (time.sec(), time.nsec())
}

///|
pub async fn ctime(
  path : StringView,
  follow_symlink? : Bool,
) -> (Int64, Int32) raise IOError {
  let time = @async_fs.ctime(path, follow_symlink?) catch {
    err => raise IOError::IOError(err.to_string())
  }
  (time.sec(), time.nsec())
}

///|
pub async fn mkdir(
  path : StringView,
  permission? : Int32,
  recursive? : Bool,
) -> Unit raise IOError {
  @async_fs.mkdir(path, permission?, recursive?) catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
pub async fn readdir(
  path : StringView,
  include_hidden? : Bool,
  include_special? : Bool,
  sort? : Bool,
) -> Array[String] raise IOError {
  @async_fs.readdir(path, include_hidden?, include_special?, sort?) catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
pub async fn remove(path : StringView) -> Unit raise IOError {
  @async_fs.remove(path) catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
pub async fn rename(
  old_path : StringView,
  new_path : StringView,
  replace? : Bool,
) -> Unit raise IOError {
  @async_fs.rename(old_path, new_path, replace?) catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
pub async fn rmdir(path : StringView, recursive? : Bool) -> Unit raise IOError {
  // Core's `rmdir` is a deprecated alias of `remove`, which also deletes
  // regular files; keep `rmdir` directory-only like the JS/wasm-gc backends.
  // The kind check and the removal resolve `path` separately, so a
  // concurrent replacement of the directory in between is not detected
  // (core offers no directory-handle-relative removal).
  let kind = @async_fs.kind(path, follow_symlink=false) catch {
    err => raise IOError::IOError(err.to_string())
  }
  guard kind is Directory else {
    raise IOError::IOError("rmdir: not a directory: \{path}")
  }
  @async_fs.remove(path, recursive?) catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
fn from_async_kind(k : @async_fs.FileKind) -> FileKind {
  match k {
    Unknown => Unknown
    Regular => Regular
    Directory => Directory
    SymLink => SymLink
    Socket => Socket
    Pipe => Pipe
    BlockDevice => BlockDevice
    CharDevice => CharDevice
    _ => Unknown
  }
}

///|
pub async fn kind(
  path : StringView,
  follow_symlink? : Bool,
) -> FileKind raise IOError {
  let k = try {
    match follow_symlink {
      None => @async_fs.kind(path)
      Some(b) => @async_fs.kind(path, follow_symlink=b)
    }
  } catch {
    err => raise IOError::IOError(err.to_string())
  }
  from_async_kind(k)
}

///|
pub async fn realpath(path : StringView) -> String raise IOError {
  @async_fs.realpath(path) catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
pub async fn symlink(
  target~ : StringView,
  link_path : StringView,
) -> Unit raise IOError {
  @async_fs.symlink(target~, link_path) catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
pub struct File {
  priv write_controller : @io.BinaryWriterController
  priv read_controller : @io.BinaryReaderController
  priv inner : @async_fs.File
}

///|
pub async fn open(
  path : StringView,
  mode~ : Mode,
  sync? : SyncMode,
  append? : Bool,
  create_mode? : CreateMode,
  permission? : Int32,
  create? : Int32,
  truncate? : Bool,
) -> File raise IOError {
  let sync = sync.map(to_async_sync_mode)
  let create_mode = to_async_create_mode(
    default_open_create_mode(create_mode?, create?, truncate?),
  )
  let permission = permission_or_create(permission?, create?)
  let inner = @async_fs.open(
    path,
    mode=to_async_mode(mode),
    sync?,
    append?,
    create_mode~,
    permission~,
  ) catch {
    err => raise IOError::IOError(err.to_string())
  }
  File::{
    write_controller: @io.BinaryWriterController(),
    read_controller: @io.BinaryReaderController(),
    inner,
  }
}

///|
pub async fn create(
  path : StringView,
  allow_existing? : Bool,
  permission? : Int32,
  sync? : SyncMode,
) -> File raise IOError {
  let sync = sync.map(to_async_sync_mode)
  let inner = @async_fs.create(path, allow_existing?, permission?, sync?) catch {
    err => raise IOError::IOError(err.to_string())
  }
  File::{
    write_controller: @io.BinaryWriterController(),
    read_controller: @io.BinaryReaderController(),
    inner,
  }
}

///|
pub fn File::close(self : File) -> Unit {
  self.inner.close()
}

///|
pub fn File::fd(self : File) -> Int32 {
  file_fd_to_int(self.inner.fd())
}

///|
pub fn File::as_dir(self : File) -> Directory raise IOError {
  let inner = self.inner.as_dir() catch {
    err => raise IOError::IOError(err.to_string())
  }
  Directory::{ inner, }
}

///|
pub fn File::kind(self : File) -> FileKind {
  from_async_kind(self.inner.kind())
}

///|
pub async fn File::size(self : File) -> Int64 raise IOError {
  self.inner.size() catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
pub async fn File::atime(self : File) -> (Int64, Int32) raise IOError {
  let time = self.inner.atime() catch {
    err => raise IOError::IOError(err.to_string())
  }
  (time.sec(), time.nsec())
}

///|
pub async fn File::mtime(self : File) -> (Int64, Int32) raise IOError {
  let time = self.inner.mtime() catch {
    err => raise IOError::IOError(err.to_string())
  }
  (time.sec(), time.nsec())
}

///|
pub async fn File::ctime(self : File) -> (Int64, Int32) raise IOError {
  let time = self.inner.ctime() catch {
    err => raise IOError::IOError(err.to_string())
  }
  (time.sec(), time.nsec())
}

///|
pub async fn File::read_at(
  self : File,
  buf : FixedArray[Byte],
  position~ : Int64,
  offset? : Int32,
  len? : Int32,
) -> Int32 raise IOError {
  self.inner.at(position).read_into(buf, offset?, max_len?=len) catch {
    err => raise IOError::IOError(error_message(err))
  }
}

///|
pub async fn File::read_exactly_at(
  self : File,
  len : Int32,
  position~ : Int64,
) -> Bytes raise IOError {
  self.inner.at(position).read_exactly(len) catch {
    err => raise IOError::IOError(error_message(err))
  }
}

///|
pub async fn File::write_at(
  self : File,
  buf : BytesView,
  position~ : Int64,
) -> Unit raise IOError {
  self.inner.at(position).write(buf) catch {
    err => raise IOError::IOError(error_message(err))
  }
}

///|
pub async fn File::sync(self : File, only_data? : Bool) -> Unit raise IOError {
  self.inner.sync(only_data?) catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
pub async fn File::lock(self : File, lock : Lock) -> Unit raise IOError {
  self.inner.lock(to_async_lock(lock)) catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
pub fn File::try_lock(self : File, lock : Lock) -> Bool raise IOError {
  self.inner.try_lock(to_async_lock(lock)) catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
pub fn File::unlock(self : File) -> Unit {
  self.inner.unlock()
}

///|
impl @io.BinaryReaderImpl for File with fn get_controller(self) {
  self.read_controller
}

///|
impl @io.BinaryReaderImpl for File with fn raw_read_impl(
  self,
  buf,
  offset~,
  max_len~,
) {
  self.inner.read_into(buf, offset~, max_len~)
}

///|
impl @io.BinaryWriterImpl for File with fn raw_write_impl(
  self,
  buf,
  offset~,
  len~,
) {
  self.inner.write(buf[offset:offset + len])
  len
}

///|
pub async fn tmpdir(prefix~ : StringView) -> String raise IOError {
  @async_fs.tmpdir(prefix~) catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
pub async fn walk(
  path : StringView,
  f : async (String, Array[String]) -> Unit,
  exclude? : (String) -> Bool,
  max_concurrency? : Int32,
  allow_failure? : Bool,
) -> Unit raise IOError {
  @async_fs.walk(path, f, exclude?, max_concurrency?, allow_failure?) catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
pub struct Directory {
  inner : @async_fs.Directory
}

///|
pub async fn opendir(path : StringView) -> Directory raise IOError {
  let inner = @async_fs.opendir(path) catch {
    err => raise IOError::IOError(err.to_string())
  }
  Directory::{ inner, }
}

///|
pub fn Directory::close(self : Directory) -> Unit {
  self.inner.close()
}

///|
pub async fn Directory::next(
  self : Directory,
  include_hidden? : Bool,
  include_special? : Bool,
) -> DirectoryEntry? raise IOError {
  let entry = self.inner.next(include_hidden?, include_special?) catch {
    err => raise IOError::IOError(err.to_string())
  }
  match entry {
    None => None
    Some(entry) => Some({ name: entry.name, is_dir: entry.is_dir, })
  }
}

///|
pub async fn Directory::read_all(
  self : Directory,
  include_hidden? : Bool,
  include_special? : Bool,
) -> Array[String] raise IOError {
  self.inner.read_all(include_hidden?, include_special?) catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
pub impl @io.BinaryReader for File

///|
pub extend File with @io.BinaryReader::{
  read_into,
  read_at_least,
  peek,
  peek_at_least,
  read_exactly,
  drop_exactly,
  peek_exactly,
  drop_all,
  peek_until,
}

///|
pub impl @io.BinaryWriter for File

///|
pub extend File with @io.BinaryWriter::{write_reader}

///|
impl @io.BinaryWriterImpl for File with fn get_controller(self) {
  self.write_controller
}

///|
impl @io.BinaryReaderImpl for File with fn name(_self) {
  "File"
}

///|
impl @io.BinaryWriterImpl for File with fn name(_self) {
  "File"
}

///|
impl @io.BinaryWriterImpl for File with fn flush_partial_data(_self) {
  ()
}

///|
/// Core's reader/writer errors only derive `Debug`; `Error` still has `Show`.
fn error_message(err : Error) -> String {
  err.to_string()
}
