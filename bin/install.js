const fs = require('fs');
const path = require('path');
const os = require('os');

const CLAUDE_DIR = path.join(os.homedir(), '.claude');
const DEST_FILE = path.join(CLAUDE_DIR, 'statusline-command.sh');
const SETTINGS_FILE = path.join(CLAUDE_DIR, 'settings.json');
const BACKUP_DIR = path.join(CLAUDE_DIR, '.statusbar-backup');
const SOURCE_FILE = path.resolve(__dirname, '..', 'scripts', 'statusbar.sh');

async function install() {
  console.log('Claude Code Statusbar: Installing...\n');

  // Check Claude Code is installed
  if (!fs.existsSync(CLAUDE_DIR)) {
    throw new Error('~/.claude directory not found. Is Claude Code installed?');
  }

  if (!fs.existsSync(SOURCE_FILE)) {
    throw new Error(`statusbar.sh not found at ${SOURCE_FILE}`);
  }

  // Backup existing statusbar if present
  if (fs.existsSync(DEST_FILE)) {
    fs.mkdirSync(BACKUP_DIR, { recursive: true });
    fs.copyFileSync(DEST_FILE, path.join(BACKUP_DIR, 'statusline-command.sh'));
    console.log(`Backup: Saved existing script to ${BACKUP_DIR}/statusline-command.sh`);
  }

  if (fs.existsSync(SETTINGS_FILE)) {
    const settings = JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf8'));
    if (settings.statusLine) {
      fs.mkdirSync(BACKUP_DIR, { recursive: true });
      fs.writeFileSync(
        path.join(BACKUP_DIR, 'statusbar-settings.json'),
        JSON.stringify({ statusLine: settings.statusLine }, null, 2)
      );
      console.log(`Backup: Saved existing statusLine config to ${BACKUP_DIR}/statusbar-settings.json`);
    }
  }

  // Install statusbar script
  fs.copyFileSync(SOURCE_FILE, DEST_FILE);
  fs.chmodSync(DEST_FILE, 0o755);
  console.log(`Installed: ${DEST_FILE}`);

  // Update settings.json
  const statusLineConfig = {
    type: 'command',
    command: 'bash ~/.claude/statusline-command.sh'
  };

  let settings = {};
  if (fs.existsSync(SETTINGS_FILE)) {
    settings = JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf8'));
  }

  const current = JSON.stringify(settings.statusLine);
  const desired = JSON.stringify(statusLineConfig);

  if (current === desired) {
    console.log('Settings: statusLine already configured — skipping.');
  } else {
    settings.statusLine = statusLineConfig;
    fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2) + '\n');
    console.log(`Settings: ${current ? 'Updated' : 'Added'} statusLine in ${SETTINGS_FILE}`);
  }

  console.log('');
  console.log('Claude Code Statusbar installed successfully.');
  console.log('');
  console.log('Restart Claude Code to see your statusbar:');
  console.log('');
  console.log('  Opus 4.6  5hr:██░░░░░░░░ 12%  ctx:██░░░░░░░░ 24%  Code/myproject  main');
  console.log('');
  console.log('To customize:  npx claude-code-statusbar configure');
  console.log('To uninstall:  npx claude-code-statusbar uninstall');
}

module.exports = { install };
