#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");
const sharp = require("sharp");

async function main() {
  const [url, outputPath, widthText = "844", heightText = "390"] = process.argv.slice(2);
  if (!url || !outputPath) {
    throw new Error("usage: capture_mobile_web.cjs URL OUTPUT_PNG [WIDTH HEIGHT]");
  }

  const width = Number(widthText);
  const height = Number(heightText);
  const executablePath = process.env.VMS_CHROMIUM_PATH || undefined;
  const browser = await chromium.launch({ headless: true, executablePath });
  const context = await browser.newContext({
    viewport: { width, height },
    deviceScaleFactor: 1,
    hasTouch: true,
    isMobile: true,
  });
  const page = await context.newPage();
  const consoleErrors = [];
  const pageErrors = [];
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(message.text());
  });
  page.on("pageerror", (error) => pageErrors.push(String(error)));

  await page.goto(url, { waitUntil: "networkidle" });
  await page.locator("canvas").waitFor({ state: "visible" });
  await page.locator("canvas").click({ position: { x: width / 2, y: height / 2 } });
  await page.keyboard.press("Enter");
  await page.waitForTimeout(1800);

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  await page.screenshot({ path: outputPath });

  // The approved VM-0.7.2 deck layout reserves the upper portion for a
  // centered 16:9 monitor. This broad crop intentionally checks rendered
  // content rather than screenshot-perfect pixels.
  const crop = {
    left: Math.max(0, Math.floor(width * 0.20)),
    top: Math.max(0, Math.floor(height * 0.01)),
    width: Math.max(1, Math.floor(width * 0.60)),
    height: Math.max(1, Math.floor(height * 0.70)),
  };
  const { data, info } = await sharp(outputPath)
    .extract(crop)
    .removeAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  const bins = new Set();
  let nonNearBlack = 0;
  for (let i = 0; i < data.length; i += info.channels) {
    const r = data[i];
    const g = data[i + 1];
    const b = data[i + 2];
    bins.add(`${r >> 4},${g >> 4},${b >> 4}`);
    if (r + g + b > 45) nonNearBlack += 1;
  }
  const pixelCount = data.length / info.channels;
  const stats = {
    viewport: { width, height },
    crop,
    quantized_color_bins: bins.size,
    non_near_black_ratio: nonNearBlack / pixelCount,
    actual_gameplay_pixels_present: bins.size >= 24 && nonNearBlack / pixelCount >= 0.20,
    console_errors: consoleErrors,
    page_errors: pageErrors,
    screenshot: outputPath,
  };
  console.log(JSON.stringify(stats));
  await browser.close();
  if (!stats.actual_gameplay_pixels_present || pageErrors.length > 0) process.exitCode = 1;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
