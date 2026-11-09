import { chromium } from 'playwright';
import path from 'path';
const root = 'E:/Projects/spendwiser_app';
const browser = await chromium.launch();
const context = await browser.newContext({ viewport: { width: 390, height: 844 }, locale: 'en-IN', timezoneId: 'Asia/Calcutta' });
await context.addInitScript(() => localStorage.setItem('spendwiser.ob', '1'));
const page = await context.newPage();
await page.goto('file:///' + path.join(root, 'Spendwiser-app-reference.html').replaceAll('\\', '/'));
await page.waitForTimeout(1200);
const rows = await page.evaluate(() => tx.filter(t => new Date(t[7]).getMonth() === 5 && new Date(t[7]).getFullYear() === 2026).map(t => [t[0], t[1], t[2], new Date(t[7]).toDateString(), t[10]]));
console.log(JSON.stringify(rows));
const seedFirst = await page.evaluate(() => {
  let s = 42;
  const rnd = () => ((s = (s * 16807) % 2147483647) / 2147483647);
  const n = 16 + ((rnd() * 6) | 0);
  const out = [['n', n]];
  for (let j = 0; j < 8; j++) {
    const c = ['Food','Food','Food','Travel','Shop','Fun','Bills'][(rnd() * 7) | 0];
    const mer = {Food:['Swiggy','Zomato','Blue Tokai Coffee','Big Basket','Chaayos'],Travel:['Uber','Ola','Metro card','Indian Oil'],Shop:['Amazon','Myntra','Decathlon'],Fun:['BookMyShow','Cult.fit','Steam'],Bills:['BESCOM Electricity','Airtel Fiber','Jio Recharge']};
    const m = mer[c];
    const name = m[(rnd() * m.length) | 0];
    const a = Math.round((c == 'Shop' ? 900 + rnd() * 3500 : c == 'Bills' ? 600 + rnd() * 1500 : c == 'Travel' ? 120 + rnd() * 500 : c == 'Fun' ? 300 + rnd() * 900 : 150 + rnd() * 700) / 10) * 10;
    const day = Math.max(1, Math.min(28, 1 + ((rnd() * 28) | 0)));
    out.push([name, c, -a, day]);
  }
  return out;
});
console.log(JSON.stringify(seedFirst));
await browser.close();
