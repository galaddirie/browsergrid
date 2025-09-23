const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const MANIFEST_PATH = path.join(__dirname, 'browser_versions.json');

const DEFAULT_REGISTRY = 'browsergrid';
function getPlaywrightVersion() {
  try {
    return execSync('npm show playwright version').toString().trim();
  } catch (error) {
    console.error('Error getting Playwright version:', error);
    process.exit(1);
  }
}

async function getSingleBrowserVersion(browserName) {
  const tempDir = path.join(__dirname, 'temp-browser-check');
  if (!fs.existsSync(tempDir)) {
    fs.mkdirSync(tempDir);
  }

  try {
    fs.writeFileSync(
      path.join(tempDir, 'package.json'),
      JSON.stringify({
        dependencies: {
          playwright: 'latest'
        }
      })
    );

    execSync('npm install', { cwd: tempDir });
    try {
      const installTarget = browserName === 'chrome' ? 'chromium' : browserName;
      execSync(`npx playwright install --with-deps ${installTarget}`, { cwd: tempDir });
    } catch (e) {
      console.warn('playwright install failed in temp dir, will rely on auto-download:', e.message || e);
    }

    const scriptPath = path.join(tempDir, 'get-version.js');
    fs.writeFileSync(
      scriptPath,
      `
      const { chromium } = require('playwright');
      
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
            default:
              throw new Error('Unsupported browser: ' + browserName);
          }
          
          version = await browser.version();
          await browser.close();
          
          const versionMatch = version.match(/(\\d+\\.\\d+\\.\\d+)/);
          if (versionMatch) {
            console.log(versionMatch[1]);
            return;
          }
          console.log(version);
        } catch(e) {
          console.error(e);
          process.exit(1);
        }
      }
      
      getBrowserVersion();
      `
    );

    const output = execSync(`node ${scriptPath}`).toString().trim();
    return output;
  } catch (error) {
    console.error(`Error getting ${browserName} version:`, error);
    return 'unknown';
  } finally {
    execSync(`rm -rf ${tempDir}`);
  }
}

async function getBrowserVersions(playwrightVersion) {
  const tempDir = path.join(__dirname, 'temp-browser-check');
  if (!fs.existsSync(tempDir)) {
    fs.mkdirSync(tempDir);
  }

  try {
    fs.writeFileSync(
      path.join(tempDir, 'package.json'),
      JSON.stringify({
        dependencies: {
          playwright: playwrightVersion
        }
      })
    );

    execSync('npm install', { cwd: tempDir });
    try {
      execSync('npx playwright install --with-deps', { cwd: tempDir });
    } catch (e) {
      console.warn('playwright install failed in temp dir, will rely on auto-download:', e.message || e);
    }

    const scriptPath = path.join(tempDir, 'get-versions.js');
    fs.writeFileSync(
      scriptPath,
      `
      const { chromium } = require('playwright');
      
      async function getBrowserVersions() {
        const versions = {};
        
        try {
          const browser = await chromium.launch();
          versions.chrome = await browser.version();
          await browser.close();
        } catch (e) {
          console.error('Chrome error:', e);
          versions.chrome = 'unknown';
        }

        versions.chromium = versions.chrome;
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

    const output = execSync(`node ${scriptPath}`).toString().trim();
    return JSON.parse(output);
  } catch (error) {
    console.error('Error getting browser versions:', error);
    return {
      chrome: 'unknown',
      chromium: 'unknown',
    };
  } finally {
    execSync(`rm -rf ${tempDir}`);
  }
}

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

function saveManifest(manifest) {
  fs.writeFileSync(MANIFEST_PATH, JSON.stringify(manifest, null, 2));
}

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

function checkVersionExists(browser, version, registryOrg = DEFAULT_REGISTRY) {
  try {
    const result = execSync(`curl -s "https://hub.docker.com/v2/repositories/${registryOrg}/${browser}/tags/${version}" | grep -q "\\\"name\\\""`, { stdio: 'pipe' });
    return true;
  } catch (error) {
    return false;
  }
}

async function main() {
  const playwrightVersion = getPlaywrightVersion();
  console.log(`Latest Playwright version: ${playwrightVersion}`);

  const browserVersions = await getBrowserVersions(playwrightVersion);
  console.log('Browser versions:', browserVersions);

  const currentManifest = loadManifest();
  console.log('Current manifest:', currentManifest);

  const changes = checkForChanges(currentManifest, playwrightVersion, browserVersions);
  console.log('Changes detected:', changes);

  const newManifest = {
    playwrightVersion,
    browserVersions,
    lastUpdated: new Date().toISOString()
  };
  saveManifest(newManifest);

  return {
    changes,
    newManifest
  };
}

async function handleCommandLineArguments() {
  const args = process.argv.slice(2);
  
  if (args.includes('--get-playwright-version')) {
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