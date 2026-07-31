# EXLCHAR v11 — User Guide

Character editor, sprite animator and level editor for the EXL100, generating a complete
TMS7000 game engine (`engine.asm`) and level data (`level.h`).

Single HTML file — open it in a browser, no install, no server.

---

## 1. Overview

EXLCHAR covers three linked jobs:

| Area | Purpose |
|---|---|
| **Character editor** | The 128 redefinable 8×10 characters (BAGC1 bank) |
| **Animation editor** | Multi-cell sprites, frames, key bindings |
| **Level editor** | A 40×25 tile map with its own tile library |

**EXPORT ASM** produces a working engine: it programs the video generators, loads the
characters, draws the level, reads the keyboard and animates the sprite. **EXPORT .H FILE**
(level tab) produces the level data the engine includes.

Work is auto-saved to browser storage — **RESTORE** brings back your last session.
**SAVE JSON** / **LOAD JSON** for real backups (do use them; browser storage is not a safe).

---

## 2. Characters

The base grid holds 128 characters of 8×10 pixels, each with a foreground and background
colour. These are the building blocks: sprite cells and tiles both reference them.

Two slots are reserved by the hardware and never allocated: **$20** and **$7F**
(blank). Usable budget: **126 slots per bank**.

---

## 3. Animations

### Structure

An animation has a name, a **key binding**, a **default** flag, and a list of frames.
A frame is a rectangle of cells (cols × rows), each cell being one 8×10 character.

| Field | Meaning |
|---|---|
| **key** | NONE, LEFT, RIGHT, UP, DOWN, SPACE, ENTER |
| **default** | The idle animation, played when no key is pressed |
| **x_off** | Horizontal offset of this frame, in columns |
| **duration** | Display time in VBL frames (see §7) |
| **x_advance** | Columns gained per animation cycle (see §6) |

> **Critical rule — the default animation must have key = NONE.**
> A keyed default walks by itself with no key pressed: the idle dispatcher re-runs it
> every loop and each pass executes its movement step. The exporter now refuses this
> configuration and explains why.

### Sprite import

**IMPORT IMG** loads a sprite sheet; position the capture window over a pose and
**⬇ CAPTURE → FRAME** turns it into a frame in the chosen animation. Repeat for each pose.

### Frame pixel editor

Select a frame chip and the preview becomes editable:

- **Left click / drag** — draw · **Right click / drag** — erase
- **Zoom** 2× / 4× / 6× / 8×; the pixel grid appears from 4×
- **Blue lines** mark the 8×10 character boundaries — keep details from straddling two
  cells, each straddle costs extra character slots
- **FLIP H** — mirror the frame (build a left walk from a right walk)
- **◀ ▶ ▲ ▼** — shift *all* pixels one pixel, crossing cell boundaries. Ideal for
  realigning an imported capture. Pixels pushed off the edge are lost
- **CLEAR** — empty the frame

### Frame operations

| Button | Effect |
|---|---|
| **◀ MOVE / MOVE ▶** | Move the frame earlier / later in the sequence |
| **DUP+** | Duplicate right after itself, following frames shift right |
| **COPY→END** | Copy to the end of the same animation |
| **COPY TO→** | Copy to another animation (choose it in the dropdown) |
| **DELETE FRAME** | Remove it |

Recommended workflow for a mirrored walk: for each right-walk frame — **COPY TO→**
WALK_LEFT, then **FLIP H**, then **MOVE** into place.

---

## 4. Level editor

### PAINT tab

- 40 columns × 25 rows grid; **left click** paints the selected tile,
  **right click** erases the cell to air
- **Tile palette**: **+ TILE** adds one, **DEL** removes the selected one,
  **PRUNE** removes every tile not used in the grid and renumbers the map accordingly
- **Stamps**: multi-cell blocks; select one and click to place the whole block
- **− / +** zoom, **CLEAR** empties the map
- **SAVE JSON / LOAD JSON** — level backup (also carries the tile bitmaps)

Clicking a tile in the palette leaves stamp mode; right click always erases a single
cell whichever mode you are in.

### TILE IMPORT tab

**📁 LOAD IMAGE** → position/zoom (**FIT EXL100** fits the screen) →
**EXTRACT → TILE LIBRARY**. The image region is cut into 8×10 cells, deduplicated, and
turned into tiles plus a stamp of the whole block. Tiles are named `<block>_<code>`.

### The "solid (blocks movement)" checkbox

Marks the tile as solid in the exported `TILE_SOLID` table. **The current engine does not
use it yet** — it is data prepared for future collision detection (blocked walls, floors).
Ticking it changes two lines in `level.h` and nothing on screen.

### Attribute byte

`BF GF RF | CG1 CG0 | BB GB RB` — the top three bits are the **foreground colour**,
bits 3–4 select the **generator**. So `$F8`, `$B8`, `$98`… are all BAGC3 tiles in
different colours. Only the generator field is used to classify a tile.

Export warns you when a tile used in the map would be invisible: empty bitmap, undrawn
BAGC1 character, or an unsupported generator.

---

## 5. The exported engine

### Structure

```
equates → generator setup → character load → level draw
main_loop → key read → animation dispatch
play_anim_N → per-frame: move, draw, delay, key check
run_celllist / bg_restore_cell / erase_n_cols   (runtime executors)
op tables (dtb_N / ttb_N) + ALL_CHARS + ALL_CHARS2
```

### Transitions, not erase-then-redraw

For each consecutive frame pair the exporter precomputes exactly which cells change,
and stores that as a **table** of 4-byte operations `[column, row, attribute, code]`.
A cell identical in both frames generates nothing at all; a vacated cell is repainted
from the level map. Result: no flicker, roughly half the video writes.

Full draws (`dtb_N`) are used when entering an animation from another one.

### Two character banks

Sprites use **BAGC1** (attribute `$F0`, 126 slots). Beyond that, the exporter
automatically opens **BAGC2** (attribute `$E8`, base `$0A00`), for a total budget of
**252 unique cells**. Beyond that, export aborts with a per-animation breakdown.

`ALL_CHARS2` and its loading code only appear when actually needed.

### Interrupt safety

The ROM interrupt handler preserves only registers A and B: anything from R5 up is
silently destroyed on every keypress. All routines holding state in TEMP1–4 are wrapped
in `dint` / `eint`.

---

## 6. Movement: filmstrip vs classic

The exporter detects two ways of encoding movement and generates the matching code.

**Classic** — every frame has `x_off = 0`. `PLAYER_X` advances one column per frame.
Simple, suits hand-drawn animations.

**Filmstrip** — frames carry increasing `x_off` values (typical of a captured sprite
sheet, e.g. 0,0,1,1,2,3,…,9). Here the movement is *already in the data*: the sprite is
drawn at `PLAYER_X + x_off`, and `PLAYER_X` itself does not move during the cycle.
At the loop back to frame 0 it catches up in one step of **x_advance** columns.

**x_advance** therefore reconciles `PLAYER_X` with the distance the x_offs already
walked. Default = *last frame's x_off + 1*, which makes the loop-back a normal one-column
stride. Leave it alone unless the wrap looks wrong; a value ≤ 0 means "auto".

The engine folds `x_off` into `PLAYER_X` at every boundary — entering, leaving, hitting a
wall — so the logical position and the drawn position can never diverge.

---

## 7. Animation speed

`FRAMES_PER_STEP` (an equate at the top of `engine.asm`) sets how many VBL frames each
step lasts. It is generated as the **most common duration** in your session, so editing
this single line re-times the whole animation:

| Value | Speed |
|---|---|
| 1 | ~50 steps/s |
| 2 | ~25 steps/s |
| 3 | ~16 steps/s |
| 4 | ~12 steps/s |

A frame whose **duration** differs from that majority value emits its own literal and
overrides the equate. That is how you hold a single pose longer — much cheaper than
duplicating the frame, which costs ~110 bytes of sequencing code.

---

## 8. Assembly and testing

Assemble with TASM: `tasm -tEXL -a -b engine.asm`.
Keep `level.h` and `mixt_api.asm` in the same directory.

Ordering rule: **all `#DEFINE` and `#include` directives must come after `.org`**.
`#include "level.h"` placed before it would land the tile data in the register file
($0000–$007F).

If the program exceeds the space available at `.org $1000`, move it to `.org $0200`
(the cartridge window runs $0200–$7FFF).

### Debug option

The **key debug** checkbox next to EXPORT ASM makes the engine display `VALUE0`
(the keyboard register) as two hex digits at the top right. Idle values: `$86` EXL100,
`$89` Exeltel, `$04` key released, `$00` boot. Useful when the sprite reacts to keys
you are not pressing.

---

## 9. Troubleshooting

| Symptom | Likely cause |
|---|---|
| Sprite moves with no key pressed | The default animation has a key binding — set it to NONE |
| Sprite jumps back several columns each cycle | Old export; filmstrip mode fixes this |
| Sprite teleports on the first keypress | Old export; the wrap advance ran before the entry check |
| Blank level on hardware | A tile is invisible — read the export warning |
| Cells display the character above | TRAP 19 slot misalignment (`TEMP7` must be `$00`) |
| Popup loop "too many unique cells" | Old export; the limit is now 252 with a single message |
| "Range of relative branch exceeded" | A conditional jump beyond ±127 bytes — needs a `br` trampoline |
| Tile previews empty after reload | Reload the level JSON: the stamps carry the bitmaps |

---

## 10. Recommended workflow

1. Draw or import the sprite poses → animations
2. Set the key bindings, one animation as **default with key = NONE**
3. Build the level: import tiles, paint, **PRUNE**
4. **EXPORT .H FILE** (level) then **EXPORT ASM** (engine)
5. Assemble, test in the emulator, then on real hardware
6. **SAVE JSON** for both the session and the level

Keep numbered versions of the ASM (engine1, engine2, …) rather than overwriting —
comparing two exports is the fastest way to find what a change actually did.
