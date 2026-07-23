// Unit tests — format helpers (Item 4)

test "format_date empty" {
  assert_eq(format_date(""), "")
}

test "format_date year only" {
  assert_eq(format_date("2020"), "2020")
}

test "format_date month year" {
  assert_eq(format_date("2024-04"), "April 2024")
}

test "format_date december" {
  assert_eq(format_date("2019-12"), "December 2019")
}

test "format_date_range present" {
  assert_eq(format_date_range("2024-04", ""), "April 2024 – Present")
}

test "format_date_range both ends" {
  assert_eq(
    format_date_range("2020-01", "2022-06"),
    "January 2020 – June 2022",
  )
}

test "format_date_range empty start" {
  assert_eq(format_date_range("", "2020-01"), "")
}

test "slugify simple" {
  assert_eq(slugify("Hello World"), "hello-world")
}

test "slugify company punctuation" {
  assert_eq(slugify("TensorWave Inc."), "tensorwave-inc")
}

test "slugify collapses separators" {
  assert_eq(slugify("foo   bar__baz"), "foo-bar-baz")
}

test "slugify empty" {
  assert_eq(slugify(""), "")
}

test "location_label both" {
  assert_eq(location_label("Las Vegas", "NV"), "Las Vegas, NV")
}

test "location_label city only" {
  assert_eq(location_label("Remote", ""), "Remote")
}

test "location_label region only" {
  assert_eq(location_label("", "CA"), "CA")
}

test "company_label with description" {
  assert_eq(company_label("Acme", "AI infra"), "Acme (AI infra)")
}

test "company_label bare" {
  assert_eq(company_label("Acme", ""), "Acme")
}
