const {spawnSync} = require('node:child_process');
const path = require('node:path');
const fs = require('node:fs');
const cwd = path.join(__dirname, 'video');
const cli = path.join(cwd, 'node_modules', '@remotion', 'cli', 'remotion-cli.js');
const targets = [
  ['PlanetCraftWide', 'planetcraft-youtube-1920x1080.mp4'],
  ['PlanetCraftVertical', 'planetcraft-vertical-1080x1920.mp4'],
];
for (const [id, file] of targets) {
  console.log(new Date().toISOString() + ' Rendering ' + id);
  const logFile = fs.openSync(path.join(__dirname, id + '.log'), 'w');
  const child = spawnSync(process.execPath, [
    cli, 'render', 'src/index.tsx', id, path.join(__dirname, file),
    '--codec=h264', '--crf=18', '--pixel-format=yuv420p', '--concurrency=4',
    '--x264-preset=fast', '--log=warn',
  ], {cwd, stdio:['ignore', logFile, logFile]});
  fs.closeSync(logFile);
  if (child.error) throw child.error;
  if (child.status !== 0) process.exit(child.status ?? 1);
  console.log(new Date().toISOString() + ' Completed ' + id);
}

