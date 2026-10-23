#!/usr/bin/env node
// Renders the five built-in theme folders from the spec's scene code (docs/SPEC.html, THEMES object).
// Output is committed, so the app ships plain PNGs. No dependencies: a pixel-buffer canvas and a PNG encoder.
//
//   node tools/render-themes.mjs [--out Resources/Themes] [--preview path.png] [--check]
//   --check renders in memory and compares pixels with the folder, so CI passes whatever zlib Node ships with.
//
// Layers come from rendering each scene twice with two sentinel colours in the ink (or tint) slot:
// pixels that follow the sentinel are the ink/tint mask, everything else is fixed-colour art.
import { deflateSync, inflateSync } from 'node:zlib';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const args = process.argv.slice(2);
const arg = (name, fallback) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : fallback; };
const OUT = arg('--out', join(dirname(fileURLToPath(import.meta.url)), '..', 'Resources', 'Themes'));
const PREVIEW = arg('--preview', null);
const CHECK = args.includes('--check');
const mismatches = [];

// IHDR plus the inflated scanlines: what a PNG means, independent of how its encoder packed it.
function pngPayload(buf) {
  let i = 8, ihdr = Buffer.alloc(0);
  const idat = [];
  while (i < buf.length) {
    const len = buf.readUInt32BE(i), type = buf.toString('latin1', i + 4, i + 8), data = buf.subarray(i + 8, i + 8 + len);
    if (type === 'IHDR') ihdr = data; else if (type === 'IDAT') idat.push(data);
    i += 12 + len;
  }
  return Buffer.concat([ihdr, inflateSync(Buffer.concat(idat))]);
}

function emit(path, data) {
  if (!CHECK) { writeFileSync(path, data); return; }
  const buf = Buffer.from(data);
  const same = existsSync(path) && (path.endsWith('.png') ? pngPayload(readFileSync(path)).equals(pngPayload(buf)) : readFileSync(path).equals(buf));
  if (!same) mismatches.push(path);
}

// ---- Minimal canvas: only what the scene code uses (fillStyle, globalAlpha, fillRect). ----
function parseColor(c) {
  if (c.startsWith('#')) {
    const h = c.length === 4 ? [...c.slice(1)].map(x => x + x).join('') : c.slice(1);
    return [parseInt(h.slice(0, 2), 16) / 255, parseInt(h.slice(2, 4), 16) / 255, parseInt(h.slice(4, 6), 16) / 255, 1];
  }
  const m = c.match(/rgba?\(([^)]+)\)/);
  if (!m) throw new Error('colour ' + c);
  const p = m[1].split(',').map(s => parseFloat(s));
  return [p[0] / 255, p[1] / 255, p[2] / 255, p.length > 3 ? p[3] : 1];
}
class Canvas {
  constructor(w, h) { this.w = w; this.h = h; this.px = new Float64Array(w * h * 4); this.fillStyle = '#000'; this.globalAlpha = 1; }
  fillRect(x, y, w, h) {
    const [r, g, b, a0] = parseColor(this.fillStyle), a = a0 * this.globalAlpha;
    for (let j = Math.max(0, y); j < Math.min(this.h, y + h); j++) for (let i = Math.max(0, x); i < Math.min(this.w, x + w); i++) {
      const o = (j * this.w + i) * 4, da = this.px[o + 3], na = a + da * (1 - a);
      if (na <= 0) continue;
      for (let k = 0; k < 3; k++) this.px[o + k] = ([r, g, b][k] * a + this.px[o + k] * da * (1 - a)) / na;
      this.px[o + 3] = na;
    }
  }
  get(i, j) { const o = (j * this.w + i) * 4; return [this.px[o], this.px[o + 1], this.px[o + 2], this.px[o + 3]]; }
}

// ---- PNG encoder (RGBA8, no filtering). ----
const CRC = new Int32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c; });
const crc32 = buf => { let c = -1; for (const b of buf) c = CRC[(c ^ b) & 0xff] ^ (c >>> 8); return (c ^ -1) >>> 0; };
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
function png(w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let j = 0; j < h; j++) { raw[j * (w * 4 + 1)] = 0; rgba.copy(raw, j * (w * 4 + 1) + 1, j * w * 4, (j + 1) * w * 4); }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}
const toBuffer = layer => { const b = Buffer.alloc(layer.w * layer.h * 4); for (let i = 0; i < b.length; i++) b[i] = Math.round(Math.min(1, Math.max(0, layer.px[i])) * 255); return b; };
const emptyLayer = (w, h) => ({ w, h, px: new Float64Array(w * h * 4), used: false });

// The spec's page reads its CSS variables for two colours; the renderer supplies them.
let cssVars = { '--chomp': '#e9b800' };
const css = n => cssVars[n];

  const SP = {"GHOST":[".....####.....","...########...","..##########..",".##ww####ww##.",".#wwww##wwww#.",".#wwbb##wwbb#.","##wwbb##wwbb##","###ww####ww###","##############","##############","##############","##############","##.###..###.##","#...##..##...#"],"CHECK":["..............","..............","............##","...........###","..........###.",".........###..",".##.....###...",".###...###....","..###.###.....","...#####......","....###.......",".....#........","..............",".............."],"CRAB":["...#.....#...","....#...#....","...#######...","..##.###.##..",".###########.",".#.#######.#.",".#.#.....#.#.","....##.##...."],"CANNON":["......#......",".....###.....",".....###.....",".###########.","#############","#############","#############","#############"],"SQUID1":["...##...","..####..",".######.","##.##.##","########","..#..#..",".#.##.#.","#.#..#.#"],"SQUID2":["...##...","..####..",".######.","##.##.##","########",".#.##.#.","#......#",".#....#."],"GUN":["....#....","...###...",".#######.","#########","#########"],"KONG1":["....bbbbbb....","...bbbbbbbb...","..bbffbbffbb..","..bfwkffkwfb..","..bffffffffb..","...bfkkkkfb...",".bbbbffffbbbb.","bbbbbbbbbbbbbb","bbb.bbbbbb.bbb","bbb.bbbbbb.bbb","bb..bbbbbb..bb","....bb..bb....","...bbb..bbb...","..bbbb..bbbb.."],"KONG2":["bb..bbbbbb..bb","bbbbbbbbbbbbbb",".bbbffbbffbbb.","..bfwkffkwfb..","..bffffffffb..","...bfkkkkfb...","...bbffffbb...","..bbbbbbbbbb..","..bbbbbbbbbb..","..bbbbbbbbbb..","...bbbbbbbb...","....bb..bb....","...bbb..bbb...","..bbbb..bbbb.."],"BARREL1":[".oooo.","oddddo","oooooo","oooooo","oddddo",".oooo."],"BARREL2":[".oooo.","oooooo","oddddo","oddddo","oooooo",".oooo."],"FIRE":["......#......",".....##..#...","..#..###.##..","..##.######..",".###########.",".##yyyyyyy##.","##ywkyyywky##","##yyyyyyyyy##","##yyyyyyyyy##",".##yyyyyyy##.",".###yyyyy###.","..#########..","....#####...."],"HAMMER":[".##########.",".#dd####dd#.",".##########.",".....##.....",".....##.....",".....##.....",".....##.....",".....##.....",".....##.....","....####....","....####...."],"FIGHTER":[".r............",".rr...........","..wwww........","..wbbwww......",".wwwwwwwww....","wwwwwwwwwwwww.",".wwwwwwwww....","..wbbwww......","..wwww........",".rr...........",".r............"],"BEE":["...#.....#...","....#...#....",".##.yyyyy.##.","###yyyyyyy###","###bbyyybb###",".#.yybbbyy.#.","...yyyyyyy...","..##.yyy.##..",".##...y...##.",".#.........#."],"BEESM":[".#.....#.","..#yyy#..","##yyyyy##","##bbybb##",".#yyyyy#.",".#.y.y.#.","#.......#"],"FLAG":[".##..........",".####........",".######......",".########....",".##########..",".########....",".######......",".####........",".##..........",".##..........",".##..........",".##..........","####........."],"PAC0":["....#####....","..#########..",".###########.",".###########.","#############","#############","#############","#############","#############",".###########.",".###########.","..#########..","....#####...."],"PAC1":["....#####....","..#########..",".###########.",".###########.","###########..","#########....","#######......","#########....","###########..",".###########.",".###########.","..#########..","....#####...."],"PAC2":["....#####....","..#########..",".##########..",".########....","#######......","######.......","#####........","######.......","#######......",".########....",".##########..","..#########..","....#####...."]};
  const SCENE_W = 44, BOX = 14;
  const FIXED = { w: '#ffffff', b: '#2121de', k: '#14172e', y: '#ffd21f', f: '#f2b26b', o: '#c8641e', d: '#5c2d0c', r: '#e5484d' };
  const KONG_PAL = { b: '#8b4a1c', f: '#f2b26b', w: '#ffffff', k: '#2a1206' };
  const TETRO = { I: '#00c8e0', O: '#f0c800', T: '#a43ff0', S: '#20b850', Z: '#e5322d', J: '#2f5bf0', L: '#f08a00' };

  function sprite(ctx, rows, pal, x, y, px = 1) {
    x = Math.round(x); y = Math.round(y);
    rows.forEach((row, j) => [...row].forEach((ch, i) => {
      if (ch === '.') return;
      ctx.fillStyle = typeof pal === 'string' ? pal : (pal[ch] || pal['#']);
      ctx.fillRect(x + i * px, y + j * px, px, px);
    }));
  }
  function boxed(ctx, rows, pal, x, cy) {
    sprite(ctx, rows, pal, x + Math.floor((BOX - rows[0].length) / 2), cy - BOX / 2 + Math.floor((BOX - rows.length) / 2));
  }
  function block(ctx, x, y, s, color, mono) {
    x = Math.round(x); y = Math.round(y);
    ctx.fillStyle = color; ctx.fillRect(x, y, s, s);
    if (mono) return;
    ctx.fillStyle = 'rgba(255,255,255,.45)'; ctx.fillRect(x, y, s, 1); ctx.fillRect(x, y, 1, s);
    ctx.fillStyle = 'rgba(0,0,0,.25)'; ctx.fillRect(x, y + s - 1, s, 1); ctx.fillRect(x + s - 1, y, 1, s);
  }
  const tri = t => { const m = ((t % 2) + 2) % 2; return m < 1 ? m : 2 - m; };

  const THEMES = {
    chomp: {
      name: 'Chomp', after: 'Pac-Man', needName: 'ghost', doneName: 'check',
      scene(ctx, L, cy, f, ink, anim, mono) {
        const tick = anim ? Math.floor(f * 2) : 1, off = anim ? (tick % 4) * 2 : 0;
        ctx.fillStyle = ink;
        for (let i = 0; i < 4; i++) { const px = L + 17 + i * 8 - off; if (px > L + 9) ctx.fillRect(px, cy - 1, 2, 2); }
        sprite(ctx, [SP.PAC2, SP.PAC1, SP.PAC0, SP.PAC1][tick % 4], mono ? ink : css('--chomp'), L, cy - 6);
      },
      need(ctx, x, cy, t) { boxed(ctx, SP.GHOST, { '#': t, ...FIXED }, x, cy); },
      done(ctx, x, cy, t) { boxed(ctx, SP.CHECK, t, x, cy); },
      icon(ctx, x, cy) { boxed(ctx, SP.PAC1, css('--chomp'), x, cy); }
    },
    invaders: {
      name: 'Invaders', after: 'Space Invaders', needName: 'crab invader', doneName: 'laser cannon',
      scene(ctx, L, cy, f, ink, anim, mono) {
        const march = anim ? Math.round(tri(f / 2) * 8) : 4, frame = anim && Math.floor(f * 2) % 2 ? SP.SQUID2 : SP.SQUID1;
        for (let i = 0; i < 3; i++) sprite(ctx, frame, ink, L + 1 + march + i * 12, cy - 8);
        const gx = L + 2 + Math.round((anim ? tri(f / 3 + .4) : .5) * 32);
        sprite(ctx, SP.GUN, ink, gx, cy + 3);
        if (anim) { ctx.fillStyle = ink; ctx.fillRect(gx + 4, cy + 1 - Math.floor((f * 16) % 9), 1, 2); }
      },
      need(ctx, x, cy, t) { boxed(ctx, SP.CRAB, t, x, cy); },
      done(ctx, x, cy, t) { boxed(ctx, SP.CANNON, t, x, cy); },
      icon(ctx, x, cy, ink) { boxed(ctx, SP.SQUID1, ink, x, cy); }
    },
    kong: {
      name: 'Kong', after: 'Donkey Kong', needName: 'fireball', doneName: 'hammer',
      scene(ctx, L, cy, f, ink, anim, mono) {
        sprite(ctx, anim && Math.floor(f * 2) % 2 ? SP.KONG2 : SP.KONG1, mono ? ink : KONG_PAL, L, cy - 7);
        ctx.fillStyle = mono ? ink : '#e5484d'; ctx.fillRect(L + 15, cy + 5, SCENE_W - 15, 2);
        if (!mono) { ctx.fillStyle = '#ffb3b3'; for (let i = 0; i < 7; i++) ctx.fillRect(L + 16 + i * 4, cy + 5, 1, 1); }
        for (let b = 0; b < 2; b++) {
          const bx = L + 16 + ((anim ? f * 7 : 3) + b * 13) % 23;
          sprite(ctx, (Math.floor(f * 2) + b) % 2 ? SP.BARREL2 : SP.BARREL1, mono ? ink : FIXED, Math.round(bx), cy - 1);
        }
      },
      need(ctx, x, cy, t) { boxed(ctx, SP.FIRE, { '#': t, ...FIXED }, x, cy); },
      done(ctx, x, cy, t) { boxed(ctx, SP.HAMMER, { '#': t, d: 'rgba(0,0,0,.35)' }, x, cy); },
      icon(ctx, x, cy) { boxed(ctx, SP.KONG1, KONG_PAL, x, cy); }
    },
    galaxy: {
      name: 'Galaxy', after: 'Galaga', needName: 'bee', doneName: 'stage flag',
      scene(ctx, L, cy, f, ink, anim, mono) {
        const bob = anim ? Math.round(Math.sin(f * Math.PI) * .8) : 0;
        sprite(ctx, SP.FIGHTER, mono ? ink : { ...FIXED, w: ink, b: '#3d5afe' }, L, cy - 5 + bob);
        const by = cy - 3 + (anim ? Math.round(Math.sin(f * 1.4) * 3) : 0);
        sprite(ctx, SP.BEESM, mono ? ink : { '#': '#3d5afe', ...FIXED }, L + SCENE_W - 9, by);
        if (anim) { ctx.fillStyle = mono ? ink : '#f0a500'; for (let b = 0; b < 2; b++) ctx.fillRect(L + 15 + Math.floor((f * 10 + b * 10) % 18), cy + bob, 3, 1); }
      },
      need(ctx, x, cy, t) { boxed(ctx, SP.BEE, { '#': t, ...FIXED }, x, cy); },
      done(ctx, x, cy, t) { boxed(ctx, SP.FLAG, t, x, cy); },
      icon(ctx, x, cy, ink) { boxed(ctx, SP.FIGHTER, { ...FIXED, w: ink, b: '#3d5afe' }, x, cy); }
    },
    blocks: {
      name: 'Blocks', after: 'Tetris', needName: 'T-piece', doneName: 'full block',
      scene(ctx, L, cy, f, ink, anim, mono) {
        const C = 4, top = cy - 8, col = k => mono ? ink : TETRO[k];
        const t = anim ? Math.floor(f * 2) % 7 : 3;
        const stack3 = 'LLJJOO...SSI'.slice(0, 11), stack2 = 'ZZ.......TT';
        [...stack2].forEach((k, i) => { if (k !== '.') block(ctx, L + i * C, top + 2 * C, C - 1 + 0, col(k), mono); });
        if (t < 5) [...stack3].forEach((k, i) => { if (k !== '.') block(ctx, L + i * C, top + 3 * C, C, col(k), mono); });
        const r = Math.min(t, 3);
        if (t <= 3) [[6, r], [7, r], [8, r], [7, r - 1]].forEach(([c, rr]) => rr >= 0 && block(ctx, L + c * C, top + rr * C, C, col('T'), mono));
        if (t === 4) { ctx.fillStyle = mono ? ink : '#ffffff'; ctx.fillRect(L, top + 3 * C, 11 * C, C); }
      },
      need(ctx, x, cy, t) { [[0, 0], [1, 0], [2, 0], [1, 1]].forEach(([c, r]) => block(ctx, x + c * 5 - 0, cy - 4 + r * 5, 4, t)); },
      done(ctx, x, cy, t) { for (let c = 0; c < 3; c++) for (let r = 0; r < 3; r++) block(ctx, x + c * 5 - 0, cy - 7 + r * 5, 4, t); },
      icon(ctx, x, cy) { [[0, 0], [1, 0], [2, 0], [1, 1]].forEach(([c, r]) => block(ctx, x + c * 5, cy - 4 + r * 5, 4, TETRO.T)); }
    }
  };

// ---- Layer separation. ----
const S1 = '#010203', S2 = '#fdfeff';
const [s1, s2] = [parseColor(S1), parseColor(S2)];
/** Splits a render into (mask alpha, fixed art) given the same drawing done with S1 and S2 in the slot. */
function separate(c1, c2) {
  const w = c1.w, h = c1.h, mask = emptyLayer(w, h), art = emptyLayer(w, h);
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
    const p1 = c1.get(i, j), p2 = c2.get(i, j), o = (j * w + i) * 4;
    if (p1[3] <= 0.002) continue;
    let k = 0;
    for (let ch = 0; ch < 3; ch++) k += (p1[ch] - p2[ch]) / (s1[ch] - s2[ch]);
    k = Math.min(1, Math.max(0, k / 3));
    if (k <= 0.01) { art.px.set(p1, o); art.used = true; continue; }
    mask.px.set([1, 1, 1, p1[3]], o); mask.used = true;
    if (k < 0.99) {
      const a = 1 - k, c = [0, 1, 2].map(ch => Math.min(1, Math.max(0, (p1[ch] - s1[ch] * (1 - a)) / a)));
      art.px.set([...c, a], o); art.used = true;
    }
  }
  return { mask, art };
}
function renderPair(w, h, draw) {
  const a = new Canvas(w, h), b = new Canvas(w, h);
  draw(a, S1); draw(b, S2);
  return separate(a, b);
}
const sameLayer = (a, b) => a.px.every((v, i) => Math.abs(v - b.px[i]) < 1 / 255);

const FRAMES = { chomp: 4, invaders: 24, kong: 23, galaxy: 32, blocks: 7 };
const IDLE_FRAME = { chomp: 1, invaders: 0, kong: 0, galaxy: 0, blocks: 3 };
const W = SCENE_W, H = 16;

function renderTheme(id) {
  const th = THEMES[id], n = FRAMES[id];
  const scene = emptyLayer(W * n, H), ink = emptyLayer(W * n, H), dark = emptyLayer(W * n, H);
  for (let frame = 0; frame < n; frame++) {
    const f = frame / 2;
    cssVars = { '--chomp': '#e9b800' };
    const light = renderPair(W, H, (ctx, inkColor) => th.scene(ctx, 0, 8, f, inkColor, true, false));
    cssVars = { '--chomp': '#ffd21f' };
    const darkPair = renderPair(W, H, (ctx, inkColor) => th.scene(ctx, 0, 8, f, inkColor, true, false));
    for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) {
      const src = (j * W + i) * 4, dst = (j * W * n + frame * W + i) * 4;
      scene.px.set(light.art.px.subarray(src, src + 4), dst);
      ink.px.set(light.mask.px.subarray(src, src + 4), dst);
      dark.px.set(darkPair.art.px.subarray(src, src + 4), dst);
    }
    ink.used ||= light.mask.used;
  }
  const need = renderPair(BOX, BOX, (ctx, t) => th.need(ctx, 0, BOX / 2, t));
  const done = renderPair(BOX, BOX, (ctx, t) => th.done(ctx, 0, BOX / 2, t));
  cssVars = { '--chomp': '#e9b800' };
  const icon = renderPair(BOX, BOX, (ctx, inkColor) => th.icon(ctx, 0, BOX / 2, inkColor));
  if (!need.mask.used || !done.mask.used) throw new Error(id + ': need/done must use the tint slot');

  const dir = join(OUT, id);
  mkdirSync(dir, { recursive: true });
  const write = (name, layer) => emit(join(dir, name), png(layer.w, layer.h, toBuffer(layer)));
  emit(join(dir, 'theme.json'), JSON.stringify({ schema: 1, id, name: th.name, after: th.after, fps: 8, idleFrame: IDLE_FRAME[id] }, null, 2) + '\n');
  write('scene.png', scene);
  if (ink.used) write('scene-ink.png', ink);
  if (!sameLayer(scene, dark)) write('scene-dark.png', dark);
  write('need.png', need.mask);
  if (need.art.used) write('need-detail.png', need.art);
  write('done.png', done.mask);
  if (done.art.used) write('done-detail.png', done.art);
  write('icon.png', icon.art);
  if (icon.mask.used) write('icon-ink.png', icon.mask);
  console.log(`${id}: ${n} frames${ink.used ? ' + ink' : ''}${sameLayer(scene, dark) ? '' : ' + dark'}, need${need.art.used ? '+detail' : ''}, done${done.art.used ? '+detail' : ''}, icon${icon.mask.used ? '+ink' : ''}`);
}

for (const id of Object.keys(THEMES)) renderTheme(id);
if (CHECK) {
  if (mismatches.length) { console.error('themes differ from the spec:\n  ' + mismatches.join('\n  ')); process.exit(1); }
  console.log('themes match the spec');
}

// ---- Optional preview sheet: every theme's working frame 0, still frame, need, done and icon on a dark bar at 4x. ----
if (PREVIEW) {
  const K = 4, rowH = 20 * K, sheet = new Canvas(140 * K, rowH * 5 * 2);
  sheet.fillStyle = '#1e2034'; sheet.fillRect(0, 0, sheet.w, sheet.h);
  const blit = (ctx, draw, x, y) => { const c = new Canvas(44, 16); draw(c); for (let j = 0; j < 16; j++) for (let i = 0; i < 44; i++) { const p = c.get(i, j); if (p[3] > 0.002) { ctx.fillStyle = `rgba(${p[0] * 255},${p[1] * 255},${p[2] * 255},${p[3]})`; ctx.fillRect(x + i * K, y + j * K, K, K); } } };
  Object.keys(THEMES).forEach((id, r) => {
    const th = THEMES[id], y = r * rowH * 2 + 2 * K;
    cssVars = { '--chomp': '#ffd21f' };
    blit(sheet, c => th.scene(c, 0, 8, 0, '#eef0fb', true, false), 2 * K, y);
    blit(sheet, c => th.scene(c, 0, 8, IDLE_FRAME[id] / 2, '#eef0fb', true, false), 50 * K, y);
    blit(sheet, c => th.need(c, 0, 8, '#ff9a3d'), 98 * K, y);
    blit(sheet, c => th.done(c, 0, 8, '#3fd184'), 112 * K, y);
    blit(sheet, c => th.icon(c, 0, 8, '#eef0fb'), 126 * K, y);
    blit(sheet, c => { c.globalAlpha = .5; th.scene(c, 0, 8, IDLE_FRAME[id] / 2, '#eef0fb', false, true); }, 2 * K, y + rowH);
    blit(sheet, c => th.need(c, 0, 8, '#ff4a3d'), 98 * K, y + rowH);
  });
  writeFileSync(PREVIEW, png(sheet.w, sheet.h, toBuffer(sheet)));
  console.log('preview →', PREVIEW);
}
