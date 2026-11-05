#!/usr/bin/env node
// Regenerates tests/fixtures/csgear1_live_gear_lists.txt (addon#57).
// Input: a GET /api/v1/characters/{id}/gear-lists response (platform openapi/v1.yaml
// GearList) saved as tests/fixtures/live_gear_lists_response.json. Output: the exact
// CSGEAR1 string the live site's encoder (web js/csgear1.js reply()) hands back to the game.
// Usage: node scripts/gen-live-gear-fixture.js <path/to/web/js/csgear1.js>
'use strict';
const fs = require('fs'), path = require('path'), vm = require('vm');
const web = process.argv[2];
if (!web) { console.error('usage: gen-live-gear-fixture.js <web/js/csgear1.js>'); process.exit(2); }
const root = path.join(__dirname, '..');
const resp = JSON.parse(fs.readFileSync(path.join(root, 'tests/fixtures/live_gear_lists_response.json'), 'utf8'));
const win = {};
const ctx = { window: win, TextEncoder, btoa: (s) => Buffer.from(s, 'binary').toString('base64'), Date: class extends Date { constructor() { super('2026-11-05T09:30:00Z'); } } };
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(web, 'utf8'), ctx);
const c = resp.character;
const out = win.CSGear1.reply({ region: c.region, realm: c.realm, character: c.character_name }, c, resp.items, {});
fs.writeFileSync(path.join(root, 'tests/fixtures/csgear1_live_gear_lists.txt'), out + '\n');
console.log(out);
