#!/usr/bin/env node
/*
 * Garmin Webloader (command line, Node.js)
 *
 * Copy Connect IQ .prg files onto a Garmin that's plugged in over USB.
 *
 *   node webloader.js app.prg            load a file onto your Garmin
 *   node webloader.js list               see what's already on it
 *   node webloader.js remove app.prg     take an app off it
 *
 * Options:
 *   -d, --device PATH   the GARMIN folder, the Apps folder, or the whole drive
 *   -y, --yes           don't ask before replacing or removing
 *   --no-verify         skip the double-check after copying
 *
 * Needs Node 16 or newer. Nothing to install.
 */
'use strict';
const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');
const readline = require('readline');

const COMMANDS = ['load', 'list', 'remove'];

function fail(message) {
  console.error('Oops: ' + message);
  process.exit(1);
}

function subfolders(dir) {
  try {
    return fs.readdirSync(dir, { withFileTypes: true }).filter(e => e.isDirectory()).map(e => path.join(dir, e.name));
  } catch (e) { return []; }
}

// Find a folder inside `parent`, ignoring upper and lower case.
function child(parent, name) {
  return subfolders(parent).find(p => path.basename(p).toLowerCase() === name.toLowerCase()) || null;
}

function driveRoots() {
  if (process.platform === 'win32') {
    const roots = [];
    for (const letter of 'ABCDEFGHIJKLMNOPQRSTUVWXYZ') {
      const p = letter + ':\\';
      try { if (fs.existsSync(p)) roots.push(p); } catch (e) { /* skip */ }
    }
    return roots;
  }
  if (process.platform === 'darwin') return subfolders('/Volumes');
  const user = process.env.USER || process.env.LOGNAME || os.userInfo().username || '';
  return [path.join('/media', user), path.join('/run/media', user), '/media', '/mnt'].flatMap(subfolders);
}

function makeDevice(garmin, apps) {
  const device = { garmin, apps: apps || child(garmin, 'Apps'), name: null };
  try {
    const xml = fs.readFileSync(path.join(garmin, 'GarminDevice.xml'), 'utf8');
    const model = xml.match(/<(?:\w+:)?Model>[\s\S]*?<\/(?:\w+:)?Model>/);
    const desc = model && model[0].match(/<(?:\w+:)?Description>([^<]*)</);
    if (desc && desc[1].trim()) device.name = desc[1].trim();
  } catch (e) { /* no device file, that's fine */ }
  return device;
}

const label = d => (d.name ? d.name + ' ' : '') + '(' + d.garmin + ')';

function deviceFromPath(text) {
  const p = path.resolve(text.replace(/^~(?=$|\/)/, os.homedir()));
  if (!fs.existsSync(p) || !fs.statSync(p).isDirectory()) fail('“' + text + '” isn\'t a folder.');
  const lower = path.basename(p).toLowerCase();
  if (lower === 'apps') return makeDevice(path.dirname(p), p);
  if (lower === 'garmin') return makeDevice(p);
  const inside = child(p, 'GARMIN');
  if (!inside) fail('There\'s no GARMIN folder inside “' + text + '”. Is that your Garmin\'s drive?');
  return makeDevice(inside);
}

function ask(question) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise(resolve => rl.question(question, answer => { rl.close(); resolve(answer.trim()); }));
}
async function yes(question, assumeYes) {
  return assumeYes || /^y(es)?$/i.test(await ask(question + ' [y/N] '));
}

async function pickDevice(opts) {
  if (opts.device) return deviceFromPath(opts.device);
  const found = [], seen = new Set();
  for (const root of driveRoots()) {
    const garmin = path.basename(root).toUpperCase() === 'GARMIN' ? root : child(root, 'GARMIN');
    if (garmin && !seen.has(garmin)) { seen.add(garmin); found.push(makeDevice(garmin)); }
  }
  if (!found.length) {
    fail('Couldn\'t find a Garmin. Plug it in and wait for it to show up as a drive. ' +
         'If it only appears as a media device, copy the file into GARMIN/Apps yourself, or point me at it with --device.');
  }
  if (found.length === 1) return found[0];
  console.log('I found more than one Garmin:');
  found.forEach((d, i) => console.log('  ' + (i + 1) + ') ' + label(d)));
  const n = parseInt(await ask('Which one? [1-' + found.length + '] '), 10);
  if (!(n >= 1 && n <= found.length)) fail('That wasn\'t one of the choices.');
  return found[n - 1];
}

const sha256 = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const sizeText = n => n < 1024 ? n + ' B' : n < 1048576 ? (n / 1024).toFixed(1) + ' KB' : (n / 1048576).toFixed(1) + ' MB';

function appsDir(device) {
  if (!device.apps) {
    device.apps = path.join(device.garmin, 'Apps');
    fs.mkdirSync(device.apps, { recursive: true });
    console.log('Made a new Apps folder on your Garmin.');
  }
  return device.apps;
}

function programs(device) {
  if (!device.apps) return [];
  return fs.readdirSync(device.apps, { withFileTypes: true })
    .filter(e => e.isFile() && e.name.toLowerCase().endsWith('.prg'))
    .map(e => e.name).sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));
}

async function load(opts) {
  for (const f of opts.files) {
    if (!fs.existsSync(f) || !fs.statSync(f).isFile()) fail('Can\'t find “' + f + '”.');
    if (!f.toLowerCase().endsWith('.prg')) fail('“' + path.basename(f) + '” isn\'t a .prg file. Only .prg files work here.');
    if (fs.statSync(f).size === 0) fail('“' + path.basename(f) + '” is empty.');
  }
  const device = await pickDevice(opts);
  console.log('Connected to ' + label(device));
  const target = appsDir(device);
  for (const f of opts.files) {
    const name = path.basename(f), dest = path.join(target, name);
    if (fs.existsSync(dest) && !(await yes(name + ' is already on your Garmin. Replace it?', opts.yes))) {
      console.log('Skipped ' + name);
      continue;
    }
    console.log('Copying ' + name + ' (' + sizeText(fs.statSync(f).size) + ')...');
    fs.copyFileSync(f, dest);
    const fd = fs.openSync(dest, 'r+'); fs.fsyncSync(fd); fs.closeSync(fd);
    if (!opts.noVerify && sha256(f) !== sha256(dest)) fail(name + ' didn\'t copy cleanly. Give it another try.');
    console.log('  done' + (opts.noVerify ? '' : ', checked and good'));
  }
  console.log('All done! Eject your Garmin safely before you unplug it, then look for the new app on it.');
}

async function list(opts) {
  const device = await pickDevice(opts);
  console.log('Connected to ' + label(device));
  const names = programs(device);
  if (!names.length) return console.log('Nothing installed from a file yet.');
  for (const n of names) {
    const st = fs.statSync(path.join(device.apps, n));
    console.log('  ' + n.padEnd(36) + sizeText(st.size).padStart(9) + '   ' + st.mtime.toISOString().slice(0, 10));
  }
}

async function remove(opts) {
  const device = await pickDevice(opts);
  console.log('Connected to ' + label(device));
  for (const wanted of opts.files) {
    const match = programs(device).find(n => n.toLowerCase() === path.basename(wanted).toLowerCase());
    if (!match) { console.log('Couldn\'t find ' + wanted + ' on your Garmin.'); continue; }
    if (await yes('Remove ' + match + ' from your Garmin?', opts.yes)) {
      fs.unlinkSync(path.join(device.apps, match));
      console.log('Removed ' + match);
    }
  }
}

async function main(argv) {
  if (argv.length && !COMMANDS.includes(argv[0]) && !argv[0].startsWith('-')) argv = ['load', ...argv]; // shortcut
  const opts = { command: argv[0], files: [], device: null, yes: false, noVerify: false };
  for (let i = 1; i < argv.length; i++) {
    const a = argv[i];
    if (a === '-d' || a === '--device') opts.device = argv[++i];
    else if (a === '-y' || a === '--yes') opts.yes = true;
    else if (a === '--no-verify') opts.noVerify = true;
    else opts.files.push(a);
  }
  if (!COMMANDS.includes(opts.command)) fail('Try: node webloader.js app.prg, list, or remove app.prg');
  if (opts.command !== 'list' && !opts.files.length) fail('Which .prg file? For example: node webloader.js ' + opts.command + ' app.prg');
  try {
    await ({ load, list, remove })[opts.command](opts);
  } catch (e) {
    fail(e.code === 'EACCES' || e.code === 'EPERM' ? 'The Garmin wouldn\'t let me write there (' + e.message + ').' : e.message);
  }
}

main(process.argv.slice(2));
