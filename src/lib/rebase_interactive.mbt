///| Interactive rebase: todo types, parser, serializer, autosquash, engine

///|
pub enum TodoCommand {
  Pick
  Reword
  Edit
  Squash
  Fixup
  Drop
} derive(Show, Eq)

///|
pub struct InteractiveTodoEntry {
  command : TodoCommand
  commit_hex : String
  subject : String
} derive(Show, Eq)

///|
fn parse_todo_command(s : String) -> TodoCommand? {
  match s {
    "pick" | "p" => Some(TodoCommand::Pick)
    "reword" | "r" => Some(TodoCommand::Reword)
    "edit" | "e" => Some(TodoCommand::Edit)
    "squash" | "s" => Some(TodoCommand::Squash)
    "fixup" | "f" => Some(TodoCommand::Fixup)
    "drop" | "d" => Some(TodoCommand::Drop)
    _ => None
  }
}

///|
fn todo_command_to_string(cmd : TodoCommand) -> String {
  match cmd {
    Pick => "pick"
    Reword => "reword"
    Edit => "edit"
    Squash => "squash"
    Fixup => "fixup"
    Drop => "drop"
  }
}

///|
pub fn parse_interactive_todo(text : String) -> Array[InteractiveTodoEntry] {
  let entries : Array[InteractiveTodoEntry] = []
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    let trimmed = @string_utils.trim_string(line)
    if trimmed.length() == 0 || trimmed.has_prefix("#") {
      continue
    }
    let first_space = trimmed.find(" ")
    guard first_space is Some(sp1) else { continue }
    let cmd_str = String::unsafe_substring(trimmed, start=0, end=sp1)
    let after_cmd = String::unsafe_substring(
      trimmed,
      start=sp1 + 1,
      end=trimmed.length(),
    )
    let after_trimmed = @string_utils.trim_string(after_cmd)
    let second_space = after_trimmed.find(" ")
    let (commit_hex, subject) = match second_space {
      Some(sp2) => (
        String::unsafe_substring(after_trimmed, start=0, end=sp2),
        @string_utils.trim_string(
          String::unsafe_substring(
            after_trimmed,
            start=sp2 + 1,
            end=after_trimmed.length(),
          ),
        ),
      )
      None => (after_trimmed, "")
    }
    match parse_todo_command(cmd_str) {
      Some(cmd) => entries.push({ command: cmd, commit_hex, subject })
      None => ()
    }
  }
  entries
}

///|
pub fn serialize_interactive_todo(
  entries : Array[InteractiveTodoEntry]
) -> String {
  let sb = StringBuilder::new()
  for entry in entries {
    sb.write_string(todo_command_to_string(entry.command))
    sb.write_string(" ")
    sb.write_string(entry.commit_hex)
    sb.write_string(" ")
    sb.write_string(entry.subject)
    sb.write_string("\n")
  }
  sb.to_string()
}
