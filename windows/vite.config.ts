import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { resolve } from "node:path";

const host = process.env.TAURI_DEV_HOST;

export default defineConfig({
  plugins: [react()],
  clearScreen: false,
  server: {
    port: 1420,
    strictPort: true,
    host: host || false,
    hmr: host
      ? {
          protocol: "ws",
          host,
          port: 1421,
        }
      : undefined,
  },
  build: {
    target: ["es2021", "chrome105", "safari15"],
    rollupOptions: {
      input: {
        main: resolve(__dirname, "index.html"),
        pill: resolve(__dirname, "pill.html"),
      },
    },
  },
});
