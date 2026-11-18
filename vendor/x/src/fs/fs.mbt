///|
/// File system error.
pub suberror IOError {
  IOError(String)
}

///|
pub impl Show for IOError with fn output(self, logger) {
  let IOError(msg) = self
  logger.write_string("IOError(\{msg})")
}

///|
/// File kind, mirroring `moonbitlang/core/async/fs.FileKind` (same variants and
/// numeric tags) so the same code compiles for native (delegates to
/// upstream) and JS (translated from Node `fs.lstat` / `fs.stat`).
#derive(Eq, @debug.Debug)
pub(all) enum FileKind {
  Unknown = 0
  Regular = 1
  Directory = 2
  SymLink = 3
  Socket = 4
  Pipe = 5
  BlockDevice = 6
  CharDevice = 7
}

///|
pub impl Show for FileKind with fn output(self, logger) {
  logger.write_string(
    match self {
      Unknown => "Unknown"
      Regular => "Regular"
      Directory => "Directory"
      SymLink => "SymLink"
      Socket => "Socket"
      Pipe => "Pipe"
      BlockDevice => "BlockDevice"
      CharDevice => "CharDevice"
    },
  )
}

///|
/// Directory entry returned by `Directory::next`.
pub(all) struct DirectoryEntry {
  name : String
  is_dir : Bool
}

///|
pub(all) enum Mode {
  ReadOnly
  WriteOnly
  ReadWrite
}

///|
pub(all) enum SyncMode {
  NoSync
  Data
  Full
}

///|
pub(all) enum CreateMode {
  OpenExisting
  TruncateExisting
  OpenOrCreate
  CreateOrTruncate
  CreateNew
}

///|
pub(all) enum Lock {
  Shared
  Exclusive
}

///|
pub extend IOError with Show::{to_string, output}

///|
pub extend FileKind with Eq::{not_equal, equal}

///|
pub extend FileKind with @debug.Debug::{to_repr}

///|
pub extend FileKind with Show::{to_string, output}
