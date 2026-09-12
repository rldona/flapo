import puppeteer from 'puppeteer-core';

const url = process.argv[2] || 'http://localhost:5180/';
const chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

const browser = await puppeteer.launch({
  executablePath: chrome,
  headless: 'new',
  args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
});
const page = await browser.newPage();
page.on('pageerror', (e) => console.log('pageerror', e.message));
await page.setViewport({ width: 900, height: 1200, deviceScaleFactor: 1 });
await page.goto(url, { waitUntil: 'networkidle0' });
await new Promise((r) => setTimeout(r, 1600));

// Empieza una partida y fuerza el escenario de día para la portada.
await page.click('[data-act="play"]');
await new Promise((r) => setTimeout(r, 250));
await page.evaluate(() => {
  const g = window.__flapo;
  g.skyColor = '#7CB3D7';
  g.background.setVariant(0);
});
await new Promise((r) => setTimeout(r, 250));

let capturado = false;
for (let i = 0; i < 400; i++) {
  const info = await page.evaluate(() => {
    const g = window.__flapo;
    const next = g.pipeSpawner.pipes
      .filter((p) => p.x + 13 > g.bird.x)
      .sort((a, b) => a.x - b.x)[0];
    return {
      y: g.bird.y,
      target: next ? next.gapCenter : 256,
      state: g.getState(),
      pipes: g.pipeSpawner.pipes.map((p) => p.x),
      fruits: g.fruitSpawner.fruits.length,
    };
  });
  if (info.state === 1) {
    await page.keyboard.down('Space');
    await new Promise((r) => setTimeout(r, 70));
    await page.keyboard.up('Space');
    await new Promise((r) => setTimeout(r, 40));
    continue;
  }
  if (info.state === 2 && info.y > info.target + 2) {
    await page.keyboard.down('Space');
    await new Promise((r) => setTimeout(r, 60));
    await page.keyboard.up('Space');
  }
  const pipeVisible = info.pipes.some((x) => x > 20 && x < 150);
  if (i > 50 && pipeVisible && info.state === 2) {
    await page.screenshot({ path: 'assets/cover.png' });
    capturado = true;
    break;
  }
  if (info.state === 3) break;
  await new Promise((r) => setTimeout(r, 35));
}

console.log('capturado:', capturado);
await browser.close();
process.exit(capturado ? 0 : 1);
