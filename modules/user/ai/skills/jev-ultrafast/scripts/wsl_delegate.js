import fs from 'fs';
import { spawnSync, execSync } from 'child_process';

/**
 * Finds Windows node.exe when running inside WSL.
 */
export function getWindowsNodePath() {
  const candidates = [
    '/mnt/d/scoop/sandy/local/apps/nodejs-lts/current/node.exe',
    '/mnt/c/Program Files/nodejs/node.exe'
  ];

  for (const c of candidates) {
    if (fs.existsSync(c)) return c;
  }

  try {
    const whichNode = execSync('which node.exe 2>/dev/null', { encoding: 'utf-8' }).trim();
    if (whichNode && fs.existsSync(whichNode)) return whichNode;
  } catch (e) {}

  return null;
}

/**
 * Converts a Linux/WSL path to a Windows UNC or drive path.
 */
export function toWindowsPath(linuxPath) {
  try {
    const winPath = execSync(`wslpath -w "${linuxPath}" 2>/dev/null`, { encoding: 'utf-8' }).trim();
    if (winPath) return winPath;
  } catch (e) {}
  return linuxPath;
}

/**
 * If running on Linux inside WSL and Windows node.exe is available,
 * seamlessly delegates execution to Windows node.exe so Windows Chrome.exe
 * can be launched and controlled without needing Chromium on Linux/Nix.
 */
export function delegateToWindowsIfNeeded() {
  if (process.env._JEV_WSL_DELEGATED) return;

  const isWSL = process.platform === 'linux' && (
    fs.existsSync('/proc/sys/fs/binfmt_misc/WSLInterop') ||
    fs.existsSync('/run/WSL')
  );

  if (!isWSL) return;

  const winNode = getWindowsNodePath();
  if (!winNode) return;

  const scriptPath = process.argv[1];
  const winScriptPath = toWindowsPath(scriptPath);
  const args = [winScriptPath, ...process.argv.slice(2)];

  const result = spawnSync(winNode, args, {
    stdio: ['ignore', 'inherit', 'inherit'],
    env: {
      ...process.env,
      _JEV_WSL_DELEGATED: '1'
    }
  });

  process.exit(result.status ?? 0);
}
