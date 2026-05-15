///| git column - display data in columns

///|
async fn handle_column(args : Array[String]) -> Unit raise Error {
  let mut mode = "column" // column, row, plain
  let mut width = 80
  let mut padding = 1
  for arg in args {
    match arg {
      "-h" | "--help" => {
        show_simple_command_help(
          "git column [--mode=<mode>] [--width=<n>] [--padding=<n>]",
          summary="Display data in columns.",
        )
        return
      }
      _ if arg.has_prefix("--mode=") => {
        let val = String::unsafe_substring(arg, start=7, end=arg.length())
        // Accept modes: column, row, plain, never, auto, always
        match val {
          "column" | "dense" | "column,dense" => mode = "column"
          "row" | "row,dense" => mode = "row"
          "plain" | "never" => mode = "plain"
          "auto" | "always" => mode = "column"
          _ => mode = val
        }
      }
      _ if arg.has_prefix("--raw-mode=") => {
        let val = String::unsafe_substring(arg, start=11, end=arg.length())
        // Raw mode is a numeric value
        let n = @string.parse_int(val) catch { _ => 0 }
        // Bit 0-1: layout (0=column, 1=row, 2=plain)
        let layout = n & 0x3
        match layout {
          0 => mode = "column"
          1 => mode = "row"
          _ => mode = "plain"
        }
      }
      _ if arg.has_prefix("--width=") => {
        let val = String::unsafe_substring(arg, start=8, end=arg.length())
        width = @string.parse_int(val) catch { _ => 80 }
      }
      _ if arg.has_prefix("--padding=") => {
        let val = String::unsafe_substring(arg, start=10, end=arg.length())
        padding = @string.parse_int(val) catch { _ => 1 }
      }
      _ if arg.has_prefix("--indent=") => () // accept but ignore
      _ if arg.has_prefix("-") => warn_unimplemented_arg("column", arg)
      _ => ()
    }
  }
  let input = decode_bytes(read_all_stdin())
  let items : Array[String] = []
  for line_view in input.split("\n") {
    let line = line_view.to_string()
    if line.length() > 0 {
      items.push(line)
    }
  }
  if items.length() == 0 {
    return
  }
  match mode {
    "plain" =>
      for item in items {
        print_line(item)
      }
    "row" => column_layout_row(items, width, padding)
    _ =>
      // Default: column layout
      column_layout_column(items, width, padding)
  }
}

///|
async fn column_layout_column(
  items : Array[String],
  width : Int,
  padding : Int,
) -> Unit {
  // Find the maximum item width
  let mut max_width = 0
  for item in items {
    if item.length() > max_width {
      max_width = item.length()
    }
  }
  let col_width = max_width + padding
  let num_cols = if col_width > 0 {
    let n = width / col_width
    if n < 1 {
      1
    } else {
      n
    }
  } else {
    1
  }
  let num_rows = (items.length() + num_cols - 1) / num_cols
  let result = StringBuilder::new()
  let mut row = 0
  while row < num_rows {
    let mut col = 0
    while col < num_cols {
      let idx = col * num_rows + row
      if idx < items.length() {
        let item = items[idx]
        result.write_string(item)
        // Add padding (except for last column)
        if col < num_cols - 1 && (col + 1) * num_rows + row < items.length() {
          let spaces_needed = col_width - item.length()
          let mut s = 0
          while s < spaces_needed {
            result.write_char(' ')
            s += 1
          }
        }
      }
      col += 1
    }
    result.write_char('\n')
    row += 1
  }
  print_str(result.to_string())
}

///|
async fn column_layout_row(
  items : Array[String],
  width : Int,
  padding : Int,
) -> Unit {
  // Find the maximum item width
  let mut max_width = 0
  for item in items {
    if item.length() > max_width {
      max_width = item.length()
    }
  }
  let col_width = max_width + padding
  let num_cols = if col_width > 0 {
    let n = width / col_width
    if n < 1 {
      1
    } else {
      n
    }
  } else {
    1
  }
  let result = StringBuilder::new()
  for i, item in items {
    result.write_string(item)
    let col_in_row = i % num_cols
    if col_in_row == num_cols - 1 || i == items.length() - 1 {
      result.write_char('\n')
    } else {
      let spaces_needed = col_width - item.length()
      let mut s = 0
      while s < spaces_needed {
        result.write_char(' ')
        s += 1
      }
    }
  }
  print_str(result.to_string())
}
