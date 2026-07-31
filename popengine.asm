; ============================================================
; WALK_LEFT — EXLCHAR v11 — table-driven animation engine (transition rendering)
; 3 animations, 26 total frames, 159 unique cells (BAGC1: 126, BAGC2: 33), 18 draw tables + 24 transition tables = 2070 table bytes (318 transition cells, 458 skipped)
; KEY BINDINGS:
;   WALK_LEFT: key=LEFT
;   WALK_RIGHT: key=RIGHT
;   STAND: key=NONE [DEFAULT]
; ============================================================

#include "c:/jeux/emulateur/exl/tasm/H/7020.equ"
#include "c:/jeux/emulateur/exl/tasm/H/3556.equ"

SCR             .equ    $7340
BAGC1_ADR       .equ    $0500
SPR_ROW         .equ    8
FRAMES_PER_STEP .equ    2       ; VBL frames per animation step (50/3 ≈ 16fps)
; Key codes
KEY_LEFT        .equ    $83     ; arrow left
KEY_A_UP        .equ    $41     ; A (uppercase)
KEY_A_LO        .equ    $61     ; a (lowercase)
KEY_RIGHT       .equ    $81     ; arrow right
KEY_R_UP        .equ    $52     ; R (uppercase)
KEY_R_LO        .equ    $72     ; r (lowercase)
KEY_UP          .equ    $80     ; arrow up
KEY_Z_UP        .equ    $5A     ; Z
KEY_DOWN        .equ    $82     ; arrow down
KEY_SPACE       .equ    $20
KEY_ENTER       .equ    $0D
KEY_NONE_EXL    .equ    $86     ; no-key EXL100
KEY_NONE_EXT    .equ    $89     ; no-key Exeltel
KEY_NONE_REL    .equ    $04     ; key-released sentinel (see mixt_api wait_relkey)
; NOTE: $00 is also treated as no-key (boot value / Exeltel idle)
; Game state
ANIM_CUR        .equ    $C3F0   ; current animation index
PLAYER_X        .equ    $C3F1   ; player screen column (0..39)
PREV_X          .equ    $C3F2   ; player X before last move (for erase)
PREV_COLS       .equ    $C3F3   ; cols width of last drawn frame (for erase)
ANIM_NEW        .equ    $C3F4   ; 1 = animation just switched, need full redraw
FRAME_CTR       .equ    $C3F5   ; frame counter for animation speed control
; v11 runtime-executor work vars ($C3E0-$C3EB)
OP_PL           .equ    $C3E0   ; celllist table pointer (lo)
OP_PH           .equ    $C3E1   ; celllist table pointer (hi)
OP_B0           .equ    $C3E2   ; current op: column offset
OP_ROW          .equ    $C3E3   ; current op: absolute row
OP_ATTR         .equ    $C3E4   ; current op: attr ($FF = bg restore)
OP_CODE         .equ    $C3E5   ; current op: char code
BG_ROW          .equ    $C3E6   ; bg_restore_cell: row
BG_COL          .equ    $C3E7   ; bg_restore_cell: col
EW              .equ    $C3E8   ; generic erase: width
ER_C            .equ    $C3E9   ; generic erase / level init: col
ER_R            .equ    $C3EA   ; generic erase: row
LI_ROW          .equ    $C3EB   ; level init: row

        .org    $1000

start:
        dint
        mov     %$58,B
        ldsp
        movp    P40,A
        movp    P36,A
        call    @init_vdp
        #DEFINE Finit_vdp
        eint
        movd    %$0000,TEMP8
        trap    13
        ; ── Set BAGC1 base address to $0500 (walkman.asm proven sequence)
        movp    %$01,P45
        movp    %$FE,P45
        movp    %$02,P45
        movp    %$04,P45
        movp    %$0C,P45       ; BAGC1 register (12)
        movp    %$00,P45
        movp    %$00,P45
        ; ── Set BAGC3 base address to $0F00 (register 14)
        movp    %$01,P45
        movp    %$FE,P45
        movp    %$02,P45
        movp    %$0E,P45
        movp    %$0E,P45       ; BAGC3 register (14)
        movp    %$00,P45
        movp    %$00,P45
        ; ── Set BAGC2 base address to $0A00 (register 13)
        movp    %$01,P45
        movp    %$FE,P45
        movp    %$02,P45
        movp    %$09,P45
        movp    %$0D,P45       ; BAGC2 register (13)
        movp    %$00,P45
        movp    %$00,P45
        ; ── Load BAGC1 sprite chars ──────────────────────────
        movd    %ALL_CHARS,TEMP3
        movd    %BAGC1_ADR,TEMP2
        mov     %$00,TEMP7             ; first slot = 0: ALL_CHARS[i] → slot i (draw codes start at 0)
        mov     %128,TEMP4-1
        trap    19
        ; ── Load BAGC2 sprite chars (overflow bank, attr $E8) ──
        movd    %ALL_CHARS2,TEMP3
        movd    %$0A00,TEMP2           ; BAGC2 base address
        mov     %$00,TEMP7
        mov     %34,TEMP4-1
        trap    19
        ; ── Load BAGC3 tile chars from level.h ──────────────
        mov     %BAGC3_TILE_CHAR_COUNT,A
        jz      @skip_bagc3    ; skip if no BAGC3 tiles
        movd    %BAGC3_TILE_CHARS,TEMP3
        movd    %$0F00,TEMP2           ; BAGC3 base address
        mov     %BAGC3_TILE_SLOT_START,TEMP7 ; first char slot
        mov     %BAGC3_TILE_CHAR_COUNT,TEMP4-1
        trap    19
skip_bagc3:
        clr     A
        sta     @BRJOY0
        sta     @BRJOY0+1
        sta     @BRTIME
        sta     @BRTIME+1
        dint
        call    @init_textapi
        #DEFINE Finit_textapi
        call    @set_25LINE
        #DEFINE Fset_25LINE
        movd    %SCR,R1
        call    @set_vidbuf
        #DEFINE Fset_vidbuf
        movd    %SCR,R1
        call    @set_screen_adr
        #DEFINE Fset_screen_adr
        movd    %screen_data2+24,R1
        call    @set_MIXTMODE
        #DEFINE Fset_MIXTMODE
        mov     %FWHITE|BAGC2|BBLACK,A
        movd    %$0000,TEMP1
        movd    %$1928,TEMP2
        call    @set_window
        #DEFINE Fset_window
        eint                   ; enable interrupts

        ; Start with default animation: STAND
        mov     %2,A
        sta     @ANIM_CUR
        clr     A
        sta     @PLAYER_X      ; start at col 0
        sta     @PREV_X
        sta     @PREV_COLS     ; no sprite drawn yet
        mov     %1,A
        sta     @ANIM_NEW      ; force draw on first frame

        ; ── Draw full level map ─────────────────────────────────────
        dint                   ; disable interrupts: TEMP3/6/7 not interrupt-safe
        clr     A
        sta     @LI_ROW
li_row:
        clr     A
        sta     @ER_C          ; col 0..39 (reuses erase counter)
li_col:
        lda     @ER_C
        mov     A,B
        lda     @LI_ROW
        call    @bg_restore_cell
        lda     @ER_C
        inc     A
        sta     @ER_C
        cmp     %40,A
        jl      @li_col
        lda     @LI_ROW
        inc     A
        sta     @LI_ROW
        cmp     %25,A
        jl      @li_row

        eint                   ; re-enable interrupts after level init

main_loop:
        ; ── Read keyboard ──────────────────────────────────
        mov     VALUE0,A
        cmp     %KEY_NONE_EXL,A
        jeq     @no_key
        cmp     %KEY_NONE_EXT,A
        jeq     @no_key
        cmp     %KEY_NONE_REL,A
        jeq     @no_key
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @no_key
        ; ── Key dispatch ──
        cmp     %$83,A       ; LEFT → WALK_LEFT
        jeq     @run_anim_0
        cmp     %$61,A       ; LEFT → WALK_LEFT
        jeq     @run_anim_0
        cmp     %$41,A       ; LEFT → WALK_LEFT
        jeq     @run_anim_0
        cmp     %$81,A       ; RIGHT → WALK_RIGHT
        jeq     @run_anim_1
        cmp     %$72,A       ; RIGHT → WALK_RIGHT
        jeq     @run_anim_1
        cmp     %$52,A       ; RIGHT → WALK_RIGHT
        jeq     @run_anim_1
no_key:
        ; no key pressed → if current anim is keyed, reset to default
        lda     @ANIM_CUR
        cmp     %0,A      ; if current=WALK_LEFT (keyed), reset to default
        jeq     @run_anim_2
        lda     @ANIM_CUR
        cmp     %1,A      ; if current=WALK_RIGHT (keyed), reset to default
        jeq     @run_anim_2
        lda     @ANIM_CUR
        cmp     %0,A
        jeq     @run_anim_0
        cmp     %1,A
        jeq     @run_anim_1
        cmp     %2,A
        jeq     @run_anim_2
        br      @main_loop

run_anim_0:
        lda     @ANIM_CUR
        cmp     %0,A
        jeq     @ra_same_0   ; same anim → keep ANIM_NEW=0, no forced redraw
        mov     %0,A
        sta     @ANIM_CUR
        mov     %1,A
        sta     @ANIM_NEW      ; signal new animation
ra_same_0:
        call    @play_anim_0
        br      @main_loop
run_anim_1:
        lda     @ANIM_CUR
        cmp     %1,A
        jeq     @ra_same_1   ; same anim → keep ANIM_NEW=0, no forced redraw
        mov     %1,A
        sta     @ANIM_CUR
        mov     %1,A
        sta     @ANIM_NEW      ; signal new animation
ra_same_1:
        call    @play_anim_1
        br      @main_loop
run_anim_2:
        lda     @ANIM_CUR
        cmp     %2,A
        jeq     @ra_same_2   ; same anim → keep ANIM_NEW=0, no forced redraw
        mov     %2,A
        sta     @ANIM_CUR
        mov     %1,A
        sta     @ANIM_NEW      ; signal new animation
ra_same_2:
        call    @play_anim_2
        br      @main_loop
; ── VBL sync subroutine ─────────────────────────────────────────────────
sync:
        movp    %$03,P45       ; request VDP status register
        btjop   %$20,P37,sync  ; wait while ST3=1 (active display)
        rets

; ── Wait N VBL frames subroutine ────────────────────────────────────────
; IN: FRAME_CTR already loaded with FRAMES_PER_STEP
wait_frames:
        call    @sync          ; wait for VBL
        ; wait for end of blanking (ST3 goes high = beam active again)
wf_act: movp    %$03,P45
        btjzp   %$20,P37,wf_act ; wait while ST3=0 (blanking)
        lda     @FRAME_CTR
        dec     A
        sta     @FRAME_CTR
        jnz     @wait_frames   ; loop N times
        rets

; ── Animation play subroutines ──────────────────────────────────────────
; ── Animation: WALK_LEFT (key=LEFT) ──────────
play_anim_0:
; Frame 0 id=17 x_off=0 (transition from frame 0, dx=-1)
        lda     @PLAYER_X
        cmp     %2,A
        jl      @gen_0_0      ; pinned at left wall → generic redraw
        dec     A
        sta     @PLAYER_X
        lda     @ANIM_NEW
        jnz     @gen_0_0      ; cross-animation entry → generic redraw
        lda     @PLAYER_X
        cmp     %40,A
        jl      @nx_t0_0
        mov     %39,A
nx_t0_0:
        mov     A,TEMP4
        movd    %ttb_0,TEMP2
        call    @run_celllist
        br      @fdone_0_0
gen_0_0:
        clr     A
        sta     @ANIM_NEW
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        cmp     %40,A
        jl      @nx_g0_0
        mov     %39,A
nx_g0_0:
        mov     A,TEMP4
        movd    %dtb_0,TEMP2
        call    @run_celllist
fdone_0_0:
        lda     @PLAYER_X
        cmp     %40,A
        jl      @px_0_0
        mov     %39,A          ; clamp like the draw
px_0_0:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %2,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %FRAMES_PER_STEP,A
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d0_0_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d0_0_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d0_0_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d0_0_exit
        cmp     %$83,A
        jeq     @d0_0_nk
        cmp     %$61,A
        jeq     @d0_0_nk
        cmp     %$41,A
        jeq     @d0_0_nk
d0_0_exit:
        rets
d0_0_nk:
        rets

; ── Animation: WALK_RIGHT (key=RIGHT) ──────────
play_anim_1:
; Frame 0 id=3 x_off=0 (transition from frame 23, dx=0)
        lda     @ANIM_NEW
        jnz     @gen_1_0      ; cross-animation entry → generic redraw
        lda     @PLAYER_X
        cmp     %18,A
        jl      @fsw_1_0
        br      @fs_fold_1  ; wall — fold x_off into X, hold pose
fsw_1_0:
        add     %11,A     ; filmstrip wrap advance
        sta     @PLAYER_X
        lda     @PLAYER_X
        cmp     %40,A
        jl      @nx_t1_0
        mov     %39,A
nx_t1_0:
        mov     A,TEMP4
        movd    %ttb_1,TEMP2
        call    @run_celllist
        br      @fdone_1_0
gen_1_0:
        clr     A
        sta     @ANIM_NEW
        lda     @PLAYER_X
        cmp     %29,A
        jl      @fse_1_0
        br      @fs_hold_1  ; at wall on entry → hold
fse_1_0:
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        cmp     %40,A
        jl      @nx_g1_0
        mov     %39,A
nx_g1_0:
        mov     A,TEMP4
        movd    %dtb_1,TEMP2
        call    @run_celllist
fdone_1_0:
        lda     @PLAYER_X
        cmp     %40,A
        jl      @px_1_0
        mov     %39,A          ; clamp like the draw
px_1_0:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %2,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %FRAMES_PER_STEP,A
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d1_0_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d1_0_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d1_0_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d1_0_exit
        cmp     %$81,A
        jeq     @d1_0_nk
        cmp     %$72,A
        jeq     @d1_0_nk
        cmp     %$52,A
        jeq     @d1_0_nk
d1_0_exit:
        rets
d1_0_nk:
; Frame 1 id=5 x_off=0 (transition from frame 0, dx=0)
        lda     @PLAYER_X
        cmp     %40,A
        jl      @nx_t1_1
        mov     %39,A
nx_t1_1:
        mov     A,TEMP4
        movd    %ttb_2,TEMP2
        call    @run_celllist
        br      @fdone_1_1
gen_1_1:
        clr     A
        sta     @ANIM_NEW
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        cmp     %40,A
        jl      @nx_g1_1
        mov     %39,A
nx_g1_1:
        mov     A,TEMP4
        movd    %dtb_2,TEMP2
        call    @run_celllist
fdone_1_1:
        lda     @PLAYER_X
        cmp     %40,A
        jl      @px_1_1
        mov     %39,A          ; clamp like the draw
px_1_1:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %3,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %FRAMES_PER_STEP,A
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d1_1_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d1_1_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d1_1_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d1_1_exit
        cmp     %$81,A
        jeq     @d1_1_nk
        cmp     %$72,A
        jeq     @d1_1_nk
        cmp     %$52,A
        jeq     @d1_1_nk
d1_1_exit:
        rets
d1_1_nk:
; Frame 2 id=6 x_off=1 (transition from frame 1, dx=1)
        lda     @PLAYER_X
        add     %1,A     ; frame x_off
        cmp     %40,A
        jl      @nx_t1_2
        mov     %39,A
nx_t1_2:
        mov     A,TEMP4
        movd    %ttb_3,TEMP2
        call    @run_celllist
        br      @fdone_1_2
gen_1_2:
        clr     A
        sta     @ANIM_NEW
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        add     %1,A     ; frame x_off
        cmp     %40,A
        jl      @nx_g1_2
        mov     %39,A
nx_g1_2:
        mov     A,TEMP4
        movd    %dtb_3,TEMP2
        call    @run_celllist
fdone_1_2:
        lda     @PLAYER_X
        add     %1,A     ; include frame x_off
        cmp     %40,A
        jl      @px_1_2
        mov     %39,A          ; clamp like the draw
px_1_2:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %4,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %FRAMES_PER_STEP,A
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d1_2_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d1_2_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d1_2_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d1_2_exit
        cmp     %$81,A
        jeq     @d1_2_nk
        cmp     %$72,A
        jeq     @d1_2_nk
        cmp     %$52,A
        jeq     @d1_2_nk
d1_2_exit:
        lda     @PLAYER_X
        add     %1,A     ; fold x_off (exit mid-cycle)
        cmp     %39,A
        jl      @dxf_1_2
        mov     %38,A
dxf_1_2:
        sta     @PLAYER_X
        rets
d1_2_nk:
; Frame 3 id=7 x_off=1 (transition from frame 2, dx=0)
        lda     @PLAYER_X
        add     %1,A     ; frame x_off
        cmp     %40,A
        jl      @nx_t1_3
        mov     %39,A
nx_t1_3:
        mov     A,TEMP4
        movd    %ttb_4,TEMP2
        call    @run_celllist
        br      @fdone_1_3
gen_1_3:
        clr     A
        sta     @ANIM_NEW
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        add     %1,A     ; frame x_off
        cmp     %40,A
        jl      @nx_g1_3
        mov     %39,A
nx_g1_3:
        mov     A,TEMP4
        movd    %dtb_4,TEMP2
        call    @run_celllist
fdone_1_3:
        lda     @PLAYER_X
        add     %1,A     ; include frame x_off
        cmp     %40,A
        jl      @px_1_3
        mov     %39,A          ; clamp like the draw
px_1_3:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %3,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %2,A       ; frame duration
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d1_3_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d1_3_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d1_3_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d1_3_exit
        cmp     %$81,A
        jeq     @d1_3_nk
        cmp     %$72,A
        jeq     @d1_3_nk
        cmp     %$52,A
        jeq     @d1_3_nk
d1_3_exit:
        lda     @PLAYER_X
        add     %1,A     ; fold x_off (exit mid-cycle)
        cmp     %39,A
        jl      @dxf_1_3
        mov     %38,A
dxf_1_3:
        sta     @PLAYER_X
        rets
d1_3_nk:
; Frame 4 id=8 x_off=2 (transition from frame 3, dx=1)
        lda     @PLAYER_X
        add     %2,A     ; frame x_off
        cmp     %40,A
        jl      @nx_t1_4
        mov     %39,A
nx_t1_4:
        mov     A,TEMP4
        movd    %ttb_5,TEMP2
        call    @run_celllist
        br      @fdone_1_4
gen_1_4:
        clr     A
        sta     @ANIM_NEW
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        add     %2,A     ; frame x_off
        cmp     %40,A
        jl      @nx_g1_4
        mov     %39,A
nx_g1_4:
        mov     A,TEMP4
        movd    %dtb_5,TEMP2
        call    @run_celllist
fdone_1_4:
        lda     @PLAYER_X
        add     %2,A     ; include frame x_off
        cmp     %40,A
        jl      @px_1_4
        mov     %39,A          ; clamp like the draw
px_1_4:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %3,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %2,A       ; frame duration
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d1_4_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d1_4_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d1_4_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d1_4_exit
        cmp     %$81,A
        jeq     @d1_4_nk
        cmp     %$72,A
        jeq     @d1_4_nk
        cmp     %$52,A
        jeq     @d1_4_nk
d1_4_exit:
        lda     @PLAYER_X
        add     %2,A     ; fold x_off (exit mid-cycle)
        cmp     %39,A
        jl      @dxf_1_4
        mov     %38,A
dxf_1_4:
        sta     @PLAYER_X
        rets
d1_4_nk:
; Frame 5 id=9 x_off=2 (transition from frame 4, dx=0)
        lda     @PLAYER_X
        add     %2,A     ; frame x_off
        cmp     %40,A
        jl      @nx_t1_5
        mov     %39,A
nx_t1_5:
        mov     A,TEMP4
        movd    %ttb_6,TEMP2
        call    @run_celllist
        br      @fdone_1_5
gen_1_5:
        clr     A
        sta     @ANIM_NEW
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        add     %2,A     ; frame x_off
        cmp     %40,A
        jl      @nx_g1_5
        mov     %39,A
nx_g1_5:
        mov     A,TEMP4
        movd    %dtb_6,TEMP2
        call    @run_celllist
fdone_1_5:
        lda     @PLAYER_X
        add     %2,A     ; include frame x_off
        cmp     %40,A
        jl      @px_1_5
        mov     %39,A          ; clamp like the draw
px_1_5:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %4,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %2,A       ; frame duration
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d1_5_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d1_5_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d1_5_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d1_5_exit
        cmp     %$81,A
        jeq     @d1_5_nk
        cmp     %$72,A
        jeq     @d1_5_nk
        cmp     %$52,A
        jeq     @d1_5_nk
d1_5_exit:
        lda     @PLAYER_X
        add     %2,A     ; fold x_off (exit mid-cycle)
        cmp     %39,A
        jl      @dxf_1_5
        mov     %38,A
dxf_1_5:
        sta     @PLAYER_X
        rets
d1_5_nk:
; Frame 6 id=10 x_off=3 (transition from frame 5, dx=1)
        lda     @PLAYER_X
        add     %3,A     ; frame x_off
        cmp     %40,A
        jl      @nx_t1_6
        mov     %39,A
nx_t1_6:
        mov     A,TEMP4
        movd    %ttb_7,TEMP2
        call    @run_celllist
        br      @fdone_1_6
gen_1_6:
        clr     A
        sta     @ANIM_NEW
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        add     %3,A     ; frame x_off
        cmp     %40,A
        jl      @nx_g1_6
        mov     %39,A
nx_g1_6:
        mov     A,TEMP4
        movd    %dtb_7,TEMP2
        call    @run_celllist
fdone_1_6:
        lda     @PLAYER_X
        add     %3,A     ; include frame x_off
        cmp     %40,A
        jl      @px_1_6
        mov     %39,A          ; clamp like the draw
px_1_6:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %3,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %2,A       ; frame duration
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d1_6_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d1_6_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d1_6_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d1_6_exit
        cmp     %$81,A
        jeq     @d1_6_nk
        cmp     %$72,A
        jeq     @d1_6_nk
        cmp     %$52,A
        jeq     @d1_6_nk
d1_6_exit:
        lda     @PLAYER_X
        add     %3,A     ; fold x_off (exit mid-cycle)
        cmp     %39,A
        jl      @dxf_1_6
        mov     %38,A
dxf_1_6:
        sta     @PLAYER_X
        rets
d1_6_nk:
; Frame 7 id=11 x_off=3 (transition from frame 6, dx=0)
        lda     @PLAYER_X
        add     %3,A     ; frame x_off
        cmp     %40,A
        jl      @nx_t1_7
        mov     %39,A
nx_t1_7:
        mov     A,TEMP4
        movd    %ttb_8,TEMP2
        call    @run_celllist
        br      @fdone_1_7
gen_1_7:
        clr     A
        sta     @ANIM_NEW
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        add     %3,A     ; frame x_off
        cmp     %40,A
        jl      @nx_g1_7
        mov     %39,A
nx_g1_7:
        mov     A,TEMP4
        movd    %dtb_8,TEMP2
        call    @run_celllist
fdone_1_7:
        lda     @PLAYER_X
        add     %3,A     ; include frame x_off
        cmp     %40,A
        jl      @px_1_7
        mov     %39,A          ; clamp like the draw
px_1_7:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %4,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %2,A       ; frame duration
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d1_7_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d1_7_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d1_7_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d1_7_exit
        cmp     %$81,A
        jeq     @d1_7_nk
        cmp     %$72,A
        jeq     @d1_7_nk
        cmp     %$52,A
        jeq     @d1_7_nk
d1_7_exit:
        lda     @PLAYER_X
        add     %3,A     ; fold x_off (exit mid-cycle)
        cmp     %39,A
        jl      @dxf_1_7
        mov     %38,A
dxf_1_7:
        sta     @PLAYER_X
        rets
d1_7_nk:
; Frame 8 id=12 x_off=4 (transition from frame 7, dx=1)
        lda     @PLAYER_X
        add     %4,A     ; frame x_off
        cmp     %40,A
        jl      @nx_t1_8
        mov     %39,A
nx_t1_8:
        mov     A,TEMP4
        movd    %ttb_9,TEMP2
        call    @run_celllist
        br      @fdone_1_8
gen_1_8:
        clr     A
        sta     @ANIM_NEW
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        add     %4,A     ; frame x_off
        cmp     %40,A
        jl      @nx_g1_8
        mov     %39,A
nx_g1_8:
        mov     A,TEMP4
        movd    %dtb_9,TEMP2
        call    @run_celllist
fdone_1_8:
        lda     @PLAYER_X
        add     %4,A     ; include frame x_off
        cmp     %40,A
        jl      @px_1_8
        mov     %39,A          ; clamp like the draw
px_1_8:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %4,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %2,A       ; frame duration
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d1_8_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d1_8_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d1_8_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d1_8_exit
        cmp     %$81,A
        jeq     @d1_8_nk
        cmp     %$72,A
        jeq     @d1_8_nk
        cmp     %$52,A
        jeq     @d1_8_nk
d1_8_exit:
        lda     @PLAYER_X
        add     %4,A     ; fold x_off (exit mid-cycle)
        cmp     %39,A
        jl      @dxf_1_8
        mov     %38,A
dxf_1_8:
        sta     @PLAYER_X
        rets
d1_8_nk:
; Frame 9 id=13 x_off=4 (transition from frame 8, dx=0)
        lda     @PLAYER_X
        add     %4,A     ; frame x_off
        cmp     %40,A
        jl      @nx_t1_9
        mov     %39,A
nx_t1_9:
        mov     A,TEMP4
        movd    %ttb_10,TEMP2
        call    @run_celllist
        br      @fdone_1_9
gen_1_9:
        clr     A
        sta     @ANIM_NEW
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        add     %4,A     ; frame x_off
        cmp     %40,A
        jl      @nx_g1_9
        mov     %39,A
nx_g1_9:
        mov     A,TEMP4
        movd    %dtb_10,TEMP2
        call    @run_celllist
fdone_1_9:
        lda     @PLAYER_X
        add     %4,A     ; include frame x_off
        cmp     %40,A
        jl      @px_1_9
        mov     %39,A          ; clamp like the draw
px_1_9:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %5,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %2,A       ; frame duration
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d1_9_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d1_9_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d1_9_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d1_9_exit
        cmp     %$81,A
        jeq     @d1_9_nk
        cmp     %$72,A
        jeq     @d1_9_nk
        cmp     %$52,A
        jeq     @d1_9_nk
d1_9_exit:
        lda     @PLAYER_X
        add     %4,A     ; fold x_off (exit mid-cycle)
        cmp     %39,A
        jl      @dxf_1_9
        mov     %38,A
dxf_1_9:
        sta     @PLAYER_X
        rets
d1_9_nk:
; Frame 10 id=14 x_off=5 (transition from frame 9, dx=1)
        lda     @PLAYER_X
        add     %5,A     ; frame x_off
        cmp     %40,A
        jl      @nx_t1_10
        mov     %39,A
nx_t1_10:
        mov     A,TEMP4
        movd    %ttb_11,TEMP2
        call    @run_celllist
        br      @fdone_1_10
gen_1_10:
        clr     A
        sta     @ANIM_NEW
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        add     %5,A     ; frame x_off
        cmp     %40,A
        jl      @nx_g1_10
        mov     %39,A
nx_g1_10:
        mov     A,TEMP4
        movd    %dtb_11,TEMP2
        call    @run_celllist
fdone_1_10:
        lda     @PLAYER_X
        add     %5,A     ; include frame x_off
        cmp     %40,A
        jl      @px_1_10
        mov     %39,A          ; clamp like the draw
px_1_10:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %3,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %2,A       ; frame duration
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d1_10_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d1_10_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d1_10_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d1_10_exit
        cmp     %$81,A
        jeq     @d1_10_nk
        cmp     %$72,A
        jeq     @d1_10_nk
        cmp     %$52,A
        jeq     @d1_10_nk
d1_10_exit:
        lda     @PLAYER_X
        add     %5,A     ; fold x_off (exit mid-cycle)
        cmp     %39,A
        jl      @dxf_1_10
        mov     %38,A
dxf_1_10:
        sta     @PLAYER_X
        rets
d1_10_nk:
; Frame 11 id=15 x_off=5 (transition from frame 10, dx=0)
        lda     @PLAYER_X
        add     %5,A     ; frame x_off
        cmp     %40,A
        jl      @nx_t1_11
        mov     %39,A
nx_t1_11:
        mov     A,TEMP4
        movd    %ttb_12,TEMP2
        call    @run_celllist
        br      @fdone_1_11
gen_1_11:
        clr     A
        sta     @ANIM_NEW
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        add     %5,A     ; frame x_off
        cmp     %40,A
        jl      @nx_g1_11
        mov     %39,A
nx_g1_11:
        mov     A,TEMP4
        movd    %dtb_12,TEMP2
        call    @run_celllist
fdone_1_11:
        lda     @PLAYER_X
        add     %5,A     ; include frame x_off
        cmp     %40,A
        jl      @px_1_11
        mov     %39,A          ; clamp like the draw
px_1_11:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %3,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %2,A       ; frame duration
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d1_11_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d1_11_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d1_11_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d1_11_exit
        cmp     %$81,A
        jeq     @d1_11_nk
        cmp     %$72,A
        jeq     @d1_11_nk
        cmp     %$52,A
        jeq     @d1_11_nk
d1_11_exit:
        lda     @PLAYER_X
        add     %5,A     ; fold x_off (exit mid-cycle)
        cmp     %39,A
        jl      @dxf_1_11
        mov     %38,A
dxf_1_11:
        sta     @PLAYER_X
        rets
d1_11_nk:
; Frame 12 id=16 x_off=6 (transition from frame 11, dx=1)
        lda     @PLAYER_X
        add     %6,A     ; frame x_off
        cmp     %40,A
        jl      @nx_t1_12
        mov     %39,A
nx_t1_12:
        mov     A,TEMP4
        movd    %ttb_13,TEMP2
        call    @run_celllist
        br      @fdone_1_12
gen_1_12:
        clr     A
        sta     @ANIM_NEW
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        add     %6,A     ; frame x_off
        cmp     %40,A
        jl      @nx_g1_12
        mov     %39,A
nx_g1_12:
        mov     A,TEMP4
        movd    %dtb_13,TEMP2
        call    @run_celllist
fdone_1_12:
        lda     @PLAYER_X
        add     %6,A     ; include frame x_off
        cmp     %40,A
        jl      @px_1_12
        mov     %39,A          ; clamp like the draw
px_1_12:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %4,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %2,A       ; frame duration
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d1_12_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d1_12_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d1_12_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d1_12_exit
        cmp     %$81,A
        jeq     @d1_12_nk
        cmp     %$72,A
        jeq     @d1_12_nk
        cmp     %$52,A
        jeq     @d1_12_nk
d1_12_exit:
        lda     @PLAYER_X
        add     %6,A     ; fold x_off (exit mid-cycle)
        cmp     %39,A
        jl      @dxf_1_12
        mov     %38,A
dxf_1_12:
        sta     @PLAYER_X
        rets
d1_12_nk:
; Frame 13 id=10 x_off=6 (transition from frame 12, dx=0)
        lda     @PLAYER_X
        add     %6,A     ; frame x_off
        cmp     %40,A
        jl      @nx_t1_13
        mov     %39,A
nx_t1_13:
        mov     A,TEMP4
        movd    %ttb_14,TEMP2
        call    @run_celllist
        br      @fdone_1_13
gen_1_13:
        clr     A
        sta     @ANIM_NEW
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        add     %6,A     ; frame x_off
        cmp     %40,A
        jl      @nx_g1_13
        mov     %39,A
nx_g1_13:
        mov     A,TEMP4
        movd    %dtb_14,TEMP2
        call    @run_celllist
fdone_1_13:
        lda     @PLAYER_X
        add     %6,A     ; include frame x_off
        cmp     %40,A
        jl      @px_1_13
        mov     %39,A          ; clamp like the draw
px_1_13:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %3,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %2,A       ; frame duration
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d1_13_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d1_13_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d1_13_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d1_13_exit
        cmp     %$81,A
        jeq     @d1_13_nk
        cmp     %$72,A
        jeq     @d1_13_nk
        cmp     %$52,A
        jeq     @d1_13_nk
d1_13_exit:
        lda     @PLAYER_X
        add     %6,A     ; fold x_off (exit mid-cycle)
        cmp     %39,A
        jl      @dxf_1_13
        mov     %38,A
dxf_1_13:
        sta     @PLAYER_X
        rets
d1_13_nk:
; Frame 14 id=11 x_off=7 (transition from frame 13, dx=1)
        lda     @PLAYER_X
        add     %7,A     ; frame x_off
        cmp     %40,A
        jl      @nx_t1_14
        mov     %39,A
nx_t1_14:
        mov     A,TEMP4
        movd    %ttb_15,TEMP2
        call    @run_celllist
        br      @fdone_1_14
gen_1_14:
        clr     A
        sta     @ANIM_NEW
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        add     %7,A     ; frame x_off
        cmp     %40,A
        jl      @nx_g1_14
        mov     %39,A
nx_g1_14:
        mov     A,TEMP4
        movd    %dtb_8,TEMP2
        call    @run_celllist
fdone_1_14:
        lda     @PLAYER_X
        add     %7,A     ; include frame x_off
        cmp     %40,A
        jl      @px_1_14
        mov     %39,A          ; clamp like the draw
px_1_14:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %4,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %2,A       ; frame duration
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d1_14_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d1_14_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d1_14_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d1_14_exit
        cmp     %$81,A
        jeq     @d1_14_nk
        cmp     %$72,A
        jeq     @d1_14_nk
        cmp     %$52,A
        jeq     @d1_14_nk
d1_14_exit:
        lda     @PLAYER_X
        add     %7,A     ; fold x_off (exit mid-cycle)
        cmp     %39,A
        jl      @dxf_1_14
        mov     %38,A
dxf_1_14:
        sta     @PLAYER_X
        rets
d1_14_nk:
; Frame 15 id=12 x_off=7 (transition from frame 14, dx=0)
        lda     @PLAYER_X
        add     %7,A     ; frame x_off
        cmp     %40,A
        jl      @nx_t1_15
        mov     %39,A
nx_t1_15:
        mov     A,TEMP4
        movd    %ttb_16,TEMP2
        call    @run_celllist
        br      @fdone_1_15
gen_1_15:
        clr     A
        sta     @ANIM_NEW
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        add     %7,A     ; frame x_off
        cmp     %40,A
        jl      @nx_g1_15
        mov     %39,A
nx_g1_15:
        mov     A,TEMP4
        movd    %dtb_15,TEMP2
        call    @run_celllist
fdone_1_15:
        lda     @PLAYER_X
        add     %7,A     ; include frame x_off
        cmp     %40,A
        jl      @px_1_15
        mov     %39,A          ; clamp like the draw
px_1_15:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %4,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %2,A       ; frame duration
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d1_15_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d1_15_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d1_15_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d1_15_exit
        cmp     %$81,A
        jeq     @d1_15_nk
        cmp     %$72,A
        jeq     @d1_15_nk
        cmp     %$52,A
        jeq     @d1_15_nk
d1_15_exit:
        lda     @PLAYER_X
        add     %7,A     ; fold x_off (exit mid-cycle)
        cmp     %39,A
        jl      @dxf_1_15
        mov     %38,A
dxf_1_15:
        sta     @PLAYER_X
        rets
d1_15_nk:
; Frame 16 id=15 x_off=8 (transition from frame 15, dx=1)
        lda     @PLAYER_X
        add     %8,A     ; frame x_off
        cmp     %40,A
        jl      @nx_t1_16
        mov     %39,A
nx_t1_16:
        mov     A,TEMP4
        movd    %ttb_17,TEMP2
        call    @run_celllist
        br      @fdone_1_16
gen_1_16:
        clr     A
        sta     @ANIM_NEW
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        add     %8,A     ; frame x_off
        cmp     %40,A
        jl      @nx_g1_16
        mov     %39,A
nx_g1_16:
        mov     A,TEMP4
        movd    %dtb_16,TEMP2
        call    @run_celllist
fdone_1_16:
        lda     @PLAYER_X
        add     %8,A     ; include frame x_off
        cmp     %40,A
        jl      @px_1_16
        mov     %39,A          ; clamp like the draw
px_1_16:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %3,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %2,A       ; frame duration
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d1_16_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d1_16_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d1_16_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d1_16_exit
        cmp     %$81,A
        jeq     @d1_16_nk
        cmp     %$72,A
        jeq     @d1_16_nk
        cmp     %$52,A
        jeq     @d1_16_nk
d1_16_exit:
        lda     @PLAYER_X
        add     %8,A     ; fold x_off (exit mid-cycle)
        cmp     %39,A
        jl      @dxf_1_16
        mov     %38,A
dxf_1_16:
        sta     @PLAYER_X
        rets
d1_16_nk:
; Frame 17 id=16 x_off=8 (transition from frame 16, dx=0)
        lda     @PLAYER_X
        add     %8,A     ; frame x_off
        cmp     %40,A
        jl      @nx_t1_17
        mov     %39,A
nx_t1_17:
        mov     A,TEMP4
        movd    %ttb_18,TEMP2
        call    @run_celllist
        br      @fdone_1_17
gen_1_17:
        clr     A
        sta     @ANIM_NEW
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        add     %8,A     ; frame x_off
        cmp     %40,A
        jl      @nx_g1_17
        mov     %39,A
nx_g1_17:
        mov     A,TEMP4
        movd    %dtb_13,TEMP2
        call    @run_celllist
fdone_1_17:
        lda     @PLAYER_X
        add     %8,A     ; include frame x_off
        cmp     %40,A
        jl      @px_1_17
        mov     %39,A          ; clamp like the draw
px_1_17:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %4,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %2,A       ; frame duration
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d1_17_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d1_17_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d1_17_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d1_17_exit
        cmp     %$81,A
        jeq     @d1_17_nk
        cmp     %$72,A
        jeq     @d1_17_nk
        cmp     %$52,A
        jeq     @d1_17_nk
d1_17_exit:
        lda     @PLAYER_X
        add     %8,A     ; fold x_off (exit mid-cycle)
        cmp     %39,A
        jl      @dxf_1_17
        mov     %38,A
dxf_1_17:
        sta     @PLAYER_X
        rets
d1_17_nk:
; Frame 18 id=10 x_off=9 (transition from frame 17, dx=1)
        lda     @PLAYER_X
        add     %9,A     ; frame x_off
        cmp     %40,A
        jl      @nx_t1_18
        mov     %39,A
nx_t1_18:
        mov     A,TEMP4
        movd    %ttb_19,TEMP2
        call    @run_celllist
        br      @fdone_1_18
gen_1_18:
        clr     A
        sta     @ANIM_NEW
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        add     %9,A     ; frame x_off
        cmp     %40,A
        jl      @nx_g1_18
        mov     %39,A
nx_g1_18:
        mov     A,TEMP4
        movd    %dtb_14,TEMP2
        call    @run_celllist
fdone_1_18:
        lda     @PLAYER_X
        add     %9,A     ; include frame x_off
        cmp     %40,A
        jl      @px_1_18
        mov     %39,A          ; clamp like the draw
px_1_18:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %3,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %2,A       ; frame duration
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d1_18_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d1_18_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d1_18_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d1_18_exit
        cmp     %$81,A
        jeq     @d1_18_nk
        cmp     %$72,A
        jeq     @d1_18_nk
        cmp     %$52,A
        jeq     @d1_18_nk
d1_18_exit:
        lda     @PLAYER_X
        add     %9,A     ; fold x_off (exit mid-cycle)
        cmp     %39,A
        jl      @dxf_1_18
        mov     %38,A
dxf_1_18:
        sta     @PLAYER_X
        rets
d1_18_nk:
; Frame 19 id=11 x_off=9 (transition from frame 18, dx=0)
        lda     @PLAYER_X
        add     %9,A     ; frame x_off
        cmp     %40,A
        jl      @nx_t1_19
        mov     %39,A
nx_t1_19:
        mov     A,TEMP4
        movd    %ttb_20,TEMP2
        call    @run_celllist
        br      @fdone_1_19
gen_1_19:
        clr     A
        sta     @ANIM_NEW
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        add     %9,A     ; frame x_off
        cmp     %40,A
        jl      @nx_g1_19
        mov     %39,A
nx_g1_19:
        mov     A,TEMP4
        movd    %dtb_8,TEMP2
        call    @run_celllist
fdone_1_19:
        lda     @PLAYER_X
        add     %9,A     ; include frame x_off
        cmp     %40,A
        jl      @px_1_19
        mov     %39,A          ; clamp like the draw
px_1_19:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %4,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %2,A       ; frame duration
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d1_19_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d1_19_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d1_19_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d1_19_exit
        cmp     %$81,A
        jeq     @d1_19_nk
        cmp     %$72,A
        jeq     @d1_19_nk
        cmp     %$52,A
        jeq     @d1_19_nk
d1_19_exit:
        lda     @PLAYER_X
        add     %9,A     ; fold x_off (exit mid-cycle)
        cmp     %39,A
        jl      @dxf_1_19
        mov     %38,A
dxf_1_19:
        sta     @PLAYER_X
        rets
d1_19_nk:
; Frame 20 id=15 x_off=10 (transition from frame 19, dx=1)
        lda     @PLAYER_X
        add     %10,A     ; frame x_off
        cmp     %40,A
        jl      @nx_t1_20
        mov     %39,A
nx_t1_20:
        mov     A,TEMP4
        movd    %ttb_21,TEMP2
        call    @run_celllist
        br      @fdone_1_20
gen_1_20:
        clr     A
        sta     @ANIM_NEW
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        add     %10,A     ; frame x_off
        cmp     %40,A
        jl      @nx_g1_20
        mov     %39,A
nx_g1_20:
        mov     A,TEMP4
        movd    %dtb_17,TEMP2
        call    @run_celllist
fdone_1_20:
        lda     @PLAYER_X
        add     %10,A     ; include frame x_off
        cmp     %40,A
        jl      @px_1_20
        mov     %39,A          ; clamp like the draw
px_1_20:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %3,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %2,A       ; frame duration
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d1_20_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d1_20_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d1_20_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d1_20_exit
        cmp     %$81,A
        jeq     @d1_20_nk
        cmp     %$72,A
        jeq     @d1_20_nk
        cmp     %$52,A
        jeq     @d1_20_nk
d1_20_exit:
        lda     @PLAYER_X
        add     %10,A     ; fold x_off (exit mid-cycle)
        cmp     %39,A
        jl      @dxf_1_20
        mov     %38,A
dxf_1_20:
        sta     @PLAYER_X
        rets
d1_20_nk:
; Frame 21 id=16 x_off=10 (transition from frame 20, dx=0)
        lda     @PLAYER_X
        add     %10,A     ; frame x_off
        cmp     %40,A
        jl      @nx_t1_21
        mov     %39,A
nx_t1_21:
        mov     A,TEMP4
        movd    %ttb_22,TEMP2
        call    @run_celllist
        br      @fdone_1_21
gen_1_21:
        clr     A
        sta     @ANIM_NEW
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        add     %10,A     ; frame x_off
        cmp     %40,A
        jl      @nx_g1_21
        mov     %39,A
nx_g1_21:
        mov     A,TEMP4
        movd    %dtb_13,TEMP2
        call    @run_celllist
fdone_1_21:
        lda     @PLAYER_X
        add     %10,A     ; include frame x_off
        cmp     %40,A
        jl      @px_1_21
        mov     %39,A          ; clamp like the draw
px_1_21:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %4,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %2,A       ; frame duration
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d1_21_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d1_21_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d1_21_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d1_21_exit
        cmp     %$81,A
        jeq     @d1_21_nk
        cmp     %$72,A
        jeq     @d1_21_nk
        cmp     %$52,A
        jeq     @d1_21_nk
d1_21_exit:
        lda     @PLAYER_X
        add     %10,A     ; fold x_off (exit mid-cycle)
        cmp     %39,A
        jl      @dxf_1_21
        mov     %38,A
dxf_1_21:
        sta     @PLAYER_X
        rets
d1_21_nk:
; Frame 22 id=10 x_off=11 (transition from frame 21, dx=1)
        lda     @PLAYER_X
        add     %11,A     ; frame x_off
        cmp     %40,A
        jl      @nx_t1_22
        mov     %39,A
nx_t1_22:
        mov     A,TEMP4
        movd    %ttb_19,TEMP2
        call    @run_celllist
        br      @fdone_1_22
gen_1_22:
        clr     A
        sta     @ANIM_NEW
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        add     %11,A     ; frame x_off
        cmp     %40,A
        jl      @nx_g1_22
        mov     %39,A
nx_g1_22:
        mov     A,TEMP4
        movd    %dtb_14,TEMP2
        call    @run_celllist
fdone_1_22:
        lda     @PLAYER_X
        add     %11,A     ; include frame x_off
        cmp     %40,A
        jl      @px_1_22
        mov     %39,A          ; clamp like the draw
px_1_22:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %3,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %2,A       ; frame duration
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d1_22_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d1_22_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d1_22_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d1_22_exit
        cmp     %$81,A
        jeq     @d1_22_nk
        cmp     %$72,A
        jeq     @d1_22_nk
        cmp     %$52,A
        jeq     @d1_22_nk
d1_22_exit:
        lda     @PLAYER_X
        add     %11,A     ; fold x_off (exit mid-cycle)
        cmp     %39,A
        jl      @dxf_1_22
        mov     %38,A
dxf_1_22:
        sta     @PLAYER_X
        rets
d1_22_nk:
; Frame 23 id=11 x_off=11 (transition from frame 22, dx=0)
        lda     @PLAYER_X
        add     %11,A     ; frame x_off
        cmp     %40,A
        jl      @nx_t1_23
        mov     %39,A
nx_t1_23:
        mov     A,TEMP4
        movd    %ttb_20,TEMP2
        call    @run_celllist
        br      @fdone_1_23
gen_1_23:
        clr     A
        sta     @ANIM_NEW
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        add     %11,A     ; frame x_off
        cmp     %40,A
        jl      @nx_g1_23
        mov     %39,A
nx_g1_23:
        mov     A,TEMP4
        movd    %dtb_8,TEMP2
        call    @run_celllist
fdone_1_23:
        lda     @PLAYER_X
        add     %11,A     ; include frame x_off
        cmp     %40,A
        jl      @px_1_23
        mov     %39,A          ; clamp like the draw
px_1_23:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %4,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %2,A       ; frame duration
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d1_23_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d1_23_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d1_23_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d1_23_exit
        cmp     %$81,A
        jeq     @d1_23_nk
        cmp     %$72,A
        jeq     @d1_23_nk
        cmp     %$52,A
        jeq     @d1_23_nk
d1_23_exit:
        lda     @PLAYER_X
        add     %11,A     ; fold x_off (exit mid-cycle)
        cmp     %39,A
        jl      @dxf_1_23
        mov     %38,A
dxf_1_23:
        sta     @PLAYER_X
        rets
d1_23_nk:
        rets
fs_fold_1:          ; A = PLAYER_X (from the wrap guard)
        add     %11,A
        cmp     %39,A
        jl      @fsf2_1
        mov     %38,A
fsf2_1:
        sta     @PLAYER_X      ; X now ≈ drawn col → STAND entry matches
fs_hold_1:
        mov     %FRAMES_PER_STEP,A
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A
        cmp     %$81,A
        jeq     @fs_hold_1  ; still pressing into the wall
        cmp     %$72,A
        jeq     @fs_hold_1  ; still pressing into the wall
        cmp     %$52,A
        jeq     @fs_hold_1  ; still pressing into the wall
        rets                   ; released / other key → dispatch

; ── Animation: STAND (key=NONE) ──────────
play_anim_2:
        lda     @ANIM_NEW
        jz      @play_anim_2_nodelay  ; already on screen → just wait for key
; Frame 0 id=18 x_off=0 (transition from frame 0, dx=0)
        lda     @ANIM_NEW
        jnz     @gen_2_0      ; cross-animation entry → generic redraw
        lda     @PLAYER_X
        cmp     %40,A
        jl      @nx_t2_0
        mov     %39,A
nx_t2_0:
        mov     A,TEMP4
        movd    %ttb_23,TEMP2
        call    @run_celllist
        br      @fdone_2_0
gen_2_0:
        clr     A
        sta     @ANIM_NEW
        lda     @PREV_X
        mov     A,TEMP4        ; erase base col = PREV_X
        lda     @PREV_COLS
        call    @erase_n_cols  ; erase PREV_COLS cols at TEMP4
        lda     @PLAYER_X
        cmp     %40,A
        jl      @nx_g2_0
        mov     %39,A
nx_g2_0:
        mov     A,TEMP4
        movd    %dtb_0,TEMP2
        call    @run_celllist
fdone_2_0:
        lda     @PLAYER_X
        cmp     %40,A
        jl      @px_2_0
        mov     %39,A          ; clamp like the draw
px_2_0:
        sta     @PREV_X        ; where sprite was actually drawn
        mov     %2,A
        sta     @PREV_COLS     ; width of drawn sprite
        mov     %FRAMES_PER_STEP,A
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A       ; check key after frame delay
        cmp     %KEY_NONE_EXL,A
        jeq     @d2_0_exit
        cmp     %KEY_NONE_EXT,A
        jeq     @d2_0_exit
        cmp     %KEY_NONE_REL,A
        jeq     @d2_0_exit
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @d2_0_exit
d2_0_exit:
        rets
d2_0_nk:
        rets
play_anim_2_nodelay:
        mov     %FRAMES_PER_STEP,A
        sta     @FRAME_CTR
        call    @wait_frames
        mov     VALUE0,A
        cmp     %KEY_NONE_EXL,A
        jeq     @play_anim_2_nodelay  ; still no key, keep waiting
        cmp     %KEY_NONE_EXT,A
        jeq     @play_anim_2_nodelay
        cmp     %KEY_NONE_REL,A
        jeq     @play_anim_2_nodelay
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @play_anim_2_nodelay
        rets

; ═══ Runtime cell executors (v11): op tables replace unrolled code ═══════
; run_celllist: TEMP2 pair = table addr, TEMP4 = base column.
; Op = 4 bytes [colOff, absRow, attr, code]; attr $FF = restore background;
; $80 in colOff position = end of table.
run_celllist:
        dint           ; ROM IRQ clobbers R5+ — protect table walk + VDP writes
        mov     TEMP2-1,A
        sta     @OP_PH
        mov     TEMP2,A
        sta     @OP_PL
rcl_loop:
        lda     @OP_PH
        mov     A,TEMP2-1
        lda     @OP_PL
        mov     A,TEMP2
        lda     *TEMP2         ; byte0: colOff or $80 end
        cmp     %$80,A
        jeq     @rcl_done
        sta     @OP_B0
        add     %1,TEMP2       ; 16-bit pointer++ (no INCD on TMS7000)
        adc     %0,TEMP2-1
        lda     *TEMP2         ; byte1: absolute row
        sta     @OP_ROW
        add     %1,TEMP2       ; 16-bit pointer++ (no INCD on TMS7000)
        adc     %0,TEMP2-1
        lda     *TEMP2         ; byte2: attr ($FF = background restore)
        sta     @OP_ATTR
        add     %1,TEMP2       ; 16-bit pointer++ (no INCD on TMS7000)
        adc     %0,TEMP2-1
        lda     *TEMP2         ; byte3: char code
        sta     @OP_CODE
        add     %1,TEMP2       ; 16-bit pointer++ (no INCD on TMS7000)
        adc     %0,TEMP2-1
        mov     TEMP2-1,A      ; save advanced pointer
        sta     @OP_PH
        mov     TEMP2,A
        sta     @OP_PL
        lda     @OP_B0
        add     TEMP4,A        ; absolute column (signed offset wraps)
        cmp     %40,A
        jhs     @rcl_loop      ; off-screen (incl. negative wrap) → skip
        mov     A,B
        lda     @OP_ATTR
        cmp     %$FF,A
        jeq     @rcl_bg
        lda     @OP_ROW
        call    @calcul_pointer
        #DEFINE Fcalcul_pointer
        movd    TEMP3,TEMP1
        trap    9
        lda     @OP_ATTR
        wvdp(A)
        lda     @OP_CODE
        wvdp(A)
        br      @rcl_loop
rcl_bg:
        lda     @OP_ROW
        call    @bg_restore_cell
        br      @rcl_loop
rcl_done:
        eint
        rets

; bg_restore_cell: A = absolute row, B = column → repaint one background cell
; (shared by transitions, generic erase, and level init)
bg_restore_cell:
        sta     @BG_ROW
        mov     B,A
        sta     @BG_COL
        lda     @BG_COL
        mov     A,B
        lda     @BG_ROW
        call    @calcul_pointer
        movd    TEMP3,TEMP1
        trap    9
        movd    %LEVEL_MAP,TEMP2
        lda     @BG_ROW
        mpy     %40,A          ; A:B = row*40 (MPY: 16-bit product in A:B)
        add     R1,TEMP2       ; R1 = B (row*40 low)
        adc     R0,TEMP2-1     ; R0 = A (row*40 high)
        lda     @BG_COL
        add     R0,TEMP2       ; R0 = A (col)
        adc     %0,TEMP2-1
        lda     *TEMP2         ; tile index from LEVEL_MAP
        cmp     %$FF,A
        jne     @bgc_tile
        mov     %$10,A         ; air → BAGC1 blank
        wvdp(A)
        mov     %$7F,A
        wvdp(A)
        rets
bgc_tile:
        clrc
        rl      A              ; ×2 for TILE_CHARS (attr,char)
        mov     A,B
        lda     @TILE_CHARS(B)
        wvdp(A)
        lda     @TILE_CHARS+1(B)
        wvdp(A)
        rets

; Generic erase: A = width in cols, TEMP4 = base col — repaint background
erase_n_cols:
        dint
        sta     @EW
        cmp     %0,A
        jeq     @en_done       ; width 0 = nothing drawn yet
        clr     A
        sta     @ER_C
en_col:
        clr     A
        sta     @ER_R
en_row:
        lda     @ER_C
        add     TEMP4,A
        cmp     %40,A
        jhs     @en_next       ; off-screen col → skip
        mov     A,B
        lda     @ER_R
        add     %8,A     ; + sprite top row
        call    @bg_restore_cell
en_next:
        lda     @ER_R
        inc     A
        sta     @ER_R
        cmp     %8,A
        jl      @en_row
        lda     @ER_C
        inc     A
        sta     @ER_C
        cmpa    @EW
        jl      @en_col
en_done:
        eint
        rets

; ── Draw tables (18) — full draws for cross-anim entry ──────────
; celllist: full draw 2×8 (10 ops, 41 bytes)
dtb_0:
        .byte   $00,$0B,$F0,$00
        .byte   $00,$0C,$F0,$01
        .byte   $00,$0D,$F0,$02
        .byte   $00,$0E,$F0,$03
        .byte   $00,$0F,$F0,$04
        .byte   $01,$0B,$F0,$05
        .byte   $01,$0C,$F0,$06
        .byte   $01,$0D,$F0,$07
        .byte   $01,$0E,$F0,$08
        .byte   $01,$0F,$F0,$09
        .byte   $80            ; end of list

; celllist: full draw 2×8 (9 ops, 37 bytes)
dtb_1:
        .byte   $00,$0C,$F0,$0A
        .byte   $00,$0D,$F0,$0B
        .byte   $00,$0E,$F0,$0C
        .byte   $00,$0F,$F0,$0D
        .byte   $01,$0B,$F0,$0E
        .byte   $01,$0C,$F0,$0F
        .byte   $01,$0D,$F0,$10
        .byte   $01,$0E,$F0,$11
        .byte   $01,$0F,$F0,$12
        .byte   $80            ; end of list

; celllist: full draw 3×8 (11 ops, 45 bytes)
dtb_2:
        .byte   $00,$0D,$F0,$13
        .byte   $00,$0E,$F0,$14
        .byte   $00,$0F,$F0,$15
        .byte   $01,$0C,$F0,$16
        .byte   $01,$0D,$F0,$17
        .byte   $01,$0E,$F0,$18
        .byte   $01,$0F,$F0,$19
        .byte   $02,$0C,$F0,$1A
        .byte   $02,$0D,$F0,$1B
        .byte   $02,$0E,$F0,$1C
        .byte   $02,$0F,$F0,$1D
        .byte   $80            ; end of list

; celllist: full draw 4×8 (11 ops, 45 bytes)
dtb_3:
        .byte   $00,$0E,$F0,$13
        .byte   $00,$0F,$F0,$1E
        .byte   $01,$0D,$F0,$1F
        .byte   $01,$0E,$F0,$21
        .byte   $01,$0F,$F0,$22
        .byte   $02,$0C,$F0,$23
        .byte   $02,$0D,$F0,$24
        .byte   $02,$0E,$F0,$25
        .byte   $02,$0F,$F0,$26
        .byte   $03,$0C,$F0,$27
        .byte   $03,$0F,$F0,$28
        .byte   $80            ; end of list

; celllist: full draw 3×8 (9 ops, 37 bytes)
dtb_4:
        .byte   $00,$0F,$F0,$29
        .byte   $01,$0C,$F0,$2A
        .byte   $01,$0D,$F0,$2B
        .byte   $01,$0E,$F0,$2C
        .byte   $01,$0F,$F0,$2D
        .byte   $02,$0C,$F0,$2E
        .byte   $02,$0D,$F0,$2F
        .byte   $02,$0E,$F0,$30
        .byte   $02,$0F,$F0,$31
        .byte   $80            ; end of list

; celllist: full draw 3×8 (8 ops, 33 bytes)
dtb_5:
        .byte   $00,$0F,$F0,$32
        .byte   $01,$0D,$F0,$33
        .byte   $01,$0E,$F0,$34
        .byte   $01,$0F,$F0,$35
        .byte   $02,$0C,$F0,$36
        .byte   $02,$0D,$F0,$37
        .byte   $02,$0E,$F0,$38
        .byte   $02,$0F,$F0,$39
        .byte   $80            ; end of list

; celllist: full draw 4×8 (13 ops, 53 bytes)
dtb_6:
        .byte   $00,$0E,$F0,$3A
        .byte   $00,$0F,$F0,$3B
        .byte   $01,$0D,$F0,$3C
        .byte   $01,$0E,$F0,$3D
        .byte   $01,$0F,$F0,$3E
        .byte   $02,$0C,$F0,$3F
        .byte   $02,$0D,$F0,$40
        .byte   $02,$0E,$F0,$41
        .byte   $02,$0F,$F0,$42
        .byte   $03,$0C,$F0,$43
        .byte   $03,$0D,$F0,$44
        .byte   $03,$0E,$F0,$45
        .byte   $03,$0F,$F0,$46
        .byte   $80            ; end of list

; celllist: full draw 3×8 (10 ops, 41 bytes)
dtb_7:
        .byte   $00,$0E,$F0,$47
        .byte   $00,$0F,$F0,$48
        .byte   $01,$0C,$F0,$49
        .byte   $01,$0D,$F0,$4A
        .byte   $01,$0E,$F0,$4B
        .byte   $01,$0F,$F0,$4C
        .byte   $02,$0C,$F0,$4D
        .byte   $02,$0D,$F0,$4E
        .byte   $02,$0E,$F0,$4F
        .byte   $02,$0F,$F0,$50
        .byte   $80            ; end of list

; celllist: full draw 4×8 (11 ops, 45 bytes)
dtb_8:
        .byte   $00,$0E,$F0,$3A
        .byte   $00,$0F,$F0,$51
        .byte   $01,$0D,$F0,$52
        .byte   $01,$0E,$F0,$53
        .byte   $01,$0F,$F0,$54
        .byte   $02,$0C,$F0,$55
        .byte   $02,$0D,$F0,$56
        .byte   $02,$0E,$F0,$57
        .byte   $02,$0F,$F0,$58
        .byte   $03,$0C,$F0,$59
        .byte   $03,$0F,$F0,$5A
        .byte   $80            ; end of list

; celllist: full draw 4×8 (11 ops, 45 bytes)
dtb_9:
        .byte   $00,$0F,$F0,$5B
        .byte   $01,$0E,$F0,$5C
        .byte   $01,$0F,$F0,$5D
        .byte   $02,$0C,$F0,$5E
        .byte   $02,$0D,$F0,$5F
        .byte   $02,$0E,$F0,$60
        .byte   $02,$0F,$F0,$61
        .byte   $03,$0C,$F0,$62
        .byte   $03,$0D,$F0,$63
        .byte   $03,$0E,$F0,$64
        .byte   $03,$0F,$F0,$65
        .byte   $80            ; end of list

; celllist: full draw 5×8 (13 ops, 53 bytes)
dtb_10:
        .byte   $00,$0E,$F0,$13
        .byte   $00,$0F,$F0,$66
        .byte   $01,$0E,$F0,$67
        .byte   $01,$0F,$F0,$68
        .byte   $02,$0D,$F0,$69
        .byte   $02,$0E,$F0,$6A
        .byte   $02,$0F,$F0,$6B
        .byte   $03,$0C,$F0,$6C
        .byte   $03,$0D,$F0,$6D
        .byte   $03,$0E,$F0,$6E
        .byte   $03,$0F,$F0,$6F
        .byte   $04,$0C,$F0,$70
        .byte   $04,$0F,$F0,$71
        .byte   $80            ; end of list

; celllist: full draw 3×8 (10 ops, 41 bytes)
dtb_11:
        .byte   $00,$0D,$F0,$72
        .byte   $00,$0E,$F0,$73
        .byte   $00,$0F,$F0,$74
        .byte   $01,$0C,$F0,$75
        .byte   $01,$0D,$F0,$76
        .byte   $01,$0E,$F0,$77
        .byte   $01,$0F,$F0,$78
        .byte   $02,$0C,$F0,$79
        .byte   $02,$0D,$F0,$7A
        .byte   $02,$0F,$F0,$7B
        .byte   $80            ; end of list

; celllist: full draw 3×8 (10 ops, 41 bytes)
dtb_12:
        .byte   $00,$0D,$F0,$7C
        .byte   $00,$0F,$F0,$7D
        .byte   $01,$0C,$F0,$7E
        .byte   $01,$0D,$E8,$00
        .byte   $01,$0E,$E8,$01
        .byte   $01,$0F,$E8,$02
        .byte   $02,$0C,$E8,$03
        .byte   $02,$0D,$E8,$04
        .byte   $02,$0E,$E8,$05
        .byte   $02,$0F,$E8,$06
        .byte   $80            ; end of list

; celllist: full draw 4×8 (12 ops, 49 bytes)
dtb_13:
        .byte   $00,$0F,$E8,$07
        .byte   $01,$0D,$E8,$08
        .byte   $01,$0E,$E8,$09
        .byte   $01,$0F,$E8,$0A
        .byte   $02,$0C,$E8,$0B
        .byte   $02,$0D,$E8,$0C
        .byte   $02,$0E,$E8,$0D
        .byte   $02,$0F,$E8,$0E
        .byte   $03,$0C,$E8,$0F
        .byte   $03,$0D,$E8,$10
        .byte   $03,$0E,$E8,$11
        .byte   $03,$0F,$E8,$12
        .byte   $80            ; end of list

; celllist: full draw 3×8 (10 ops, 41 bytes)
dtb_14:
        .byte   $00,$0E,$E8,$13
        .byte   $00,$0F,$E8,$14
        .byte   $01,$0C,$F0,$13
        .byte   $01,$0D,$E8,$15
        .byte   $01,$0E,$E8,$16
        .byte   $01,$0F,$E8,$17
        .byte   $02,$0C,$E8,$18
        .byte   $02,$0D,$E8,$19
        .byte   $02,$0E,$E8,$1A
        .byte   $02,$0F,$E8,$1B
        .byte   $80            ; end of list

; celllist: full draw 4×8 (11 ops, 45 bytes)
dtb_15:
        .byte   $00,$0F,$E8,$1C
        .byte   $01,$0E,$F0,$5C
        .byte   $01,$0F,$F0,$5D
        .byte   $02,$0C,$F0,$5E
        .byte   $02,$0D,$F0,$5F
        .byte   $02,$0E,$F0,$60
        .byte   $02,$0F,$F0,$61
        .byte   $03,$0C,$F0,$62
        .byte   $03,$0D,$F0,$63
        .byte   $03,$0E,$F0,$64
        .byte   $03,$0F,$F0,$65
        .byte   $80            ; end of list

; celllist: full draw 3×8 (10 ops, 41 bytes)
dtb_16:
        .byte   $00,$0D,$F0,$7C
        .byte   $00,$0F,$E8,$1D
        .byte   $01,$0C,$F0,$7E
        .byte   $01,$0D,$E8,$00
        .byte   $01,$0E,$E8,$01
        .byte   $01,$0F,$E8,$02
        .byte   $02,$0C,$E8,$03
        .byte   $02,$0D,$E8,$04
        .byte   $02,$0E,$E8,$05
        .byte   $02,$0F,$E8,$1E
        .byte   $80            ; end of list

; celllist: full draw 3×8 (10 ops, 41 bytes)
dtb_17:
        .byte   $00,$0D,$F0,$7C
        .byte   $00,$0F,$E8,$1F
        .byte   $01,$0C,$F0,$7E
        .byte   $01,$0D,$E8,$00
        .byte   $01,$0E,$E8,$01
        .byte   $01,$0F,$E8,$02
        .byte   $02,$0C,$E8,$03
        .byte   $02,$0D,$E8,$04
        .byte   $02,$0E,$E8,$05
        .byte   $02,$0F,$E8,$21
        .byte   $80            ; end of list

; ── Transition tables (24) — single-pass updates, no flicker ────
; celllist: transition id=17→17 dx=-1 (15 ops, 61 bytes)
ttb_0:
        .byte   $00,$0B,$F0,$00
        .byte   $00,$0C,$F0,$01
        .byte   $00,$0D,$F0,$02
        .byte   $00,$0E,$F0,$03
        .byte   $00,$0F,$F0,$04
        .byte   $01,$0B,$F0,$05
        .byte   $01,$0C,$F0,$06
        .byte   $01,$0D,$F0,$07
        .byte   $01,$0E,$F0,$08
        .byte   $01,$0F,$F0,$09
        .byte   $02,$0B,$FF,$00
        .byte   $02,$0C,$FF,$00
        .byte   $02,$0D,$FF,$00
        .byte   $02,$0E,$FF,$00
        .byte   $02,$0F,$FF,$00
        .byte   $80            ; end of list

; celllist: transition id=11→3 dx=0 (15 ops, 61 bytes)
ttb_1:
        .byte   $00,$0C,$F0,$0A
        .byte   $00,$0D,$F0,$0B
        .byte   $00,$0E,$F0,$0C
        .byte   $00,$0F,$F0,$0D
        .byte   $01,$0B,$F0,$0E
        .byte   $01,$0C,$F0,$0F
        .byte   $01,$0D,$F0,$10
        .byte   $01,$0E,$F0,$11
        .byte   $01,$0F,$F0,$12
        .byte   $02,$0C,$FF,$00
        .byte   $02,$0D,$FF,$00
        .byte   $02,$0E,$FF,$00
        .byte   $02,$0F,$FF,$00
        .byte   $03,$0C,$FF,$00
        .byte   $03,$0F,$FF,$00
        .byte   $80            ; end of list

; celllist: transition id=3→5 dx=0 (13 ops, 53 bytes)
ttb_2:
        .byte   $00,$0C,$FF,$00
        .byte   $00,$0D,$F0,$13
        .byte   $00,$0E,$F0,$14
        .byte   $00,$0F,$F0,$15
        .byte   $01,$0B,$FF,$00
        .byte   $01,$0C,$F0,$16
        .byte   $01,$0D,$F0,$17
        .byte   $01,$0E,$F0,$18
        .byte   $01,$0F,$F0,$19
        .byte   $02,$0C,$F0,$1A
        .byte   $02,$0D,$F0,$1B
        .byte   $02,$0E,$F0,$1C
        .byte   $02,$0F,$F0,$1D
        .byte   $80            ; end of list

; celllist: transition id=5→6 dx=1 (17 ops, 69 bytes)
ttb_3:
        .byte   $FF,$0D,$FF,$00
        .byte   $FF,$0E,$FF,$00
        .byte   $FF,$0F,$FF,$00
        .byte   $00,$0C,$FF,$00
        .byte   $00,$0D,$FF,$00
        .byte   $00,$0E,$F0,$13
        .byte   $00,$0F,$F0,$1E
        .byte   $01,$0C,$FF,$00
        .byte   $01,$0D,$F0,$1F
        .byte   $01,$0E,$F0,$21
        .byte   $01,$0F,$F0,$22
        .byte   $02,$0C,$F0,$23
        .byte   $02,$0D,$F0,$24
        .byte   $02,$0E,$F0,$25
        .byte   $02,$0F,$F0,$26
        .byte   $03,$0C,$F0,$27
        .byte   $03,$0F,$F0,$28
        .byte   $80            ; end of list

; celllist: transition id=6→7 dx=0 (12 ops, 49 bytes)
ttb_4:
        .byte   $00,$0E,$FF,$00
        .byte   $00,$0F,$F0,$29
        .byte   $01,$0C,$F0,$2A
        .byte   $01,$0D,$F0,$2B
        .byte   $01,$0E,$F0,$2C
        .byte   $01,$0F,$F0,$2D
        .byte   $02,$0C,$F0,$2E
        .byte   $02,$0D,$F0,$2F
        .byte   $02,$0E,$F0,$30
        .byte   $02,$0F,$F0,$31
        .byte   $03,$0C,$FF,$00
        .byte   $03,$0F,$FF,$00
        .byte   $80            ; end of list

; celllist: transition id=7→8 dx=1 (13 ops, 53 bytes)
ttb_5:
        .byte   $FF,$0F,$FF,$00
        .byte   $00,$0C,$FF,$00
        .byte   $00,$0D,$FF,$00
        .byte   $00,$0E,$FF,$00
        .byte   $00,$0F,$F0,$32
        .byte   $01,$0C,$FF,$00
        .byte   $01,$0D,$F0,$33
        .byte   $01,$0E,$F0,$34
        .byte   $01,$0F,$F0,$35
        .byte   $02,$0C,$F0,$36
        .byte   $02,$0D,$F0,$37
        .byte   $02,$0E,$F0,$38
        .byte   $02,$0F,$F0,$39
        .byte   $80            ; end of list

; celllist: transition id=8→9 dx=0 (13 ops, 53 bytes)
ttb_6:
        .byte   $00,$0E,$F0,$3A
        .byte   $00,$0F,$F0,$3B
        .byte   $01,$0D,$F0,$3C
        .byte   $01,$0E,$F0,$3D
        .byte   $01,$0F,$F0,$3E
        .byte   $02,$0C,$F0,$3F
        .byte   $02,$0D,$F0,$40
        .byte   $02,$0E,$F0,$41
        .byte   $02,$0F,$F0,$42
        .byte   $03,$0C,$F0,$43
        .byte   $03,$0D,$F0,$44
        .byte   $03,$0E,$F0,$45
        .byte   $03,$0F,$F0,$46
        .byte   $80            ; end of list

; celllist: transition id=9→10 dx=1 (13 ops, 53 bytes)
ttb_7:
        .byte   $FF,$0E,$FF,$00
        .byte   $FF,$0F,$FF,$00
        .byte   $00,$0D,$FF,$00
        .byte   $00,$0E,$F0,$47
        .byte   $00,$0F,$F0,$48
        .byte   $01,$0C,$F0,$49
        .byte   $01,$0D,$F0,$4A
        .byte   $01,$0E,$F0,$4B
        .byte   $01,$0F,$F0,$4C
        .byte   $02,$0C,$F0,$4D
        .byte   $02,$0D,$F0,$4E
        .byte   $02,$0E,$F0,$4F
        .byte   $02,$0F,$F0,$50
        .byte   $80            ; end of list

; celllist: transition id=10→11 dx=0 (12 ops, 49 bytes)
ttb_8:
        .byte   $00,$0E,$F0,$3A
        .byte   $00,$0F,$F0,$51
        .byte   $01,$0C,$FF,$00
        .byte   $01,$0D,$F0,$52
        .byte   $01,$0E,$F0,$53
        .byte   $01,$0F,$F0,$54
        .byte   $02,$0C,$F0,$55
        .byte   $02,$0D,$F0,$56
        .byte   $02,$0E,$F0,$57
        .byte   $02,$0F,$F0,$58
        .byte   $03,$0C,$F0,$59
        .byte   $03,$0F,$F0,$5A
        .byte   $80            ; end of list

; celllist: transition id=11→12 dx=1 (17 ops, 69 bytes)
ttb_9:
        .byte   $FF,$0E,$FF,$00
        .byte   $FF,$0F,$FF,$00
        .byte   $00,$0D,$FF,$00
        .byte   $00,$0E,$FF,$00
        .byte   $00,$0F,$F0,$5B
        .byte   $01,$0C,$FF,$00
        .byte   $01,$0D,$FF,$00
        .byte   $01,$0E,$F0,$5C
        .byte   $01,$0F,$F0,$5D
        .byte   $02,$0C,$F0,$5E
        .byte   $02,$0D,$F0,$5F
        .byte   $02,$0E,$F0,$60
        .byte   $02,$0F,$F0,$61
        .byte   $03,$0C,$F0,$62
        .byte   $03,$0D,$F0,$63
        .byte   $03,$0E,$F0,$64
        .byte   $03,$0F,$F0,$65
        .byte   $80            ; end of list

; celllist: transition id=12→13 dx=0 (14 ops, 57 bytes)
ttb_10:
        .byte   $00,$0E,$F0,$13
        .byte   $00,$0F,$F0,$66
        .byte   $01,$0E,$F0,$67
        .byte   $01,$0F,$F0,$68
        .byte   $02,$0C,$FF,$00
        .byte   $02,$0D,$F0,$69
        .byte   $02,$0E,$F0,$6A
        .byte   $02,$0F,$F0,$6B
        .byte   $03,$0C,$F0,$6C
        .byte   $03,$0D,$F0,$6D
        .byte   $03,$0E,$F0,$6E
        .byte   $03,$0F,$F0,$6F
        .byte   $04,$0C,$F0,$70
        .byte   $04,$0F,$F0,$71
        .byte   $80            ; end of list

; celllist: transition id=13→14 dx=1 (15 ops, 61 bytes)
ttb_11:
        .byte   $FF,$0E,$FF,$00
        .byte   $FF,$0F,$FF,$00
        .byte   $00,$0D,$F0,$72
        .byte   $00,$0E,$F0,$73
        .byte   $00,$0F,$F0,$74
        .byte   $01,$0C,$F0,$75
        .byte   $01,$0D,$F0,$76
        .byte   $01,$0E,$F0,$77
        .byte   $01,$0F,$F0,$78
        .byte   $02,$0C,$F0,$79
        .byte   $02,$0D,$F0,$7A
        .byte   $02,$0E,$FF,$00
        .byte   $02,$0F,$F0,$7B
        .byte   $03,$0C,$FF,$00
        .byte   $03,$0F,$FF,$00
        .byte   $80            ; end of list

; celllist: transition id=14→15 dx=0 (11 ops, 45 bytes)
ttb_12:
        .byte   $00,$0D,$F0,$7C
        .byte   $00,$0E,$FF,$00
        .byte   $00,$0F,$F0,$7D
        .byte   $01,$0C,$F0,$7E
        .byte   $01,$0D,$E8,$00
        .byte   $01,$0E,$E8,$01
        .byte   $01,$0F,$E8,$02
        .byte   $02,$0C,$E8,$03
        .byte   $02,$0D,$E8,$04
        .byte   $02,$0E,$E8,$05
        .byte   $02,$0F,$E8,$06
        .byte   $80            ; end of list

; celllist: transition id=15→16 dx=1 (18 ops, 73 bytes)
ttb_13:
        .byte   $FF,$0D,$FF,$00
        .byte   $FF,$0F,$FF,$00
        .byte   $00,$0C,$FF,$00
        .byte   $00,$0D,$FF,$00
        .byte   $00,$0E,$FF,$00
        .byte   $00,$0F,$E8,$07
        .byte   $01,$0C,$FF,$00
        .byte   $01,$0D,$E8,$08
        .byte   $01,$0E,$E8,$09
        .byte   $01,$0F,$E8,$0A
        .byte   $02,$0C,$E8,$0B
        .byte   $02,$0D,$E8,$0C
        .byte   $02,$0E,$E8,$0D
        .byte   $02,$0F,$E8,$0E
        .byte   $03,$0C,$E8,$0F
        .byte   $03,$0D,$E8,$10
        .byte   $03,$0E,$E8,$11
        .byte   $03,$0F,$E8,$12
        .byte   $80            ; end of list

; celllist: transition id=16→10 dx=0 (14 ops, 57 bytes)
ttb_14:
        .byte   $00,$0E,$E8,$13
        .byte   $00,$0F,$E8,$14
        .byte   $01,$0C,$F0,$13
        .byte   $01,$0D,$E8,$15
        .byte   $01,$0E,$E8,$16
        .byte   $01,$0F,$E8,$17
        .byte   $02,$0C,$E8,$18
        .byte   $02,$0D,$E8,$19
        .byte   $02,$0E,$E8,$1A
        .byte   $02,$0F,$E8,$1B
        .byte   $03,$0C,$FF,$00
        .byte   $03,$0D,$FF,$00
        .byte   $03,$0E,$FF,$00
        .byte   $03,$0F,$FF,$00
        .byte   $80            ; end of list

; celllist: transition id=10→11 dx=1 (16 ops, 65 bytes)
ttb_15:
        .byte   $FF,$0E,$FF,$00
        .byte   $FF,$0F,$FF,$00
        .byte   $00,$0C,$FF,$00
        .byte   $00,$0D,$FF,$00
        .byte   $00,$0E,$F0,$3A
        .byte   $00,$0F,$F0,$51
        .byte   $01,$0C,$FF,$00
        .byte   $01,$0D,$F0,$52
        .byte   $01,$0E,$F0,$53
        .byte   $01,$0F,$F0,$54
        .byte   $02,$0C,$F0,$55
        .byte   $02,$0D,$F0,$56
        .byte   $02,$0E,$F0,$57
        .byte   $02,$0F,$F0,$58
        .byte   $03,$0C,$F0,$59
        .byte   $03,$0F,$F0,$5A
        .byte   $80            ; end of list

; celllist: transition id=11→12 dx=0 (13 ops, 53 bytes)
ttb_16:
        .byte   $00,$0E,$FF,$00
        .byte   $00,$0F,$E8,$1C
        .byte   $01,$0D,$FF,$00
        .byte   $01,$0E,$F0,$5C
        .byte   $01,$0F,$F0,$5D
        .byte   $02,$0C,$F0,$5E
        .byte   $02,$0D,$F0,$5F
        .byte   $02,$0E,$F0,$60
        .byte   $02,$0F,$F0,$61
        .byte   $03,$0C,$F0,$62
        .byte   $03,$0D,$F0,$63
        .byte   $03,$0E,$F0,$64
        .byte   $03,$0F,$F0,$65
        .byte   $80            ; end of list

; celllist: transition id=12→15 dx=1 (12 ops, 49 bytes)
ttb_17:
        .byte   $FF,$0F,$FF,$00
        .byte   $00,$0D,$F0,$7C
        .byte   $00,$0E,$FF,$00
        .byte   $00,$0F,$E8,$1D
        .byte   $01,$0C,$F0,$7E
        .byte   $01,$0D,$E8,$00
        .byte   $01,$0E,$E8,$01
        .byte   $01,$0F,$E8,$02
        .byte   $02,$0C,$E8,$03
        .byte   $02,$0D,$E8,$04
        .byte   $02,$0E,$E8,$05
        .byte   $02,$0F,$E8,$1E
        .byte   $80            ; end of list

; celllist: transition id=15→16 dx=0 (14 ops, 57 bytes)
ttb_18:
        .byte   $00,$0D,$FF,$00
        .byte   $00,$0F,$E8,$07
        .byte   $01,$0C,$FF,$00
        .byte   $01,$0D,$E8,$08
        .byte   $01,$0E,$E8,$09
        .byte   $01,$0F,$E8,$0A
        .byte   $02,$0C,$E8,$0B
        .byte   $02,$0D,$E8,$0C
        .byte   $02,$0E,$E8,$0D
        .byte   $02,$0F,$E8,$0E
        .byte   $03,$0C,$E8,$0F
        .byte   $03,$0D,$E8,$10
        .byte   $03,$0E,$E8,$11
        .byte   $03,$0F,$E8,$12
        .byte   $80            ; end of list

; celllist: transition id=16→10 dx=1 (12 ops, 49 bytes)
ttb_19:
        .byte   $FF,$0F,$FF,$00
        .byte   $00,$0D,$FF,$00
        .byte   $00,$0E,$E8,$13
        .byte   $00,$0F,$E8,$14
        .byte   $01,$0C,$F0,$13
        .byte   $01,$0D,$E8,$15
        .byte   $01,$0E,$E8,$16
        .byte   $01,$0F,$E8,$17
        .byte   $02,$0C,$E8,$18
        .byte   $02,$0D,$E8,$19
        .byte   $02,$0E,$E8,$1A
        .byte   $02,$0F,$E8,$1B
        .byte   $80            ; end of list

; celllist: transition id=10→11 dx=0 (12 ops, 49 bytes)
ttb_20:
        .byte   $00,$0E,$F0,$3A
        .byte   $00,$0F,$F0,$51
        .byte   $01,$0C,$FF,$00
        .byte   $01,$0D,$F0,$52
        .byte   $01,$0E,$F0,$53
        .byte   $01,$0F,$F0,$54
        .byte   $02,$0C,$F0,$55
        .byte   $02,$0D,$F0,$56
        .byte   $02,$0E,$F0,$57
        .byte   $02,$0F,$F0,$58
        .byte   $03,$0C,$F0,$59
        .byte   $03,$0F,$F0,$5A
        .byte   $80            ; end of list

; celllist: transition id=11→15 dx=1 (13 ops, 53 bytes)
ttb_21:
        .byte   $FF,$0E,$FF,$00
        .byte   $FF,$0F,$FF,$00
        .byte   $00,$0D,$F0,$7C
        .byte   $00,$0E,$FF,$00
        .byte   $00,$0F,$E8,$1F
        .byte   $01,$0C,$F0,$7E
        .byte   $01,$0D,$E8,$00
        .byte   $01,$0E,$E8,$01
        .byte   $01,$0F,$E8,$02
        .byte   $02,$0C,$E8,$03
        .byte   $02,$0D,$E8,$04
        .byte   $02,$0E,$E8,$05
        .byte   $02,$0F,$E8,$21
        .byte   $80            ; end of list

; celllist: transition id=15→16 dx=0 (14 ops, 57 bytes)
ttb_22:
        .byte   $00,$0D,$FF,$00
        .byte   $00,$0F,$E8,$07
        .byte   $01,$0C,$FF,$00
        .byte   $01,$0D,$E8,$08
        .byte   $01,$0E,$E8,$09
        .byte   $01,$0F,$E8,$0A
        .byte   $02,$0C,$E8,$0B
        .byte   $02,$0D,$E8,$0C
        .byte   $02,$0E,$E8,$0D
        .byte   $02,$0F,$E8,$0E
        .byte   $03,$0C,$E8,$0F
        .byte   $03,$0D,$E8,$10
        .byte   $03,$0E,$E8,$11
        .byte   $03,$0F,$E8,$12
        .byte   $80            ; end of list

; celllist: transition id=18→18 dx=0 (0 ops, 1 bytes)
ttb_23:
        .byte   $80            ; end of list

screen_data2:
        .byte   $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte   $00,$00,$00,$00,$00

ALL_CHARS:
        .byte   $07,$01,$00,$00,$00,$00,$00,$00,$00,$00  ; $00
        .byte   $0B,$07,$0F,$05,$03,$01,$0F,$0B,$01,$0D  ; $01
        .byte   $05,$0D,$0B,$0B,$08,$19,$19,$19,$19,$09  ; $02
        .byte   $3F,$3F,$1F,$1F,$0F,$0F,$0F,$19,$1E,$17  ; $03
        .byte   $FF,$C0,$DF,$FC,$58,$2B,$01,$1E,$3F,$3F  ; $04
        .byte   $E0,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; $05
        .byte   $80,$00,$00,$00,$C0,$E0,$60,$80,$A0,$D0  ; $06
        .byte   $80,$80,$80,$80,$00,$C0,$C0,$C0,$80,$80  ; $07
        .byte   $80,$80,$80,$80,$80,$80,$80,$80,$80,$80  ; $08
        .byte   $FF,$58,$BD,$BF,$7F,$DF,$CF,$FF,$7F,$80  ; $09
        .byte   $02,$01,$01,$00,$00,$00,$00,$01,$00,$00  ; $0A
        .byte   $0F,$0F,$0E,$04,$01,$03,$07,$03,$07,$05  ; $0B
        .byte   $3F,$3F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$1F  ; $0C
        .byte   $FF,$C0,$BF,$BD,$90,$9B,$85,$9E,$FF,$3F  ; $0D
        .byte   $6C,$30,$00,$00,$00,$00,$00,$00,$00,$00  ; $0E
        .byte   $B0,$30,$E0,$D0,$2C,$1C,$66,$B8,$3A,$DE  ; $0F
        .byte   $E0,$9C,$60,$C0,$98,$38,$78,$38,$B8,$B8  ; $10
        .byte   $70,$70,$30,$B0,$B0,$B0,$B0,$B0,$B0,$E0  ; $11
        .byte   $FF,$58,$BD,$3F,$7F,$DF,$CF,$FF,$3F,$E0  ; $12
        .byte   $01,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; $13
        .byte   $1F,$0F,$07,$03,$01,$01,$01,$01,$01,$01  ; $14
        .byte   $FF,$FC,$E3,$EF,$E2,$ED,$C8,$E7,$EF,$1F  ; $15
        .byte   $04,$03,$00,$00,$01,$06,$00,$03,$01,$00  ; $16
        .byte   $FF,$FF,$F0,$6F,$1C,$19,$3C,$16,$1F,$0B  ; $17
        .byte   $EF,$E7,$E3,$F3,$F7,$F7,$FF,$FF,$FF,$FF  ; $18
        .byte   $FF,$18,$DC,$83,$1F,$A7,$DB,$F1,$AF,$DF  ; $19
        .byte   $80,$40,$C0,$70,$B8,$C0,$E8,$6C,$B0,$D0  ; $1A
        .byte   $00,$00,$F0,$F8,$00,$C0,$C0,$C0,$40,$40  ; $1B
        .byte   $C0,$E0,$F0,$F0,$F0,$E0,$C0,$C0,$80,$80  ; $1C
        .byte   $FF,$3F,$CF,$FF,$7F,$F8,$FF,$7F,$FF,$C0  ; $1D
        .byte   $FF,$F0,$EF,$DA,$B3,$CC,$B1,$87,$F7,$07  ; $1E
        .byte   $1F,$1C,$09,$03,$03,$03,$01,$02,$01,$00  ; $1F
        .byte   $00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; $20
        .byte   $FC,$FC,$7C,$7E,$3E,$3E,$3F,$3F,$3F,$3F  ; $21
        .byte   $FF,$C1,$EC,$F7,$ED,$2A,$D3,$EC,$F5,$F9  ; $22
        .byte   $70,$08,$1F,$53,$59,$5E,$71,$37,$1B,$00  ; $23
        .byte   $BE,$E0,$80,$B0,$78,$B8,$D8,$E8,$6C,$E8  ; $24
        .byte   $FE,$7E,$1E,$7E,$FC,$FC,$F8,$F8,$F0,$CC  ; $25
        .byte   $FF,$FF,$7F,$3F,$FF,$C7,$1F,$F7,$FB,$FC  ; $26
        .byte   $00,$00,$00,$00,$00,$00,$80,$80,$00,$00  ; $27
        .byte   $FF,$FF,$FF,$FE,$BF,$FF,$FF,$FF,$FF,$00  ; $28
        .byte   $FF,$80,$BB,$EA,$E8,$CB,$DB,$87,$F7,$01  ; $29
        .byte   $00,$01,$01,$00,$01,$00,$00,$00,$00,$00  ; $2A
        .byte   $76,$71,$33,$37,$39,$1C,$0E,$07,$02,$01  ; $2B
        .byte   $37,$0F,$3F,$7F,$FF,$FE,$E6,$DE,$DA,$D6  ; $2C
        .byte   $FF,$1F,$EF,$4F,$3F,$C7,$FC,$FF,$FF,$FF  ; $2D
        .byte   $3C,$EC,$64,$3C,$FA,$DC,$20,$00,$00,$00  ; $2E
        .byte   $00,$80,$C0,$C0,$C0,$E0,$E0,$C0,$E0,$A0  ; $2F
        .byte   $80,$80,$00,$00,$00,$00,$00,$20,$F0,$90  ; $30
        .byte   $FF,$FF,$FF,$F9,$FE,$FF,$FF,$7F,$7F,$80  ; $31
        .byte   $FF,$E1,$1E,$B6,$A0,$A7,$CF,$DF,$EF,$01  ; $32
        .byte   $37,$6F,$5C,$D3,$E7,$EF,$67,$3C,$1E,$07  ; $33
        .byte   $EF,$77,$7C,$7B,$27,$1F,$3F,$3F,$7F,$3F  ; $34
        .byte   $FF,$FF,$FF,$FB,$B3,$7F,$FF,$71,$13,$EF  ; $35
        .byte   $D0,$30,$3E,$EE,$B2,$BC,$E3,$6F,$36,$00  ; $36
        .byte   $00,$00,$00,$B8,$D3,$C2,$E0,$E0,$E0,$F0  ; $37
        .byte   $F0,$F8,$78,$F8,$F0,$F0,$E0,$C0,$80,$00  ; $38
        .byte   $FF,$FE,$FF,$3F,$CF,$F7,$FF,$FF,$9F,$F0  ; $39
        .byte   $07,$03,$00,$00,$00,$00,$00,$00,$00,$00  ; $3A
        .byte   $FF,$C7,$BB,$AB,$4B,$51,$47,$FF,$FF,$0F  ; $3B
        .byte   $06,$0E,$0F,$0F,$0C,$0C,$0C,$0F,$03,$00  ; $3C
        .byte   $F8,$FC,$FE,$7E,$7E,$3D,$1B,$17,$0F,$09  ; $3D
        .byte   $FF,$FF,$FF,$E7,$FB,$FE,$7F,$DF,$EF,$F0  ; $3E
        .byte   $2C,$0A,$07,$19,$16,$17,$18,$1D,$0F,$00  ; $3F
        .byte   $F0,$E0,$90,$38,$7D,$FC,$7E,$9E,$EE,$FC  ; $40
        .byte   $3F,$1F,$1F,$7F,$7F,$FE,$FE,$FC,$F8,$F0  ; $41
        .byte   $FF,$C0,$BF,$B9,$CB,$C7,$BE,$BF,$BF,$3F  ; $42
        .byte   $00,$00,$C0,$C0,$40,$00,$60,$A0,$80,$00  ; $43
        .byte   $00,$00,$00,$00,$C0,$10,$18,$10,$00,$00  ; $44
        .byte   $80,$80,$80,$80,$00,$00,$00,$00,$00,$00  ; $45
        .byte   $FF,$5F,$AF,$3B,$FF,$DE,$FF,$FF,$7F,$00  ; $46
        .byte   $63,$23,$01,$00,$00,$00,$00,$00,$00,$00  ; $47
        .byte   $FF,$F6,$FD,$FD,$BE,$DE,$BA,$DE,$FD,$7B  ; $48
        .byte   $07,$00,$00,$00,$03,$03,$01,$01,$00,$00  ; $49
        .byte   $7E,$4F,$1E,$39,$39,$1C,$0E,$07,$0B,$09  ; $4A
        .byte   $CF,$EF,$DF,$1F,$3F,$7F,$7F,$7F,$7E,$7E  ; $4B
        .byte   $FF,$03,$FF,$CA,$7F,$C3,$3F,$7F,$7F,$BF  ; $4C
        .byte   $80,$60,$50,$90,$E0,$70,$80,$B0,$D0,$00  ; $4D
        .byte   $60,$E0,$00,$80,$C0,$C0,$40,$40,$40,$C0  ; $4E
        .byte   $C0,$C0,$80,$80,$00,$00,$00,$00,$00,$00  ; $4F
        .byte   $FF,$FF,$FF,$FF,$FF,$9F,$FF,$FF,$FF,$80  ; $50
        .byte   $FF,$80,$C7,$BC,$A3,$99,$A6,$EF,$EF,$0F  ; $51
        .byte   $3F,$18,$07,$07,$07,$09,$05,$02,$00,$00  ; $52
        .byte   $FB,$FD,$FE,$7E,$7E,$7E,$7F,$7F,$7F,$3F  ; $53
        .byte   $FF,$FF,$FF,$BF,$FE,$C8,$3F,$91,$CB,$F7  ; $54
        .byte   $34,$0B,$07,$1B,$6E,$0E,$37,$1B,$0C,$00  ; $55
        .byte   $E0,$00,$F0,$FF,$27,$98,$D8,$E8,$58,$38  ; $56
        .byte   $F8,$FC,$FC,$3E,$7E,$FE,$FC,$FC,$F8,$F0  ; $57
        .byte   $FF,$FF,$FF,$FE,$FF,$FF,$FF,$3F,$FF,$E0  ; $58
        .byte   $00,$00,$00,$80,$00,$80,$80,$00,$00,$00  ; $59
        .byte   $FF,$FF,$FF,$FF,$3F,$DF,$F7,$FF,$FF,$00  ; $5A
        .byte   $BF,$DD,$FB,$FF,$B4,$BD,$BB,$FF,$FB,$01  ; $5B
        .byte   $FF,$3F,$0F,$07,$07,$07,$07,$03,$03,$01  ; $5C
        .byte   $FF,$FF,$FF,$FF,$FF,$BF,$E7,$FB,$FE,$FF  ; $5D
        .byte   $00,$00,$00,$03,$03,$01,$01,$00,$00,$00  ; $5E
        .byte   $F3,$6F,$0D,$0E,$36,$37,$D7,$2B,$05,$03  ; $5F
        .byte   $80,$C1,$C3,$E7,$F7,$FB,$FF,$FF,$FF,$FF  ; $60
        .byte   $FF,$FC,$DB,$E2,$F9,$FC,$FB,$FB,$7B,$01  ; $61
        .byte   $60,$78,$98,$64,$70,$86,$FA,$F8,$00,$00  ; $62
        .byte   $80,$FC,$FC,$C0,$E0,$60,$E0,$E0,$40,$80  ; $63
        .byte   $F0,$F0,$F0,$F0,$E0,$C0,$C0,$80,$80,$80  ; $64
        .byte   $E1,$00,$CB,$3F,$FF,$CF,$EF,$FF,$F7,$F0  ; $65
        .byte   $FF,$FF,$7F,$DF,$FF,$F2,$FF,$FF,$FF,$03  ; $66
        .byte   $8F,$03,$00,$00,$00,$00,$00,$00,$00,$00  ; $67
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FE,$F7,$0F,$7F  ; $68
        .byte   $0F,$0E,$01,$03,$06,$0F,$07,$03,$00,$00  ; $69
        .byte   $FF,$FF,$3F,$1F,$1F,$1F,$1F,$1F,$1F,$1F  ; $6A
        .byte   $FF,$FE,$FE,$7F,$9E,$EF,$0B,$F9,$FE,$FF  ; $6B
        .byte   $7C,$0C,$0F,$29,$2C,$2F,$38,$1B,$0D,$00  ; $6C
        .byte   $B0,$70,$C0,$38,$78,$7C,$BC,$CC,$EC,$68  ; $6D
        .byte   $7C,$7C,$BC,$BC,$F8,$F8,$D0,$D0,$C0,$C0  ; $6E
        .byte   $FF,$03,$FD,$ED,$1F,$1F,$FF,$FB,$FD,$FC  ; $6F
        .byte   $00,$00,$80,$80,$80,$00,$C0,$C0,$80,$00  ; $70
        .byte   $FF,$FF,$FF,$BF,$FF,$7F,$FF,$FF,$FF,$00  ; $71
        .byte   $06,$06,$00,$01,$01,$01,$00,$00,$00,$00  ; $72
        .byte   $03,$01,$00,$00,$01,$03,$07,$07,$07,$07  ; $73
        .byte   $FF,$F0,$EF,$8E,$F2,$B1,$B7,$A1,$BB,$6B  ; $74
        .byte   $1F,$00,$00,$01,$07,$00,$03,$01,$00,$00  ; $75
        .byte   $40,$90,$AC,$9E,$9F,$CF,$E7,$73,$3B,$1F  ; $76
        .byte   $FF,$FF,$7F,$FE,$FE,$FE,$FC,$F8,$B0,$70  ; $77
        .byte   $FF,$1F,$EF,$4B,$7F,$97,$DF,$C7,$FB,$FE  ; $78
        .byte   $40,$A0,$70,$B8,$E0,$E8,$68,$B0,$80,$00  ; $79
        .byte   $00,$30,$70,$E0,$00,$00,$00,$00,$40,$00  ; $7A
        .byte   $FF,$FF,$FF,$FF,$FB,$FF,$FF,$FF,$FF,$00  ; $7B
        .byte   $01,$01,$01,$01,$01,$00,$00,$00,$00,$00  ; $7C
        .byte   $FF,$FA,$C2,$BC,$1D,$BD,$A6,$F7,$01,$01  ; $7D
        .byte   $00,$00,$03,$03,$01,$01,$00,$00,$00,$00  ; $7E
        .byte   $00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; $7F ← blank

; ── BAGC2 sprite chars (overflow bank: slots 128+, attr $E8) ──
ALL_CHARS2:
        .byte   $B2,$E7,$9F,$9F,$CF,$FB,$3D,$1D,$03,$00  ; $00 (attr $E8)
        .byte   $F0,$E7,$CF,$7F,$FF,$FF,$FE,$5E,$DE,$DE  ; $01 (attr $E8)
        .byte   $FF,$7F,$CE,$BF,$BF,$66,$6F,$DF,$DF,$EF  ; $02 (attr $E8)
        .byte   $58,$98,$E0,$70,$86,$B8,$D8,$00,$00,$00  ; $03 (attr $E8)
        .byte   $00,$74,$06,$C4,$80,$A0,$A0,$80,$40,$60  ; $04 (attr $E8)
        .byte   $F0,$E0,$E0,$C0,$80,$00,$00,$00,$00,$00  ; $05 (attr $E8)
        .byte   $FF,$FF,$FC,$FF,$FF,$FF,$7F,$C7,$E0,$F0  ; $06 (attr $E8)
        .byte   $FF,$78,$87,$F7,$E9,$EA,$E8,$FD,$FD,$01  ; $07 (attr $E8)
        .byte   $00,$00,$01,$01,$01,$01,$01,$00,$00,$00  ; $08 (attr $E8)
        .byte   $FF,$3F,$1F,$0F,$07,$07,$03,$02,$01,$01  ; $09 (attr $E8)
        .byte   $FF,$FF,$7F,$7F,$FD,$3F,$E7,$FB,$FD,$FE  ; $0A (attr $E8)
        .byte   $05,$01,$00,$03,$02,$02,$03,$01,$00,$00  ; $0B (attr $E8)
        .byte   $5E,$FC,$B2,$F3,$8F,$9F,$8F,$F3,$7D,$1F  ; $0C (attr $E8)
        .byte   $03,$83,$C3,$C7,$CF,$BF,$7F,$FF,$FF,$3E  ; $0D (attr $E8)
        .byte   $FF,$F8,$F3,$F7,$FB,$F8,$F7,$F7,$F7,$07  ; $0E (attr $E8)
        .byte   $80,$40,$F8,$38,$C8,$F0,$8C,$BC,$D8,$00  ; $0F (attr $E8)
        .byte   $00,$00,$00,$00,$A8,$90,$D1,$D2,$D0,$80  ; $10 (attr $E8)
        .byte   $F0,$F0,$F0,$F0,$E0,$C0,$C0,$80,$00,$00  ; $11 (attr $E8)
        .byte   $FF,$03,$F3,$B7,$3F,$FF,$DF,$FF,$EF,$F0  ; $12 (attr $E8)
        .byte   $18,$08,$00,$00,$00,$00,$00,$00,$00,$00  ; $13 (attr $E8)
        .byte   $FF,$FD,$FF,$7F,$AF,$D7,$CE,$D7,$DF,$1E  ; $14 (attr $E8)
        .byte   $1F,$13,$07,$0E,$0E,$07,$03,$01,$02,$02  ; $15 (attr $E8)
        .byte   $F3,$FB,$77,$07,$0F,$1F,$1F,$1F,$1F,$1F  ; $16 (attr $E8)
        .byte   $FF,$80,$7F,$72,$9F,$B0,$8F,$9F,$5F,$EF  ; $17 (attr $E8)
        .byte   $E0,$18,$16,$26,$F8,$DC,$61,$6E,$36,$00  ; $18 (attr $E8)
        .byte   $98,$F8,$80,$60,$70,$30,$90,$D0,$D0,$70  ; $19 (attr $E8)
        .byte   $F0,$F0,$E0,$E0,$C0,$C0,$C0,$C0,$80,$80  ; $1A (attr $E8)
        .byte   $FF,$FF,$FF,$BF,$FF,$E7,$FF,$FF,$FF,$E0  ; $1B (attr $E8)
        .byte   $BF,$DD,$FB,$FF,$B4,$BD,$BB,$C7,$FB,$01  ; $1C (attr $E8)
        .byte   $FF,$FA,$C2,$BC,$1D,$BD,$BE,$C7,$F9,$01  ; $1D (attr $E8)
        .byte   $FF,$FF,$FC,$FF,$FF,$FF,$7F,$CF,$E7,$F0  ; $1E (attr $E8)
        .byte   $FF,$FA,$C2,$BC,$1D,$BD,$BE,$87,$FD,$01  ; $1F (attr $E8)
        .byte   $00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; $20 (attr $E8)
        .byte   $FF,$FF,$FC,$FF,$FF,$FB,$7F,$CF,$E7,$F0  ; $21 (attr $E8)

; NOTE: level.h is included HERE (after .org) so data lands in ROM space
; Do NOT include level.h before .org — data would land in register file ($0000-$00FF)!
#include "level.h"            ; tile data and level map (must be after .org $1000)
#include "mixt_api.asm"

        .end