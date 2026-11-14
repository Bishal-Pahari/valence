import { fileURLToPath } from 'node:url';

export default {
  resolve: {
    alias: {
      '@getvalence/bridge': fileURLToPath(new URL('../../../bridge/src/index.ts', import.meta.url)),
    },
  },
};
