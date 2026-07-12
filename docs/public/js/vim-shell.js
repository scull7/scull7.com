/**
 * scull7.com — vim-inspired keyboard shell
 * Modes: NORMAL | COMMAND | SEARCH
 * Commands: :help :open :e :ls :q  /search  gg G hjkl
 */
import {
  PROFILE,
  SUMMARY,
  COMPETENCIES,
  HIGHLIGHTS,
  EXPERIENCE,
  OPEN_SOURCE,
  SKILLS,
  EDUCATION,
  CODE_SAMPLES,
  BUFFERS,
} from "./data.js";

const MODE = { NORMAL: "NORMAL", COMMAND: "COMMAND", SEARCH: "SEARCH", INSERT: "INSERT" };

const COMMANDS = [
  { cmd: "help", desc: "Show keyboard help", run: (ctx) => ctx.openBuffer("help.txt") },
  { cmd: "ls", desc: "List buffers", run: (ctx) => ctx.showLs() },
  { cmd: "open", desc: "Open buffer (:open name)", run: (ctx, arg) => ctx.openByQuery(arg) },
  { cmd: "e", desc: "Edit/open buffer (:e name)", run: (ctx, arg) => ctx.openByQuery(arg) },
  { cmd: "q", desc: "Close overlay / go home", run: (ctx) => ctx.quit() },
  { cmd: "quit", desc: "Alias for :q", run: (ctx) => ctx.quit() },
  { cmd: "home", desc: "Open README.md", run: (ctx) => ctx.openBuffer("README.md") },
  { cmd: "experience", desc: "Open experience.md", run: (ctx) => ctx.openBuffer("experience.md") },
  { cmd: "skills", desc: "Open skills.md", run: (ctx) => ctx.openBuffer("skills.md") },
  { cmd: "oss", desc: "Open opensource.md", run: (ctx) => ctx.openBuffer("opensource.md") },
  { cmd: "terminal", desc: "Open live terminal", run: (ctx) => ctx.openBuffer("terminal") },
  { cmd: "relay", desc: "Open Relay viz", run: (ctx) => ctx.openBuffer("relay-viz") },
];

class VimShell {
  constructor(root) {
    this.root = root;
    this.mode = MODE.NORMAL;
    this.focusIdx = 0;
    this.activeId = "README.md";
    this.msg = "Press : for commands · / to search · ? for help";
    this.msgKind = "";
    this.gPending = false;
    this.paletteItems = [];
    this.paletteFocus = 0;
    this.paletteMode = null; // 'command' | 'search'
    this.termHistory = [];
    this.termHistIdx = -1;

    this.buffersCollapsed = false;
    this.renderChrome();
    this.bind();
    this.syncBuffersCollapsed(window.matchMedia("(max-width: 860px)").matches);
    this.openBuffer(this.activeId, { silent: true });
    this.setMsg(this.msg);
  }

  $(sel, el = this.root) {
    return el.querySelector(sel);
  }

  renderChrome() {
    this.root.innerHTML = `
      <div class="galaxy" aria-hidden="true"></div>
      <div class="workspace">
        <aside class="buffer-list glass" id="buffer-list" aria-label="Buffer list">
          <button type="button" class="buffer-list-header" id="buffer-toggle" aria-expanded="true" aria-controls="buffer-items">
            <span class="title"><span class="chevron" aria-hidden="true">▾</span> buffers</span>
            <span class="hint">:ls</span>
          </button>
          <ul class="buffer-items" id="buffer-items"></ul>
        </aside>
        <section class="buffer-pane glass-strong" aria-label="Active buffer">
          <div class="buffer-tabbar" id="tabbar"></div>
          <div class="buffer-body" id="buffer-body" tabindex="0"></div>
        </section>
      </div>

      <div class="bottom-chrome" id="bottom-chrome">
        <footer class="statusline" role="status">
          <span class="mode" id="mode-badge">NORMAL</span>
          <span class="file" id="status-file">README.md</span>
          <span class="spacer"></span>
          <span class="meta">
            <span id="status-loc">${PROFILE.location}</span>
            <span id="status-pos">1:1</span>
            <span>utf-8</span>
          </span>
        </footer>
        <div class="cmdline" id="cmdline">
          <span class="msg" id="cmdline-msg"></span>
        </div>
      </div>

      <div class="palette" id="palette" aria-hidden="true">
        <div class="palette-panel glass-strong">
          <div class="palette-input-row">
            <span class="pfx" id="palette-pfx">:</span>
            <input id="palette-input" type="text" autocomplete="off" spellcheck="false" aria-label="Command palette" />
          </div>
          <ul class="palette-results" id="palette-results"></ul>
        </div>
      </div>
    `;

    this.els = {
      list: this.$("#buffer-list"),
      toggle: this.$("#buffer-toggle"),
      items: this.$("#buffer-items"),
      body: this.$("#buffer-body"),
      tabbar: this.$("#tabbar"),
      mode: this.$("#mode-badge"),
      file: this.$("#status-file"),
      pos: this.$("#status-pos"),
      cmdline: this.$("#cmdline"),
      msg: this.$("#cmdline-msg"),
      palette: this.$("#palette"),
      paletteInput: this.$("#palette-input"),
      paletteResults: this.$("#palette-results"),
      palettePfx: this.$("#palette-pfx"),
    };

    this.renderBufferList();

    // Reparent chrome to <body> so position:fixed sticks to the viewport
    // even if Astra wraps #vim-root in transformed/filtered ancestors.
    const bottom = this.$(".bottom-chrome");
    const palette = this.els.palette;
    if (bottom && bottom.parentElement !== document.body) {
      document.body.appendChild(bottom);
    }
    if (palette && palette.parentElement !== document.body) {
      document.body.appendChild(palette);
    }
  }

  isMobile() {
    return window.matchMedia("(max-width: 860px)").matches;
  }

  syncBuffersCollapsed(collapsed) {
    this.buffersCollapsed = Boolean(collapsed);
    this.els.list?.classList.toggle("is-collapsed", this.buffersCollapsed);
    if (this.els.toggle) {
      this.els.toggle.setAttribute("aria-expanded", this.buffersCollapsed ? "false" : "true");
    }
  }

  toggleBuffers() {
    this.syncBuffersCollapsed(!this.buffersCollapsed);
  }

  renderBufferList() {
    this.els.items.innerHTML = BUFFERS.map((b, i) => `
      <li class="buffer-item${i === this.focusIdx ? " focused" : ""}${b.id === this.activeId ? " active" : ""}"
          data-id="${b.id}" data-idx="${i}" role="option" aria-selected="${i === this.focusIdx}">
        <span class="icon">${b.icon}</span>
        <span class="name">${b.label}</span>
        <span class="badge">${b.badge}</span>
      </li>
    `).join("");
  }

  bind() {
    document.addEventListener("keydown", (e) => this.onKey(e));
    this.els.toggle?.addEventListener("click", () => this.toggleBuffers());
    this.els.items.addEventListener("click", (e) => {
      const li = e.target.closest(".buffer-item");
      if (!li) return;
      this.focusIdx = Number(li.dataset.idx);
      this.openBuffer(li.dataset.id);
    });
    this.els.paletteInput.addEventListener("input", () => this.refreshPalette());
    this.els.palette.addEventListener("click", (e) => {
      if (e.target === this.els.palette) this.closePalette();
      const li = e.target.closest("li[data-idx]");
      if (li) {
        this.paletteFocus = Number(li.dataset.idx);
        this.acceptPalette();
      }
    });
    window.matchMedia("(max-width: 860px)").addEventListener("change", (e) => {
      this.syncBuffersCollapsed(e.matches);
    });
  }

  onKey(e) {
    // Let inputs handle typing when focused (terminal / palette)
    const tag = (e.target.tagName || "").toLowerCase();
    const isField = tag === "input" || tag === "textarea" || e.target.isContentEditable;

    if (this.paletteMode) {
      this.onPaletteKey(e);
      return;
    }

    if (isField && e.target.id !== "palette-input") {
      // terminal insert mode
      if (e.key === "Escape") {
        e.preventDefault();
        e.target.blur();
        this.setMode(MODE.NORMAL);
      }
      return;
    }

    if (this.mode === MODE.NORMAL) {
      this.onNormalKey(e);
    }
  }

  onNormalKey(e) {
    const key = e.key;

    if (key === ":" && !e.ctrlKey && !e.metaKey) {
      e.preventDefault();
      this.openPalette("command");
      return;
    }
    if (key === "/" && !e.ctrlKey && !e.metaKey) {
      e.preventDefault();
      this.openPalette("search");
      return;
    }
    if (key === "?") {
      e.preventDefault();
      this.openBuffer("help.txt");
      return;
    }

    if (key === "j" || key === "ArrowDown") {
      e.preventDefault();
      this.moveFocus(1);
      return;
    }
    if (key === "k" || key === "ArrowUp") {
      e.preventDefault();
      this.moveFocus(-1);
      return;
    }
    if (key === "h" || key === "ArrowLeft") {
      e.preventDefault();
      this.els.items.focus?.();
      return;
    }
    if (key === "l" || key === "ArrowRight" || key === "Enter") {
      e.preventDefault();
      this.openBuffer(BUFFERS[this.focusIdx].id);
      return;
    }
    if (key === "g") {
      if (this.gPending) {
        e.preventDefault();
        this.gPending = false;
        this.focusIdx = 0;
        this.renderBufferList();
        this.scrollFocusIntoView();
        this.setMsg("gg → top");
      } else {
        this.gPending = true;
        setTimeout(() => { this.gPending = false; }, 500);
      }
      return;
    }
    if (key === "G") {
      e.preventDefault();
      this.focusIdx = BUFFERS.length - 1;
      this.renderBufferList();
      this.scrollFocusIntoView();
      this.setMsg("G → bottom");
      return;
    }
    if (key === "Escape") {
      this.setMsg("");
      return;
    }
  }

  onPaletteKey(e) {
    if (e.key === "Escape") {
      e.preventDefault();
      this.closePalette();
      return;
    }
    if (e.key === "ArrowDown") {
      e.preventDefault();
      this.paletteFocus = Math.min(this.paletteFocus + 1, this.paletteItems.length - 1);
      this.paintPaletteFocus();
      return;
    }
    if (e.key === "ArrowUp") {
      e.preventDefault();
      this.paletteFocus = Math.max(this.paletteFocus - 1, 0);
      this.paintPaletteFocus();
      return;
    }
    if (e.key === "Enter") {
      e.preventDefault();
      this.acceptPalette();
    }
  }

  moveFocus(delta) {
    this.focusIdx = (this.focusIdx + delta + BUFFERS.length) % BUFFERS.length;
    this.renderBufferList();
    this.scrollFocusIntoView();
    this.els.pos.textContent = `${this.focusIdx + 1}:1`;
  }

  scrollFocusIntoView() {
    const el = this.els.items.querySelector(`.buffer-item[data-idx="${this.focusIdx}"]`);
    el?.scrollIntoView({ block: "nearest" });
  }

  setMode(mode) {
    this.mode = mode;
    this.els.mode.textContent = mode;
    this.els.mode.className = "mode " + mode.toLowerCase();
  }

  setMsg(text, kind = "") {
    this.msg = text || "";
    this.msgKind = kind;
    this.els.msg.textContent = this.msg;
    this.els.msg.className = "msg" + (kind ? ` ${kind}` : "");
  }

  openPalette(kind) {
    this.paletteMode = kind;
    this.paletteFocus = 0;
    this.setMode(kind === "search" ? MODE.SEARCH : MODE.COMMAND);
    this.els.palette.classList.add("open");
    this.els.palette.setAttribute("aria-hidden", "false");
    this.els.palettePfx.textContent = kind === "search" ? "/" : ":";
    this.els.paletteInput.value = "";
    this.els.paletteInput.focus();
    this.refreshPalette();
  }

  closePalette() {
    this.paletteMode = null;
    this.els.palette.classList.remove("open");
    this.els.palette.setAttribute("aria-hidden", "true");
    this.els.paletteInput.blur();
    this.setMode(MODE.NORMAL);
  }

  refreshPalette() {
    const q = this.els.paletteInput.value.trim().toLowerCase();
    if (this.paletteMode === "search") {
      this.paletteItems = BUFFERS
        .filter((b) => !q || b.label.toLowerCase().includes(q) || b.badge.includes(q) || b.kind.includes(q))
        .map((b) => ({ label: b.label, desc: b.badge, action: () => this.openBuffer(b.id) }));
    } else {
      // command mode — filter COMMANDS + buffer names for :e
      const raw = this.els.paletteInput.value.trim();
      const [head, ...rest] = raw.split(/\s+/);
      const arg = rest.join(" ");
      if (!head || "help ls open e q quit home experience skills oss terminal relay".split(" ").some((c) => c.startsWith(head.toLowerCase()))) {
        this.paletteItems = COMMANDS
          .filter((c) => !head || c.cmd.startsWith(head.toLowerCase()))
          .map((c) => ({
            label: ":" + c.cmd + (c.cmd === "open" || c.cmd === "e" ? " {buf}" : ""),
            desc: c.desc,
            action: () => c.run(this, arg || head),
            cmd: c.cmd,
            arg,
          }));
      }
      // also suggest buffers when typing after :e / :open
      if (head && (head === "e" || head === "open" || "e".startsWith(head) || "open".startsWith(head))) {
        const bufQ = (arg || "").toLowerCase();
        const bufs = BUFFERS
          .filter((b) => !bufQ || b.label.toLowerCase().includes(bufQ))
          .map((b) => ({
            label: `:${head || "e"} ${b.label}`,
            desc: "open buffer",
            action: () => this.openBuffer(b.id),
          }));
        this.paletteItems = [...this.paletteItems, ...bufs];
      }
    }
    this.paletteFocus = 0;
    this.renderPaletteResults();
  }

  renderPaletteResults() {
    if (!this.paletteItems.length) {
      this.els.paletteResults.innerHTML = `<div class="palette-empty">No matches</div>`;
      return;
    }
    this.els.paletteResults.innerHTML = this.paletteItems.map((item, i) => `
      <li data-idx="${i}" class="${i === this.paletteFocus ? "focused" : ""}">
        <span>${item.label}</span>
        <span class="desc">${item.desc || ""}</span>
      </li>
    `).join("");
  }

  paintPaletteFocus() {
    this.els.paletteResults.querySelectorAll("li").forEach((li, i) => {
      li.classList.toggle("focused", i === this.paletteFocus);
    });
  }

  acceptPalette() {
    const item = this.paletteItems[this.paletteFocus];
    if (!item) {
      // try freeform :cmd
      if (this.paletteMode === "command") {
        this.runCommandLine(this.els.paletteInput.value.trim());
      }
      this.closePalette();
      return;
    }
    this.closePalette();
    item.action();
  }

  runCommandLine(raw) {
    if (!raw) return;
    const [head, ...rest] = raw.split(/\s+/);
    const arg = rest.join(" ");
    const cmd = COMMANDS.find((c) => c.cmd === head.toLowerCase());
    if (cmd) {
      cmd.run(this, arg);
      return;
    }
    // bare buffer name
    if (this.openByQuery(raw)) return;
    this.setMsg(`E492: Not an editor command: ${raw}`, "error");
  }

  openByQuery(q) {
    if (!q) {
      this.setMsg("E32: No file name", "error");
      return false;
    }
    const needle = q.toLowerCase().replace(/^:/, "");
    const buf = BUFFERS.find(
      (b) =>
        b.id.toLowerCase() === needle ||
        b.label.toLowerCase() === needle ||
        b.label.toLowerCase().startsWith(needle) ||
        b.id.toLowerCase().includes(needle)
    );
    if (!buf) {
      this.setMsg(`E94: No matching buffer for ${q}`, "error");
      return false;
    }
    this.openBuffer(buf.id);
    return true;
  }

  quit() {
    this.closePalette();
    this.openBuffer("README.md");
    this.setMsg("closed → README.md", "ok");
  }

  showLs() {
    if (this.isMobile()) this.syncBuffersCollapsed(false);
    const list = BUFFERS.map((b, i) => `${i === this.focusIdx ? "%" : " "} ${b.label}`).join("  ");
    this.setMsg(list);
  }

  openBuffer(id, { silent = false } = {}) {
    const buf = BUFFERS.find((b) => b.id === id);
    if (!buf) return;
    this.activeId = id;
    const idx = BUFFERS.findIndex((b) => b.id === id);
    if (idx >= 0) this.focusIdx = idx;
    this.els.file.textContent = buf.label;
    this.els.pos.textContent = `${this.focusIdx + 1}:1`;
    this.renderBufferList();
    this.els.tabbar.innerHTML = `<div class="buffer-tab active">${buf.icon} ${buf.label}</div>`;
    this.els.body.innerHTML = this.renderBufferContent(buf);
    this.els.body.scrollTop = 0;

    if (buf.kind === "terminal") this.mountTerminal();
    if (buf.kind === "relay") this.mountRelay();

    // On mobile, collapse buffer menu after opening so content has room
    if (!silent && this.isMobile()) this.syncBuffersCollapsed(true);

    if (!silent) this.setMsg(`"${buf.label}" opened`, "ok");
  }

  renderBufferContent(buf) {
    switch (buf.kind) {
      case "home":
        return this.viewHome();
      case "experience":
        return this.viewExperience();
      case "highlights":
        return this.viewHighlights();
      case "skills":
        return this.viewSkills();
      case "opensource":
        return this.viewOpenSource();
      case "code":
        return this.viewCode(buf);
      case "relay":
        return this.viewRelayShell();
      case "terminal":
        return this.viewTerminalShell();
      case "help":
        return this.viewHelp();
      default:
        return `<p>Empty buffer</p>`;
    }
  }

  viewHome() {
    const summaryHtml = SUMMARY
      .split(/\n+/)
      .filter(Boolean)
      .map((p) => `<p class="summary">${p}</p>`)
      .join("");
    return `
      <div class="hero">
        <div class="hero-kicker">~/scull7.com</div>
        <h1>${PROFILE.name}</h1>
        <p class="tagline">${PROFILE.tagline}</p>
        <div class="hero-links">
          <a href="mailto:${PROFILE.email}">${PROFILE.email}</a>
          <a href="${PROFILE.linkedin}" target="_blank" rel="noopener">linkedin/in/scull7</a>
          <a href="${PROFILE.github}" target="_blank" rel="noopener">github.com/scull7</a>
        </div>
      </div>
      <h2 class="section-title">summary</h2>
      ${summaryHtml}
      <div class="competency-grid">
        ${COMPETENCIES.map((c) => `<span class="pill hot">${c}</span>`).join("")}
      </div>
      <div class="help-strip">
        <span><kbd>:</kbd> command</span>
        <span><kbd>/</kbd> search</span>
        <span><kbd>j</kbd><kbd>k</kbd> buffers</span>
        <span><kbd>Enter</kbd> open</span>
        <span><kbd>gg</kbd>/<kbd>G</kbd> top/bottom</span>
        <span><kbd>?</kbd> help</span>
      </div>
    `;
  }

  viewExperience() {
    return `
      <h2 class="section-title">work experience</h2>
      ${EXPERIENCE.map((job) => `
        <article class="job" id="job-${job.id}">
          <div class="job-head">
            <div class="job-title">${job.role} · <span class="company">${job.company}</span></div>
            <div class="job-meta">${job.dates} · ${job.location}</div>
          </div>
          <ul>${job.bullets.map((b) => `<li>${b}</li>`).join("")}</ul>
        </article>
      `).join("")}
    `;
  }

  viewHighlights() {
    return `
      <h2 class="section-title">career highlights</h2>
      <ul>${HIGHLIGHTS.map((h) => `<li style="margin:10px 0;color:var(--text-dim)">${h}</li>`).join("")}</ul>
      <h2 class="section-title" style="margin-top:28px">education</h2>
      ${EDUCATION.map((e) => `
        <div class="job">
          <div class="job-head">
            <div class="job-title">${e.school}</div>
            <div class="job-meta">${e.dates}</div>
          </div>
          <div style="color:var(--text-dim)">${e.detail}</div>
        </div>
      `).join("")}
    `;
  }

  viewSkills() {
    const block = (title, items) => `
      <h2 class="section-title">${title}</h2>
      <div class="competency-grid" style="margin-bottom:18px">
        ${items.map((s) => `<span class="pill">${s}</span>`).join("")}
      </div>
    `;
    return `
      ${block("languages (active)", SKILLS.languagesActive)}
      ${block("languages (prior)", SKILLS.languagesPrior)}
      ${block("web / ui", SKILLS.web)}
      ${block("data", SKILLS.data)}
      ${block("infrastructure", SKILLS.infra)}
      ${block("cloud", SKILLS.cloud)}
      ${block("ci / cd", SKILLS.cicd)}
    `;
  }

  viewOpenSource() {
    return `
      <h2 class="section-title">open source</h2>
      ${OPEN_SOURCE.map((o) => `
        <div class="oss-card">
          <h3><a href="${o.url}" target="_blank" rel="noopener">${o.name}</a> <span class="pill">${o.lang}</span></h3>
          <p>${o.blurb}</p>
        </div>
      `).join("")}
      <p style="margin-top:18px;color:var(--text-mute);font-family:var(--font-mono);font-size:12px">
        github.com/scull7 · crates.io/users/scull7
      </p>
    `;
  }

  viewCode(buf) {
    const html = CODE_SAMPLES[buf.sample] || "// empty";
    return `
      <h2 class="section-title">${buf.label}</h2>
      <pre class="code-block" tabindex="0">${html}</pre>
      <p style="margin-top:14px;color:var(--text-mute);font-family:var(--font-mono);font-size:12px">
        sample buffer · read-only · :e terminal for live commands
      </p>
    `;
  }

  viewRelayShell() {
    return `
      <h2 class="section-title">relay · gpu cloud control plane</h2>
      <div class="relay-viz">
        <div class="relay-canvas" id="relay-canvas">
          <div class="relay-node" style="left:18%;top:50%">clients</div>
          <div class="relay-node primary" style="left:50%;top:30%">Relay</div>
          <div class="relay-node" style="left:50%;top:70%">Event API</div>
          <div class="relay-node gpu" style="left:82%;top:50%">AMD GPU fleet</div>
          <div class="relay-packet"></div>
          <div class="relay-packet b"></div>
          <div class="relay-packet c"></div>
        </div>
        <div class="relay-stats">
          <div class="relay-stat"><div class="label">Role</div><div class="value" style="font-size:15px">Dir Eng · IC</div></div>
          <div class="relay-stat"><div class="label">Domain</div><div class="value" style="font-size:15px">GPU clouds</div></div>
          <div class="relay-stat"><div class="label">Impact</div><div class="value" style="font-size:15px">Record delivery</div></div>
          <div class="relay-stat"><div class="label">Stack</div><div class="value" style="font-size:15px">Rust · distributed</div></div>
        </div>
        <p class="summary" style="font-size:14px;color:var(--text-dim)">
          At TensorWave, Relay is the path that turns workload intent into scheduled GPU capacity.
          As Director of Engineering and primary IC, I architected and shipped the service that
          unlocked the largest AMD-based GPU clouds the company has delivered — under aggressive timelines.
        </p>
      </div>
    `;
  }

  viewTerminalShell() {
    return `
      <h2 class="section-title">live terminal</h2>
      <div class="terminal glass" id="live-term">
        <div class="terminal-output" id="term-out"></div>
        <div class="terminal-input-row">
          <span class="terminal-prompt">scull7@resume:~$</span>
          <input class="terminal-input" id="term-in" type="text" autocomplete="off" spellcheck="false" aria-label="Terminal input" />
        </div>
      </div>
    `;
  }

  viewHelp() {
    const rows = [
      [":help", "This screen"],
      [":ls", "List buffers in statusline"],
      [":e {name} / :open {name}", "Open a buffer by name"],
      [":q", "Return to README.md"],
      [":terminal / :relay", "Jump to demos"],
      ["/", "Fuzzy find buffers"],
      ["j k  /  ↓ ↑", "Move buffer focus"],
      ["Enter / l", "Open focused buffer"],
      ["gg / G", "Top / bottom of buffer list"],
      ["Esc", "Cancel command / leave insert"],
      ["?", "Open help"],
    ];
    return `
      <h2 class="section-title">help.txt</h2>
      <p class="summary" style="margin-bottom:16px">Vim-inspired navigation for this resume. Mouse works too — but the keyboard is faster.</p>
      <div class="help-grid">
        ${rows.map(([c, d]) => `<div class="cmd">${c}</div><div class="desc">${d}</div>`).join("")}
      </div>
    `;
  }

  mountTerminal() {
    const out = this.$("#term-out");
    const input = this.$("#term-in");
    if (!out || !input) return;

    const println = (text, cls = "") => {
      const line = document.createElement("div");
      if (cls) line.className = cls;
      line.textContent = text;
      out.appendChild(line);
      out.scrollTop = out.scrollHeight;
    };

    println("scull7.com interactive shell — type help", "line-info");
    println("try: help | whoami | ls | open experience | cats | clear", "line-dim");

    input.addEventListener("focus", () => this.setMode(MODE.INSERT));
    input.addEventListener("blur", () => this.setMode(MODE.NORMAL));

    input.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        const raw = input.value.trim();
        println(`scull7@resume:~$ ${raw}`);
        if (raw) {
          this.termHistory.push(raw);
          this.termHistIdx = this.termHistory.length;
        }
        this.execTerm(raw, println);
        input.value = "";
      } else if (e.key === "ArrowUp") {
        e.preventDefault();
        if (this.termHistIdx > 0) {
          this.termHistIdx -= 1;
          input.value = this.termHistory[this.termHistIdx] || "";
        }
      } else if (e.key === "ArrowDown") {
        e.preventDefault();
        if (this.termHistIdx < this.termHistory.length - 1) {
          this.termHistIdx += 1;
          input.value = this.termHistory[this.termHistIdx] || "";
        } else {
          this.termHistIdx = this.termHistory.length;
          input.value = "";
        }
      }
    });

    setTimeout(() => input.focus(), 50);
  }

  execTerm(raw, println) {
    if (!raw) return;
    const [cmd, ...args] = raw.split(/\s+/);
    const arg = args.join(" ");

    switch (cmd.toLowerCase()) {
      case "help":
        println("commands: help whoami ls open cat clear fortune skills contact", "line-info");
        break;
      case "whoami":
        println(`${PROFILE.name} — ${PROFILE.tagline}`, "line-ok");
        break;
      case "ls":
        println(BUFFERS.map((b) => b.label).join("  "));
        break;
      case "open":
      case "e":
      case "cat":
        if (this.openByQuery(arg || "README.md")) println(`opened ${arg || "README.md"}`, "line-ok");
        else println(`no such buffer: ${arg}`, "line-err");
        break;
      case "clear":
        this.$("#term-out").innerHTML = "";
        break;
      case "skills":
        println(SKILLS.languagesActive.join(", "), "line-ok");
        break;
      case "contact":
        println(`${PROFILE.email}  ${PROFILE.github}  ${PROFILE.linkedin}`, "line-info");
        break;
      case "fortune":
        println("Talk is cheap. Show me the code. — Linus", "line-ok");
        break;
      case "pwd":
        println("~/scull7.com");
        break;
      case "echo":
        println(arg);
        break;
      default:
        println(`command not found: ${cmd}`, "line-err");
        println("type help for available commands", "line-dim");
    }
  }

  mountRelay() {
    // animation is pure CSS; nothing to mount
  }
}

function boot() {
  const mount = document.getElementById("vim-root") || document.getElementById("app");
  if (!mount) {
    // create host if markdown didn't provide one
    const host = document.createElement("div");
    host.id = "vim-root";
    document.body.prepend(host);
    new VimShell(host);
    return;
  }
  new VimShell(mount);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", boot);
} else {
  boot();
}
