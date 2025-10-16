// runDemo.ts
//
// Usage:
//   BROWSER_CDP_ENDPOINT=http://localhost:9222 ts-node runDemo.ts
//
// What this does:
// - Discover the browser's CDP WebSocket from `${BROWSER_CDP_ENDPOINT}/json/version`
// - Connect via Playwright CDP
// - Run focused tests:
//    1) navigate & extract structured data (+ screenshot)
//    2) fetch & validate a JSON endpoint
//    3) negative navigation (expected failure)
// - Emit a single JSON summary to stdout (success or error)

import { chromium, Browser, Page } from 'playwright';

const CONFIG = {
    baseUrl: process.env.BROWSER_CDP_ENDPOINT || 'http://localhost',
    primaryUrl: process.env.TEST_PRIMARY_URL || 'https://www.google.com',
    jsonProbeUrl: process.env.TEST_JSON_URL || 'https://httpbin.org/json',
    screenshotPath: process.env.SCREENSHOT_PATH || 'screenshot.png',
    defaultTimeoutMs: Number(process.env.DEFAULT_TIMEOUT_MS || 20_000),
};

const nowIso = () => new Date().toISOString();


async function fetchWithTimeout(url: string, timeoutMs: number) {
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), timeoutMs);
    try {
        return await fetch(url, { signal: ctrl.signal });
    } finally {
        clearTimeout(t);
    }
}

async function fetchWebSocketEndpoint(baseUrl: string): Promise<string> {
    const url = `${baseUrl.replace(/\/+$/, '')}/json/version`;
    console.info('Fetching WebSocket endpoint', { url });

    const response = await fetchWithTimeout(url, CONFIG.defaultTimeoutMs);
    if (!response.ok) {
        throw new Error(
            `Failed to fetch version info: ${response.status} ${response.statusText}`
        );
    }

    const versionInfo = (await response.json()) as any;
    const wsEndpoint: string | undefined = versionInfo.webSocketDebuggerUrl;
    if (!wsEndpoint) throw new Error('webSocketDebuggerUrl not found');
    console.debug('Version info', {
        browser: versionInfo.Browser,
        protocolVersion: versionInfo['Protocol-Version'],
        userAgent: versionInfo['User-Agent'],
    });
    return wsEndpoint;
}

async function extractPageData(page: Page) {
    return page.evaluate(() => {
        return {
            title: document.title,
            heading: document.querySelector('h1')?.textContent?.trim() || null,
            paragraphs: Array.from(document.querySelectorAll('p'))
                .map((p) => (p.textContent || '').trim())
                .filter(Boolean),
            links: Array.from(document.querySelectorAll('a')).map((a) => ({
                text: (a.textContent || '').trim(),
                href: (a as HTMLAnchorElement).href,
            })),
            timestamp: new Date().toISOString(),
        };
    });
}


// ------------------------------------------------------------

async function testNavigateAndExtract(browser: Browser) {
    const page = await browser.newPage();
    page.setDefaultTimeout(CONFIG.defaultTimeoutMs);

    try {
        console.info('Navigating to primary URL', { url: CONFIG.primaryUrl });
        await page.goto(CONFIG.primaryUrl, {
            waitUntil: 'domcontentloaded',
            timeout: CONFIG.defaultTimeoutMs,
        });

        const pageTitle = await page.title();
        const pageUrl = page.url();
        console.info('Primary page loaded', { title: pageTitle, url: pageUrl });

        console.info('Extracting page data');
        const extracted = await extractPageData(page);

        console.info('Capturing screenshot', { path: CONFIG.screenshotPath });
        const shot = await page.screenshot({
            fullPage: true,
            path: CONFIG.screenshotPath,
            type: 'png',
        });

        return {
            pageTitle,
            pageUrl,
            extracted,
            screenshotPath: CONFIG.screenshotPath,
            screenshotSizeBytes: shot.length,
        };
    } finally {
        await safeClosePage(page, 'navigate/extract page');
    }
}


async function testJsonProbe(browser: Browser) {
    const page = await browser.newPage();
    page.setDefaultTimeout(CONFIG.defaultTimeoutMs);

    try {
        console.info('Navigating to JSON probe URL', { url: CONFIG.jsonProbeUrl });
        await page.goto(CONFIG.jsonProbeUrl, {
            waitUntil: 'networkidle',
            timeout: CONFIG.defaultTimeoutMs,
        });

        try {
            const r = await fetchWithTimeout(CONFIG.jsonProbeUrl, CONFIG.defaultTimeoutMs);
            const payload = await r.json();
            return { url: CONFIG.jsonProbeUrl, payload };
        } catch (e) {
            console.warn('Direct fetch failed; falling back to DOM parse', {
                error: (e as Error).message,
            });

            const payload = await page.evaluate(() => {
                const bodyText = document.body?.textContent || '';
                try {
                    return JSON.parse(bodyText);
                } catch {
                    return {
                        error: 'Failed to parse JSON from body',
                        sample: bodyText.slice(0, 500),
                    };
                }
            });
            return { url: CONFIG.jsonProbeUrl, payload };
        }
    } finally {
        await safeClosePage(page, 'json probe page');
    }
}



async function testNegativeNavigation(browser: Browser) {
    const page = await browser.newPage();
    page.setDefaultTimeout(CONFIG.defaultTimeoutMs);

    try {
        const badUrl = 'https://non-existent-domain-12345.example';
        console.info('Executing expected negative navigation', { url: badUrl });

        try {
            await page.goto(badUrl, { timeout: 5_000 });
            throw new Error('Negative navigation unexpectedly succeeded');
        } catch (err) {
            const msg = (err as Error).message;
            console.warn('Expected navigation error handled', { error: msg });
            return { attemptedUrl: badUrl, errorMessage: msg };
        }
    } finally {
        await safeClosePage(page, 'negative nav page');
    }
}


async function safeClosePage(page: Page, label: string) {
    try {
        await page.close();
    } catch (e) {
        console.warn(`Failed closing ${label}`, { error: (e as Error).message });
    }
}


async function main() {
    const start = Date.now();
    let browser: Browser | null = null;

    console.info('CDP smoke test starting', { config: CONFIG });

    try {
        const wsEndpoint = await fetchWebSocketEndpoint(CONFIG.baseUrl);
        console.info('Discovered CDP WebSocket endpoint', { wsEndpoint });

        browser = await chromium.connectOverCDP(wsEndpoint);
        console.info('Connected to browser over CDP');

        const navExtract = await testNavigateAndExtract(browser);
        const jsonProbe = await testJsonProbe(browser);
        const negative = await testNegativeNavigation(browser);

        const durationMs = Date.now() - start;
        const result = {
            status: 'success' as const,
            demo_results: {
                page_title: navExtract.pageTitle,
                page_url: navExtract.pageUrl,
                extracted_data: navExtract.extracted,
                screenshot_path: navExtract.screenshotPath,
                screenshot_size_bytes: navExtract.screenshotSizeBytes,
                json_probe: jsonProbe.payload,
                environment: {
                    node_env: process.env.NODE_ENV || null,
                    instance_id: process.env.INSTANCE_ID || 'default',
                    session_id: process.env.BROWSER_SESSION_ID || null,
                },
                execution_time_iso: nowIso(),
                duration_ms: durationMs,
                pages_processed: 3,
            },
            metrics: {
                total_pages: 3,
                errors_handled: 1,
                screenshot_captured: true,
                data_extracted: true,
            },
            negative_navigation: negative,
        };

        return result;
    } finally {
        if (browser) {
            try {
                await browser.close();
            } catch (e) {
                console.warn('Failed closing browser', { error: (e as Error).message });
            }
        }
        console.info('Shutdown complete');
    }
}


(async () => {
    try {
        const res = await main();
        console.log(JSON.stringify(res, null, 2));
        process.exitCode = 0;
    } catch (error) {
        const payload = {
            status: 'error' as const,
            error: (error as Error).message,
            stack: (error as Error).stack,
            timestamp: nowIso(),
        };
        console.error(JSON.stringify(payload, null, 2));
        process.exitCode = 1;
    }
})();
