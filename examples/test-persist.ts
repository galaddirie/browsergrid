/**
 * test-persist.ts
 *
 * Purpose:
 *   Verify that persistent browser session profiles correctly retain data between runs.
 *
 * Usage:
 *   BROWSER_CDP_ENDPOINT=http://localhost:9222 ts-node test-persist.ts
 *
 * Behavior:
 *   1. Connects to browser via CDP using process.env.BROWSER_CDP_ENDPOINT.
 *   2. Navigates to a test page (default: https://example.com).
 *   3. Checks localStorage for a marker key.
 *   4. If key exists, reports "visited before"; if not, sets it and reports "first visit".
 */

import { chromium, Browser, Page } from "playwright";

const CONFIG = {
  baseUrl: process.env.BROWSER_CDP_ENDPOINT || "http://localhost:9222",
  testUrl: process.env.TEST_URL || "https://example.com",
  markerKey: "__persistent_profile_test_marker__",
  defaultTimeoutMs: Number(process.env.DEFAULT_TIMEOUT_MS || 10000),
};

const nowIso = () => new Date().toISOString();

async function fetchWebSocketEndpoint(baseUrl: string): Promise<string> {
  const res = await fetch(`${baseUrl.replace(/\/+$/, "")}/json/version`);
  if (!res.ok) throw new Error(`Failed to fetch version info: ${res.statusText}`);
  const info = await res.json();
  if (!info.webSocketDebuggerUrl) throw new Error("Missing webSocketDebuggerUrl in response");
  return info.webSocketDebuggerUrl;
}

async function main() {
  console.info("Starting persistent profile test...", CONFIG);
  const wsEndpoint = await fetchWebSocketEndpoint(CONFIG.baseUrl);

  const browser = await chromium.connectOverCDP(wsEndpoint);
  const page = await browser.newPage();
  page.setDefaultTimeout(CONFIG.defaultTimeoutMs);

  console.info(`Navigating to ${CONFIG.testUrl}`);
  await page.goto(CONFIG.testUrl, { waitUntil: "domcontentloaded" });

  // Check and update localStorage marker
  const visitInfo = await page.evaluate((markerKey) => {
    const prev = localStorage.getItem(markerKey);
    const now = new Date().toISOString();
    if (prev) {
      return { visitedBefore: true, firstSeen: prev, currentTime: now };
    } else {
      localStorage.setItem(markerKey, now);
      return { visitedBefore: false, currentTime: now };
    }
  }, CONFIG.markerKey);

  console.log(
    JSON.stringify(
      {
        status: "success",
        message: visitInfo.visitedBefore
          ? "This profile has visited before."
          : "First time visiting with this profile.",
        data: visitInfo,
        timestamp: nowIso(),
      },
      null,
      2
    )
  );

  await page.close();
  await browser.close();
}

// Run script
(async () => {
  try {
    await main();
    process.exitCode = 0;
  } catch (err) {
    console.error(
      JSON.stringify(
        {
          status: "error",
          error: (err as Error).message,
          stack: (err as Error).stack,
          timestamp: nowIso(),
        },
        null,
        2
      )
    );
    process.exitCode = 1;
  }
})();
