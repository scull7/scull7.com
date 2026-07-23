// Unit tests — map_resume (Item 4)

fn minimal_doc() -> ResumeDoc {
  {
    basics: {
      name: "Test User",
      label: "Builder · Rust",
      email: "test@example.com",
      url: "https://example.com",
      summary: "Short summary.",
      location: { city: "Las Vegas", region: "NV", countryCode: "US" },
      profiles: [
        { network: "LinkedIn", username: "test", url: "https://linkedin.com/in/test" },
        { network: "GitHub", username: "test", url: "https://github.com/test" },
      ],
    },
    work: [
      {
        name: "TensorWave",
        position: "Director of Engineering",
        location: "Las Vegas, NV",
        startDate: "2024-04",
        endDate: "",
        url: "",
        description: "",
        summary: "",
        highlights: ["Shipped Relay", "Grew the team"],
      },
      {
        name: "Prior Co",
        position: "Engineer",
        location: "Remote",
        startDate: "2020-01",
        endDate: "2023-12",
        url: "",
        description: "SaaS",
        summary: "",
        highlights: ["Did things"],
      },
    ],
    education: [
      {
        institution: "Test University",
        area: "CS",
        studyType: "B.S.",
        startDate: "2000",
        endDate: "2004",
      },
    ],
    skills: [
      {
        name: "Languages (active)",
        level: "",
        keywords: ["Rust", "MoonBit"],
      },
      {
        name: "Cloud",
        level: "",
        keywords: ["AWS"],
      },
    ],
    projects: [
      {
        name: "cents",
        description: "Money as integer cents",
        url: "https://github.com/test/cents",
        keywords: ["Rust", "open-source"],
        entity: "",
      },
      {
        name: "internal-tool",
        description: "Not oss",
        url: "",
        keywords: ["TypeScript"],
        entity: "",
      },
    ],
    interests: [
      {
        name: "Core competencies",
        keywords: ["Distributed systems", "Leadership"],
      },
    ],
  }
}

test "map_resume profile" {
  let v = map_resume(minimal_doc())
  assert_eq(v.profile.name, "Test User")
  assert_eq(v.profile.tagline, "Builder · Rust")
  assert_eq(v.profile.location, "Las Vegas, NV")
  assert_eq(v.profile.email, "test@example.com")
  assert_eq(v.profile.linkedin, "https://linkedin.com/in/test")
  assert_eq(v.profile.github, "https://github.com/test")
  assert_eq(v.summary, "Short summary.")
}

test "map_resume experience count and dates" {
  let v = map_resume(minimal_doc())
  assert_eq(v.experience.length(), 2)
  assert_eq(v.experience[0].company, "TensorWave")
  assert_eq(v.experience[0].role, "Director of Engineering")
  assert_eq(v.experience[0].dates, "April 2024 – Present")
  assert_eq(v.experience[0].id, "tensorwave")
  assert_eq(v.experience[1].company, "Prior Co (SaaS)")
  assert_eq(v.experience[1].dates, "January 2020 – December 2023")
}

test "map_resume highlights dedupe cap" {
  let v = map_resume(minimal_doc())
  assert_eq(v.highlights.length(), 3)
  assert_eq(v.highlights[0], "Shipped Relay")
}

test "map_resume competencies from interests" {
  let v = map_resume(minimal_doc())
  assert_eq(v.competencies.length(), 2)
  assert_eq(v.competencies[0], "Distributed systems")
}

test "map_resume open source filter" {
  let v = map_resume(minimal_doc())
  assert_eq(v.open_source.length(), 1)
  assert_eq(v.open_source[0].name, "cents")
  assert_eq(v.open_source[0].lang, "Rust")
}

test "map_resume skills buckets" {
  let v = map_resume(minimal_doc())
  assert_eq(v.skills.languages_active.length(), 2)
  assert_eq(v.skills.languages_active[0], "Rust")
  assert_eq(v.skills.cloud[0], "AWS")
}

test "map_resume education" {
  let v = map_resume(minimal_doc())
  assert_eq(v.education.length(), 1)
  assert_eq(v.education[0].school, "Test University")
  assert_eq(v.education[0].detail, "B.S. · CS")
}
