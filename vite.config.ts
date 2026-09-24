import { readFileSync } from "node:fs";
import process from "node:process";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

const host = process.env.TAURI_DEV_HOST;
const { version } = JSON.parse(readFileSync("package.json", "utf8"));

export default defineConfig(() => ({
  plugins: [react()],
  // The page is served from a project path on GitHub Pages and from the app root in the
  // installed builds, so every asset is asked for relative to the page itself.
  base: "./",
  define: { __APP_VERSION__: JSON.stringify(version) },

  // Tauri prints its own errors, and expects the dev server on a fixed port.
  clearScreen: false,
  server: {
    port: 1420,
    strictPort: true,
    host: host || false,
    hmr: host ? { protocol: "ws", host, port: 1421 } : undefined,
    watch: {
      // Ignore what the build writes: Rust output and coverage reports are thousands of
      // files, and watching them reloads the window in a loop.
      ignored: ["**/src-tauri/**", "**/coverage/**", "**/dist/**"],
    },
  },
}));
