// Captures delivery-checklist screenshots: /login (developer footer) and /about.
import { chromium } from '@playwright/test';
import { mkdirSync } from 'node:fs';

const BASE = process.env.APP_URL ?? 'http://localhost:3000';
mkdirSync('screenshots', { recursive: true });

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1366, height: 768 } });

for (const [path, name] of [['/login', 'login-with-developer-footer'], ['/about', 'about-screen']]) {
  await page.goto(BASE + path, { waitUntil: 'networkidle' });
  await page.screenshot({ path: `screenshots/${name}.png`, fullPage: true });
  console.log(`captured ${name}`);
}
await browser.close();
