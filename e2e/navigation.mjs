/**
 * Playwright e2e — buffer navigation + palette focus (Item 4).
 * Usage: BASE_URL=http://127.0.0.1:4173 node e2e/navigation.mjs
 */
import { chromium } from "playwright";

const BASE = process.env.BASE_URL || "http://127.0.0.1:4173";
const TIMEOUT = 15_000;

function assert(cond, msg) {
  if (!cond) throw new Error(msg);
}

async function waitReady(page) {
  await page.goto(BASE + "/", { waitUntil: "networkidle", timeout: TIMEOUT });
  await page.waitForSelector("#vim-root", { timeout: TIMEOUT });
  await page.waitForTimeout(400);
}

async function main() {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));

  try {
    await waitReady(page);

    const hero = await page.locator("#buffer-body .hero h1").textContent();
    assert(hero?.includes("Nathan Sculli"), `hero name missing: ${hero}`);

    const homeBody = await page.locator("#buffer-body").innerText();
    assert(homeBody.length > 40, "home body empty");

    await page.locator("#buffer-items .buffer-item", { hasText: "experience.md" }).click();
    await page.waitForTimeout(350);
    const expBody = await page.locator("#buffer-body").innerText();
    assert(
      /work experience/i.test(expBody) || expBody.includes("TensorWave"),
      "experience body did not load (regression: tab-only switch)",
    );
    assert(expBody !== homeBody, "body text unchanged after experience click");

    await page.locator("#buffer-items .buffer-item .name", { hasText: /^skills\.md$/ }).click();
    await page.waitForTimeout(350);
    const skillsBody = await page.locator("#buffer-body").innerText();
    assert(skillsBody !== expBody, "body text unchanged after skills click");
    assert(
      /language|skill|rust|stack/i.test(skillsBody),
      `skills body unexpected: ${skillsBody.slice(0, 120)}`,
    );

    await page.locator("#buffer-items .buffer-item", { hasText: "cents.rs" }).click();
    await page.waitForTimeout(350);
    const kw = await page.locator("#buffer-body pre.code-block .kw").count();
    assert(kw > 0, "code highlight missing .kw spans");

    await page.keyboard.press(":");
    await page.waitForTimeout(300);
    const focused = await page.evaluate(() => document.activeElement?.id);
    assert(focused === "palette-input", `palette not focused, got ${focused}`);
    const open = await page.locator("#palette.open").count();
    assert(open === 1, "palette not open");

    // cmdline mirrors palette (Item 5 hybrid echo)
    await page.keyboard.type("exp");
    await page.waitForTimeout(150);
    const echo = await page.locator(".cmdline .msg").innerText();
    assert(echo.startsWith(":exp"), `cmdline echo missing, got "${echo}"`);
    const topLabel = await page.locator(".palette-results li").first().innerText();
    assert(/experience/i.test(topLabel), `fuzzy rank failed, top="${topLabel}"`);

    await page.keyboard.press("Escape");
    await page.waitForTimeout(250);
    const closed = await page.locator("#palette.open").count();
    assert(closed === 0, "palette still open after Esc");

    // help mode diagram present
    await page.locator("#buffer-items .buffer-item", { hasText: "help.txt" }).click();
    await page.waitForTimeout(300);
    const help = await page.locator("#buffer-body").innerText();
    assert(/NORMAL/.test(help) && /COMMAND/.test(help), "help mode diagram missing");

    // Ctrl-[ closes palette (Esc synonym)
    await page.keyboard.press(":");
    await page.waitForTimeout(200);
    await page.keyboard.press("Control+[");
    await page.waitForTimeout(250);
    assert((await page.locator("#palette.open").count()) === 0, "Ctrl-[ did not close palette");

    assert(errors.length === 0, `page errors: ${errors.join("; ")}`);

    console.log("e2e/navigation.mjs PASS");
    await browser.close();
    process.exit(0);
  } catch (e) {
    console.error("e2e/navigation.mjs FAIL:", e.message);
    if (errors.length) console.error("pageerrors:", errors);
    await browser.close().catch(() => {});
    process.exit(1);
  }
}

main();
