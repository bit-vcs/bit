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
