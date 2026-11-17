import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Builds into ../html, which the fxmanifest ships. Fixed file names (no hashes) so the manifest's globs and
// the page never drift. html/img/items is kept: emptyOutDir is off.
export default defineConfig({
  plugins: [react()],
  base: './',
  build: {
    outDir: process.env.OUT_DIR || '../html',
    emptyOutDir: false,
    target: 'chrome103', // FiveM's CEF
    cssTarget: 'chrome103',
    assetsDir: 'assets',
    rollupOptions: {
      output: {
        entryFileNames: 'assets/app.js',
        chunkFileNames: 'assets/[name].js',
        assetFileNames: 'assets/[name][extname]',
      },
    },
  },
});
