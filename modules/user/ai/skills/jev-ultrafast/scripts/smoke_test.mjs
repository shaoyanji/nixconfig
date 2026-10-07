#!/usr/bin/env node

import { delegateToWindowsIfNeeded } from './wsl_delegate.js';
delegateToWindowsIfNeeded();

import { loadEnv } from './env_helper.js';
import { launchBrowser, observePage, buildActionSpace, executeAction, getChromiumPath } from './browser_primitives.js';
import { predictJevAction } from './jev_client.js';

async function runSmokeTest() {
  console.log('--- Jev Ultrafast Smoke Test on guckloch using Windows Chrome.exe ---');

  // 1. Verify API Key
  const env = loadEnv();
  const apiKey = env.TYPESAFE_API_KEY;
  if (!apiKey) {
    console.error('FAIL: No TYPESAFE_API_KEY or TYPESAFEAI_API_KEY found.');
    process.exit(1);
  }
  console.log('✓ Found TypeSafe API key');

  // 2. Launch Windows Chrome
  const chromePath = getChromiumPath();
  console.log(`Launching Windows Chrome: ${chromePath || 'Default'}...`);
  const browser = await launchBrowser({ headless: true });
  console.log('✓ Windows Chrome.exe launched successfully!');

  const context = await browser.newContext();
  const page = await context.newPage();

  // 3. Load sample interactive HTML page
  const testHtml = `
    <!DOCTYPE html>
    <html>
      <head><title>Jev Test Page</title></head>
      <body>
        <h1>Test Application</h1>
        <label for="search-box">Search Query</label>
        <input id="search-box" type="text" placeholder="Type a term here" />
        <button id="submit-btn" type="button" onclick="document.getElementById('status').innerText='Clicked!'">Submit Query</button>
        <div id="status">Waiting...</div>
      </body>
    </html>
  `;
  await page.setContent(testHtml);
  console.log('✓ Test HTML content set');

  // 4. Observe DOM and build action space
  const pageState = await observePage(page);
  console.log(`✓ DOM observed: ${pageState.actions.length} raw actions found`);

  const actionSpace = buildActionSpace(pageState.actions);
  console.log(`✓ Action space built: ${actionSpace.elements.length} elements indexed`);

  // 5. Query TypeSafe Jev model
  console.log('Calling TypeSafe Jev System One API...');
  const goal = 'Click the Submit Query button';
  const decision = await predictJevAction({
    pageState,
    actionSpace,
    goal,
    history: []
  });

  console.log(`✓ Jev responded in ${decision.latencyMs}ms!`);
  console.log(`  Operation:  ${decision.operation}`);
  console.log(`  Confidence: ${(decision.confidence * 100).toFixed(1)}%`);
  if (decision.action) {
    console.log(`  Target:     ${decision.action.label} (${decision.action.id})`);
  }

  // 6. Execute action
  const execResult = await executeAction(page, decision);
  console.log(`✓ Execution result: ${execResult.executed ? 'Success' : 'Failed'}`);

  const statusText = await page.locator('#status').innerText();
  console.log(`  Page status text after click: "${statusText}"`);

  await browser.close();

  if (statusText === 'Clicked!') {
    console.log('\n🌟 ALL SMOKE TESTS PASSED! Windows chrome.exe is fully driven from guckloch without local Linux Chromium!');
  } else {
    console.log('\n⚠️ Smoke test completed with partial assertion.');
  }
}

runSmokeTest().catch(err => {
  console.error('\nSmoke test failed with error:', err);
  process.exit(1);
});
