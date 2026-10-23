# Pixel-level animation sampling

When you look at frames visually and the movements seem "roughly right", or you cannot tell whether a progress bar is retreating from 10% to 5%, that is the image-viewer limit: a 4px-wide bar over a 60px-tall row renders a 5% difference as 3 pixels. You cannot see that in a scaled-compressed image view. You need to read the pixel data directly from the frames.

**Technique** (four steps, language-agnostic): extract a 1-pixel-wide vertical slice at the bar position per frame, decode the raw RGB bytes, classify each pixel by RGB threshold into a small set of categories (selected colour, unread colour, background), count per category per frame to get an exact percentage. Reference implementation in Node + ffmpeg (sessions can wire the same four steps in any language and any frame extractor):

```javascript
const { execSync } = require('child_process')
const fs = require('fs')

const X = 29  // bar x-position in the GIF (measure beforehand via a single slice)
const gif = '/tmp/capture.gif'

function classify(r, g, b) {
  if (b > 150 && r < 180) return 'P'                    // purple/violet
  if (r > 200 && g > 140 && g < 190 && b < 120) return 'A'  // amber
  if (r > 200 && g > 200 && b > 200) return '.'         // background
  return '?'                                             // transition state
}

for (let n = 0; n < 50; n++) {
  execSync(`ffmpeg -y -v error -i ${gif} -vf "select=eq(n\\,${n}),crop=1:206:${X}:0" -vframes 1 /tmp/slice-${n}.ppm`)
  const buf = fs.readFileSync(`/tmp/slice-${n}.ppm`)
  // PPM: P6\n<w> <h>\n<max>\n<binary>
  const headerEnd = buf.indexOf(0x0a, buf.indexOf(0x0a, buf.indexOf(0x0a) + 1) + 1) + 1
  const pixels = buf.slice(headerEnd)
  const cells = []
  for (let i = 0; i < pixels.length; i += 3) cells.push(classify(pixels[i], pixels[i + 1], pixels[i + 2]))
  const p = cells.filter((c) => c === 'P').length
  const a = cells.filter((c) => c === 'A').length
  const pct = p + a > 0 ? Math.round(p * 100 / (p + a)) : 0
  console.log(`f${n}: ${cells.join('')}  purple=${pct}%`)
}
```

**The output gives the true picture that image view cannot deliver.** You do not just see that the bar goes from amber to purple; you see exactly that on frame 13 there is a jump to 28%, on frame 14 a peak to 33%, on frame 27 a low of 12%, etc. Only with this data can you work backwards to determine which CSS transition, $effect race, or JS reset is the cause.

**When to use**:
- A user reports a bug in an animation that you cannot see visually.
- You are unsure whether a progress bar fills linearly or has overshoot.
- You see a peak/dip/oscillation and want to know how large it is.
- Two elements animate simultaneously and you want to know whether they run in sync.

**When not needed**:
- Gross movement (entire element repositions, opacity 0 to 1).
- A difference of 20%+ that you can see with the naked eye.

**Rule of thumb**: if the user says "there is still a flicker/retreat/jitter" twice and you cannot see it, move from visual inspection to pixel sampling. Image view simply does not have the resolution for sub-5% movements.
