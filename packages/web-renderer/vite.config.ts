import { defineConfig } from 'vite';
import { resolve } from 'path';

export default defineConfig({
  build: {
    lib: {
      entry: resolve(__dirname, 'src/index.ts'),
      name: 'Jasonette',
      formats: ['es', 'cjs', 'umd'],
      fileName: (format) => {
        if (format === 'es') return 'jasonette.js';
        if (format === 'cjs') return 'jasonette.cjs';
        return 'jasonette.umd.js';
      },
    },
    rollupOptions: {
      external: [],
    },
  },
});
