///|
/// SkillEntry is a raw skill definition with content.
pub(all) struct SkillEntry {
  name : String
  path : String
  source : String
  content : String
}

///|
pub fn SkillEntry::new(
  name : String,
  path : String,
  source : String,
  content : String,
) -> SkillEntry {
  { name, path, source, content }
}

///|
/// SkillInfo is a projected skill metadata view for listings.
pub(all) struct SkillInfo {
  name : String
  path : String
  source : String
  available : Bool
}

///|
pub fn SkillInfo::new(
  name : String,
  path : String,
  source : String,
  available : Bool,
) -> SkillInfo {
  { name, path, source, available }
}
