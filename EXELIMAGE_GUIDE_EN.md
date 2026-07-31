# EXELIMAGE — User Guide

Converts any image into an EXL100 screen: a 40×25 character display using all four
character generators (BAGC0–BAGC3), exported as TMS7000 assembly.

Single HTML file — open it in a browser, no install, no server.

---

## 1. What it produces

The EXL100 screen is 40 columns × 25 rows = **1000 cells**. Each cell is 8×10 pixels
and displays one character in two colours (foreground + background).

EXELIMAGE analyses your image, invents up to **512 custom characters** (128 per
generator bank × 4 banks), and writes an `.asm` file containing:

| Block | Contents |
|---|---|
| `BAGC0_DATA` … `BAGC3_DATA` | 4 × 128 characters × 10 bytes of bitmap |
| `SCREEN_DATA` | 1000 cells × 2 bytes (attribute byte + character code) |
| `write_screen` | Routine that pushes the cells to VRAM via TRAP 9 |
| Boot code | Generator base addresses, MIXT mode, screen setup |

The generated program is standalone: assemble it and it displays the image.

---

## 2. Quick start

1. **⊕ BROWSE IMAGE** — load a PNG/JPG. Any size; it is scaled to 320×250.
2. Pick a **Style preset** (see §3).
3. **◈ PROCESS IMAGE** — conversion runs, the preview appears.
4. Adjust settings, press **↺ REPROCESS** after each change.
5. When satisfied, the ASM is generated — copy or download it.

Watch the status bar: **BAGC2+BAGC3: n/256 slots**. If you saturate the banks, the
image loses detail — reduce dithering or choose a simpler style.

---

## 3. Style presets

Each preset sets a whole family of parameters at once. Start here, fine-tune after.

| Preset | Best for |
|---|---|
| **Photorealistic** | Photographs, faces, gradients |
| **Comics / Cartoon** | Line art, drawings, flat colours |
| **Pop Art** | Strong saturated contrasts |
| **Black & White** | Monochrome, engravings, high contrast |
| **Neon / Cyberpunk** | Dark images with bright accents |
| **Thermal / Infrared** | False-colour heat-map look |
| **Posterize** | Reduced colour bands, poster look |
| **Japanese Woodblock** | Prints, flat areas with outlines |

---

## 4. Settings panel

### Colour algorithm
Each cell can only hold **two colours**. This chooses which two.

- **K-Means 2-color (best)** — clusters the cell's pixels; best quality, default choice.
- **Dominant 2 colors** — the two most frequent colours; fast, good for flat art.
- **Min+Max luminance** — darkest and lightest pixel; maximum contrast.
- **Best pair (exhaustive)** — tries every pair; slowest, marginally better on tricky cells.

### Dithering
Simulates intermediate shades by alternating pixels.

- **Threshold (none)** — hard cut. Sharpest, best for line art and text.
- **Bayer 4×4 / 8×8 ordered** — regular pattern. Good gradients, visible texture. 8×8 is finer.
- **Floyd-Steinberg** — error diffusion. Most natural on photographs, but produces many
  unique cells (watch the slot counter).

### Adjustments

| Slider | Range | Notes |
|---|---|---|
| Brightness | −100 … +100 | Apply before dithering |
| Contrast | −100 … +100 | Raising it usually helps legibility on EXL100 |
| Saturation | 0 … 200 | 0 = greyscale |
| Sharpen | 0 … 300 | Recovers detail lost in downscaling; too high adds noise |
| Dither % | 0 … 100 | Dither strength; lower = fewer unique characters |

### Character optimisation
How the 512-character budget is allocated.

- **Greedy (fast)** — first come, first served. Quick previews.
- **K-means cluster (best)** — groups similar cells and shares characters. Best final quality.
- **Halftone (B&W)** — uses a fixed halftone library instead of custom characters.
  Very economical in slots; pairs with the **Pattern preset** below.

### Pattern preset (halftone mode)
`None` (max detail), `Bayer`, `Bayer soft`, `Clustered dots`, `Horizontal lines`,
`Vertical lines`. Line patterns suit engraving/comic-strip looks.

### Colour Remap
Eight swatches, one per EXL100 colour. Each can be redirected to another colour —
useful to fix a palette the conversion chose badly (e.g. forcing a background to black),
without reprocessing the image.

---

## 5. Preview tools

- **⊞ CELL GRID** — overlays the 8×10 cell boundaries. Essential for checking that a
  face or an outline is not cut across two cells.
- **◧ COMPARE** — side-by-side source vs result.
- **⊕ 1×** — zoom cycle for pixel-level inspection.

---

## 6. Pixel editor tab

Manual retouching of the conversion result, cell by cell.

| Tool | Action |
|---|---|
| ✏ PIXEL | Draw / erase single pixels |
| ▣ FILL | Flood fill |
| ⊕ INVERT | Invert the cell |
| □ CLEAR | Empty the cell |
| ← UNDO / → REDO | Full history |
| ⊞ GRID | Toggle the pixel grid |

- **◈ GENERATE ASM** — regenerate the assembly with your edits included.
- **↺ RESET TO GENERATED** — discard manual edits, back to the automatic conversion.
- **⧉ COPY ASM** — copy the source to the clipboard.

Typical use: the automatic conversion is 95 % right, but an eye or a letter is mangled —
fix those few cells by hand rather than reprocessing everything.

---

## 7. Settings persistence

Every generated `.asm` embeds its settings in a header comment block
(`EXELIMAGE_SETTINGS_BEGIN … END`): source file, style, algorithms, all slider values,
and the colour remap.

**⬆ IMPORT SETTINGS FROM ASM** reads that block back. So an old export can be reopened
months later and tweaked, instead of hunting for the settings that produced it.

---

## 8. Practical notes

- **Slot budget**: 512 characters total. Floyd-Steinberg + high dither % on a detailed
  photo will exhaust them. If the counter saturates, lower Dither %, switch to Bayer,
  or use K-means character optimisation.
- **Prepare the image beforehand**: crop to a 40:25 (1.6:1) ratio in an image editor.
  EXELIMAGE scales without cropping, so an ill-proportioned source gets squashed.
- **Contrast beats resolution**: at 320×250 with 2 colours per cell, a strongly
  contrasted image always reads better than a subtle one.
- **DC5 bit**: the generated code sets DC5 = 1 *after* `set_25LINE`, because that routine
  resets CM2 = $C8 and clears DC5. Keep that ordering if you merge this code into a
  larger program.
- **Merging with another program**: the exported file is complete and standalone
  (`start:`, `.org`, `screen_data2`, `#include "mixt_api.asm"`, `.end`). To combine it
  with a game, keep only the generator setup, the character data, `SCREEN_DATA` and
  `write_screen`, and remove the duplicate boot/end sections.
