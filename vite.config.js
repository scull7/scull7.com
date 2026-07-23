import { defineConfig } from "vite";
import { moonbit } from "vite-plugin-moonbit";

export default defineConfig(({ command }) => ({
  plugins: [
    moonbit({
      // Watch only in dev; Netlify/CI must not hang on a watcher.
      watch: command === "serve",
      showLogs: true,
    }),
  ],
  publicDir: "public",
}));
