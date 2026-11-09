import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';

const root = 'E:/Projects/spendwiser_app';
const outDir = path.join(root, '.ref');
fs.mkdirSync(outDir, { recursive: true });

const browser = await chromium.launch();
const context = await browser.newContext({
  viewport: { width: 390, height: 844 },
  deviceScaleFactor: 2,
  reducedMotion: 'reduce',
  locale: 'en-IN',
  timezoneId: 'Asia/Calcutta',
});
const page = await context.newPage();
page.on('console', m => { if (m.type() === 'error') console.log('CONSOLE', m.text()); });
page.on('pageerror', e => console.log('PAGEERROR', e.message));
await context.addInitScript(() => {
  localStorage.setItem('spendwiser.ob', '1');
});
await page.goto('file:///' + path.join(root, 'Spendwiser-app-reference.html').replaceAll('\\', '/'));
await page.waitForTimeout(1800);
try { await page.evaluate(() => document.fonts.ready); } catch {}
await page.waitForTimeout(600);

const shot = async (name) => {
  await page.screenshot({ path: path.join(outDir, name + '.png'), clip: { x: 0, y: 0, width: 390, height: 844 } });
  console.log('shot', name);
};

const go = async (k, wait = 700) => {
  await page.evaluate((key) => { try { go(key); } catch (e) { console.log(e); } }, k);
  await page.waitForTimeout(wait);
};

await go('home');
await shot('01-home');
await page.evaluate(() => { document.querySelector('#scr').scrollTop = 600; });
await page.waitForTimeout(400);
await shot('02-home-scrolled');
await page.evaluate(() => { document.querySelector('#scr').scrollTop = 0; });

await page.evaluate(() => { document.querySelector('#orb').click(); });
await page.waitForTimeout(800);
await shot('03-orb');
await page.evaluate(() => { document.querySelector('#orb').click(); });

await go('ledger');
await shot('04-ledger');
await page.evaluate(() => { document.querySelector('#ledger') });
await go('cc');
await shot('05-cards');
await page.evaluate(() => { CT = 'st'; rr(); });
await page.waitForTimeout(500);
await shot('06-cards-statements');
await page.evaluate(() => { CT = 'tx'; rr(); });
await page.waitForTimeout(500);
await shot('07-cards-tx');
await page.evaluate(() => { CT = 'ov'; rr(); });

await go('loan');
await shot('08-debt');
await page.evaluate(() => { lopen(0); });
await page.waitForTimeout(600);
await shot('09-debt-detail');
await page.evaluate(() => { ltt('pj'); });
await page.waitForTimeout(600);
await shot('10-debt-projection');
await page.evaluate(() => { LD = -1; rr(); });

await go('bud');
await shot('11-budgets');
await go('sub');
await shot('12-subs');
await go('goal');
await shot('13-goals');
await go('ins');
await shot('14-insights');
await page.evaluate(() => { IT = 'hl'; rr(); });
await page.waitForTimeout(600);
await shot('15-health');
await page.evaluate(() => { IT = 'cat'; rr(); });
await go('set');
await shot('16-settings');
await page.evaluate(() => { window.scrollTo(0,0); document.querySelector('#scr').scrollTop = 700; });
await page.waitForTimeout(400);
await shot('17-settings-scrolled');
await page.evaluate(() => { document.querySelector('#scr').scrollTop = 0; });

await go('home');
await page.evaluate(() => { addx(); });
await page.waitForTimeout(600);
await shot('18-add-tx');
await page.evaluate(() => { xs(); ask(); });
await page.waitForTimeout(600);
await shot('19-ask');
await page.evaluate(() => { ask('Food last month'); });
await page.waitForTimeout(800);
await shot('20-ask-answer');
await page.evaluate(() => { xs(); });

// light theme
await page.evaluate(() => { ss('th', 'light'); go('home'); });
await page.waitForTimeout(800);
await shot('21-home-light');
await page.evaluate(() => { ss('th', 'dark'); });

// onboarding
await page.evaluate(() => { localStorage.removeItem('spendwiser.ob'); });
await page.reload();
await page.waitForTimeout(1600);
await shot('22-onboarding');

await browser.close();
console.log('done');
