import { chromium } from 'playwright';
import path from 'path';
const root = 'E:/Projects/spendwiser_app';
const browser = await chromium.launch();
const context = await browser.newContext({ viewport: { width: 390, height: 844 }, locale: 'en-IN', timezoneId: 'Asia/Calcutta' });
await context.addInitScript(() => localStorage.setItem('spendwiser.ob', '1'));
const page = await context.newPage();
await page.goto('file:///' + path.join(root, 'Spendwiser-app-reference.html').replaceAll('\\', '/'));
await page.waitForTimeout(800);
const info = await page.evaluate(() => {
  const stored = localStorage.getItem('spendwiser.v2');
  const fresh = seed();
  return {
    stored: stored ? stored.length : null,
    txFirst: tx.slice(0, 6).map(t => [t[0], t[2], t[7]]),
    freshFirst: fresh.slice(0, 12).map(t => [t[0], t[1], t[2], new Date(t[7]).toDateString()]),
    freshCount: fresh.length,
    txCount: tx.length,
  };
});
console.log(JSON.stringify(info, null, 1));
await browser.close();
