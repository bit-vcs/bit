///| JS-export specific record shapes.

///|
pub struct JsBranchInfo {
  name : String
  commit_id : String
  is_current : Bool
} derive(Debug, Eq)

///|
pub struct JsLogEntry {
  id : String
  author : String
  message : String
  timestamp : Int
} derive(Debug, Eq)

///|
pub struct JsRefInfo {
  name : String
  id : String
} derive(Debug, Eq)

///|
pub struct JsReflogEntry {
  old_id : String
  new_id : String
  author : String
  email : String
  timestamp : Int
  timezone : String
  message : String
} derive(Debug, Eq)

///|
pub struct JsStashEntry {
  id : String
  message : String
} derive(Debug, Eq)

///|
pub struct JsRemoteVerboseEntry {
  name : String
  value : String
} derive(Debug, Eq)

///|
pub struct JsMergeResult {
  status : String
  commit_id : String
  conflicts : Array[String]
} derive(Debug, Eq)

///|
pub struct JsRebaseResult {
  status : String
  commit_id : String
  conflicts : Array[String]
} derive(Debug, Eq)

///|
pub struct JsCherryPickResult {
  status : String
  commit_id : String
  conflicts : Array[String]
} derive(Debug, Eq)

///|
pub struct JsFetchResult {
  status : String
  commit_id : String
  refname : String
  remote_ref : String
} derive(Debug, Eq)

///|
pub struct JsCloneResult {
  status : String
  commit_id : String
  refname : String
} derive(Debug, Eq)

///|
pub struct JsGcResult {
  pack_id : String
  object_count : Int
  pack_bytes : Int
  dangling : Array[String]
} derive(Debug, Eq)

///|
pub struct JsFsckResult {
  errors : Int
  reachable : Int
  missing : Array[String]
  root_commits : Array[String]
  tag_objects : Array[String]
} derive(Debug, Eq)

///|
pub struct JsWorktreeInfo {
  path : String
  head_id : String
  branch : String
  locked : Bool
  is_main : Bool
  is_bare : Bool
} derive(Debug, Eq)
