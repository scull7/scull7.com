// Unit tests — buffer catalog (Item 4)

test "find_buffer home" {
  match find_buffer("README.md") {
    Some(b) => {
      assert_true(b.kind == Home)
      assert_eq(b.label, "README.md")
    }
    None => fail("expected README.md")
  }
}

test "find_buffer missing" {
  match find_buffer("nope.md") {
    None => ()
    Some(_) => fail("expected None")
  }
}

test "find_buffer_by_query fuzzy" {
  match find_buffer_by_query("exp") {
    Some(b) => assert_eq(b.id, "experience.md")
    None => fail("expected experience")
  }
}

test "code_sample cents non-empty" {
  let s = code_sample("cents")
  assert_true(s.length() > 20)
  assert_true(s.contains("Cents"))
}

test "code_sample result has comment" {
  let s = code_sample("result")
  assert_true(s.contains("bs-result"))
}

test "buffers catalog size" {
  assert_eq(buffers.length(), 11)
}
