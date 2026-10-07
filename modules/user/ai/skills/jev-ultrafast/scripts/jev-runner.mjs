#!/usr/bin/env node

import { delegateToWindowsIfNeeded } from './wsl_delegate.js';
delegateToWindowsIfNeeded();

import { launchBrowser, observePage, buildActionSpace, executeAction, getChromiumPath } from './browser_primitives.js';
import { predictJevAction, generateFieldText } from './jev_client.js';

function parseArgs(args) {
  const options = {
    url: '',
    goal: '',
    maxSteps: 25,
    headless: true,
    stepDelay: 100
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--url' && args[i + 1]) {
      options.url = args[++i];
    } else if (arg === '--goal' && args[i + 1]) {
      options.goal = args[++i];
    } else if (arg === '--max-steps' && args[i + 1]) {
      options.maxSteps = parseInt(args[++i], 10);
    } else if (arg === '--headed') {
      options.headless = false;
    } else if (arg === '--delay' && args[i + 1]) {
      options.stepDelay = parseInt(args[++i], 10);
    } else if (arg === '--help' || arg === '-h') {
      console.log(`
Jev Ultrafast Runner (Browser Use x TypeSafe)

Usage:
  node scripts/jev-runner.mjs --url <URL> --goal <GOAL> [options]

Options:
  --url <url>           Target website URL (required)
  --goal <goal>         Natural-language goal to achieve (required)
  --max-steps <num>     Maximum action iterations (default: 25)
  --headed              Run with visible Windows Chrome window (default: headless)
  --delay <ms>          Delay between steps in ms (default: 100)
  --help, -h            Show this help message
`);
      process.exit(0);
    }
  }

  return options;
}

async function main() {
  const options = parseArgs(process.argv.slice(2));

  if (!options.url || !options.goal) {
    console.error('Error: Both --url and --goal are required.');
    console.error('Run with --help for usage details.');
    process.exit(1);
  }

  const chromePath = getChromiumPath();
  console.log(`⚡ Jev Ultrafast Web Agent`);
  console.log(`Chrome Binary: ${chromePath || 'Default'}`);
  console.log(`Target URL:    ${options.url}`);
  console.log(`Goal:          ${options.goal}`);
  console.log(`Headless:      ${options.headless}`);
  console.log(`Max Steps:     ${options.maxSteps}\n`);

  const browser = await launchBrowser({ headless: options.headless });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 800 }
  });
  const page = await context.newPage();

  const history = [];
  const startTime = Date.now();

  try {
    console.log(`Navigating to ${options.url}...`);
    await page.goto(options.url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await page.waitForTimeout(1000);

    for (let step = 1; step <= options.maxSteps; step++) {
      const pageState = await observePage(page);
      if (!pageState) {
        console.warn(`[Step ${step}] Could not read page DOM.`);
        break;
      }

      const actionSpace = buildActionSpace(pageState.actions);
      console.log(`[Step ${step}] Observed ${actionSpace.elements.length} elements across ${pageState.actions.length} action targets.`);

      const decision = await predictJevAction({
        pageState,
        actionSpace,
        goal: options.goal,
        history
      });

      console.log(`[Step ${step}] Jev decision: ${decision.operation} (confidence: ${(decision.confidence * 100).toFixed(1)}%, latency: ${decision.latencyMs}ms)`);

      if (decision.operation === 'DONE') {
        console.log(`\n🎉 Goal marked as DONE by Jev policy.`);
        break;
      }

      if (decision.operation === 'BLOCKED') {
        console.warn(`\n🛑 Jev reported BLOCKED: no available action advances the goal.`);
        break;
      }

      let textToType = null;
      if (decision.operation === 'TYPE_TEXT') {
        textToType = await generateFieldText({
          goal: options.goal,
          action: decision.action,
          pageState,
          history
        });
        console.log(`[Step ${step}] Generated text to enter: "${textToType}"`);
      }

      const execution = await executeAction(page, decision, textToType);
      console.log(`[Step ${step}] Execution: ${execution.executed ? 'Success' : 'Failed (' + execution.reason + ')'}`);

      history.push({
        step,
        operation: decision.operation,
        actionId: decision.action?.elementId,
        typed: textToType,
        executed: execution.executed
      });

      if (options.stepDelay > 0) {
        await page.waitForTimeout(options.stepDelay);
      }
    }

    const elapsedMs = Date.now() - startTime;
    console.log(`\nCompleted run in ${(elapsedMs / 1000).toFixed(2)}s across ${history.length} steps.`);
  } catch (err) {
    console.error('\nExecution error:', err.message);
  } finally {
    await browser.close();
  }
}

main();
