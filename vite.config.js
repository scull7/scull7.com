import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";
import elmPlugin from "vite-plugin-elm";

const root = path.dirname(fileURLToPath(import.meta.url));

const CRAWLABLE_CLI = path.join(
  root,
  "_build/default/src/melange/crawlable/src/melange/crawlable_cli.cjs",
);

function injectCrawlableResume() {
  if (!fs.existsSync(CRAWLABLE_CLI)) {
    throw new Error(
      "crawlable Melange CLI missing; run `npm run melange` before `vite build`",
    );
  }
  const html = path.join(root, "dist/index.html");
  const resume = path.join(root, "public/resume.json");
  const result = spawnSync(
    process.execPath,
    [CRAWLABLE_CLI, "inject", html, resume],
    { cwd: root, encoding: "utf8" },
  );
  if (result.status !== 0) {
    const msg = (result.stderr || result.stdout || "").trim();
    throw new Error(msg || `crawlable inject exited ${result.status}`);
  }
}

function crawlableResumePlugin() {
  return {
    name: "crawlable-resume-melange",
    apply: "build",
    closeBundle() {
      injectCrawlableResume();
    },
  };
}

export default defineConfig({
  plugins: [
    elmPlugin({
      debug: false,
      optimize: process.env.NODE_ENV === "production",
    }),
    crawlableResumePlugin(),
  ],
  publicDir: "public",
  resolve: {
    alias: {
      // Melange runtime packages (npm)
      melange: path.resolve(root, "node_modules/melange"),
      "melange.js": path.resolve(root, "node_modules/melange.js"),
    },
  },
  build: {
    target: "es2020",
  },
  server: {
    fs: {
      // Allow importing Melange output under _build/
      allow: [root],
    },
  },
});
