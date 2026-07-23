// JSON Resume types + view-model mapping.
// Schema: https://jsonresume.org/schema
// Optional fields are normalized to "" in public/resume.json for simple FromJson.

///|
pub struct Profile {
  network : String
  username : String
  url : String
} derive(FromJson, ToJson, Eq)

///|
pub struct Location {
  city : String
  region : String
  countryCode : String
} derive(FromJson, ToJson, Eq)

///|
pub struct Basics {
  name : String
  label : String
  email : String
  url : String
  summary : String
  location : Location
  profiles : Array[Profile]
} derive(FromJson, ToJson)

///|
pub struct Work {
  name : String
  position : String
  location : String
  startDate : String
  endDate : String
  url : String
  description : String
  summary : String
  highlights : Array[String]
} derive(FromJson, ToJson)

///|
pub struct Education {
  institution : String
  area : String
  studyType : String
  startDate : String
  endDate : String
} derive(FromJson, ToJson)

///|
pub struct Skill {
  name : String
  level : String
  keywords : Array[String]
} derive(FromJson, ToJson)

///|
pub struct Project {
  name : String
  description : String
  url : String
  keywords : Array[String]
  entity : String
} derive(FromJson, ToJson)

///|
pub struct Interest {
  name : String
  keywords : Array[String]
} derive(FromJson, ToJson)

///|
pub struct ResumeDoc {
  basics : Basics
  work : Array[Work]
  education : Array[Education]
  skills : Array[Skill]
  projects : Array[Project]
  interests : Array[Interest]
} derive(FromJson, ToJson)

///|
pub struct ViewProfile {
  name : String
  tagline : String
  location : String
  email : String
  linkedin : String
  github : String
  crates : String
  site : String
}

///|
pub struct JobView {
  id : String
  company : String
  role : String
  location : String
  dates : String
  bullets : Array[String]
}

///|
pub struct OssView {
  name : String
  lang : String
  url : String
  blurb : String
}

///|
pub struct EduView {
  school : String
  detail : String
  dates : String
}

///|
pub struct SkillsView {
  languages_active : Array[String]
  languages_prior : Array[String]
  web : Array[String]
  data : Array[String]
  infra : Array[String]
  cloud : Array[String]
  cicd : Array[String]
}

///|
pub struct ResumeView {
  profile : ViewProfile
  summary : String
  competencies : Array[String]
  highlights : Array[String]
  experience : Array[JobView]
  open_source : Array[OssView]
  skills : SkillsView
  education : Array[EduView]
}

///|
fn skill_keywords(skills : Array[Skill], name : String) -> Array[String] {
  for s in skills {
    if s.name == name {
      return s.keywords
    }
  }
  []
}

///|
fn is_oss_project(p : Project) -> Bool {
  for k in p.keywords {
    if k.to_lower().contains("open-source") {
      return true
    }
  }
  let n = p.name.to_lower()
  n.has_prefix("cents") || n.has_prefix("bs-")
}

///|
fn project_lang(p : Project) -> String {
  let langs = ["Rust", "ReasonML", "OCaml", "JavaScript", "Haskell"]
  for k in p.keywords {
    for l in langs {
      if k.to_lower() == l.to_lower() {
        return l
      }
    }
  }
  match p.keywords {
    [first, ..] => first
    [] => ""
  }
}

///|
pub fn map_resume(doc : ResumeDoc) -> ResumeView {
  let basics = doc.basics
  let profiles = basics.profiles
  let work = doc.work
  let education = doc.education
  let skills = doc.skills
  let projects = doc.projects
  let interests = doc.interests

  let profile : ViewProfile = {
    name: basics.name,
    tagline: basics.label,
    location: location_label(basics.location.city, basics.location.region),
    email: basics.email,
    linkedin: profile_url(profiles, "LinkedIn"),
    github: profile_url(profiles, "GitHub"),
    crates: profile_url(profiles, "Crates.io"),
    site: basics.url,
  }

  let competencies = {
    let mut found : Array[String] = []
    let mut hit = false
    for i in interests {
      if i.name.to_lower().contains("core competencies") {
        found = i.keywords
        hit = true
        break
      }
    }
    if hit {
      found
    } else {
      let out : Array[String] = []
      for s in skills {
        for k in s.keywords {
          if out.length() < 8 {
            out.push(k)
          }
        }
      }
      out
    }
  }

  let highlights = {
    let out : Array[String] = []
    for job in work {
      for h in job.highlights {
        if !h.is_empty() {
          let mut exists = false
          for x in out {
            if x == h {
              exists = true
              break
            }
          }
          if !exists && out.length() < 12 {
            out.push(h)
          }
        }
      }
    }
    out
  }

  let experience = work.map(job => {
    let id_base = slugify(job.name)
    let id = if !id_base.is_empty() {
      id_base
    } else {
      let p = slugify(job.position)
      if !p.is_empty() {
        p
      } else {
        "role"
      }
    }
    {
      id,
      company: company_label(job.name, job.description),
      role: job.position,
      location: job.location,
      dates: format_date_range(job.startDate, job.endDate),
      bullets: job.highlights,
    }
  })

  let open_source = projects.filter(is_oss_project).map(p => {
    {
      name: p.name,
      lang: project_lang(p),
      url: p.url,
      blurb: p.description,
    }
  })

  let skills_view : SkillsView = {
    languages_active: skill_keywords(skills, "Languages (active)"),
    languages_prior: skill_keywords(skills, "Languages (prior)"),
    web: skill_keywords(skills, "Web / UI"),
    data: skill_keywords(skills, "Data"),
    infra: skill_keywords(skills, "Infrastructure"),
    cloud: skill_keywords(skills, "Cloud"),
    cicd: skill_keywords(skills, "CI / CD"),
  }

  let edu_view = education.map(e => {
    let start = format_date(e.startDate)
    let end = format_date(e.endDate)
    let dates = if !start.is_empty() && !end.is_empty() && start != end {
      start + " – " + end
    } else if !end.is_empty() {
      end
    } else {
      start
    }
    let detail = if !e.studyType.is_empty() && !e.area.is_empty() {
      e.studyType + " · " + e.area
    } else if !e.studyType.is_empty() {
      e.studyType
    } else {
      e.area
    }
    {
      school: e.institution,
      detail,
      dates,
    }
  })

  {
    profile,
    summary: basics.summary,
    competencies,
    highlights,
    experience,
    open_source,
    skills: skills_view,
    education: edu_view,
  }
}

///|
pub async fn load_resume(url : String) -> Result[ResumeView, String] raise {
  let response = @http.fetch(url, method_="GET", cache="no-cache")
  if !response.ok {
    return Err(
      "Failed to load resume.json (" + response.status.to_string() + ")",
    )
  }
  let any = response.json()
  let j = @mbtconv.to_json(any)
  let doc : ResumeDoc = @json.from_json(j) catch {
    e => return Err("Invalid resume.json: " + e.to_string())
  }
  Ok(map_resume(doc))
}
