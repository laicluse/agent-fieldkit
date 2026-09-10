#!/usr/bin/env node
// ink-assert: gating tool for visual-equivalence iteration. Compares a candidate PNG against a reference PNG
// across multiple structural axes and exits 0 only if ALL of them pass the configured tolerances.
//
// Axes:
//   frame.w/h            bbox of (FRAME ∪ INK ∪ EDGE)
//   ink.w/h              bbox of INK class
//   pad.top/right/bot/left  distance from frame bbox to ink bbox
//   corner.TL/TR/BL/BR   diagonal inset from corner to first FRAME/INK pixel (catches NEAREST point of curve)
//   edgeExt.TL/TR/BL/BR  edge-walk inset along top/bottom row from corner (catches CURVE EXTENT, including AA halo
//                        that pushes "where the curve ends" further inward; CRUCIAL because diagInset alone may
//                        miss soft-edged-vs-crisp-edged corner-radius differences with the same nearest-point)
//   halo.TL/TR/BL/BR     count of EDGE-class pixels in 5x5 corner block (catches AA softness)
//   hist.INK/FRAME/EDGE/BG  class-share % within frame area
//   ms.WxH.meanRGB       mean RGB at each halved-resolution scale down to 1x1; the 1x1 is the strict overall-color test
//   pixel diff           per-channel max diff > threshold over scaled-aligned frame
//
// Acceptance: OVERALL PASS only when every axis passes its tolerance. Cross-pipeline floors (CSS-text vs
// canvas-text rendering) live in the pixel-diff axis; raise --max-diff to the documented floor for that pipeline
// pair, NOT to make the result PASS-by-budget. The structural axes must always pass.
//
// IMPORTANT: capture both reference and candidate against the SAME background. A pill on a sidebar bg compared
// with a favicon on white will diverge at edge AA because corner pixels bleed the surrounding bg. Inject the
// reference into the candidate's parent context (or vice versa) before screenshotting.

import fs from 'fs'
import os from 'os'
import path from 'path'
import { execSync } from 'child_process'

// Per-invocation scratch directory. Two simultaneous ink-assert processes with the same OS pid would otherwise
// collide on /tmp/ink-${pid}-* paths, which becomes a real risk if a caller wraps run-corpus.mjs in Promise.all.
// mkdtempSync gives each process a unique directory; the closeScratch() handler runs at exit to avoid leaks.
const SCRATCH = fs.mkdtempSync(path.join(os.tmpdir(), 'ink-assert-'))
function scratch(name) { return path.join(SCRATCH, name) }
process.on('exit', () => { try { fs.rmSync(SCRATCH, { recursive: true, force: true }) } catch (_) {} })

function parseArgs(argv) { const o = {}; for (let i = 0; i < argv.length; i++) { const a = argv[i]; if (!a.startsWith('--')) continue; const k = a.slice(2), n = argv[i+1]; if (n === undefined || n.startsWith('--')) o[k] = true; else { o[k] = n; i++ } } return o }
let _readSeq = 0
function readImage(p) { const m = execSync(`ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "${p}"`).toString().trim().split(','); const tmp = scratch(`r${++_readSeq}.raw`); execSync(`ffmpeg -y -v error -i "${p}" -f rawvideo -pix_fmt rgb24 "${tmp}"`); const px = fs.readFileSync(tmp); fs.unlinkSync(tmp); return { w: parseInt(m[0]), h: parseInt(m[1]), px } }
function rgb(img, x, y) { const i = (y*img.w+x)*3; return [img.px[i], img.px[i+1], img.px[i+2]] }
function dist(a, b) { return Math.sqrt((a[0]-b[0])**2 + (a[1]-b[1])**2 + (a[2]-b[2])**2) }
// Tie-break order on equal distances: INK > FRAME > BG. Documented because Math.min would otherwise
// resolve ties by argument order silently and a 1-unit shift in tolerance could flip a pixel's class.
function classify(c, anchors, tol) {
  const dI = dist(c, anchors.ink), dF = dist(c, anchors.frame), dB = dist(c, anchors.bg)
  const m = Math.min(dI, dF, dB)
  if (m > tol) return 'EDGE'
  if (dI === m) return 'INK'
  if (dF === m) return 'FRAME'
  return 'BG'
}
function bbox(img, anchors, tol, pred) { let mnx = img.w, mny = img.h, mxx = -1, mxy = -1; for (let y = 0; y < img.h; y++) for (let x = 0; x < img.w; x++) { const c = rgb(img, x, y), k = classify(c, anchors, tol); if (pred(k, c)) { if (x < mnx) mnx = x; if (x > mxx) mxx = x; if (y < mny) mny = y; if (y > mxy) mxy = y } } return mxx < 0 ? null : { mnx, mny, mxx, mxy, w: mxx-mnx+1, h: mxy-mny+1 } }
// cornerWalk: walks inward from corner `c` along an axis ('row' = horizontal along bbox top/bottom,
// 'diag' = diagonal toward bbox center), stopping at the first FRAME or INK pixel. With predicate=null,
// returns the inward step at which FRAME/INK was found (the inset distance). With a predicate, counts
// every non-FRAME pixel that matches the predicate during the walk and returns that count. This single
// function backs five legacy variants (diagInset / edgeExtent / bgExtent / aaExtent / bgDiag / aaDiag).
function cornerWalk(img, anchors, tol, fr, c, mode, predicate) {
  const sx = c === 'TL' || c === 'BL' ? fr.mnx : fr.mxx
  const sy = c === 'TL' || c === 'TR' ? fr.mny : fr.mxy
  const dx = c === 'TL' || c === 'BL' ? +1 : -1
  const dy = mode === 'row' ? 0 : (c === 'TL' || c === 'TR' ? +1 : -1)
  let count = 0
  for (let i = 0; i < 30; i++) {
    const x = sx + dx * i, y = sy + dy * i
    if (x < 0 || y < 0 || x >= img.w || y >= img.h) return predicate === null ? -1 : count
    const k = classify(rgb(img, x, y), anchors, tol)
    if (k === 'FRAME' || k === 'INK') return predicate === null ? i : count
    if (predicate !== null && predicate(k)) count++
  }
  return predicate === null ? -1 : count
}
function diagInset(img, anchors, tol, fr, c) { return cornerWalk(img, anchors, tol, fr, c, 'diag', null) }
function edgeExtent(img, anchors, tol, fr, c) { return cornerWalk(img, anchors, tol, fr, c, 'row', () => true) }
function bgExtent(img, anchors, tol, fr, c) { return cornerWalk(img, anchors, tol, fr, c, 'row', (k) => k === 'BG') }
function aaExtent(img, anchors, tol, fr, c) { return cornerWalk(img, anchors, tol, fr, c, 'row', (k) => k === 'EDGE') }
function bgDiag(img, anchors, tol, fr, c) { return cornerWalk(img, anchors, tol, fr, c, 'diag', (k) => k === 'BG') }
function aaDiag(img, anchors, tol, fr, c) { return cornerWalk(img, anchors, tol, fr, c, 'diag', (k) => k === 'EDGE') }
function cornerHaloCount(img, anchors, tol, fr, c) { const x0 = c==='TL'||c==='BL'?fr.mnx:fr.mxx-4; const y0 = c==='TL'||c==='TR'?fr.mny:fr.mxy-4; let n = 0; for (let dy = 0; dy < 5; dy++) for (let dx = 0; dx < 5; dx++) { const x = x0+dx, y = y0+dy; if (x<0||y<0||x>=img.w||y>=img.h) continue; if (classify(rgb(img, x, y), anchors, tol) === 'EDGE') n++ } return n }
function classCounts(img, anchors, tol, fr) { const c = { INK:0,FRAME:0,EDGE:0,BG:0 }; for (let y = fr.mny; y <= fr.mxy; y++) for (let x = fr.mnx; x <= fr.mxx; x++) c[classify(rgb(img, x, y), anchors, tol)]++; return c }
function multiScale(p, fr, anchors, tol) { const cropPath = `${SCRATCH}/mscrop.png`; execSync(`ffmpeg -y -v error -i "${p}" -vf "crop=${fr.w}:${fr.h}:${fr.mnx}:${fr.mny}" "${cropPath}"`); const scales = []; let cw = fr.w, ch = fr.h, cp = cropPath, step = 0; while (cw>=1&&ch>=1) { const img = readImage(cp); let sR=0,sG=0,sB=0; const counts = {INK:0,FRAME:0,EDGE:0,BG:0}; for (let y=0;y<img.h;y++) for (let x=0;x<img.w;x++) { const c = rgb(img,x,y); sR+=c[0]; sG+=c[1]; sB+=c[2]; counts[classify(c, anchors, tol)]++ } const t = img.w*img.h; scales.push({step,w:img.w,h:img.h,mean:{r:round(sR/t,1),g:round(sG/t,1),b:round(sB/t,1)},counts,pct:{INK:100*counts.INK/t,FRAME:100*counts.FRAME/t,EDGE:100*counts.EDGE/t,BG:100*counts.BG/t}}); if (cw===1&&ch===1) break; const nw = Math.max(1,Math.round(cw/2)), nh = Math.max(1,Math.round(ch/2)); if (nw===cw&&nh===ch) break; const np = `${SCRATCH}/ms${step+1}.png`; execSync(`ffmpeg -y -v error -i "${cp}" -vf "scale=${nw}:${nh}:flags=area" "${np}"`); if (step>0) try { fs.unlinkSync(cp) } catch (_) {}; cw = nw; ch = nh; cp = np; step++ } try { fs.unlinkSync(cp) } catch (_) {}; try { fs.unlinkSync(cropPath) } catch (_) {}; return scales }
function pixelDiff(refImg, candImg, threshold) { const rB = bbox(refImg, refImg.anchors, 60, k => k==='FRAME'||k==='INK'||k==='EDGE'); const cB = bbox(candImg, candImg.anchors, 60, k => k==='FRAME'||k==='INK'||k==='EDGE'); if (!rB||!cB) return { error: 'frame not found' }; const rC = `${SCRATCH}/r.png`, cC = `${SCRATCH}/c.png`; execSync(`ffmpeg -y -v error -i "${refImg.path}" -vf "crop=${rB.w}:${rB.h}:${rB.mnx}:${rB.mny}" "${rC}"`); execSync(`ffmpeg -y -v error -i "${candImg.path}" -vf "crop=${cB.w}:${cB.h}:${cB.mnx}:${cB.mny},scale=${rB.w}:${rB.h}:flags=bicubic" "${cC}"`); const r = readImage(rC), c = readImage(cC); let total = 0, diff = 0; for (let y=0;y<r.h;y++) for (let x=0;x<r.w;x++) { const i = (y*r.w+x)*3; const d = Math.max(Math.abs(r.px[i]-c.px[i]), Math.abs(r.px[i+1]-c.px[i+1]), Math.abs(r.px[i+2]-c.px[i+2])); total++; if (d > threshold) diff++ } fs.unlinkSync(rC); fs.unlinkSync(cC); return { total, diff, percent: 100*diff/total } }
// autoBg averages the four bbox corners. When those four pixels disagree, the image has a non-uniform
// background (gradient, transparency leak, neighbouring UI bleeding into the crop) and the auto-detected
// anchor will silently misclassify pixels. AUTO_BG_SPREAD_THRESHOLD is the max acceptable per-channel
// range across the four corners; values above it warn to stderr. The threshold is set just below the
// classify() tolerance default (60) to catch cases where the bg uncertainty would already affect class
// boundaries; tighter would chatter on benign jpeg-style noise, looser would silently pass real bleed.
const AUTO_BG_SPREAD_THRESHOLD = 30
function autoBg(img) {
  const c = [rgb(img,0,0), rgb(img,img.w-1,0), rgb(img,0,img.h-1), rgb(img,img.w-1,img.h-1)]
  const mn = c[0].map((_, i) => Math.min(...c.map((p) => p[i])))
  const mx = c[0].map((_, i) => Math.max(...c.map((p) => p[i])))
  const spread = Math.max(mx[0]-mn[0], mx[1]-mn[1], mx[2]-mn[2])
  if (spread > AUTO_BG_SPREAD_THRESHOLD) {
    console.error(`ink-assert: warning: autoBg corner spread is ${spread} RGB units (>${AUTO_BG_SPREAD_THRESHOLD}). Background is non-uniform; pass --bg R,G,B explicitly to avoid silent misclassification. Sample the bg colour from a known-empty pixel of the reference image (image viewer's eyedropper, or run \`magick reference.png -resize 1x1 txt:\` for a single-pixel average). Corners:`, c.map((p) => `(${p.join(',')})`).join(' '))
  }
  return c.reduce((a,x) => [a[0]+x[0],a[1]+x[1],a[2]+x[2]], [0,0,0]).map(s => Math.round(s/4))
}
function parseRGB(s) { if (!s) return null; const a = s.split(',').map(Number); return a.length===3&&a.every(Number.isFinite)?a:null }
function analyze(p, anchors) { const img = readImage(p); img.path = p; img.anchors = anchors; const tol = 60; const fr = bbox(img, anchors, tol, k => k==='FRAME'||k==='INK'||k==='EDGE'); const ink = bbox(img, anchors, tol, k => k==='INK'); if (!fr||!ink) return { error: 'frame or ink not found' }; const corners = { TL: diagInset(img,anchors,tol,fr,'TL'), TR: diagInset(img,anchors,tol,fr,'TR'), BL: diagInset(img,anchors,tol,fr,'BL'), BR: diagInset(img,anchors,tol,fr,'BR') }; const cornerSplit = (fn) => ({ TL: fn(img,anchors,tol,fr,'TL'), TR: fn(img,anchors,tol,fr,'TR'), BL: fn(img,anchors,tol,fr,'BL'), BR: fn(img,anchors,tol,fr,'BR') }); return { img, frame: fr, ink, padding: { top: ink.mny-fr.mny, right: fr.mxx-ink.mxx, bottom: fr.mxy-ink.mxy, left: ink.mnx-fr.mnx }, corners, bgDiag: cornerSplit(bgDiag), aaDiag: cornerSplit(aaDiag), edgeExt: cornerSplit(edgeExtent), bgExt: cornerSplit(bgExtent), aaExt: cornerSplit(aaExtent), halo: { TL: cornerHaloCount(img,anchors,tol,fr,'TL'), TR: cornerHaloCount(img,anchors,tol,fr,'TR'), BL: cornerHaloCount(img,anchors,tol,fr,'BL'), BR: cornerHaloCount(img,anchors,tol,fr,'BR') }, classCounts: classCounts(img, anchors, tol, fr), multiScale: multiScale(p, fr, anchors, tol) } }
function round(n, d) { const f = Math.pow(10, d); return Math.round(n*f)/f }
function main() {
  const a = parseArgs(process.argv.slice(2))
  if (!a.reference || !a.candidate) { console.error('Usage: ink-assert --reference REF --candidate CAND [--ink R,G,B] [--frame R,G,B] [--bg R,G,B] [--max-diff PCT] [--frame-px N] [--ink-px N] [--pad-px N] [--corner-px N] [--hist-pct N] [--diff-threshold N] [--json]'); process.exit(2) }
  const ink = parseRGB(a.ink) || [251, 146, 60]
  const frame = parseRGB(a.frame) || [10, 10, 12]
  const refRaw = readImage(a.reference); refRaw.path = a.reference
  const bg = parseRGB(a.bg) || autoBg(refRaw)
  const ref = analyze(a.reference, { ink, frame, bg })
  const candBg = parseRGB(a.bg) || autoBg(readImage(a.candidate))
  const cand = analyze(a.candidate, { ink, frame, bg: candBg })
  if (ref.error || cand.error) { console.error(ref.error||cand.error); process.exit(2) }
  const fpx = parseFloat(a['frame-px']) || 1, ipx = parseFloat(a['ink-px']) || 1, ppx = parseFloat(a['pad-px']) || 1, cpx = parseFloat(a['corner-px']) || 1
  const dthr = parseFloat(a['diff-threshold']) || 24, maxDiff = parseFloat(a['max-diff']) || 2.0, histPct = parseFloat(a['hist-pct']) || 5
  const pR = pixelDiff(ref.img, cand.img, dthr)
  const checks = []
  function check(n, r, c, t) { const d = c-r; checks.push({ name: n, ref: r, cand: c, delta: d, tol: t, pass: Math.abs(d) <= t }) }
  check('frame.w', ref.frame.w, cand.frame.w, fpx); check('frame.h', ref.frame.h, cand.frame.h, fpx)
  check('ink.w', ref.ink.w, cand.ink.w, ipx); check('ink.h', ref.ink.h, cand.ink.h, ipx)
  check('pad.top', ref.padding.top, cand.padding.top, ppx); check('pad.right', ref.padding.right, cand.padding.right, ppx)
  check('pad.bottom', ref.padding.bottom, cand.padding.bottom, ppx); check('pad.left', ref.padding.left, cand.padding.left, ppx)
  for (const c of ['TL','TR','BL','BR']) check(`corner.${c}`, ref.corners[c], cand.corners[c], cpx)
  for (const c of ['TL','TR','BL','BR']) check(`bgDiag.${c}`, ref.bgDiag[c], cand.bgDiag[c], cpx)
  for (const c of ['TL','TR','BL','BR']) check(`aaDiag.${c}`, ref.aaDiag[c], cand.aaDiag[c], cpx)
  // edgeExt is the sum of bgExt and aaExt; gating both the components and their sum double-penalises the
  // same geometry. We emit edgeExt as informational only (no check call) so the per-axis report still shows
  // the legacy aggregate for callers that consult the JSON output.
  for (const c of ['TL','TR','BL','BR']) check(`bgExt.${c}`, ref.bgExt[c], cand.bgExt[c], cpx)
  for (const c of ['TL','TR','BL','BR']) check(`aaExt.${c}`, ref.aaExt[c], cand.aaExt[c], cpx)
  for (const c of ['TL','TR','BL','BR']) check(`halo.${c}`, ref.halo[c], cand.halo[c], 2)
  function pct(c, t) { return t>0?round(100*c/t,2):0 }
  const rT = ref.classCounts.INK+ref.classCounts.FRAME+ref.classCounts.EDGE+ref.classCounts.BG
  const cT = cand.classCounts.INK+cand.classCounts.FRAME+cand.classCounts.EDGE+cand.classCounts.BG
  for (const k of ['INK','FRAME','EDGE','BG']) { const r = pct(ref.classCounts[k], rT), c = pct(cand.classCounts[k], cT), d = round(c-r, 2); checks.push({ name: `hist.${k}`, ref: r, cand: c, delta: d, tol: histPct, pass: Math.abs(d) <= histPct }) }
  const ms = Math.min(ref.multiScale.length, cand.multiScale.length)
  const tolFor = (w, h) => (w*h===1?8:(w*h<=4?12:(w*h<=16?20:30)))
  for (let i = 0; i < ms; i++) {
    const r = ref.multiScale[i], c = cand.multiScale[i], tol = tolFor(r.w, r.h)
    const dR = round(c.mean.r-r.mean.r,1), dG = round(c.mean.g-r.mean.g,1), dB = round(c.mean.b-r.mean.b,1)
    const maxD = Math.max(Math.abs(dR), Math.abs(dG), Math.abs(dB))
    checks.push({ name: `ms.${r.w}x${r.h}.meanRGB`, ref: `(${r.mean.r},${r.mean.g},${r.mean.b})`, cand: `(${c.mean.r},${c.mean.g},${c.mean.b})`, delta: `(${dR},${dG},${dB})`, tol, pass: maxD <= tol })
  }
  const pixelPass = !pR.error && pR.percent <= maxDiff
  const overall = checks.every(c => c.pass) && pixelPass
  // Confidence score 0..100 derived from axis pass-rate and pixel diff. Structural axes weigh more than multiscale axes.
  // Pixel diff contributes a noise-floor subtraction that recognises cross-pipeline irreducibility (capped at 30 since
  // CSS-text vs canvas-text floor is around 15-20%).
  function confidenceScore() {
    // Weight per axis type. Critical structural axes weigh most; multiscale informational axes weigh least.
    const weights = {
      frame: 4, ink: 3, pad: 3, corner: 2, bgDiag: 2, aaDiag: 2,
      edgeExt: 1, bgExt: 2, aaExt: 2, halo: 1, hist: 1, ms: 0.5,
    }
    function weightFor(name) {
      const family = name.split('.')[0].replace(/^ms$/, 'ms')
      return weights[family] !== undefined ? weights[family] : 1
    }
    let score = 100
    for (const c of checks) {
      if (c.pass) continue
      const w = weightFor(c.name)
      const tol = typeof c.tol === 'number' ? c.tol : 1
      const deltaSize = typeof c.delta === 'number' ? Math.abs(c.delta) : tol + 1
      const overshoot = Math.min(1.5, deltaSize / Math.max(1, tol))
      score -= w * overshoot
    }
    // Pixel diff contributes a noise-floor subtraction. Cross-pipeline floor (~15-20%) is recognised by capping at 25.
    if (!pR.error) score -= Math.min(25, pR.percent * 0.6)
    return Math.max(0, Math.round(score))
  }
  const confidence = confidenceScore()
  if (a.confidence) {
    if (a.json) console.log(JSON.stringify({ confidence, overall, pixel: pR.error ? null : { percent: round(pR.percent, 3) } }))
    else console.log(`confidence: ${confidence}`)
    process.exit(confidence >= 95 ? 0 : 1)
  }
  if (a.json) console.log(JSON.stringify({ checks, pixel: pR.error?{error:pR.error}:{percent:round(pR.percent,3),pass:pixelPass,threshold:maxDiff}, overall }, null, 2))
  else {
    console.log(`reference   ${path.basename(a.reference)}`)
    console.log(`candidate   ${path.basename(a.candidate)}\n`)
    console.log('AXIS                  | REF             | CAND            | Δ               | TOL  | RESULT')
    for (const c of checks) console.log(`${c.name.padEnd(20)} | ${String(c.ref).padStart(15)} | ${String(c.cand).padStart(15)} | ${String(c.delta).padStart(15)} | ±${String(c.tol).padEnd(3)} | ${c.pass?'PASS':'FAIL'}`)
    if (pR.error) console.log(`pixel diff       | ERROR: ${pR.error}`)
    else console.log(`pixel diff           | ${round(pR.percent,2)}% differing | ≤${maxDiff}% | ${pixelPass?'PASS':'FAIL'}`)
    console.log(`\nconfidence: ${confidence}`)
    console.log(`OVERALL: ${overall?'PASS ✓':'FAIL ✗'}`)
  }
  process.exit(overall ? 0 : 1)
}
main()
