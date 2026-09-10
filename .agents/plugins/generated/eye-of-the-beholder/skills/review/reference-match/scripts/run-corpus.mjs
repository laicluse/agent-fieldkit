#!/usr/bin/env node
// run-corpus: validates ink-assert against the cases/ corpus.
//
// For every case directory (cases/*/), runs ink-assert against reference.png and candidate.png
// and compares the OVERALL PASS/FAIL verdict to the case's verdict.txt.
//
// Outputs:
//   - per-case line: name, expected verdict, tool verdict, classification (truePass / trueFail / falsePass / falseFail / borderline)
//   - confusion matrix at the end: truePass=N, trueFail=M, falsePass=K, falseFail=L, borderline=B
//   - exits 0 only when falsePass=0 AND falseFail=0 (no misclassifications)
//
// Borderline cases are reported but do not affect the exit code (they stress-test the tool's confidence behavior, they are not pass/fail anchors).
//
// CLI: node scripts/run-corpus.mjs [--cases-dir DIR] [--max-diff PCT] [--verbose]

import fs from 'fs'
import path from 'path'
import { execSync } from 'child_process'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const ASSERT = path.join(__dirname, 'ink-assert.mjs')

function parseArgs(argv) {
  const o = {}
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]
    if (!a.startsWith('--')) continue
    const k = a.slice(2), n = argv[i + 1]
    if (n === undefined || n.startsWith('--')) o[k] = true
    else { o[k] = n; i++ }
  }
  return o
}

function readVerdict(caseDir) {
  const p = path.join(caseDir, 'verdict.txt')
  if (!fs.existsSync(p)) return null
  return fs.readFileSync(p, 'utf8').trim().toLowerCase()
}

function runAssert(refPath, candPath, maxDiff) {
  try {
    const out = execSync(`node "${ASSERT}" --reference "${refPath}" --candidate "${candPath}" --json --max-diff ${maxDiff}`, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] })
    return JSON.parse(out)
  } catch (e) {
    if (e.stdout) {
      try { return JSON.parse(e.stdout) } catch (_) {}
    }
    return { error: e.message, overall: false }
  }
}

function classify(expected, toolPass) {
  if (expected === 'borderline') return 'borderline'
  if (expected === 'match' && toolPass) return 'truePass'
  if (expected === 'mismatch' && !toolPass) return 'trueFail'
  if (expected === 'match' && !toolPass) return 'falseFail'
  if (expected === 'mismatch' && toolPass) return 'falsePass'
  return 'unknown'
}

function main() {
  const args = parseArgs(process.argv.slice(2))
  const casesDir = args['cases-dir'] || path.join(__dirname, 'cases')
  // Default --max-diff matches ink-assert's own default (2.0). Caller can override per run.
  // The previous default of 25 was inherited from a parent-session test harness and silently relaxed the
  // pixel-diff axis below the tool's normal operating bar, which let cross-pipeline cases pass on a budget
  // that no real consumer would use. Strict default; raise per case only if the verdict requires it.
  const maxDiff = args['max-diff'] || 2.0
  const verbose = !!args.verbose

  if (!fs.existsSync(casesDir)) {
    console.error(`run-corpus: cases directory not found: ${casesDir}`)
    process.exit(2)
  }

  const entries = fs.readdirSync(casesDir).filter((n) => fs.statSync(path.join(casesDir, n)).isDirectory()).sort()
  const counts = { truePass: 0, trueFail: 0, falsePass: 0, falseFail: 0, borderline: 0, unknown: 0, error: 0 }
  const lines = []

  for (const name of entries) {
    const caseDir = path.join(casesDir, name)
    const ref = path.join(caseDir, 'reference.png')
    const cand = path.join(caseDir, 'candidate.png')
    const expected = readVerdict(caseDir)
    if (!expected) {
      lines.push({ name, line: `${name.padEnd(48)} | (no verdict.txt, skipping)`, classification: 'skipped' })
      continue
    }
    if (!fs.existsSync(ref) || !fs.existsSync(cand)) {
      lines.push({ name, line: `${name.padEnd(48)} | (missing reference or candidate, skipping)`, classification: 'skipped' })
      continue
    }
    const r = runAssert(ref, cand, maxDiff)
    if (r.error) {
      counts.error++
      lines.push({ name, line: `${name.padEnd(48)} | error: ${r.error}`, classification: 'error' })
      continue
    }
    const cls = classify(expected, !!r.overall)
    counts[cls] = (counts[cls] || 0) + 1
    const failed = (r.checks || []).filter((c) => !c.pass).map((c) => c.name)
    const verdictMark = expected === 'borderline' ? '~' : (cls === 'truePass' || cls === 'trueFail' ? '✓' : '✗')
    let line = `${verdictMark} ${name.padEnd(46)} | expected=${expected.padEnd(10)} tool=${r.overall ? 'PASS' : 'FAIL'} | ${cls}`
    if (verbose && failed.length > 0) line += `\n    failed axes: ${failed.join(', ')}`
    if (r.pixel && typeof r.pixel.percent === 'number') line += `  pixel=${r.pixel.percent.toFixed(2)}%`
    lines.push({ name, line, classification: cls })
  }

  for (const { line } of lines) console.log(line)
  console.log('')
  console.log('Confusion matrix:')
  console.log(`  truePass   ${counts.truePass}    (correctly classified match)`)
  console.log(`  trueFail   ${counts.trueFail}    (correctly classified mismatch)`)
  console.log(`  falsePass  ${counts.falsePass}    (mismatch case incorrectly classified as match)`)
  console.log(`  falseFail  ${counts.falseFail}    (match case incorrectly classified as mismatch)`)
  console.log(`  borderline ${counts.borderline}    (informational, does not affect exit code)`)
  if (counts.error > 0) console.log(`  errors     ${counts.error}`)

  const ok = counts.falsePass === 0 && counts.falseFail === 0 && counts.error === 0
  console.log(`\nResult: ${ok ? 'CORPUS CLEAN ✓' : 'CORPUS DIRTY ✗'}`)
  process.exit(ok ? 0 : 1)
}

main()
