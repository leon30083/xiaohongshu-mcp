// Simple script to search Xiaohongshu for a keyword using Puppeteer
// Usage: node scripts/search_food.js "美食"

const puppeteer = require('puppeteer');

function makeSearchURL(keyword) {
  const params = new URLSearchParams({ keyword, source: 'web_explore_feed' });
  return `https://www.xiaohongshu.com/search_result?${params.toString()}`;
}

(async () => {
  const keyword = process.argv[2] || '美食';
  const url = makeSearchURL(keyword);

  const browser = await puppeteer.launch({ headless: true });
  const page = await browser.newPage();

  await page.goto(url, { waitUntil: 'domcontentloaded' });
  await page.waitForFunction(() => window.__INITIAL_STATE__ !== undefined, { timeout: 60000 });

  const stateJson = await page.evaluate(() => JSON.stringify(window.__INITIAL_STATE__));
  const state = JSON.parse(stateJson);
  const feeds = state?.search?.feeds?.feeds || state?.search?.feeds?.value || [];

  const simplified = feeds.map((f, idx) => ({
    id: f.id,
    xsecToken: f.xsecToken,
    title: f?.noteCard?.displayTitle,
    user: {
      userId: f?.noteCard?.user?.userId,
      nickname: f?.noteCard?.user?.nickname,
    },
    interact: f?.noteCard?.interactInfo || {},
    index: idx,
  }));

  console.log(JSON.stringify({ keyword, count: simplified.length, feeds: simplified.slice(0, 20) }, null, 2));

  await browser.close();
})();