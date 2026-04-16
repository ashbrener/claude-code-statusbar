const fs = require('fs');
const path = require('path');
const os = require('os');
const readline = require('readline');

const CLAUDE_DIR = path.join(os.homedir(), '.claude');
const CONFIG_FILE = path.join(CLAUDE_DIR, 'statusline-config.json');
const DEFAULT_CONFIG = path.resolve(__dirname, '..', 'scripts', 'defaults.json');

function ask(rl, question) {
  return new Promise(resolve => rl.question(question, resolve));
}

async function configure() {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

  console.log('Claude Code Statusbar — Configuration\n');

  // Load current or default config
  let config;
  if (fs.existsSync(CONFIG_FILE)) {
    config = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
    console.log(`Current config: ${CONFIG_FILE}`);
  } else {
    config = JSON.parse(fs.readFileSync(DEFAULT_CONFIG, 'utf8'));
    console.log('No config found — starting from defaults.');
  }

  // Ensure defaults
  config.segments = config.segments || ['model', 'rate', 'context', 'directory', 'branch'];
  config.bar = config.bar || { filled: '█', empty: '░', width: 10 };
  config.thresholds = config.thresholds || { warning: 50, critical: 80 };
  config.directory = config.directory || { relative_to: 'home' };

  // --- Segment selection ---
  console.log('\nWhich segments do you want? (comma-separated, or press Enter for current)');
  console.log('  Available: model, rate, context, directory, branch');
  console.log(`  Current:   ${config.segments.join(', ')}`);
  const segInput = await ask(rl, '> ');

  if (segInput.trim()) {
    config.segments = segInput.split(',').map(s => s.trim()).filter(Boolean);
  }

  // --- Segment order ---
  console.log(`\nSegment order: ${config.segments.join(', ')}`);
  const orderInput = await ask(rl, 'Reorder? (comma-separated, or Enter to keep)\n> ');

  if (orderInput.trim()) {
    config.segments = orderInput.split(',').map(s => s.trim()).filter(Boolean);
  }

  // --- Bar style ---
  console.log('\nBar style:');
  console.log(`  1) ██░░░░░░░░ (default)`);
  console.log('  2) ■■□□□□□□□□');
  console.log('  3) ●●○○○○○○○○');
  console.log('  4) ##--------');
  console.log('  5) Custom');
  const barChoice = await ask(rl, '> ');

  switch (barChoice.trim()) {
    case '2': config.bar.filled = '■'; config.bar.empty = '□'; break;
    case '3': config.bar.filled = '●'; config.bar.empty = '○'; break;
    case '4': config.bar.filled = '#'; config.bar.empty = '-'; break;
    case '5':
      config.bar.filled = (await ask(rl, 'Filled character: ')).trim() || '█';
      config.bar.empty = (await ask(rl, 'Empty character: ')).trim() || '░';
      break;
  }

  // --- Bar width ---
  console.log(`\nBar width (current: ${config.bar.width}, press Enter to keep):`);
  const widthInput = await ask(rl, '> ');
  if (widthInput.trim()) {
    const w = parseInt(widthInput.trim(), 10);
    if (!isNaN(w) && w > 0) config.bar.width = w;
  }

  // --- Directory display ---
  console.log('\nDirectory relative to:');
  console.log('  1) home (~/)  (default)');
  console.log('  2) Full absolute path');
  console.log('  3) Custom prefix to strip');
  const dirChoice = await ask(rl, '> ');

  switch (dirChoice.trim()) {
    case '2': config.directory.relative_to = 'none'; break;
    case '3':
      const prefix = await ask(rl, 'Prefix to strip (e.g. /Users/me/Code/): ');
      if (prefix.trim()) config.directory.relative_to = prefix.trim();
      break;
  }

  // --- Display mode ---
  config.display = config.display || { mode: 'used', color_ramp: 'same' };
  console.log('\nPercentage display:');
  console.log('  1) used — "ctx: 24%" means 24% consumed (default)');
  console.log('  2) remaining — "ctx: 76%" means 76% available');
  console.log(`  Current: ${config.display.mode}`);
  const modeChoice = await ask(rl, '> ');
  if (modeChoice.trim() === '2') config.display.mode = 'remaining';
  else if (modeChoice.trim() === '1') config.display.mode = 'used';

  console.log('\nColor ramp:');
  console.log('  1) same — gauge brightens in its own color (default)');
  console.log('  2) red — shifts to yellow then red at thresholds');
  console.log(`  Current: ${config.display.color_ramp}`);
  const rampChoice = await ask(rl, '> ');
  if (rampChoice.trim() === '2') config.display.color_ramp = 'red';
  else if (rampChoice.trim() === '1') config.display.color_ramp = 'same';

  // --- Labels ---
  config.labels = config.labels || { rate: 'auto', context: 'ctx' };
  console.log(`\nGauge labels:`);
  console.log(`  Rate limit: "${config.labels.rate}" (use "auto" to detect from window, e.g. 5hr)`);
  console.log(`  Context:    "${config.labels.context}"`);
  const rateLabel = await ask(rl, 'Rate limit label (Enter to keep): ');
  if (rateLabel.trim()) config.labels.rate = rateLabel.trim();
  const ctxLabel = await ask(rl, 'Context label (Enter to keep): ');
  if (ctxLabel.trim()) config.labels.context = ctxLabel.trim();

  // --- Thresholds ---
  console.log(`\nColor thresholds (when bars turn yellow/red):`);
  console.log(`  Warning at ${config.thresholds.warning}%, Critical at ${config.thresholds.critical}%`);
  const threshInput = await ask(rl, 'Enter two numbers (e.g. 60 90), or Enter to keep:\n> ');

  if (threshInput.trim()) {
    const parts = threshInput.trim().split(/\s+/);
    if (parts[0]) config.thresholds.warning = parseInt(parts[0], 10);
    if (parts[1]) config.thresholds.critical = parseInt(parts[1], 10);
  }

  rl.close();

  // Save
  fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2) + '\n');
  console.log(`\nSaved: ${CONFIG_FILE}`);

  // Preview
  const f = config.bar.filled;
  const e = config.bar.empty;
  const w = config.bar.width;
  const sampleBar = (pct) => {
    const filled = Math.round(pct * w / 100);
    return f.repeat(filled) + e.repeat(w - filled);
  };

  console.log('\nPreview:');
  const labels = config.labels || {};
  const rLabel = labels.rate === 'auto' ? '5hr' : (labels.rate || '5hr');
  const cLabel = labels.context || 'ctx';
  const isRemaining = config.display.mode === 'remaining';
  const rPct = isRemaining ? 80 : 20;
  const cPct = isRemaining ? 70 : 30;
  console.log(`  Opus 4.6  ${rLabel}:${sampleBar(rPct)} ${rPct}%  ${cLabel}:${sampleBar(cPct)} ${cPct}%  Code/myproject  main`);
  console.log('\nRestart Claude Code to apply.');
}

module.exports = { configure };
