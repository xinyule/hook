// M0 data sanity check. Usage: node tools/validate_data.js
// Checks JSON validity, cross-references, pack policy and IP hygiene.
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..', 'data');
const files = [];
function walk(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p);
    else if (e.name.endsWith('.json')) files.push(p);
  }
}
walk(root);

const errors = [];
const data = {};
for (const f of files) {
  try { data[path.relative(root, f).replace(/\\/g, '/')] = JSON.parse(fs.readFileSync(f, 'utf8')); }
  catch (e) { errors.push('JSON parse failed: ' + path.relative(root, f) + ' -> ' + e.message); }
}

// IP hygiene: no original-work proper nouns may enter the shipped data.
const rawAll = files.map(f => fs.readFileSync(f, 'utf8')).join('\n');
const banned = ['PETERPAN', 'RUFIO', 'THUDBUTT', 'POCKETS', 'BUTCHER', 'JASON', 'DAMON', 'SMEE', 'IREM', 'TRI-STAR', '铁钩船长', '虎克船长'];
for (const w of banned) {
  if (rawAll.indexOf(w) >= 0) errors.push('IP hygiene: banned original-work term found in data/: ' + w);
}

const chars = data['characters.json'] || {};
const enemies = data['enemies.json'] || {};
const bosses = data['bosses.json'] || {};
const manifest = data['packs/pack_manifest.json'] || {};
const arcade = data['rules/arcade.json'] || {};

if ((chars.characters || []).length !== 5) errors.push('expected 5 characters');
if ((enemies.templates || []).length !== 7) errors.push('expected 7 enemy templates');
if ((bosses.bosses || []).length !== 6) errors.push('expected 6 bosses');

const stageIds = new Set(Object.keys(data).filter(k => k.startsWith('stages/')).map(k => data[k].id));
for (const b of (bosses.bosses || [])) {
  if (!stageIds.has(b.stage)) errors.push('boss ' + b.id + ' references missing stage ' + b.stage);
}
for (const k of Object.keys(data).filter(k => k.startsWith('stages/'))) {
  const s = data[k];
  if (!s.id || !s.display_name || !Array.isArray(s.segments)) errors.push('stage file malformed: ' + k);
  if (s.boss && s.boss.id && !(bosses.bosses || []).some(b => b.id === s.boss.id)) {
    errors.push('stage ' + k + ' references missing boss ' + s.boss.id);
  }
}

if (manifest.default_pack !== 'public') errors.push('default pack must be public');
if (manifest.export_locked_pack !== 'public') errors.push('export must be locked to public');
const internal = (manifest.packs || {}).internal_reference || {};
if (internal.in_export !== false || internal.in_repository !== false) {
  errors.push('internal_reference pack must be excluded from repository and export');
}
if (!arcade.CreditSystem || arcade.CreditSystem.continue_by_credit !== true || !arcade.LoopPolicy || arcade.LoopPolicy.loop_after_final_stage !== true) {
  errors.push('arcade ruleset must keep coin-continue and infinite loop (一期保留项)');
}
if (arcade.CreditSystem && arcade.CreditSystem.max_players !== 4) errors.push('arcade ruleset must support 4 players');

const pending = Object.keys(data).filter(k => k.startsWith('stages/')).filter(k => data[k].verification === 'pending_frame_by_frame');

console.log('files=' + files.length + ' | stages=' + stageIds.size + ' | pending_frame_review=' + pending.length);
if (errors.length) {
  console.error('FAILED (' + errors.length + '):');
  errors.forEach(e => console.error('  - ' + e));
  process.exit(1);
}
console.log('OK: data valid, pack policy clean, arcade rules preserved, no original IP terms.');
