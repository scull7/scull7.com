import { defineConfig } from "vite";
import elmPlugin from "vite-plugin-elm";

export default defineConfig({
  plugins: [
    elmPlugin({
      debug: false,
      optimize: process.env.NODE_ENV === "production",
    }),
  ],
  publicDir: "public",
  build: {
    target: "es2020",
  },
});
