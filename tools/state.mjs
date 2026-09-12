import puppeteer from 'puppeteer-core';
const browser = await puppeteer.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless:'new', args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const page = await browser.newPage();
page.on('pageerror', e=>console.log('pageerror', e.message));
await page.setViewport({width:390,height:844,deviceScaleFactor:2});
await page.goto('http://localhost:5178/',{waitUntil:'networkidle0'});
await new Promise(r=>setTimeout(r,1500));
console.log('before click', await page.evaluate(()=>window.__flapo?.getState()));
await page.click('[data-act="play"]');
await new Promise(r=>setTimeout(r,300));
console.log('after click', await page.evaluate(()=>window.__flapo?.getState()));
await page.keyboard.down('Space'); await new Promise(r=>setTimeout(r,60)); await page.keyboard.up('Space');
await new Promise(r=>setTimeout(r,400));
console.log('after space', await page.evaluate(()=>window.__flapo?.getState()), await page.evaluate(()=>window.__flapo?.getScore()));
await page.screenshot({path:'/tmp/flapo-play.png'});
for(let i=0;i<3;i++){ await page.keyboard.down('Space'); await new Promise(r=>setTimeout(r,80)); await page.keyboard.up('Space'); await new Promise(r=>setTimeout(r,300)); }
await page.screenshot({path:'/tmp/flapo-play2.png'});
console.log('later', await page.evaluate(()=>window.__flapo?.getState()), await page.evaluate(()=>window.__flapo?.getScore()));
await browser.close();
