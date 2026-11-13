// M0 data sanity check. Usage: node tools/validate_data.js
// Checks JSON validity, cross-references, pack policy and internal-only distribution.
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

// Route A (faithful remake) is internal-only. There is no public-facing build
// to police, so the gate enforces the internal-only distribution contract instead.

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

// Single-track route A: exactly one content pack, internal distribution only.
if (manifest.route !== 'A') errors.push('route must be A (B original route cancelled)');
if (manifest.distribution !== 'internal_only') errors.push('distribution must be internal_only');
if (manifest.public_release !== false) errors.push('public_release must be false');
if (manifest.default_pack !== 'internal_reference') errors.push('default pack must be internal_reference');
if (manifest.export_locked_pack !== 'internal_reference') errors.push('export must be locked to internal_reference');
if ((manifest.packs || {}).public) errors.push('public pack must not exist (route B cancelled)');
const internal = (manifest.packs || {}).internal_reference || {};
if (internal.in_export !== true || internal.in_repository !== true) {
  errors.push('internal_reference must be the shippable pack for route A');
}
if (!arcade.CreditSystem || arcade.CreditSystem.continue_by_credit !== true || !arcade.LoopPolicy || arcade.LoopPolicy.loop_after_final_stage !== true) {
  errors.push('arcade ruleset must keep coin-continue and infinite loop (一期保留项)');
}
if (arcade.CreditSystem && arcade.CreditSystem.max_players !== 4) errors.push('arcade ruleset must support 4 players');

// M1 combat frame table and route A expression-layer mapping must exist.
const combat = data['combat_m1.json'] || {};
const attackTable = combat.attack_table || {};
for (const a of ['Attack1', 'Attack2', 'Attack3', 'Special', 'Heavy', 'JumpAttack', 'GrabHit']) {
  if (!attackTable[a] || !attackTable[a].total_frames || !attackTable[a].active_frame) {
    errors.push('M1 attack table missing or incomplete: ' + a);
  }
}
if (!combat.grab || combat.grab.max_hits !== 5) errors.push('M1 grab must auto-throw on hit 5');
if (!combat.enemy_grunt) errors.push('M1 grunt AI config missing');
if ((data['packs/internal_reference/names_a.json'] || {}).pack !== 'internal_reference') {
  errors.push('route A faithful-name mapping missing');
}

const pending = Object.keys(data).filter(k => k.startsWith('stages/')).filter(k => data[k].verification === 'pending_frame_by_frame');

console.log('files=' + files.length + ' | stages=' + stageIds.size + ' | pending_frame_review=' + pending.length);
if (errors.length) {
  console.error('FAILED (' + errors.length + '):');
  errors.forEach(e => console.error('  - ' + e));
  process.exit(1);
}
console.log('OK: data valid, single-track route A (internal-only), arcade rules preserved.');
