// Unit tests — fuzzy ranking (Item 5)

test "fuzzy exact beats substring" {
  let a = fuzzy_score("exp", "exp").unwrap()
  let b = fuzzy_score("exp", "experience.md").unwrap()
  assert_true(a < b)
}

test "fuzzy prefix beats mid" {
  let pre = fuzzy_score("term", "terminal").unwrap()
  let mid = fuzzy_score("term", "xterminal").unwrap()
  assert_true(pre < mid)
}

test "fuzzy none" {
  match fuzzy_score("zzz", "hello") {
    None => ()
    Some(_) => fail("expected no match")
  }
}

test "fuzzy empty matches all" {
  assert_eq(fuzzy_score("", "anything"), Some(0))
}
