const { spawnSync } = require('child_process');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..');

function runCommand(command, args) {
  const result = spawnSync(command, args, {
    cwd: repoRoot,
    stdio: 'inherit',
    shell: false,
  });

  if (result.error) {
    throw result.error;
  }

  if (typeof result.status === 'number' && result.status !== 0) {
    process.exit(result.status);
  }
}

try {
  // Keep Evolver validation read-only. These are the canonical repo-wide
  // checks and do not rewrite files during solidify.
  runCommand('moon', ['check']);
  runCommand('moon', ['test']);
} catch (error) {
  const message = error && error.message ? error.message : String(error);
  console.error('[validate-evolver-target] Validation failed:', message);
  process.exit(1);
}
