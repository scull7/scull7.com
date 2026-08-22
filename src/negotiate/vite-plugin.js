import fs from "node:fs";
import path from "node:path";
import { negotiateRequest } from "./handler.js";

function distStore(distDir) {
  return {
    has(filePath) {
      return fs.existsSync(path.join(distDir, filePath.replace(/^\//, "")));
    },
    read(filePath) {
      return fs.readFileSync(path.join(distDir, filePath.replace(/^\//, "")), "utf8");
    },
  };
}

function applyResult(res, result) {
  res.statusCode = result.status;
  for (const [key, value] of Object.entries(result.headers)) {
    if (value != null) res.setHeader(key, value);
  }
  res.end(result.body);
}

function createMiddleware(distDir) {
  const store = distStore(distDir);
  return async function negotiateMiddleware(req, res, next) {
    try {
      const url = new URL(req.url || "/", "http://127.0.0.1");
      const result = await negotiateRequest(
        { pathname: url.pathname, accept: req.headers.accept },
        store,
      );
      if (!result) return next();
      applyResult(res, result);
    } catch (err) {
      next(err);
    }
  };
}

/**
 * Vite plugin: Accept negotiation + custom 404 for preview (and dev if dist exists).
 */
export function markdownNegotiatePlugin(root) {
  const distDir = path.join(root, "dist");
  return {
    name: "markdown-negotiate",
    configureServer(server) {
      if (fs.existsSync(distDir)) {
        server.middlewares.use(createMiddleware(distDir));
      }
    },
    configurePreviewServer(server) {
      server.middlewares.use(createMiddleware(distDir));
    },
  };
}
