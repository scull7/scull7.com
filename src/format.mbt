// Pure formatting helpers for JSON Resume → UI display.

///|
let months : Array[String] = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
]

///|
fn parse_month(m : String) -> Int? {
  // parse 1-2 digit month without strconv package
  let chars = m.to_array()
  if chars.length() == 0 || chars.length() > 2 {
    return None
  }
  let mut n = 0
  for ch in chars {
    let c = ch.to_int()
    if c < 48 || c > 57 {
      return None
    }
    n = n * 10 + (c - 48)
  }
  Some(n)
}

///|
pub fn format_date(iso : String) -> String {
  if iso.is_empty() {
    return ""
  }
  let parts = iso.split("-").map(v => v.to_string()).collect()
  if parts.length() >= 2 {
    let y = parts[0]
    match parse_month(parts[1]) {
      Some(n) =>
        if n >= 1 && n <= 12 {
          months[n - 1] + " " + y
        } else {
          y
        }
      None => y
    }
  } else if parts.length() == 1 {
    parts[0]
  } else {
    iso
  }
}

///|
pub fn format_date_range(start_date : String, end_date : String) -> String {
  let start = format_date(start_date)
  if start.is_empty() {
    return ""
  }
  if end_date.is_empty() {
    return start + " – Present"
  }
  start + " – " + format_date(end_date)
}

///|
pub fn slugify(text : String) -> String {
  let lower = text.to_lower()
  let mut out = ""
  let mut prev_dash = false
  for ch in lower {
    let code = ch.to_int()
    let is_az = code >= 97 && code <= 122
    let is_digit = code >= 48 && code <= 57
    if is_az || is_digit {
      out = out + ch.to_string()
      prev_dash = false
    } else if !prev_dash && out.length() > 0 {
      out = out + "-"
      prev_dash = true
    }
  }
  if out.has_suffix("-") && out.length() > 0 {
    out = out.substring(end=out.length() - 1)
  }
  if out.length() > 48 {
    out.substring(end=48)
  } else {
    out
  }
}

///|
pub fn location_label(city : String, region : String) -> String {
  if !city.is_empty() && !region.is_empty() {
    city + ", " + region
  } else if !city.is_empty() {
    city
  } else {
    region
  }
}

///|
pub fn company_label(name : String, description : String) -> String {
  if !description.is_empty() {
    name + " (" + description + ")"
  } else {
    name
  }
}

///|
pub fn profile_url(profiles : Array[Profile], network : String) -> String {
  let target = network.to_lower()
  for p in profiles {
    if p.network.to_lower() == target {
      return p.url
    }
  }
  ""
}
