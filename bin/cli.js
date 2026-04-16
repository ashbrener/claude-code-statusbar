#!/usr/bin/env node

const { install } = require('./install');
const { uninstall } = require('./uninstall');
const { configure } = require('./configure');

const command = process.argv[2] || 'install';

const commands = {
  install,
  uninstall,
  configure,
  help() {
    console.log(`
Claude Code Statusbar

Usage:
  npx claude-code-statusbar              Install with defaults
  npx claude-code-statusbar configure    Customize segments, colors, bar style
  npx claude-code-statusbar uninstall    Remove and restore previous config
  npx claude-code-statusbar help         Show this help
`);
  }
};

const fn = commands[command];
if (!fn) {
  console.error(`Unknown command: ${command}`);
  commands.help();
  process.exit(1);
}

fn().catch(err => {
  console.error(err.message);
  process.exit(1);
});
