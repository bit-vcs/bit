import path from "node:path";
import { fileURLToPath } from "node:url";

import { defineConfig } from "vite";
import moonbit from "vite-plugin-moonbit";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const playgroundRoot = path.resolve(__dirname, "playground");
const playgroundDocsRoot = path.resolve(__dirname, "docs/playground");

export default defineConfig({
  root: playgroundRoot,
  base: "./",
  plugins: [
    moonbit({
      target: "js",
      mode: "release",
      watch: false,
      showLogs: true,
    }),
  ],
  server: {
    host: "127.0.0.1",
    port: 4175,
    fs: {
      allow: [__dirname],
    },
  },
  preview: {
    host: "127.0.0.1",
    port: 4176,
  },
  build: {
    outDir: playgroundDocsRoot,
    emptyOutDir: true,
    rollupOptions: {
      output: {
        entryFileNames: "app.js",
        chunkFileNames: "chunks/[name]-[hash].js",
        assetFileNames: (assetInfo) => {
          const name = assetInfo.name ?? "";
          if (name.endsWith(".css")) {
            return "styles.css";
          }
          return "assets/[name]-[hash][extname]";
        },
      },
    },
  },
});
