import puppeteer from 'puppeteer-core';

const url = process.argv[2] || 'http://localhost:5178/';
const chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const browser = await puppeteer.launch({
  executablePath: chrome,
  headless: 'new',
  args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
});

const casos = [
  ['movil', 390, 844, 2],
  ['movil-alto', 412, 1000, 2],
  ['estrecho', 430, 900, 2],
  ['tablet', 820, 1180, 2],
  ['portatil', 1280, 800, 1],
  ['portatil-hd', 1366, 768, 1],
  ['desktop', 1600, 900, 1],
];

for (const [nombre, width, height, dsf] of casos) {
  const page = await browser.newPage();
  const errs = [];
  page.on('pageerror', (e) => errs.push(e.message));
  await page.setViewport({ width, height, deviceScaleFactor: dsf });
  await page.goto(url, { waitUntil: 'networkidle0' });
  await new Promise((r) => setTimeout(r, 1200));
  await page.click('[data-act="play"]');
  await new Promise((r) => setTimeout(r, 300));
  await page.screenshot({ path: `/tmp/flapo-layout-${nombre}.png` });
  const dims = await page.evaluate(() => {
    const stage = document.getElementById('stage');
    const canvas = document.getElementById('playfield');
    return {
      inner: [window.innerWidth, window.innerHeight],
      stageCss: [stage.clientWidth, stage.clientHeight],
      canvasLogical: [canvas.width, canvas.height],
      lados: document.getElementById('app').classList.contains('has-sides'),
    };
  });
  console.log(nombre, JSON.stringify(dims), 'errores:', errs.length);
  await page.close();
}

await browser.close();
