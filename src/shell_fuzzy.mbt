// Fuzzy ranking for palette items (Item 5).

fn find_substr(hay : String, needle : String) -> Int? {
  let nlen = needle.length()
  let hlen = hay.length()
  if nlen == 0 {
    return Some(0)
  }
  if nlen > hlen {
    return None
  }
  let mut i = 0
  while i + nlen <= hlen {
    if hay[i:i + nlen].to_owned() == needle {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// Lower score is better. None = no match.
fn fuzzy_score(query : String, text : String) -> Int? {
  let q = query.to_lower()
  let t = text.to_lower()
  if q.is_empty() {
    return Some(0)
  }
  if t == q {
    return Some(0)
  }
  if t.has_prefix(q) {
    return Some(10)
  }
  match find_substr(t, q) {
    Some(idx) => return Some(30 + idx)
    None => ()
  }
  // subsequence
  let mut ti = 0
  let mut gaps = 0
  let mut last = -1
  let qn = q.length()
  let tn = t.length()
  let mut qi = 0
  while qi < qn {
    let qc = q[qi]
    let mut found = false
    while ti < tn {
      if t[ti] == qc {
        if last >= 0 {
          gaps = gaps + (ti - last - 1)
        }
        last = ti
        ti = ti + 1
        found = true
        break
      }
      ti = ti + 1
    }
    if !found {
      return None
    }
    qi = qi + 1
  }
  Some(100 + gaps)
}

///|
fn fuzzy_rank_label(query : String, label : String, desc : String) -> Int? {
  let a = fuzzy_score(query, label)
  let b = fuzzy_score(query, desc)
  match (a, b) {
    (Some(x), Some(y)) => Some(if x < y { x } else { y })
    (Some(x), None) => Some(x)
    (None, Some(y)) => Some(y + 5)
    (None, None) => None
  }
}

///|
/// Stable-ish sort: insertion sort by score then original index.
fn[T] sort_scored(items : Array[(Int, Int, T)]) -> Array[T] {
  let n = items.length()
  let mut i = 1
  while i < n {
    let mut j = i
    while j > 0 {
      let (sa, ia, _) = items[j - 1]
      let (sb, ib, _) = items[j]
      let swap = sb < sa || (sb == sa && ib < ia)
      if !swap {
        break
      }
      let tmp = items[j - 1]
      items[j - 1] = items[j]
      items[j] = tmp
      j = j - 1
    }
    i = i + 1
  }
  items.map(fn(row) {
    let (_, _, v) = row
    v
  })
}
