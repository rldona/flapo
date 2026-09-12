import puppeteer from 'puppeteer-core';

const url = process.argv[2] || 'http://localhost:5178/';
const chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

const browser = await puppeteer.launch({
  executablePath: chrome,
  headless: 'new',
  args: [
    '--no-sandbox',
    '--disable-setuid-sandbox',
    '--use-gl=angle',
    '--use-angle=swiftshader',
    '--enable-unsafe-swiftshader',
    '--autoplay-policy=no-user-gesture-required',
  ],
});

const errors = [];
const page = await browser.newPage();
page.on('console', (m) => {
  if (m.type() === 'error') errors.push(`console: ${m.text()}`);
});
page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));
page.on('requestfailed', (r) => errors.push(`requestfailed: ${r.url()} ${r.failure()?.errorText}`));

await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2 });
await page.goto(url, { waitUntil: 'networkidle0', timeout: 60000 });
await new Promise((r) => setTimeout(r, 1800));

const menu = await page.$('[data-act="play"]');
console.log('menu visible:', Boolean(menu));
if (!menu) {
  console.log('overlay html:', await page.evaluate(() => document.getElementById('overlay')?.innerHTML));
}

await page.click('[data-act="play"]');
await new Promise((r) => setTimeout(r, 400));

for (let i = 0; i < 60; i++) {
  await page.keyboard.down('Space');
  await new Promise((r) => setTimeout(r, 90));
  await page.keyboard.up('Space');
  await new Promise((r) => setTimeout(r, 210));
}

const colors = await page.evaluate(() => {
  const c = document.getElementById('playfield');
  const g = c.getContext('2d');
  const d = g.getImageData(0, 0, c.width, c.height).data;
  const set = new Set();
  for (let i = 0; i < d.length; i += 4 * 53) set.add(`${d[i]},${d[i + 1]},${d[i + 2]}`);
  return set.size;
});
console.log('colores distintos en el canvas:', colors);

await page.screenshot({ path: '/tmp/flapo-mobile.png' });

// Prueba de menús: opciones y estadísticas.
await page.evaluate(() => {
  const btns = [...document.querySelectorAll('button')];
  const menuBtn = btns.find((b) => b.textContent?.trim() === 'Menú');
  menuBtn?.click();
});
await new Promise((r) => setTimeout(r, 400));
await page.evaluate(() => {
  const b = [...document.querySelectorAll('[data-act="options"]')][0];
  b?.click();
});
await new Promise((r) => setTimeout(r, 300));
const optionsOpen = await page.$('[aria-label="Opciones"]');
console.log('opciones visibles:', Boolean(optionsOpen));
await page.screenshot({ path: '/tmp/flapo-options.png' });

// Escritorio
await page.setViewport({ width: 1600, height: 900, deviceScaleFactor: 1 });
await new Promise((r) => setTimeout(r, 600));
await page.screenshot({ path: '/tmp/flapo-desktop.png' });

console.log('errores:', errors.length);
for (const e of errors) console.log(' -', e);
await browser.close();
process.exit(errors.length > 0 ? 1 : 0);
