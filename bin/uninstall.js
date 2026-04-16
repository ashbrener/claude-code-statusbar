const fs = require('fs');
const path = require('path');
const os = require('os');

const CLAUDE_DIR = path.join(os.homedir(), '.claude');
const DEST_FILE = path.join(CLAUDE_DIR, 'statusline-command.sh');
const SETTINGS_FILE = path.join(CLAUDE_DIR, 'settings.json');
const CONFIG_FILE = path.join(CLAUDE_DIR, 'statusbar-config.json');
const BACKUP_DIR = path.join(CLAUDE_DIR, '.statusbar-backup');

async function uninstall() {
  console.log('Claude Code Statusbar: Uninstalling...\n');

  const backupScript = path.join(BACKUP_DIR, 'statusline-command.sh');
  const backupSettings = path.join(BACKUP_DIR, 'statusbar-settings.json');

  // Restore or remove statusbar script
  if (fs.existsSync(backupScript)) {
    fs.copyFileSync(backupScript, DEST_FILE);
    console.log('Restored: Previous statusbar script from backup.');
  } else if (fs.existsSync(DEST_FILE)) {
    fs.unlinkSync(DEST_FILE);
    console.log(`Removed: ${DEST_FILE}`);
  } else {
    console.log('Script not found — skipping.');
  }

  // Restore or remove statusLine from settings
  if (fs.existsSync(backupSettings)) {
    const backup = JSON.parse(fs.readFileSync(backupSettings, 'utf8'));
    if (fs.existsSync(SETTINGS_FILE)) {
      const settings = JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf8'));
      settings.statusLine = backup.statusLine;
      fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2) + '\n');
      console.log('Restored: Previous statusLine config in settings.json.');
    }
  } else if (fs.existsSync(SETTINGS_FILE)) {
    const settings = JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf8'));
    if (settings.statusLine) {
      delete settings.statusLine;
      fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2) + '\n');
      console.log('Removed: statusLine from settings.json.');
    } else {
      console.log('Settings: No statusLine found — skipping.');
    }
  }

  // Remove config file
  if (fs.existsSync(CONFIG_FILE)) {
    fs.unlinkSync(CONFIG_FILE);
    console.log(`Removed: ${CONFIG_FILE}`);
  }

  // Clean up backup directory
  if (fs.existsSync(BACKUP_DIR)) {
    fs.rmSync(BACKUP_DIR, { recursive: true });
    console.log('Cleaned up: Backup directory removed.');
  }

  console.log('');
  console.log('Uninstalled. Restart Claude Code to apply changes.');
}

module.exports = { uninstall };
