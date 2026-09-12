import puppeteer from 'puppeteer-core';

const url = process.argv[2] || 'http://localhost:5178/';
const chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

const browser = await puppeteer.launch({
  executablePath: chrome,
  headless: 'new',
  args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
});
const page = await browser.newPage();
page.on('pageerror', (e) => console.log('pageerror', e.message));
await page.setViewport({ width: 430, height: 932, deviceScaleFactor: 2 });
await page.goto(url, { waitUntil: 'networkidle0' });
await new Promise((r) => setTimeout(r, 1500));
await page.click('[data-act="play"]');
await new Promise((r) => setTimeout(r, 200));

let maxScore = 0;
for (let i = 0; i < 220; i++) {
  const info = await page.evaluate(() => {
    const g = window.__flapo;
    if (!g) return null;
    const next = g.pipeSpawner.pipes
      .filter((p) => p.x + 13 > g.bird.x)
      .sort((a, b) => a.x - b.x)[0];
    return { y: g.bird.y, target: next ? next.gapCenter : 256, state: g.getState(), score: g.getScore() };
  });
  if (!info) break;
  maxScore = Math.max(maxScore, info.score);
  if (info.state === 3) {
    await page.evaluate(() => {
      const b = [...document.querySelectorAll('button')].find((x) => x.textContent?.includes('Otra vez'));
      b?.click();
    });
    await new Promise((r) => setTimeout(r, 250));
    continue;
  }
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
  if (i === 30) await page.screenshot({ path: '/tmp/flapo-jugando2.png' });
  await new Promise((r) => setTimeout(r, 35));
}
console.log('max score alcanzado:', maxScore);
await page.screenshot({ path: '/tmp/flapo-jugando.png' });

// Fuerza el final para ver el panel de Game Over.
await page.evaluate(() => {
  const g = window.__flapo;
  g.bird.die(0, false);
});
await new Promise((r) => setTimeout(r, 900));
await page.screenshot({ path: '/tmp/flapo-gameover.png' });
const goVisible = await page.$('[aria-label="Fin de la partida"]');
console.log('panel game over visible:', Boolean(goVisible));

await browser.close();
