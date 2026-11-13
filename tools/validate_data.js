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

// M2 combat frame tables: five-character moves, ultimate, landing ultimate,
// wall jump, air throw, back throw, downed chase, and judgment-polish params.
const m2 = data['combat_m2.json'] || {};
const cm2 = m2.character_moves || {};
const heroIds = (chars.characters || []).map(c => c.id);
for (const hid of heroIds) {
  const cm = cm2[hid];
  if (!cm) { errors.push('M2 missing character move table: ' + hid); continue; }
  const at = cm.attack_table || {};
  for (const a of ['Attack1', 'Attack2', 'Attack3', 'Special', 'Heavy', 'JumpAttack', 'GrabHit']) {
    if (!at[a] || !at[a].total_frames || !at[a].active_frame) {
      errors.push('M2 attack table missing or incomplete: ' + hid + '.' + a);
    }
  }
  if (!cm.special || !cm.ultimate) errors.push('M2 missing special/ultimate for ' + hid);
  if (!cm.down_attack_max) errors.push('M2 missing down_attack_max for ' + hid);
}
if (heroIds.length === 5 && Object.keys(cm2).length !== 5) errors.push('M2 must define exactly 5 character move tables');
for (const k of ['ultimate', 'landing_ultimate', 'wall_jump', 'air_throw', 'back_throw', 'downed_chase', 'grab']) {
  if (!m2[k]) errors.push('M2 missing section: ' + k);
}
if (m2.ultimate && (m2.ultimate.hp_cost_percent !== 8 || m2.ultimate.min_hp_percent !== 15)) {
  errors.push('M2 ultimate must cost 8% HP and be disabled below 15% HP');
}
if (m2.landing_ultimate && m2.landing_ultimate.window_frames !== 6) {
  errors.push('M2 landing ultimate window must be 6 frames');
}
if (m2.downed_chase && (m2.downed_chase.default_max < 3 || m2.downed_chase.default_max > 4)) {
  errors.push('M2 downed chase default max must be 3-4');
}
if (m2.downed_chase && m2.downed_chase.pockets_max !== 8) {
  errors.push('M2 downed chase POCKETS max must be 8');
}
for (const k of ['hitbox', 'hitstop', 'vfx', 'friendly_fire', 'block']) {
  if (!m2[k]) errors.push('M2 missing judgment section: ' + k);
}
if (m2.hitstop && (m2.hitstop.light_frames !== 4 || m2.hitstop.heavy_frames !== 7 || m2.hitstop.ultimate_frames !== 10)) {
  errors.push('M2 hitstop tiers must be light=4 heavy=7 ultimate=10');
}

// M2 enemy AI config: every template must carry an ai block with core fields.
const m2Enemies = enemies.templates || [];
for (const t of m2Enemies) {
  if (!t.ai) { errors.push('M2 enemy template missing ai config: ' + t.id); continue; }
  const ai = t.ai;
  for (const f of ['speed_mps', 'attack_range_m', 'windup_frames', 'attack_frames', 'recover_frames', 'damage', 'knockback_m']) {
    if (ai[f] === undefined) errors.push('M2 enemy ' + t.id + ' ai missing field: ' + f);
  }
  if (!ai.behavior) errors.push('M2 enemy ' + t.id + ' ai missing behavior');
}

const pending = Object.keys(data).filter(k => k.startsWith('stages/')).filter(k => data[k].verification === 'pending_frame_by_frame');

console.log('files=' + files.length + ' | stages=' + stageIds.size + ' | pending_frame_review=' + pending.length);
if (errors.length) {
  console.error('FAILED (' + errors.length + '):');
  errors.forEach(e => console.error('  - ' + e));
  process.exit(1);
}
console.log('OK: data valid, single-track route A (internal-only), arcade rules preserved.');
