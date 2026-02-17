///|
pub(open) trait ObjectStore {
  get(Self, @bit.ObjectId) -> @bit.PackObject? raise @bit.GitError
  put(Self, @bit.ObjectType, Bytes) -> @bit.ObjectId raise @bit.GitError
  has(Self, @bit.ObjectId) -> Bool raise @bit.GitError
}

///|
pub(open) trait RefStore {
  resolve(Self, String) -> @bit.ObjectId? raise @bit.GitError
  update(Self, String, @bit.ObjectId?) -> Unit raise @bit.GitError
  list(Self, String) -> Array[String] raise @bit.GitError
}

///|
pub(open) trait Clock {
  now(Self) -> Int64
}

///|
pub(open) trait Random {
  short(Self) -> String
}

///|
pub struct PushUpdate {
  refname : String
  old_id : @bit.ObjectId?
  new_id : @bit.ObjectId?
}

///|
pub(open) trait Transport {
  fetch(Self, String, Array[@bit.ObjectId]) -> Bytes raise @bit.GitError
  push(Self, String, Array[PushUpdate]) -> Result[Unit, String] raise @bit.GitError
}

///|
pub(open) trait WorkingTree {
  read_file(Self, String) -> Bytes raise @bit.GitError
  write_file(Self, String, Bytes) -> Unit
  remove_file(Self, String) -> Unit
  is_file(Self, String) -> Bool
  is_dir(Self, String) -> Bool
  readdir(Self, String) -> Array[String] raise @bit.GitError
  is_dirty(Self) -> Bool
  rollback(Self) -> Unit
  get_working_files(Self) -> Array[String]
  snapshot(Self, String, String, Int64) -> @bit.ObjectId raise @bit.GitError
  checkout(Self, @bit.ObjectId) -> Unit raise @bit.GitError
}
