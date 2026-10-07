import fs from 'fs';
import path from 'path';
import os from 'os';

/**
 * Loads environment keys with priority:
 * 1. process.env
 * 2. ~/.config/hermes/hermes.env
 * 3. .env in current directory or skill root
 */
export function loadEnv() {
  const env = { ...process.env };
  const hermesPath = path.join(os.homedir(), '.config', 'hermes', 'hermes.env');
  
  const candidateFiles = [
    hermesPath,
    path.join(process.cwd(), '.env'),
    new URL('../.env', import.meta.url).pathname
  ];

  for (const filePath of candidateFiles) {
    if (fs.existsSync(filePath)) {
      try {
        const content = fs.readFileSync(filePath, 'utf-8');
        for (const line of content.split('\n')) {
          const trimmed = line.trim();
          if (!trimmed || trimmed.startsWith('#')) continue;
          const eqIdx = trimmed.indexOf('=');
          if (eqIdx > 0) {
            const key = trimmed.slice(0, eqIdx).trim();
            let val = trimmed.slice(eqIdx + 1).trim();
            if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
              val = val.slice(1, -1);
            }
            if (!env[key]) {
              env[key] = val;
            }
          }
        }
      } catch (err) {
        // ignore read error
      }
    }
  }

  // Normalize TypeSafe key
  if (!env.TYPESAFE_API_KEY && env.TYPESAFEAI_API_KEY) {
    env.TYPESAFE_API_KEY = env.TYPESAFEAI_API_KEY;
  }

  return env;
}
