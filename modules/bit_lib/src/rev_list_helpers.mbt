///| Rev-list pure helper functions

///|
/// Simple glob matching with * and ? wildcards.
pub fn rev_list_glob_match(pattern : String, text : String) -> Bool {
  let p_chars : Array[Char] = []
  let t_chars : Array[Char] = []
  for ch in pattern {
    p_chars.push(ch)
  }
  for ch in text {
    t_chars.push(ch)
  }
  let mut pi = 0
  let mut ti = 0
  let mut star_pi = -1
  let mut star_ti = -1
  while ti < t_chars.length() {
    if pi < p_chars.length() && p_chars[pi] == '?' {
      // ? matches exactly one character (but not /)
      if t_chars[ti] != '/' {
        pi += 1
        ti += 1
      } else if star_pi >= 0 {
        pi = star_pi + 1
        star_ti += 1
        ti = star_ti
      } else {
        return false
      }
    } else if pi < p_chars.length() && p_chars[pi] == t_chars[ti] {
      pi += 1
      ti += 1
    } else if pi < p_chars.length() && p_chars[pi] == '*' {
      star_pi = pi
      star_ti = ti
      pi += 1
    } else if star_pi >= 0 {
      pi = star_pi + 1
      star_ti += 1
      ti = star_ti
    } else {
      return false
    }
  }
  while pi < p_chars.length() && p_chars[pi] == '*' {
    pi += 1
  }
  pi >= p_chars.length()
}

///|
/// Find ".." or "..." in a rev-list argument. Returns (position, is_symmetric).
pub fn rev_list_find_range_dots(arg : String) -> (Int, Bool)? {
  // Look for "..." first (must check before "..")
  match arg.find("...") {
    Some(pos) => return Some((pos, true))
    None => ()
  }
  match arg.find("..") {
    Some(pos) => Some((pos, false))
    None => None
  }
}

///|
/// Compute start/end indices for skip/max-count window.
pub fn rev_list_window(
  length : Int,
  skip_count : Int,
  max_count : Int?,
) -> (Int, Int) {
  let normalized_skip = rev_list_normalize_skip(skip_count)
  let start = if normalized_skip > length { length } else { normalized_skip }
  match rev_list_normalize_max_count(max_count) {
    Some(count) => {
      let end = start + count
      (start, if end > length { length } else { end })
    }
    None => (start, length)
  }
}

///|
/// Clamp skip to non-negative.
pub fn rev_list_normalize_skip(skip_count : Int) -> Int {
  if skip_count < 0 {
    0
  } else {
    skip_count
  }
}

///|
/// Filter invalid max_count (negative values become None).
pub fn rev_list_normalize_max_count(max_count : Int?) -> Int? {
  match max_count {
    Some(count) if count >= 0 => Some(count)
    _ => None
  }
}
