///|
pub(open) trait ObjectStore {
  fn get(Self, @bit.ObjectId) -> @bit.PackObject? raise @bit.GitError
  fn put(Self, @bit.ObjectType, Bytes) -> @bit.ObjectId raise @bit.GitError
  fn has(Self, @bit.ObjectId) -> Bool raise @bit.GitError
}

///|
pub(open) trait RefStore {
  fn resolve(Self, String) -> @bit.ObjectId? raise @bit.GitError
  fn update(Self, String, @bit.ObjectId?) -> Unit raise @bit.GitError
  fn list(Self, String) -> Array[String] raise @bit.GitError
}

///|
pub(open) trait Clock {
  fn now(Self) -> Int64
}

///|
pub(open) trait Random {
  fn short(Self) -> String
}

///|
pub struct PushUpdate {
  refname : String
  old_id : @bit.ObjectId?
  new_id : @bit.ObjectId?
}

///|
pub(open) trait Transport {
  fn fetch(Self, String, Array[@bit.ObjectId]) -> Bytes raise @bit.GitError
  fn push(Self, String, Array[PushUpdate]) -> Result[Unit, String] raise @bit.GitError
}

///|
pub(open) trait WorkingTree {
  fn read_file(Self, String) -> Bytes raise @bit.GitError
  fn write_file(Self, String, Bytes) -> Unit
  fn remove_file(Self, String) -> Unit
  fn is_file(Self, String) -> Bool
  fn is_dir(Self, String) -> Bool
  fn readdir(Self, String) -> Array[String] raise @bit.GitError
  fn is_dirty(Self) -> Bool
  fn rollback(Self) -> Unit
  fn get_working_files(Self) -> Array[String]
  fn snapshot(Self, String, String, Int64) -> @bit.ObjectId raise @bit.GitError
  fn checkout(Self, @bit.ObjectId) -> Unit raise @bit.GitError
}
