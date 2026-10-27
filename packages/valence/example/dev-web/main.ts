import { call, connect, ready } from '../web-src/lib/bridge.g';

import { message } from './message.js';

let count = 0;
document.getElementById('message')!.textContent = message;
document.getElementById('increment')!.onclick = () => {
  document.getElementById('counter')!.textContent = `Counter: ${++count}`;
  console.log(`R9 counter=${count}`);
};

await connect();
const info = await call('app.info');
document.getElementById('bridge')!.textContent = `Native bridge ${info.bridge} connected`;
console.log(`R9 bridge=${info.bridge}`);
await ready();

if (import.meta.hot) {
  import.meta.hot.accept('./message.js', async (module) => {
    document.getElementById('message')!.textContent = module?.message ?? '';
    await call('prefs.set', { key: 'r9.hmr', value: JSON.stringify({ count, message: module?.message }) });
    console.log(`R9 HMR counter=${count}; native prefs write succeeded`);
  });
}
