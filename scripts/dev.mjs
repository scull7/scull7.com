#!/usr/bin/env node
/**
 * Dev server: astra build → serve dist with live rebuild on file change.
 * Astra's `dev` middleware does not serve docs/public assets (build does).
 */
import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { readFile, stat, watch } from "node:fs/promises";
import { createReadStream, existsSync, watch as watchFs } from "node:fs";
import { extname, join, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(fileURLToPath(new URL("..", import.meta.url)));
const dist = join(root, "dist");
const port = Number(process.env.PORT || 7777);

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".webp": "image/webp",
  ".json": "application/json",
  ".woff2": "font/woff2",
  ".map": "application/json",
};

function runAstraBuild() {
  return new Promise((resolvePromise, reject) => {
    const child = spawn("astra", ["build", "--out", "./dist"], {
      cwd: root,
      stdio: "inherit",
      shell: process.platform === "win32",
      env: { ...process.env, PATH: `${process.env.HOME}/.moon/bin:${process.env.PATH}` },
    });
    child.on("exit", (code) => (code === 0 ? resolvePromise() : reject(new Error(`astra build exited ${code}`))));
  });
}

function safePath(urlPath) {
  let p = decodeURIComponent(urlPath.split("?")[0]);
  if (p.endsWith("/")) p += "index.html";
  if (p === "") p = "/index.html";
  const file = resolve(dist, "." + p);
  if (!file.startsWith(dist + sep) && file !== dist) return null;
  return file;
}

function serve() {
  return createServer(async (req, res) => {
    try {
      const file = safePath(req.url || "/");
      if (!file) {
        res.writeHead(403).end("forbidden");
        return;
      }
      let target = file;
      try {
        const st = await stat(target);
        if (st.isDirectory()) target = join(target, "index.html");
      } catch {
        res.writeHead(404).end(`not found: ${req.url}`);
        return;
      }
      const type = MIME[extname(target)] || "application/octet-stream";
      res.writeHead(200, { "Content-Type": type, "Cache-Control": "no-store" });
      createReadStream(target).pipe(res);
    } catch (err) {
      res.writeHead(500).end(String(err));
    }
  });
}

let building = false;
let pending = false;

async function rebuild(reason) {
  if (building) {
    pending = true;
    return;
  }
  building = true;
  console.log(`\n[dev] rebuild (${reason})…`);
  try {
    await runAstraBuild();
    console.log("[dev] build ok");
  } catch (err) {
    console.error("[dev] build failed:", err.message);
  } finally {
    building = false;
    if (pending) {
      pending = false;
      rebuild("queued");
    }
  }
}

function watchTree(dir) {
  if (!existsSync(dir)) return;
  watchFs(dir, { recursive: true }, (_evt, filename) => {
    if (!filename) return;
    if (filename.includes(`${sep}dist${sep}`) || filename.startsWith("dist")) return;
    if (filename.endsWith(".swp") || filename.endsWith("~")) return;
    rebuild(filename);
  });
}

await rebuild("startup");
const server = serve();
server.on("error", (err) => {
  if (err && err.code === "EADDRINUSE") {
    console.error(`[dev] port ${port} is already in use.`);
    console.error(`[dev] free it with:  lsof -ti :${port} | xargs kill -9`);
    console.error(`[dev] or use another port:  PORT=7778 npm run dev`);
    process.exit(1);
  }
  throw err;
});
server.listen(port, "127.0.0.1", () => {
  console.log(`[dev] http://127.0.0.1:${port}`);
  console.log("[dev] watching docs/ + astra.config.json");
});

watchTree(join(root, "docs"));
watchTree(join(root, "astra.config.json"));
