// script to extract and manage browser versions
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Path to version manifest
const MANIFEST_PATH = path.join(__dirname, 'browser_versions.json');

// Default registry organization
const DEFAULT_REGISTRY = 'browsergrid';

/**
 * Get the latest Playwright version
 * @returns {string} The latest Playwright version
 */
function getPlaywrightVersion() {
  try {
    return execSync('npm show playwright version').toString().trim();
  } catch (error) {
    console.error('Error getting Playwright version:', error);
    process.exit(1);
  }
}

/**
 * Get the version for a single browser
 * @param {string} browserName - The browser name (chrome, chromium, firefox, webkit)
 * @returns {Promise<string>} The browser version
 */
async function getSingleBrowserVersion(browserName) {
  // Create a temporary directory
  const tempDir = path.join(__dirname, 'temp-browser-check');
  if (!fs.existsSync(tempDir)) {
    fs.mkdirSync(tempDir);
  }

  try {
    // Create a temporary package.json
    fs.writeFileSync(
      path.join(tempDir, 'package.json'),
      JSON.stringify({
        dependencies: {
          playwright: 'latest'
        }
      })
    );

    // Install Playwright
    execSync('npm install', { cwd: tempDir });

    // Download the browser binary that Playwright expects. Without this the subsequent
    // `chromium.launch()` / `firefox.launch()` / `webkit.launch()` calls fail with the
    // classic "Executable doesn't exist" error that suggests running `playwright install`.
    // We only need the specific browser requested but for safety we install just that one
    // (mapping the Playwright-friendly name when necessary).
    try {
      const installTarget = browserName === 'chrome' ? 'chromium' : browserName;
      execSync(`npx playwright install --with-deps ${installTarget}`, { cwd: tempDir });
    } catch (e) {
      console.warn('playwright install failed in temp dir, will rely on auto-download:', e.message || e);
    }

    // Create a script to get browser version
    const scriptPath = path.join(tempDir, 'get-version.js');
    fs.writeFileSync(
      scriptPath,
      `
      const { chromium, firefox, webkit } = require('playwright');
      
      async function getBrowserVersion() {
        const browserName = '${browserName}';
        let browser;
        let version;
        
        try {
          switch(browserName) {
            case 'chrome':
            case 'chromium':
              browser = await chromium.launch();
              break;
            case 'firefox':
              browser = await firefox.launch();
              break;
            case 'webkit':
              browser = await webkit.launch();
              break;
          }
          
          version = await browser.version();
          await browser.close();
          
          // Extract major.minor.patch version
          const versionMatch = version.match(/(\\d+\\.\\d+\\.\\d+)/);
          if (versionMatch) {
            console.log(versionMatch[1]);
            return;
          }
          
          // Fallback: just print the full version
          console.log(version);
        } catch(e) {
          console.error(e);
          process.exit(1);
        }
      }
      
      getBrowserVersion();
      `
    );

    // Run the script
    const output = execSync(`node ${scriptPath}`).toString().trim();
    return output;
  } catch (error) {
    console.error(`Error getting ${browserName} version:`, error);
    return 'unknown';
  } finally {
    // Clean up
    execSync(`rm -rf ${tempDir}`);
  }
}

/**
 * Get the current browser versions from Playwright
 * @param {string} playwrightVersion - The Playwright version to use
 * @returns {Object} Object containing browser versions
 */
async function getBrowserVersions(playwrightVersion) {
  // Create a temporary directory
  const tempDir = path.join(__dirname, 'temp-browser-check');
  if (!fs.existsSync(tempDir)) {
    fs.mkdirSync(tempDir);
  }

  try {
    // Create a temporary package.json
    fs.writeFileSync(
      path.join(tempDir, 'package.json'),
      JSON.stringify({
        dependencies: {
          playwright: playwrightVersion
        }
      })
    );

    // Install Playwright
    execSync('npm install', { cwd: tempDir });

    // Ensure browser binaries are available for the launches below. Installing all three
    // avoids having to figure out which targets are needed.
    try {
      execSync('npx playwright install --with-deps', { cwd: tempDir });
    } catch (e) {
      console.warn('playwright install failed in temp dir, will rely on auto-download:', e.message || e);
    }

    // Create a script to get browser versions
    const scriptPath = path.join(tempDir, 'get-versions.js');
    fs.writeFileSync(
      scriptPath,
      `
      const { chromium, firefox, webkit } = require('playwright');
      
      async function getBrowserVersions() {
        const versions = {};
        
        // Get Chrome version
        try {
          const browser = await chromium.launch();
          versions.chrome = await browser.version();
          await browser.close();
        } catch (e) {
          console.error('Chrome error:', e);
          versions.chrome = 'unknown';
        }
        
        // Get Firefox version
        try {
          const browser = await firefox.launch();
          versions.firefox = await browser.version();
          await browser.close();
        } catch (e) {
          console.error('Firefox error:', e);
          versions.firefox = 'unknown';
        }
        
        // Get WebKit version
        try {
          const browser = await webkit.launch();
          versions.webkit = await browser.version();
          await browser.close();
        } catch (e) {
          console.error('WebKit error:', e);
          versions.webkit = 'unknown';
        }
        
        // Chromium is the same as Chrome for Playwright
        versions.chromium = versions.chrome;
        
        // Format versions to just major.minor.patch
        Object.keys(versions).forEach(browser => {
          const match = versions[browser].match(/(\\d+\\.\\d+\\.\\d+)/);
          if (match) {
            versions[browser] = match[1];
          }
        });
        
        console.log(JSON.stringify(versions));
      }
      
      getBrowserVersions();
      `
    );

    // Run the script
    const output = execSync(`node ${scriptPath}`).toString().trim();
    return JSON.parse(output);
  } catch (error) {
    console.error('Error getting browser versions:', error);
    return {
      chrome: 'unknown',
      chromium: 'unknown',
      firefox: 'unknown',
      webkit: 'unknown'
    };
  } finally {
    // Clean up
    execSync(`rm -rf ${tempDir}`);
  }
}

/**
 * Load the current version manifest
 * @returns {Object} The current version manifest
 */
function loadManifest() {
  if (fs.existsSync(MANIFEST_PATH)) {
    return JSON.parse(fs.readFileSync(MANIFEST_PATH, 'utf8'));
  }
  return {
    playwrightVersion: '',
    browserVersions: {},
    lastUpdated: ''
  };
}

/**
 * Save the manifest
 * @param {Object} manifest - The manifest to save
 */
function saveManifest(manifest) {
  fs.writeFileSync(MANIFEST_PATH, JSON.stringify(manifest, null, 2));
}

/**
 * Check if versions have changed
 * @param {Object} currentManifest - The current manifest
 * @param {string} playwrightVersion - The new Playwright version
 * @param {Object} browserVersions - The new browser versions
 * @returns {Object} Object containing change information
 */
function checkForChanges(currentManifest, playwrightVersion, browserVersions) {
  const changes = {
    playwrightChanged: currentManifest.playwrightVersion !== playwrightVersion,
    browserChanges: {}
  };

  Object.keys(browserVersions).forEach(browser => {
    const oldVersion = currentManifest.browserVersions[browser];
    const newVersion = browserVersions[browser];
    changes.browserChanges[browser] = oldVersion !== newVersion;
  });

  return changes;
}

/**
 * Check if a browser version exists in Docker Hub
 * @param {string} browser - The browser name
 * @param {string} version - The browser version
 * @param {string} registryOrg - The registry organization (default: browsergrid)
 * @returns {boolean} True if the version exists, false otherwise
 */
function checkVersionExists(browser, version, registryOrg = DEFAULT_REGISTRY) {
  try {
    // Docker Hub API v2 call to check if tag exists
    const result = execSync(`curl -s "https://hub.docker.com/v2/repositories/${registryOrg}/${browser}/tags/${version}" | grep -q "\\\"name\\\""`, { stdio: 'pipe' });
    return true;
  } catch (error) {
    return false;
  }
}

/**
 * Main function
 */
async function main() {
  // Get the latest Playwright version
  const playwrightVersion = getPlaywrightVersion();
  console.log(`Latest Playwright version: ${playwrightVersion}`);

  // Get the browser versions
  const browserVersions = await getBrowserVersions(playwrightVersion);
  console.log('Browser versions:', browserVersions);

  // Load the current manifest
  const currentManifest = loadManifest();
  console.log('Current manifest:', currentManifest);

  // Check for changes
  const changes = checkForChanges(currentManifest, playwrightVersion, browserVersions);
  console.log('Changes detected:', changes);

  // Update the manifest
  const newManifest = {
    playwrightVersion,
    browserVersions,
    lastUpdated: new Date().toISOString()
  };
  saveManifest(newManifest);

  // Return the changes
  return {
    changes,
    newManifest
  };
}

/**
 * Parse command line arguments and run the appropriate function
 */
async function handleCommandLineArguments() {
  const args = process.argv.slice(2);
  
  if (args.includes('--get-playwright-version')) {
    // Get and print the Playwright version
    console.log(getPlaywrightVersion());
    return;
  }
  
  if (args.includes('--get-single-browser-version')) {
    const browserIndex = args.indexOf('--get-single-browser-version') + 1;
    if (browserIndex < args.length) {
      const browserName = args[browserIndex];
      const version = await getSingleBrowserVersion(browserName);
      console.log(version);
    } else {
      console.error('Error: No browser name provided');
      process.exit(1);
    }
    return;
  }
  
  if (args.includes('--check-version-exists')) {
    const browserIndex = args.indexOf('--check-version-exists') + 1;
    const versionIndex = browserIndex + 1;
    const registryIndex = versionIndex + 1;
    
    if (browserIndex < args.length && versionIndex < args.length) {
      const browser = args[browserIndex];
      const version = args[versionIndex];
      const registryOrg = registryIndex < args.length ? args[registryIndex] : DEFAULT_REGISTRY;
      const exists = checkVersionExists(browser, version, registryOrg);
      console.log(exists ? 'true' : 'false');
    } else {
      console.error('Error: Missing browser or version parameter');
      process.exit(1);
    }
    return;
  }
  
  // If no arguments or --help, run the default main function
  if (args.length === 0 || args.includes('--help')) {
    console.log(`
Usage: node version-tracker.js [OPTION]

Options:
  --get-playwright-version                Get the latest Playwright version
  --get-single-browser-version BROWSER    Get the version for a single browser (chrome, chromium, firefox, webkit)
  --check-version-exists BROWSER VERSION [REGISTRY]  Check if a browser version exists in Docker Hub
  --help                                  Display this help message
    `);
    return;
  }
  
  // If no recognized arguments, run the main function
  await main();
}

if (require.main === module) {
  handleCommandLineArguments().catch(console.error);
}

module.exports = {
  getPlaywrightVersion,
  getSingleBrowserVersion,
  getBrowserVersions,
  loadManifest,
  saveManifest,
  checkForChanges,
  checkVersionExists,
  main
};