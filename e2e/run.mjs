/**
 * Build (optional) + vite preview + e2e/navigation.mjs
 */
import { spawn } from "node:child_process";
import { setTimeout as sleep } from "node:timers/promises";

const PORT = process.env.PORT || "4173";
const BASE = `http://127.0.0.1:${PORT}`;
const ROOT = new URL("..", import.meta.url).pathname;

function run(cmd, args, opts = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args, {
      cwd: ROOT,
      stdio: "inherit",
      env: process.env,
      ...opts,
    });
    child.on("error", reject);
    child.on("exit", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`${cmd} ${args.join(" ")} exited ${code}`));
    });
  });
}

async function waitHttp(url, attempts = 40) {
  for (let i = 0; i < attempts; i++) {
    try {
      const res = await fetch(url);
      if (res.ok) return;
    } catch {
      /* retry */
    }
    await sleep(250);
  }
  throw new Error(`server not ready: ${url}`);
}

let preview;
try {
  if (process.env.SKIP_BUILD !== "1") {
    console.log("→ npm run build");
    await run("npm", ["run", "build"]);
  }

  console.log(`→ vite preview :${PORT}`);
  preview = spawn(
    "npx",
    ["vite", "preview", "--host", "127.0.0.1", "--port", PORT, "--strictPort"],
    {
      cwd: ROOT,
      stdio: ["ignore", "pipe", "pipe"],
      env: process.env,
    },
  );
  preview.stdout.on("data", (d) => process.stdout.write(d));
  preview.stderr.on("data", (d) => process.stderr.write(d));

  await waitHttp(BASE + "/");
  console.log("→ e2e/navigation.mjs");
  await run("node", ["e2e/navigation.mjs"], {
    env: { ...process.env, BASE_URL: BASE },
  });
  console.log("e2e/run.mjs PASS");
  process.exitCode = 0;
} catch (e) {
  console.error("e2e/run.mjs FAIL:", e.message);
  process.exitCode = 1;
} finally {
  if (preview && !preview.killed) {
    preview.kill("SIGTERM");
    await sleep(200);
    try {
      process.kill(-preview.pid, "SIGKILL");
    } catch {
      try {
        preview.kill("SIGKILL");
      } catch {
        /* already dead */
      }
    }
  }
  setTimeout(() => process.exit(process.exitCode ?? 0), 100).unref();
}
