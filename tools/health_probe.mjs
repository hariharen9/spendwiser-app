import { chromium } from 'playwright';
import path from 'path';
const root = 'E:/Projects/spendwiser_app';
const browser = await chromium.launch();
const context = await browser.newContext({ viewport: { width: 390, height: 844 }, locale: 'en-IN', timezoneId: 'Asia/Calcutta' });
await context.addInitScript(() => localStorage.setItem('spendwiser.ob', '1'));
const page = await context.newPage();
await page.goto('file:///' + path.join(root, 'Spendwiser-app-reference.html').replaceAll('\\', '/'));
await page.waitForTimeout(1000);
const out = await page.evaluate(() => {
  const inc = avgM(m => fl(m).i, 1, 3) || fl().i || 1;
  const sp = avgM(m => fl(m).o, 1, 3) || fl().o || 1;
  const em = LN.reduce((s, l) => s + l.e, 0);
  const ut = CC.reduce((s, c) => s + c.u, 0) / (CC.reduce((s, c) => s + c.l, 0) || 1);
  const liq = liqf();
  const bd0 = B.length ? B.filter(b => b[2] <= b[1]).length / B.length * 100 : 100;
  const c = [
    ['Savings rate', Math.max(0, Math.min(100, (inc - sp) / inc * 200)), (inc - sp) / inc * 100],
    ['Debt load', Math.max(0, 100 - em / inc * 200), em / inc * 100],
    ['Card usage', Math.max(0, 100 - ut * 200), ut * 100],
    ['Safety net', Math.min(100, liq / sp / 6 * 100), liq / sp],
    ['Budget discipline', bd0, bd0],
  ];
  return { inc, sp, em, ut, liq, c, score: Math.round(c.reduce((a, x) => a + x[1], 0) / c.length), safe: safe2(), budgets: B, fl: fl() };
});
console.log(JSON.stringify(out, null, 1));
await browser.close();
