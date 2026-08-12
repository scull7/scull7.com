import path from "node:path";
import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";
import elmPlugin from "vite-plugin-elm";

const root = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  plugins: [
    elmPlugin({
      debug: false,
      optimize: process.env.NODE_ENV === "production",
    }),
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
