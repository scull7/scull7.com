/** Resume content for scull7.com vim shell */
export const PROFILE = {
  name: "Nathan Sculli",
  tagline: "Builder-leader · 20+ years · Rust · Distributed Systems",
  location: "Las Vegas, NV",
  email: "nathan@vegasbuckeye.com",
  linkedin: "https://linkedin.com/in/scull7",
  github: "https://github.com/scull7",
  crates: "https://crates.io/users/scull7",
  site: "https://scull7.com",
};

export const SUMMARY = `Director of Engineering at TensorWave, primary individual contributor on the Relay service that enabled delivery of the largest AMD-based GPU clouds in record time.

Over twenty years building and leading across AI infrastructure, financial services, ML and data platforms, manufacturing, and SaaS.
Equally effective scaling teams of more than one hundred engineers across a career and architecting deep systems in Rust, OCaml, ReasonML, Haskell, and JavaScript.
Founder and CTO experience across three ventures.`;

export const COMPETENCIES = [
  "Engineering Leadership",
  "AI / GPU Infrastructure",
  "Distributed Systems Architecture",
  "Industrial Robotics & MES/SCADA",
  "Rust",
  "OCaml & ReasonML",
  "Founder / CTO",
  "Open Source Author",
];

export const HIGHLIGHTS = [
  "Architected and shipped TensorWave Relay as primary IC — largest AMD-based GPU clouds in record time",
  "100+ direct reports across career; managed 20–30 engineers as VP Eng at Influential",
  "Reduced manufacturing line failure rate by 98% via MES/SCADA + robotics orchestration",
  "PCI-DSS virtual HSM on OpenBSD (sole author) with MFA tokens + encrypted RAM-disk keys",
  "Co-built Influential data platform: real-time scan/classify/search over billions of content pieces",
  "JS UI framework that let a team of 3 outpace a 10× larger team (Discover, Inc.; IE6+)",
  "Airline SSO with PAKE, PAM, and SASL; company-wide SDLC at Allegiant Air",
];

export const EXPERIENCE = [
  {
    id: "tensorwave",
    company: "TensorWave",
    role: "Director of Engineering",
    location: "Las Vegas, NV",
    dates: "April 2024 – Present",
    bullets: [
      "Primary IC on the <strong>Relay</strong> service, enabling delivery of the largest AMD-based GPU clouds in record time",
      "Lead the software development organization; architect and oversee company-wide software projects",
      "Primary IC on the Event API",
    ],
  },
  {
    id: "subzero",
    company: "Sub Zero Corp",
    role: "Founder / CTO",
    location: "Las Vegas, NV",
    dates: "April 2023 – May 2024",
    bullets: [
      "Sole IC on a web-based SaaS platform for youth sports organizations",
    ],
  },
  {
    id: "banner",
    company: "Banner (withbanner.com)",
    role: "Sr. Software Engineer",
    location: "New York, NY (remote)",
    dates: "January 2022 – April 2023",
    bullets: [
      "Cut React web build time from <strong>10 minutes to under 1 minute</strong>",
      "Fixed concurrency bugs in MongoDB call paths",
      "DevOps infrastructure design and implementation",
    ],
  },
  {
    id: "backtrace",
    company: "Backtrace.io (SauceLabs)",
    role: "Sr. Software Engineer",
    location: "New York, NY (remote)",
    dates: "November 2020 – February 2022",
    bullets: [
      "Modernized the console web application's ReasonML code; delivered I18N / L10N",
      "Built a new email service infrastructure",
    ],
  },
  {
    id: "markertrax",
    company: "Marker Trax, LLC",
    role: "Chief Solutions Architect",
    location: "Las Vegas, NV",
    dates: "July 2019 – August 2020",
    bullets: [
      "Architected a casino-credit OEM product; drove it through certification for casino infrastructure",
      "Generalized product for all major gaming machine manufacturers; shipped web and mobile apps",
    ],
  },
  {
    id: "influential",
    company: "Influential",
    role: "VP of Engineering",
    location: "Las Vegas, NV",
    dates: "October 2014 – 2019",
    bullets: [
      "Co-built a data platform that scanned, classified and searched <strong>billions</strong> of pieces of online content in real time",
      "Managed <strong>20–30</strong> software engineers as direct reports; owned Series-A technical due diligence",
      "Overall software architecture across back-end services and front-end",
    ],
  },
  {
    id: "allegiant",
    company: "Allegiant Air",
    role: "Manager of Application Development",
    location: "Las Vegas, NV",
    dates: "July 2013 – September 2014",
    bullets: [
      "Designed and implemented airline SSO using PAKE, PAM and SASL",
      "Managed 5–7 full life-cycle teams (PM, QA, Engineer); instituted company-wide SDLC",
    ],
  },
  {
    id: "dinar",
    company: "Dinar Trade, Inc.",
    role: "Software Architect",
    location: "Las Vegas, NV",
    dates: "May 2012 – May 2013",
    bullets: [
      "Managed 4 senior engineers; personally implemented complete company + e-commerce rewrite",
    ],
  },
  {
    id: "ecommlink",
    company: "eCommLink",
    role: "Sr. Software Engineer",
    location: "Las Vegas, NV",
    dates: "December 2007 – June 2011",
    bullets: [
      "Sole author of a <strong>PCI-DSS compliant</strong>, OpenBSD-based virtual HSM using MFA tokens and encrypted RAM-disk key storage",
      "Architected a JS framework (jQuery / jQueryUI) that let a team of 3 outpace a 10× larger team on financial-services UX (Discover, Inc.); IE6+ supported",
    ],
  },
  {
    id: "decoma",
    company: "Decoma SVE (Magna International)",
    role: "Project Coordinator / Programmer",
    location: "Auburn Hills, MI",
    dates: "April 2007 – November 2007",
    bullets: [
      "Architected MES system orchestrating robotic cells, plant-floor SCADA, and yard-management — <strong>reduced line failure rate by 98%</strong>",
      "Industrial robot control / PLC integration; robotic vision; AGV / material-handling",
    ],
  },
  {
    id: "jamestown",
    company: "Jamestown Industries, Inc",
    role: "Technology Director",
    location: "Youngstown, OH",
    dates: "June 2005 – April 2007",
    bullets: [
      "Architected all plant-operation infrastructure: robot control, PLC, MES/SCADA, vision, AGV",
      "Managed 6-person tech staff across 2 locations; sole author of internal web portals and reporting tools",
    ],
  },
];

export const OPEN_SOURCE = [
  {
    name: "cents",
    lang: "Rust",
    url: "https://crates.io/crates/cents",
    blurb: "Integer-cents library for financial ledgers — avoids floating-point money errors.",
  },
  {
    name: "bs-result",
    lang: "ReasonML",
    url: "https://scull7.github.io/bs-result/",
    blurb: "Full-featured Result type — category-theory primitives used to teach engineers.",
  },
  {
    name: "bs-sql-composer",
    lang: "ReasonML",
    url: "https://redex.github.io/package/bs-sql-composer",
    blurb: "Composable SQL statements; production use at Influential for dependent object sub-graphs.",
  },
  {
    name: "bs-sql-common",
    lang: "ReasonML",
    url: "https://redex.github.io/package/bs-sql-common",
    blurb: "Multi-driver SQL interface (MySQL, SQLite) with shared semantics.",
  },
  {
    name: "bs-mysql2",
    lang: "ReasonML",
    url: "https://redex.github.io/package/bs-mysql2",
    blurb: "First ReasonML mysql2 bindings — used in production at Influential.",
  },
];

export const SKILLS = {
  languagesActive: ["Rust", "OCaml", "ReasonML", "JavaScript", "Haskell", "Swift", "Dhall"],
  languagesPrior: ["Erlang", "PHP", "Python", "Java"],
  web: ["React", "React Native", "ReasonReact", "Elm", "Vue.js", "HTML", "CSS"],
  data: ["MySQL", "PostgreSQL", "Elasticsearch", "CouchDB/Couchbase", "ArangoDB", "RethinkDB"],
  infra: ["Linux", "OpenBSD", "macOS", "NGINX", "Docker", "Kubernetes"],
  cloud: ["AWS", "DigitalOcean", "Linode"],
  cicd: ["Travis CI", "Kubernetes"],
};

export const EDUCATION = [
  {
    school: "Youngstown State University",
    detail: "Computer Science coursework toward BS",
    dates: "2001 – 2006",
  },
  {
    school: "Cisco Networking Academy @ YSU",
    detail: "CCNA",
    dates: "2006",
  },
];

export const CODE_SAMPLES = {
  cents: `<span class="cm">// cents — monetary values as integer cents (Rust)</span>
<span class="kw">use</span> cents::Cents;

<span class="kw">fn</span> <span class="fn">transfer</span>(from: <span class="kw">&mut</span> <span class="ty">Cents</span>, to: <span class="kw">&mut</span> <span class="ty">Cents</span>, amount: <span class="ty">Cents</span>) -> <span class="ty">Result</span><()> {
    from.checked_sub(amount)?;
    to.checked_add(amount)?;
    <span class="ty">Ok</span>(())
}

<span class="kw">let</span> fee = <span class="ty">Cents</span>::from_dollars(<span class="st">"1.50"</span>)?; <span class="cm">// 150 cents, never 1.499999</span>`,

  result: `<span class="cm">(* bs-result — category-theory Result for ReasonML *)</span>
<span class="kw">open</span> BsResult;

<span class="kw">let</span> parseUser = (json) =>
  json
  |> decodeField(<span class="st">"id"</span>, Decode.int)
  |> flatMap(id =>
       decodeField(<span class="st">"email"</span>, Decode.string, json)
       |> map(email => {id, email})
     );

<span class="cm">/* Composition over exceptions — teachable and total */</span>`,

  relay: `<span class="cm">// Relay (conceptual) — GPU cloud control plane event path</span>
<span class="kw">pub async fn</span> <span class="fn">route_event</span>(
    evt: <span class="ty">Event</span>,
    bus: <span class="kw">&</span><span class="ty">EventBus</span>,
    fleet: <span class="kw">&</span><span class="ty">GpuFleet</span>,
) -> <span class="ty">Result</span><<span class="ty">Ack</span>> {
    <span class="kw">let</span> plan = fleet.schedule(evt.workload())?;
    bus.publish(plan.as_control_msg()).await?;
    <span class="ty">Ok</span>(Ack::accepted(plan.id()))
}`,
};

/** Buffer catalog — each is a "file" you can :e */
export const BUFFERS = [
  { id: "README.md", icon: "📄", kind: "home", label: "README.md", badge: "home" },
  { id: "experience.md", icon: "💼", kind: "experience", label: "experience.md", badge: "work" },
  { id: "highlights.md", icon: "✦", kind: "highlights", label: "highlights.md", badge: "proof" },
  { id: "skills.md", icon: "⚙", kind: "skills", label: "skills.md", badge: "stack" },
  { id: "opensource.md", icon: "⌘", kind: "opensource", label: "opensource.md", badge: "oss" },
  { id: "cents.rs", icon: "🦀", kind: "code", label: "cents.rs", badge: "rust", sample: "cents" },
  { id: "bs_result.re", icon: "λ", kind: "code", label: "bs_result.re", badge: "ocaml", sample: "result" },
  { id: "relay.rs", icon: "⚡", kind: "code", label: "relay.rs", badge: "gpu", sample: "relay" },
  { id: "relay-viz", icon: "◈", kind: "relay", label: "relay-viz", badge: "demo" },
  { id: "terminal", icon: ">_", kind: "terminal", label: "terminal", badge: "live" },
  { id: "help.txt", icon: "?", kind: "help", label: "help.txt", badge: "docs" },
];
