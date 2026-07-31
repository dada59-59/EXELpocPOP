; ============================================================
; POP.ASM - Prince of Persia (EXL100)
;   Phase 1: INTRO - exelimage screen (mona.asm) + buzzer music (music.asm)
;   Phase 2: GAME  - EXLCHAR v11 animation engine + level.h
; Any key during the intro stops the music and starts the game.
;
; Merged from mona.asm + music.asm + engine.asm + level.h
; ============================================================

#include "c:/jeux/emulateur/exl/tasm/H/7020.equ"
#include "c:/jeux/emulateur/exl/tasm/H/3556.equ"

; -- Intro char-generator VRAM bases (mona) ------------------
INTRO_BAGC0     .equ    $0200  ; CG=$00, relocated
INTRO_BAGC1     .equ    $0800  ; CG=$10
INTRO_BAGC2     .equ    $0F00  ; CG=$08
INTRO_BAGC3     .equ    $1400  ; CG=$18

; -- Music SRAM ($C300-$C304): no overlap with engine vars ---
mus_ptr_lo      .equ    $C300
mus_ptr_hi      .equ    $C301
mus_dur_lo      .equ    $C302
mus_dur_hi      .equ    $C303
mus_active      .equ    $C304

; -- Engine equates ------------------------------------------

SCR             .equ    $7340
BAGC1_ADR       .equ    $0500
SPR_ROW         .equ    8
FRAMES_PER_STEP .equ    1       ; VBL frames per animation step (50/2 = 25fps)
; Most frames use this. Change it to re-time the whole animation.
; Frames with a different duration set in the editor emit their own value.
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

; ============================================================
;  PHASE 1 - INTRO SCREEN + MUSIC
; ============================================================
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

        clr     A
        sta     @BRJOY0
        sta     @BRJOY0+1
        sta     @BRTIME
        sta     @BRTIME+1

        ; Configure BAGC0 at $0200 (CG=$00, relocated from $0A00)
        movp    %$01,P45
        movp    %$FE,P45
        movp    %$02,P45
        movp    %$01,P45
        movp    %$0B,P45
        movp    %$00,P45
        movp    %$00,P45

        ; Configure BAGC1 at $0800 (CG=$10)
        movp    %$01,P45
        movp    %$FE,P45
        movp    %$02,P45
        movp    %$07,P45
        movp    %$0C,P45
        movp    %$00,P45
        movp    %$00,P45

        ; Configure BAGC2 at $0F00 (CG=$08)
        movp    %$01,P45
        movp    %$FE,P45
        movp    %$02,P45
        movp    %$0E,P45
        movp    %$0D,P45
        movp    %$00,P45
        movp    %$00,P45

        ; Configure BAGC3 at $1400 + DC5=1 (CG=$18)
        movp    %$05,P45
        movp    %$E8,P45
        movp    %$01,P45
        movp    %$FE,P45
        movp    %$02,P45
        movp    %$13,P45
        movp    %$0E,P45
        movp    %$00,P45
        movp    %$00,P45
        ; Load char generators (guarded: skip if count = 0)
        movd    %BAGC2_DATA,TEMP3
        movd    %INTRO_BAGC2,TEMP2
        mov     %$00,TEMP7
        mov     %128,TEMP4-1
        trap    19

        movd    %BAGC3_DATA,TEMP3
        movd    %INTRO_BAGC3,TEMP2
        mov     %$00,TEMP7
        mov     %128,TEMP4-1
        trap    19

        movd    %BAGC1_DATA,TEMP3
        movd    %INTRO_BAGC1,TEMP2
        mov     %$00,TEMP7
        mov     %128,TEMP4-1
        trap    19

        movd    %BAGC0_DATA,TEMP3
        movd    %INTRO_BAGC0,TEMP2
        mov     %$00,TEMP7
        mov     %128,TEMP4-1
        trap    19

        ; -- Init MIXT API and screen for the intro ----------
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
        mov     %$08,A         ; BAGC2 blank
        movd    %$0000,TEMP1
        movd    %$1928,TEMP2
        call    @set_window
        #DEFINE Fset_window
        eint

        ; DC5=1 AFTER set_25LINE (set_25LINE resets CM2=$C8, clearing DC5)
        movp    %$05,P45
        movp    %$E8,P45

        call    @write_screen  ; paint the intro image

        ; -- Start the music (timer ISR) ---------------------
        movd    %pop_tune,TEMP4
        mov     TEMP4-1,A
        sta     @mus_ptr_hi
        mov     TEMP4,A
        sta     @mus_ptr_lo
        clr     A
        sta     @mus_dur_lo
        sta     @mus_dur_hi
        sta     @mus_active
        movd    %timer_isr,TEMP4
        mov     TEMP4-1,A
        sta     @BRTIME
        mov     TEMP4,A
        sta     @BRTIME+1
        movp    %$FF,P2
        movp    %$97,P3        ; ~50Hz - first tick loads note 1
        eint

; -- Wait for a key press ------------------------------------
; Idle VALUE0: $86 EXL100, $89 Exeltel, $04 released, $00 boot
intro_wait:
        mov     VALUE0,A
        cmp     %KEY_NONE_EXL,A
        jeq     @intro_wait
        cmp     %KEY_NONE_EXT,A
        jeq     @intro_wait
        cmp     %KEY_NONE_REL,A
        jeq     @intro_wait
        cmp     %$00,A
        jeq     @intro_wait

; -- Key pressed: stop the music, hand over to the game ------
stop_music:
        dint
        clr     A
        sta     @BRTIME        ; remove timer ISR vector
        sta     @BRTIME+1
        sta     @mus_active    ; buzzer silent
        movp    %$FF,P2        ; slowest timer rate
        movp    %$FF,P3
        eint

        ; wait for release so the game does not walk on this same press
sm_rel: mov     VALUE0,A
        cmp     %KEY_NONE_EXL,A
        jeq     @game_start
        cmp     %KEY_NONE_EXT,A
        jeq     @game_start
        cmp     %KEY_NONE_REL,A
        jeq     @game_start
        cmp     %$00,A
        jeq     @game_start
        br      @sm_rel

; ============================================================
;  PHASE 2 - GAME: reprogram the char generators (the intro's
;  four banks give way to sprite BAGC1/BAGC2 + tile BAGC3),
;  reload them, redraw the level, run the engine main loop.
; ============================================================
game_start:
        dint
        ; Set BAGC1 base address to $0500 (walkman.asm proven sequence)
        movp    %$01,P45
        movp    %$FE,P45
        movp    %$02,P45
        movp    %$04,P45
        movp    %$0C,P45       ; BAGC1 register (12)
        movp    %$00,P45
        movp    %$00,P45
        ; -- Set BAGC3 base address to $0F00 (register 14)
        movp    %$01,P45
        movp    %$FE,P45
        movp    %$02,P45
        movp    %$0E,P45
        movp    %$0E,P45       ; BAGC3 register (14)
        movp    %$00,P45
        movp    %$00,P45
        ; -- Set BAGC2 base address to $0A00 (register 13)
        movp    %$01,P45
        movp    %$FE,P45
        movp    %$02,P45
        movp    %$09,P45
        movp    %$0D,P45       ; BAGC2 register (13)
        movp    %$00,P45
        movp    %$00,P45
        ; -- Load BAGC1 sprite chars --
        movd    %ALL_CHARS,TEMP3
        movd    %BAGC1_ADR,TEMP2
        mov     %$00,TEMP7             ; first slot = 0: ALL_CHARS[i] -- slot i (draw codes start at 0)
        mov     %128,TEMP4-1
        trap    19
        ; -- Load BAGC2 sprite chars (overflow bank, attr $E8) --
        movd    %ALL_CHARS2,TEMP3
        movd    %$0A00,TEMP2           ; BAGC2 base address
        mov     %$00,TEMP7
        mov     %34,TEMP4-1
        trap    19
        ; -- Load BAGC3 tile chars from level.h --
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
        ; BRTIME already cleared in stop_music (music ISR removed)
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

        ; -- Draw full level map --
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
        ; -- Read keyboard --
        mov     VALUE0,A
        cmp     %KEY_NONE_EXL,A
        jeq     @no_key
        cmp     %KEY_NONE_EXT,A
        jeq     @no_key
        cmp     %KEY_NONE_REL,A
        jeq     @no_key
        cmp     %$00,A         ; boot / Exeltel idle
        jeq     @no_key
        ; -- Key dispatch --
        cmp     %$83,A       ; LEFT -- WALK_LEFT
        jeq     @run_anim_0
        cmp     %$61,A       ; LEFT -- WALK_LEFT
        jeq     @run_anim_0
        cmp     %$41,A       ; LEFT -- WALK_LEFT
        jeq     @run_anim_0
        cmp     %$81,A       ; RIGHT -- WALK_RIGHT
        jeq     @run_anim_1
        cmp     %$72,A       ; RIGHT -- WALK_RIGHT
        jeq     @run_anim_1
        cmp     %$52,A       ; RIGHT -- WALK_RIGHT
        jeq     @run_anim_1
no_key:
        ; no key pressed -- if current anim is keyed, reset to default
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
        jeq     @ra_same_0   ; same anim -- keep ANIM_NEW=0, no forced redraw
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
        jeq     @ra_same_1   ; same anim -- keep ANIM_NEW=0, no forced redraw
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
        jeq     @ra_same_2   ; same anim -- keep ANIM_NEW=0, no forced redraw
        mov     %2,A
        sta     @ANIM_CUR
        mov     %1,A
        sta     @ANIM_NEW      ; signal new animation
ra_same_2:
        call    @play_anim_2
        br      @main_loop
; -- VBL sync subroutine --
sync:
        movp    %$03,P45       ; request VDP status register
        btjop   %$20,P37,sync  ; wait while ST3=1 (active display)
        rets

; -- Wait N VBL frames subroutine --
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

; -- Animation play subroutines --
; -- Animation: WALK_LEFT (key=LEFT) --
play_anim_0:
; Frame 0 id=17 x_off=0 (transition from frame 0, dx=-1)
        lda     @PLAYER_X
        cmp     %2,A
        jl      @gen_0_0      ; pinned at left wall -- generic redraw
        dec     A
        sta     @PLAYER_X
        lda     @ANIM_NEW
        jnz     @gen_0_0      ; cross-animation entry -- generic redraw
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

; -- Animation: WALK_RIGHT (key=RIGHT) --
play_anim_1:
; Frame 0 id=3 x_off=0 (transition from frame 23, dx=0)
        lda     @ANIM_NEW
        jnz     @gen_1_0      ; cross-animation entry -- generic redraw
        lda     @PLAYER_X
        cmp     %18,A
        jl      @fsw_1_0
        br      @fs_fold_1  ; wall -- fold x_off into X, hold pose
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
        br      @fs_hold_1  ; at wall on entry -- hold
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
        mov     %FRAMES_PER_STEP,A
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
        mov     %FRAMES_PER_STEP,A
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
        mov     %FRAMES_PER_STEP,A
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
        mov     %FRAMES_PER_STEP,A
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
        mov     %FRAMES_PER_STEP,A
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
        mov     %FRAMES_PER_STEP,A
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
        mov     %FRAMES_PER_STEP,A
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
        mov     %FRAMES_PER_STEP,A
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
        mov     %FRAMES_PER_STEP,A
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
        mov     %FRAMES_PER_STEP,A
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
        mov     %FRAMES_PER_STEP,A
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
        mov     %FRAMES_PER_STEP,A
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
        mov     %FRAMES_PER_STEP,A
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
        mov     %FRAMES_PER_STEP,A
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
        mov     %FRAMES_PER_STEP,A
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
        mov     %FRAMES_PER_STEP,A
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
        mov     %FRAMES_PER_STEP,A
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
        mov     %FRAMES_PER_STEP,A
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
        mov     %FRAMES_PER_STEP,A
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
        mov     %FRAMES_PER_STEP,A
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
        mov     %FRAMES_PER_STEP,A
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
        sta     @PLAYER_X      ; X now -- drawn col -- STAND entry matches
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
        rets                   ; released / other key -- dispatch

; -- Animation: STAND (key=NONE) --
play_anim_2:
        lda     @ANIM_NEW
        jz      @play_anim_2_nodelay  ; already on screen -- just wait for key
; Frame 0 id=18 x_off=0 (transition from frame 0, dx=0)
        lda     @ANIM_NEW
        jnz     @gen_2_0      ; cross-animation entry -- generic redraw
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

; -- Runtime cell executors (v11): op tables replace unrolled code --
; run_celllist: TEMP2 pair = table addr, TEMP4 = base column.
; Op = 4 bytes [colOff, absRow, attr, code]; attr $FF = restore background;
; $80 in colOff position = end of table.
run_celllist:
        dint           ; ROM IRQ clobbers R5+ -- protect table walk + VDP writes
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
        jhs     @rcl_loop      ; off-screen (incl. negative wrap) -- skip
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

; bg_restore_cell: A = absolute row, B = column -- repaint one background cell
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
        mov     %$10,A         ; air -- BAGC1 blank
        wvdp(A)
        mov     %$7F,A
        wvdp(A)
        rets
bgc_tile:
        clrc
        rl      A              ; --2 for TILE_CHARS (attr,char)
        mov     A,B
        lda     @TILE_CHARS(B)
        wvdp(A)
        lda     @TILE_CHARS+1(B)
        wvdp(A)
        rets

; Generic erase: A = width in cols, TEMP4 = base col -- repaint background
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
        jhs     @en_next       ; off-screen col -- skip
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

; -- Draw tables (18) -- full draws for cross-anim entry --
; celllist: full draw 2--8 (10 ops, 41 bytes)
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

; celllist: full draw 2--8 (9 ops, 37 bytes)
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

; celllist: full draw 3--8 (11 ops, 45 bytes)
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

; celllist: full draw 4--8 (11 ops, 45 bytes)
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

; celllist: full draw 3--8 (9 ops, 37 bytes)
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

; celllist: full draw 3--8 (8 ops, 33 bytes)
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

; celllist: full draw 4--8 (13 ops, 53 bytes)
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

; celllist: full draw 3--8 (10 ops, 41 bytes)
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

; celllist: full draw 4--8 (11 ops, 45 bytes)
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

; celllist: full draw 4--8 (11 ops, 45 bytes)
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

; celllist: full draw 5--8 (13 ops, 53 bytes)
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

; celllist: full draw 3--8 (10 ops, 41 bytes)
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

; celllist: full draw 3--8 (10 ops, 41 bytes)
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

; celllist: full draw 4--8 (12 ops, 49 bytes)
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

; celllist: full draw 3--8 (10 ops, 41 bytes)
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

; celllist: full draw 4--8 (11 ops, 45 bytes)
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

; celllist: full draw 3--8 (10 ops, 41 bytes)
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

; celllist: full draw 3--8 (10 ops, 41 bytes)
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

; -- Transition tables (24) -- single-pass updates, no flicker --
; celllist: transition id=17--17 dx=-1 (15 ops, 61 bytes)
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

; celllist: transition id=11--3 dx=0 (15 ops, 61 bytes)
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

; celllist: transition id=3--5 dx=0 (13 ops, 53 bytes)
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

; celllist: transition id=5--6 dx=1 (17 ops, 69 bytes)
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

; celllist: transition id=6--7 dx=0 (12 ops, 49 bytes)
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

; celllist: transition id=7--8 dx=1 (13 ops, 53 bytes)
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

; celllist: transition id=8--9 dx=0 (13 ops, 53 bytes)
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

; celllist: transition id=9--10 dx=1 (13 ops, 53 bytes)
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

; celllist: transition id=10--11 dx=0 (12 ops, 49 bytes)
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

; celllist: transition id=11--12 dx=1 (17 ops, 69 bytes)
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

; celllist: transition id=12--13 dx=0 (14 ops, 57 bytes)
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

; celllist: transition id=13--14 dx=1 (15 ops, 61 bytes)
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

; celllist: transition id=14--15 dx=0 (11 ops, 45 bytes)
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

; celllist: transition id=15--16 dx=1 (18 ops, 73 bytes)
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

; celllist: transition id=16--10 dx=0 (14 ops, 57 bytes)
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

; celllist: transition id=10--11 dx=1 (16 ops, 65 bytes)
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

; celllist: transition id=11--12 dx=0 (13 ops, 53 bytes)
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

; celllist: transition id=12--15 dx=1 (12 ops, 49 bytes)
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

; celllist: transition id=15--16 dx=0 (14 ops, 57 bytes)
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

; celllist: transition id=16--10 dx=1 (12 ops, 49 bytes)
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

; celllist: transition id=10--11 dx=0 (12 ops, 49 bytes)
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

; celllist: transition id=11--15 dx=1 (13 ops, 53 bytes)
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

; celllist: transition id=15--16 dx=0 (14 ops, 57 bytes)
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

; celllist: transition id=18--18 dx=0 (0 ops, 1 bytes)
ttb_23:
        .byte   $80            ; end of list

; -- Intro: screen writer (mona.asm) -------------------------
write_screen:
        ; Store data pointer in SRAM $C3D0(hi):$C3D1(lo)
        mov     %SCREEN_DATA>>8,A
        sta     @$C3D0
        mov     %SCREEN_DATA&$FF,A
        sta     @$C3D1
        ; Use calcul_pointer approach: write cell by cell via TRAP 9
        ; row=0..24, col=0..39 -- calcul_pointer gives correct VRAM addr
        ; Store row and col in SRAM
        clr     A
        sta     @$C3FC              ; current row
ws_row:
        clr     A
        sta     @$C3FD              ; current col
ws_col:
        ; Set TEMP1-1:TEMP1 = VRAM address for (row, col)
        ; Formula: SCR + row*82 + col*2
        ; Use calcul_pointer: A=row, B=col, sets TEMP3=address
        lda     @$C3FC
        mov     A,TEMP3             ; save row for calcul_pointer param
        lda     @$C3FD
        mov     A,B                 ; B = col
        lda     @$C3FC              ; A = row (calcul_pointer IN: A=row, B=col)
        call    @calcul_pointer
        #DEFINE Fcalcul_pointer
        movd    TEMP3,TEMP1
        ; Write attr+char from SCREEN_DATA
        dint
        trap    9
        ; Read attr byte from SRAM data ptr $C3D0:$C3D1
        lda     @$C3D0
        mov     A,TEMP1-1
        lda     @$C3D1
        mov     A,TEMP1
        lda     *TEMP1              ; A = attr byte
        wvdp(A)
        ; Advance ptr
        lda     @$C3D1
        inc     A
        sta     @$C3D1
        jnz     @ws_nc1
        lda     @$C3D0
        inc     A
        sta     @$C3D0
ws_nc1:
        ; Read char byte
        lda     @$C3D0
        mov     A,TEMP1-1
        lda     @$C3D1
        mov     A,TEMP1
        lda     *TEMP1
        wvdp(A)
        eint
        ; Advance ptr
        lda     @$C3D1
        inc     A
        sta     @$C3D1
        jnz     @ws_nc2
        lda     @$C3D0
        inc     A
        sta     @$C3D0
ws_nc2:
        ; Next col
        lda     @$C3FD
        inc     A
        sta     @$C3FD
        cmp     %40,A
        jl      @ws_col
        ; Next row
        lda     @$C3FC
        inc     A
        sta     @$C3FC
        cmp     %25,A
        jl      @ws_row
        rets

; -- Intro: music timer ISR (music.asm) ----------------------
timer_isr:
        push    A
        push    B

        ; Toggle buzzer if active
        lda     @mus_active
        jz      @isr_no_sound
        xorp    A,P6
isr_no_sound:

        ; Decrement 16-bit duration
        lda     @mus_dur_lo
        jnz     @isr_lo_nz
        lda     @mus_dur_hi
        jz      @isr_load_next  ; both zero -- load next note
        dec     A
        sta     @mus_dur_hi
isr_lo_nz:
        lda     @mus_dur_lo
        dec     A
        sta     @mus_dur_lo
        pop     B
        pop     A
        rets

isr_load_next:
        ; Load next note: pointer in mus_ptr_hi:mus_ptr_lo
        ; Use R33:R34 as indirect pointer (INTmusic style)
        lda     @mus_ptr_lo
        mov     A,R34
        lda     @mus_ptr_hi
        mov     A,R33

        ; Read P2
        lda     *R34
        jz      @isr_tune_end   ; $00 = end -- loop
        cmp     %$FF,A
        jne     @isr_sound_note
        ; Silence: don't toggle buzzer, use slow tick timer for timing
        clr     A
        sta     @mus_active
        movp    %$FF,P2
        movp    %$97,P3         ; ~50Hz for timing
        inc     R34             ; skip P3 byte (same as sound path)
        br      @isr_read_dur
isr_sound_note:
        movp    A,P2            ; set note freq
        mov     %$08,A
        sta     @mus_active
        ; Read P3
        inc     R34             ; R34++ (no carry needed, same page)
        lda     *R34
        movp    A,P3
isr_read_dur:
        inc     R34
        lda     *R34            ; dur_hi
        sta     @mus_dur_hi
        inc     R34
        lda     *R34            ; dur_lo
        sta     @mus_dur_lo
        inc     R34             ; advance past this note (4th byte done above)
        ; Save pointer back to SRAM
        ; Note: tune is <256 bytes, R34 won't wrap page boundary
        mov     R34,A
        sta     @mus_ptr_lo
        mov     R33,A
        sta     @mus_ptr_hi
        pop     B
        pop     A
        rets

isr_tune_end:
        ; Reset pointer to start of tune
        movd    %pop_tune,TEMP4
        mov     TEMP4-1,A      ; HIGH byte
        sta     @mus_ptr_hi
        mov     TEMP4,A        ; LOW byte
        sta     @mus_ptr_lo
        clr     A
        sta     @mus_dur_lo
        sta     @mus_dur_hi
        pop     B
        pop     A
        rets

; -- Screen data --

; -- Shared MIXT screen descriptor ---------------------------
screen_data2:
        .byte   $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte   $00,$00,$00,$00,$00

; -- Music partition -----------------------------------------
pop_tune:
; === Prince of Persia DOS Prologue A - bass/pulse line ===
; Extracted from OGG audio, 76 BPM, 0-2 cents accuracy
        .byte   $E8,$82,$00,$D1 ; A3  475ms
        .byte   $DB,$85,$00,$5D ; A#2 400ms
        .byte   $DB,$85,$00,$7A ; A#2 525ms
        .byte   $DB,$85,$00,$6F ; A#2 475ms
        .byte   $D0,$84,$00,$9A ; D3  525ms
        .byte   $DB,$85,$00,$63 ; A#2 425ms
        .byte   $D0,$84,$00,$9A ; D3  525ms
        .byte   $8C,$86,$00,$27 ; D#3 125ms
        .byte   $A5,$84,$00,$4A ; F#3 200ms
        .byte   $8C,$86,$00,$36 ; D#3 175ms
        .byte   $D0,$84,$00,$84 ; D3  450ms
        .byte   $DB,$85,$00,$6F ; A#2 475ms
        .byte   $DB,$85,$00,$F4 ; A#2 1050ms
        .byte   $C3,$83,$00,$D8 ; G3  550ms
        .byte   $D0,$84,$00,$49 ; D3  250ms
        .byte   $C3,$83,$00,$CE ; G3  525ms
        .byte   $B8,$83,$00,$49 ; G#3 175ms
        .byte   $58,$86,$00,$56 ; B3  175ms
        .byte   $B8,$83,$00,$49 ; G#3 175ms
        .byte   $C3,$83,$00,$EB ; G3  600ms
        .byte   $D0,$84,$01,$43 ; D3  1100ms
        .byte   $EA,$84,$00,$AA ; C3  650ms
        .byte   $EA,$84,$00,$AA ; C3  650ms
        .byte   $EA,$84,$00,$C4 ; C3  750ms
        .byte   $58,$86,$01,$65 ; B3  725ms
        .byte   $E8,$83,$01,$39 ; E3  950ms
        .byte   $DB,$83,$00,$3D ; F3  175ms
        .byte   $B8,$83,$00,$53 ; G#3 200ms
        .byte   $DB,$83,$00,$46 ; F3  200ms
        .byte   $E8,$83,$00,$94 ; E3  450ms
        .byte   $DB,$83,$00,$57 ; F3  250ms
        .byte   $E8,$83,$00,$F7 ; E3  750ms
        .byte   $E8,$82,$01,$97 ; A3  925ms
        .byte   $DB,$82,$00,$51 ; A#3 175ms
        .byte   $B8,$82,$00,$61 ; C#4 175ms
        .byte   $DB,$82,$00,$46 ; A#3 150ms
        .byte   $E8,$82,$01,$3F ; A3  725ms
        .byte   $DB,$85,$00,$DD ; A#2 950ms
        .byte   $F8,$84,$00,$2B ; B2  175ms
        .byte   $F8,$84,$00,$2B ; B2  175ms
        .byte   $DB,$85,$01,$17 ; A#2 1199ms
        .byte   $FF,$00,$00,$32 ; REST 500ms
        .byte   $00             ; end -- loop to pop_tune

; -- Intro image data (mona.asm) -----------------------------
BAGC2_DATA:
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ; $00
        .byte   $9C,$83,$83,$83,$83,$80,$80,$FF,$FF,$FF  ; $01
        .byte   $EC,$0C,$0C,$0C,$0D,$0D,$0F,$FF,$FF,$FF  ; $02
        .byte   $F0,$F1,$F3,$F3,$F7,$FF,$FF,$FF,$FF,$FF  ; $03
        .byte   $82,$C2,$E2,$F2,$F2,$FA,$FE,$FF,$FF,$FF  ; $04
        .byte   $1E,$1E,$9E,$9E,$DE,$FE,$FF,$FF,$FF,$FF  ; $05
        .byte   $10,$18,$3C,$7E,$FF,$FF,$FF,$FF,$FF,$FF  ; $06
        .byte   $41,$E1,$F1,$F9,$F9,$FD,$FF,$FF,$FF,$FF  ; $07
        .byte   $41,$43,$47,$4F,$4F,$5F,$7F,$FF,$FF,$FF  ; $08
        .byte   $0F,$8F,$CF,$CF,$EF,$FF,$FF,$FF,$FF,$FF  ; $09
        .byte   $3C,$3C,$3C,$3C,$BD,$BF,$FF,$FF,$FF,$FF  ; $0A
        .byte   $20,$70,$F8,$FC,$FC,$FE,$FF,$FF,$FF,$FF  ; $0B
        .byte   $C1,$C1,$C1,$C1,$C1,$E1,$E1,$FF,$FF,$FF  ; $0C
        .byte   $83,$83,$83,$83,$83,$87,$87,$FF,$FF,$FF  ; $0D
        .byte   $04,$0E,$1F,$3F,$3F,$7F,$FF,$FF,$FF,$FF  ; $0E
        .byte   $3C,$3C,$3C,$3C,$BD,$FD,$FF,$FF,$FF,$FF  ; $0F
        .byte   $08,$18,$3C,$7E,$FF,$FF,$FF,$FF,$FF,$FF  ; $10
        .byte   $39,$C1,$C1,$C1,$C1,$01,$01,$FF,$FF,$FF  ; $11
        .byte   $FF,$FF,$C0,$80,$83,$83,$83,$83,$9C,$9C  ; $12
        .byte   $00,$00,$FF,$FE,$FC,$FC,$78,$30,$00,$00  ; $13
        .byte   $00,$00,$FF,$FF,$F7,$F3,$F1,$F0,$F0,$F0  ; $14
        .byte   $00,$00,$FF,$BF,$9F,$8F,$8F,$86,$82,$80  ; $15
        .byte   $00,$00,$FF,$FE,$DE,$9E,$1E,$1E,$1E,$1E  ; $16
        .byte   $00,$00,$FF,$7F,$7B,$79,$78,$78,$78,$78  ; $17
        .byte   $00,$00,$FF,$FD,$F9,$F1,$F1,$61,$41,$01  ; $18
        .byte   $00,$00,$7F,$5F,$4F,$47,$47,$43,$41,$40  ; $19
        .byte   $00,$00,$FF,$7F,$3F,$3F,$1E,$0C,$00,$00  ; $1A
        .byte   $00,$00,$FF,$BF,$BD,$3C,$3C,$3C,$3C,$3C  ; $1B
        .byte   $80,$60,$BC,$AE,$A7,$A3,$A3,$A1,$A0,$A0  ; $1C
        .byte   $1F,$0F,$07,$07,$07,$07,$83,$83,$83,$03  ; $1D
        .byte   $01,$06,$3D,$75,$E5,$C5,$C5,$85,$05,$05  ; $1E
        .byte   $00,$00,$FF,$7F,$3F,$3F,$1E,$0C,$04,$00  ; $1F
        .byte   $00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; $20
        .byte   $00,$00,$FF,$FD,$BD,$3C,$3C,$3C,$3C,$3C  ; $21
        .byte   $0F,$1F,$F0,$B0,$B0,$30,$30,$30,$37,$37  ; $22
        .byte   $FF,$FF,$03,$01,$C1,$C1,$C1,$C1,$39,$39  ; $23
        .byte   $73,$F3,$F3,$F3,$F3,$73,$73,$33,$13,$10  ; $24
        .byte   $FE,$FE,$DA,$DB,$91,$B1,$FF,$FF,$FF,$00  ; $25
        .byte   $FC,$06,$33,$79,$CD,$FC,$FF,$FF,$FF,$00  ; $26
        .byte   $DF,$F0,$00,$80,$80,$FF,$FF,$FF,$FF,$00  ; $27
        .byte   $8F,$0F,$0B,$1F,$19,$F9,$FF,$FF,$FF,$00  ; $28
        .byte   $4F,$7D,$72,$A3,$C6,$FF,$FF,$FF,$FF,$00  ; $29
        .byte   $FE,$C4,$C6,$C4,$44,$FF,$FF,$FF,$FF,$00  ; $2A
        .byte   $FC,$07,$1F,$15,$11,$FF,$FF,$FF,$FF,$00  ; $2B
        .byte   $00,$00,$E0,$F0,$5F,$EB,$FF,$FF,$FF,$00  ; $2C
        .byte   $FF,$7F,$0F,$01,$00,$00,$00,$80,$E0,$00  ; $2D
        .byte   $FF,$FF,$FF,$FF,$3F,$0F,$03,$00,$00,$00  ; $2E
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FC,$FC  ; $2F
        .byte   $FF,$FF,$FF,$FF,$FC,$F0,$C0,$00,$00,$00  ; $30
        .byte   $FF,$FE,$F0,$80,$00,$00,$00,$01,$07,$00  ; $31
        .byte   $00,$00,$07,$0F,$FA,$D7,$FF,$FF,$FF,$00  ; $32
        .byte   $3F,$F8,$F8,$AC,$88,$FF,$FF,$FF,$FF,$00  ; $33
        .byte   $6E,$21,$61,$21,$22,$FF,$FF,$FF,$FF,$00  ; $34
        .byte   $F2,$BE,$4E,$C5,$63,$FF,$FF,$FF,$FF,$00  ; $35
        .byte   $71,$70,$D0,$F8,$98,$9F,$FF,$FF,$FF,$00  ; $36
        .byte   $FB,$0F,$00,$01,$01,$FF,$FF,$FF,$FF,$00  ; $37
        .byte   $3F,$61,$CC,$9E,$B1,$3F,$FF,$FF,$FF,$00  ; $38
        .byte   $7F,$7F,$5B,$DB,$89,$8D,$FF,$FF,$FF,$00  ; $39
        .byte   $CE,$CF,$CF,$CF,$CF,$CE,$CE,$CC,$C8,$08  ; $3A
        .byte   $C0,$FF,$FF,$C0,$FF,$FF,$C0,$E0,$E0,$F0  ; $3B
        .byte   $13,$F3,$F3,$03,$F3,$F3,$03,$13,$33,$33  ; $3C
        .byte   $1A,$F3,$E0,$00,$00,$07,$07,$05,$05,$07  ; $3D
        .byte   $38,$B1,$B3,$9E,$C4,$A0,$98,$B2,$96,$FC  ; $3E
        .byte   $11,$F9,$FE,$18,$CC,$EC,$26,$87,$61,$7C  ; $3F
        .byte   $08,$08,$0C,$05,$03,$01,$01,$61,$72,$5E  ; $40
        .byte   $0F,$8D,$9C,$97,$F0,$E0,$40,$60,$40,$C0  ; $41
        .byte   $00,$00,$00,$80,$E0,$38,$FE,$FB,$59,$1C  ; $42
        .byte   $FF,$3F,$1F,$03,$01,$00,$00,$00,$C0,$70  ; $43
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$1F  ; $44
        .byte   $7F,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FF,$FF  ; $45
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$F8  ; $46
        .byte   $FF,$FF,$FF,$FF,$FF,$FE,$F0,$C0,$00,$00  ; $47
        .byte   $FF,$FC,$F8,$C0,$80,$00,$00,$00,$03,$0F  ; $48
        .byte   $19,$34,$EC,$D9,$9B,$13,$DF,$CD,$C3,$FF  ; $49
        .byte   $F0,$B1,$19,$C9,$8F,$85,$82,$82,$00,$00  ; $4A
        .byte   $83,$46,$7C,$00,$00,$00,$00,$00,$01,$21  ; $4B
        .byte   $88,$9F,$7F,$18,$13,$17,$20,$E1,$87,$3E  ; $4C
        .byte   $58,$CF,$87,$80,$00,$F0,$F0,$B0,$B0,$F0  ; $4D
        .byte   $C3,$67,$3D,$01,$01,$01,$01,$01,$01,$01  ; $4E
        .byte   $C8,$CF,$CF,$C0,$CF,$CF,$C0,$C8,$CC,$CC  ; $4F
        .byte   $F0,$F8,$F8,$FC,$FD,$FC,$F8,$F8,$F0,$E0  ; $50
        .byte   $33,$73,$F3,$F3,$F3,$F3,$73,$73,$33,$13  ; $51
        .byte   $FF,$EF,$A1,$61,$F1,$BB,$1B,$0A,$4A,$0A  ; $52
        .byte   $81,$11,$99,$19,$01,$C3,$C2,$F4,$7C,$30  ; $53
        .byte   $89,$D8,$70,$2D,$8C,$FC,$DC,$54,$5C,$DD  ; $54
        .byte   $D3,$A1,$E3,$C7,$8D,$8C,$88,$88,$8E,$8E  ; $55
        .byte   $00,$80,$C0,$E0,$90,$9C,$8E,$8F,$38,$3E  ; $56
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$7F,$1F,$0F,$03  ; $57
        .byte   $FC,$FC,$FE,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ; $58
        .byte   $7F,$3F,$7F,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ; $59
        .byte   $FF,$FF,$FF,$FE,$FF,$FF,$FF,$FF,$FF,$FF  ; $5A
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FE,$F8,$F0,$C0  ; $5B
        .byte   $FE,$FC,$F0,$E0,$C0,$00,$00,$01,$02,$0F  ; $5C
        .byte   $EB,$85,$E6,$E3,$B0,$31,$19,$11,$70,$71  ; $5D
        .byte   $99,$0B,$8F,$B4,$30,$2F,$2F,$26,$3E,$BB  ; $5E
        .byte   $EF,$E0,$10,$F8,$9C,$8C,$06,$66,$66,$04  ; $5F
        .byte   $FF,$F7,$85,$82,$C7,$CD,$C8,$50,$52,$50  ; $60
        .byte   $53,$91,$B9,$6B,$FB,$BD,$F5,$55,$5D,$D9  ; $61
        .byte   $0F,$1F,$1F,$3F,$BF,$3F,$1F,$1F,$0F,$07  ; $62
        .byte   $E0,$C0,$FF,$FF,$C0,$FF,$FF,$C0,$E0,$E0  ; $63
        .byte   $BD,$FF,$E7,$A6,$BF,$95,$96,$B6,$F7,$EA  ; $64
        .byte   $FD,$04,$1E,$3F,$2F,$8B,$EB,$EE,$EE,$00  ; $65
        .byte   $C9,$E3,$FF,$7F,$34,$04,$4B,$7F,$C7,$C3  ; $66
        .byte   $E2,$8B,$E9,$2D,$3F,$3F,$16,$16,$0A,$0B  ; $67
        .byte   $03,$01,$01,$80,$C0,$60,$20,$78,$78,$5E  ; $68
        .byte   $FE,$FE,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FF  ; $69
        .byte   $7E,$7E,$FF,$7E,$7E,$7E,$7E,$7E,$7E,$FF  ; $6A
        .byte   $CF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ; $6B
        .byte   $FF,$F7,$F7,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ; $6C
        .byte   $FF,$FF,$FF,$FE,$FC,$F8,$F0,$E0,$C0,$80  ; $6D
        .byte   $67,$D1,$97,$B4,$FC,$7C,$6C,$6C,$58,$D8  ; $6E
        .byte   $F3,$6B,$8D,$FE,$1A,$3A,$1E,$0E,$30,$1B  ; $6F
        .byte   $BF,$20,$5C,$7E,$76,$5B,$7B,$73,$37,$04  ; $70
        .byte   $BD,$FF,$E7,$67,$FD,$AD,$6D,$6D,$EF,$57  ; $71
        .byte   $07,$03,$FF,$FF,$03,$FF,$FF,$03,$07,$07  ; $72
        .byte   $E0,$F0,$F8,$F8,$FC,$FD,$FC,$F8,$F8,$F0  ; $73
        .byte   $80,$BC,$BC,$AC,$BC,$BE,$E6,$FF,$BD,$81  ; $74
        .byte   $0F,$FD,$67,$00,$00,$00,$FC,$FF,$03,$F1  ; $75
        .byte   $8E,$9F,$BF,$60,$47,$D9,$DF,$97,$9D,$DD  ; $76
        .byte   $81,$C0,$40,$40,$60,$70,$90,$98,$EC,$F4  ; $77
        .byte   $FF,$FF,$FF,$7F,$3F,$3F,$1F,$0F,$0F,$07  ; $78
        .byte   $F9,$F9,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ; $79
        .byte   $F8,$FC,$FE,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ; $7A
        .byte   $3A,$72,$F2,$F0,$F8,$7E,$7E,$7E,$7E,$FF  ; $7B
        .byte   $42,$13,$1F,$33,$73,$73,$73,$73,$73,$FF  ; $7C
        .byte   $0B,$0F,$CF,$CF,$DF,$FF,$DF,$8F,$8F,$8F  ; $7D
        .byte   $FF,$FF,$FF,$FE,$FC,$FC,$F8,$F0,$F0,$E0  ; $7E
        .byte   $81,$03,$03,$02,$06,$07,$09,$19,$37,$2F  ; $7F

BAGC3_DATA:
        .byte   $70,$F8,$FC,$06,$E2,$93,$63,$E9,$A1,$BB  ; $00
        .byte   $F3,$BF,$EE,$00,$00,$00,$3F,$FF,$C0,$8F  ; $01
        .byte   $CC,$CC,$CE,$CF,$CF,$CF,$CF,$CE,$CE,$CC  ; $02
        .byte   $07,$0F,$1F,$1F,$3F,$BF,$3F,$1F,$1F,$0F  ; $03
        .byte   $F0,$E0,$C0,$FF,$FF,$C0,$FF,$FF,$C0,$E0  ; $04
        .byte   $DD,$CD,$A3,$BF,$9E,$80,$80,$80,$80,$80  ; $05
        .byte   $92,$C4,$4F,$3F,$1E,$09,$0B,$1B,$70,$63  ; $06
        .byte   $26,$26,$62,$E2,$C3,$83,$B9,$79,$59,$58  ; $07
        .byte   $0F,$07,$07,$07,$07,$07,$03,$03,$81,$81  ; $08
        .byte   $FF,$FF,$FF,$FE,$F8,$F8,$F8,$F8,$F8,$F8  ; $09
        .byte   $FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$00  ; $0A
        .byte   $78,$70,$40,$7F,$77,$10,$70,$10,$78,$4C  ; $0B
        .byte   $03,$07,$1F,$FF,$CF,$08,$48,$08,$08,$09  ; $0C
        .byte   $8F,$8F,$CD,$E7,$F7,$7B,$7F,$FF,$FF,$FF  ; $0D
        .byte   $FC,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ; $0E
        .byte   $7F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ; $0F
        .byte   $64,$64,$46,$47,$C1,$C1,$8F,$8F,$8B,$8B  ; $10
        .byte   $C0,$60,$43,$77,$7C,$98,$C1,$70,$6F,$4B  ; $11
        .byte   $B3,$87,$6D,$79,$01,$01,$01,$01,$01,$01  ; $12
        .byte   $CC,$C8,$C8,$CF,$CF,$C0,$CF,$CF,$C0,$C8  ; $13
        .byte   $0F,$07,$03,$FF,$FF,$03,$FF,$FF,$03,$07  ; $14
        .byte   $13,$33,$33,$73,$F3,$F3,$F3,$F3,$73,$73  ; $15
        .byte   $EC,$EC,$C7,$87,$CB,$D8,$D5,$D5,$D5,$DD  ; $16
        .byte   $F1,$E0,$44,$4C,$4E,$44,$60,$31,$15,$0F  ; $17
        .byte   $82,$E6,$7E,$46,$C6,$66,$E6,$E6,$A6,$A6  ; $18
        .byte   $E7,$E7,$F7,$F7,$FF,$FF,$FF,$FF,$FF,$FF  ; $19
        .byte   $F0,$F0,$F8,$F4,$F7,$F0,$E0,$F9,$F9,$FD  ; $1A
        .byte   $9C,$0E,$0E,$0E,$FE,$7E,$7C,$FE,$FE,$FE  ; $1B
        .byte   $02,$03,$03,$03,$06,$06,$0F,$1F,$3F,$3F  ; $1C
        .byte   $2B,$BB,$BB,$BB,$22,$AB,$FF,$FF,$FF,$FC  ; $1D
        .byte   $3F,$3F,$3F,$27,$07,$07,$CF,$C7,$87,$07  ; $1E
        .byte   $9F,$9F,$9F,$9F,$9F,$9F,$9F,$BF,$FF,$1F  ; $1F
        .byte   $00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; $20
        .byte   $FF,$FE,$FE,$FE,$FC,$FC,$FF,$FF,$FF,$FF  ; $21
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$E1,$D1,$F0,$B8  ; $22
        .byte   $41,$67,$7E,$62,$63,$62,$67,$67,$65,$65  ; $23
        .byte   $8F,$07,$23,$33,$73,$22,$06,$8C,$A8,$F0  ; $24
        .byte   $36,$EF,$0B,$10,$1E,$16,$23,$61,$49,$4C  ; $25
        .byte   $C8,$CC,$CC,$CE,$CF,$CF,$CF,$CF,$CE,$CE  ; $26
        .byte   $07,$07,$0F,$1F,$1F,$3F,$BF,$3F,$1F,$1F  ; $27
        .byte   $73,$33,$13,$13,$F3,$F3,$03,$F3,$F3,$03  ; $28
        .byte   $E7,$C1,$88,$88,$DB,$DB,$BE,$B6,$B4,$AC  ; $29
        .byte   $5C,$DD,$C1,$77,$7F,$37,$90,$A0,$7F,$77  ; $2A
        .byte   $C0,$8F,$99,$21,$2F,$3B,$29,$39,$38,$9A  ; $2B
        .byte   $C0,$80,$81,$81,$03,$02,$03,$07,$07,$07  ; $2C
        .byte   $FF,$FF,$FF,$FF,$1F,$FF,$FF,$FF,$FF,$FF  ; $2D
        .byte   $F3,$FB,$FF,$FF,$FD,$FF,$FF,$FF,$FC,$FF  ; $2E
        .byte   $E0,$F0,$EB,$6C,$6E,$EB,$EB,$EB,$E3,$E7  ; $2F
        .byte   $FF,$EF,$B0,$E0,$60,$60,$A0,$D0,$E8,$E0  ; $30
        .byte   $CE,$FF,$F0,$00,$03,$03,$03,$03,$03,$03  ; $31
        .byte   $38,$F8,$0F,$18,$F8,$E4,$C2,$C3,$83,$02  ; $32
        .byte   $07,$00,$C3,$FF,$7E,$06,$02,$02,$03,$02  ; $33
        .byte   $F0,$1F,$FF,$7F,$37,$2F,$0F,$3B,$3F,$2F  ; $34
        .byte   $7E,$E0,$E0,$C1,$FF,$FE,$FE,$FE,$FF,$FF  ; $35
        .byte   $00,$00,$00,$04,$1F,$FF,$FF,$FF,$FF,$FF  ; $36
        .byte   $00,$00,$00,$00,$FF,$FF,$F0,$FB,$FF,$FF  ; $37
        .byte   $FF,$FF,$FE,$E0,$FF,$7F,$FF,$9C,$F1,$FF  ; $38
        .byte   $F8,$F8,$00,$00,$FF,$FE,$80,$1F,$FF,$FF  ; $39
        .byte   $03,$01,$81,$81,$C0,$C0,$C0,$E0,$E0,$E0  ; $3A
        .byte   $03,$F1,$99,$B4,$F4,$DE,$96,$9C,$1C,$59  ; $3B
        .byte   $3A,$BB,$83,$E2,$FE,$EC,$0D,$1D,$FC,$EC  ; $3C
        .byte   $E7,$83,$11,$11,$DB,$5B,$7D,$2D,$2D,$35  ; $3D
        .byte   $CE,$CC,$C8,$C8,$CF,$CF,$C0,$CF,$CF,$C0  ; $3E
        .byte   $C0,$E0,$E0,$F0,$F8,$F8,$FC,$FD,$FC,$F8  ; $3F
        .byte   $03,$13,$33,$33,$73,$F3,$F3,$F3,$F3,$73  ; $40
        .byte   $3F,$3F,$20,$FF,$FF,$03,$02,$8C,$F8,$F1  ; $41
        .byte   $80,$80,$C0,$FF,$87,$03,$79,$39,$7A,$5A  ; $42
        .byte   $FE,$FE,$83,$FF,$FF,$00,$80,$8F,$BF,$E0  ; $43
        .byte   $80,$00,$00,$03,$07,$0F,$1F,$1F,$3F,$7F  ; $44
        .byte   $1F,$7F,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ; $45
        .byte   $F4,$F6,$EF,$4F,$0E,$1E,$BD,$F0,$FC,$FF  ; $46
        .byte   $00,$00,$00,$FF,$7F,$01,$8F,$C7,$F0,$F0  ; $47
        .byte   $FF,$FF,$1F,$F0,$00,$14,$04,$00,$03,$FF  ; $48
        .byte   $FC,$8C,$0C,$0C,$08,$00,$0F,$3F,$FF,$37  ; $49
        .byte   $9C,$FF,$F9,$1F,$D5,$CF,$CF,$CF,$CF,$CF  ; $4A
        .byte   $0F,$20,$F3,$FF,$FB,$F3,$FF,$FE,$FE,$BE  ; $4B
        .byte   $FF,$FF,$FF,$F0,$F0,$C0,$40,$00,$07,$72  ; $4C
        .byte   $FF,$FF,$FF,$FF,$DF,$FB,$F3,$07,$4F,$FF  ; $4D
        .byte   $FF,$FF,$FF,$FF,$FF,$FE,$F8,$E0,$C3,$81  ; $4E
        .byte   $FF,$FF,$FF,$7F,$3F,$1F,$1F,$03,$00,$00  ; $4F
        .byte   $3F,$8F,$C3,$F9,$F8,$FF,$FF,$FF,$0F,$7F  ; $50
        .byte   $01,$00,$00,$C0,$E0,$F0,$18,$08,$04,$02  ; $51
        .byte   $E0,$E0,$60,$3F,$1F,$1C,$0C,$07,$07,$02  ; $52
        .byte   $7F,$7F,$C1,$FF,$FF,$00,$01,$F1,$FD,$0F  ; $53
        .byte   $FC,$FC,$0C,$FF,$FF,$E0,$60,$73,$1F,$8F  ; $54
        .byte   $0F,$0F,$09,$FF,$FF,$7F,$DB,$93,$11,$83  ; $55
        .byte   $03,$07,$07,$0F,$1F,$1F,$3F,$BF,$3F,$1F  ; $56
        .byte   $F8,$F8,$F0,$E0,$C0,$FF,$FF,$C0,$FF,$FF  ; $57
        .byte   $F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0  ; $58
        .byte   $3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F  ; $59
        .byte   $80,$80,$80,$80,$80,$80,$80,$80,$80,$80  ; $5A
        .byte   $07,$07,$07,$07,$07,$07,$07,$07,$07,$07  ; $5B
        .byte   $F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$E0,$C0  ; $5C
        .byte   $F9,$F3,$EF,$EF,$FF,$FF,$7F,$7F,$7F,$7F  ; $5D
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$F7  ; $5E
        .byte   $80,$80,$C0,$E0,$78,$FF,$E3,$CF,$FF,$F9  ; $5F
        .byte   $00,$00,$01,$00,$00,$80,$F0,$FF,$FF,$FF  ; $60
        .byte   $00,$00,$E0,$FF,$7F,$03,$00,$FF,$FF,$FC  ; $61
        .byte   $00,$00,$60,$E0,$E0,$FF,$7F,$C7,$FF,$FF  ; $62
        .byte   $00,$00,$00,$00,$00,$80,$FE,$FF,$FF,$E0  ; $63
        .byte   $FF,$FF,$FF,$E0,$FC,$3F,$07,$FF,$FF,$1E  ; $64
        .byte   $FF,$FF,$83,$20,$00,$FF,$3F,$F8,$C0,$00  ; $65
        .byte   $FF,$FF,$FF,$FF,$FF,$F7,$F3,$FB,$FC,$FE  ; $66
        .byte   $C7,$C7,$F7,$FB,$FD,$FD,$FE,$FF,$FF,$3F  ; $67
        .byte   $1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$07,$03  ; $68
        .byte   $E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0  ; $69
        .byte   $7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F,$7F  ; $6A
        .byte   $FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC  ; $6B
        .byte   $CE,$CE,$CC,$C8,$C8,$CF,$CF,$C0,$CF,$CF  ; $6C
        .byte   $FF,$C0,$E0,$E0,$F0,$F8,$F8,$FC,$FD,$FC  ; $6D
        .byte   $F3,$03,$13,$33,$33,$73,$F3,$F3,$F3,$F3  ; $6E
        .byte   $06,$02,$FF,$FF,$92,$B2,$FF,$3F,$3F,$3F  ; $6F
        .byte   $04,$06,$FF,$FD,$4D,$6D,$FF,$C0,$80,$80  ; $70
        .byte   $04,$04,$FF,$BF,$B2,$B6,$FF,$FE,$FE,$FE  ; $71
        .byte   $0C,$0F,$FF,$F8,$B8,$B8,$F8,$F8,$F8,$F8  ; $72
        .byte   $0F,$FF,$FF,$0F,$0F,$0F,$0F,$0F,$0F,$0F  ; $73
        .byte   $FF,$FF,$FC,$F0,$ED,$CF,$C6,$C5,$E3,$FF  ; $74
        .byte   $D9,$DB,$FF,$FF,$FF,$DF,$BF,$FF,$FF,$FF  ; $75
        .byte   $FF,$FF,$FE,$FC,$F8,$F0,$F0,$E0,$E0,$C0  ; $76
        .byte   $FE,$FF,$3F,$0F,$00,$00,$00,$00,$00,$00  ; $77
        .byte   $F0,$E0,$C0,$00,$00,$00,$00,$03,$03,$00  ; $78
        .byte   $78,$3C,$3F,$0F,$03,$00,$80,$80,$00,$00  ; $79
        .byte   $7F,$FF,$FF,$80,$00,$00,$00,$00,$00,$00  ; $7A
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FD,$F0,$F0  ; $7B
        .byte   $DF,$DF,$FF,$FF,$FF,$FF,$FF,$8F,$3F,$FF  ; $7C
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$3F,$1F,$8F  ; $7D
        .byte   $F0,$FF,$FF,$F0,$F0,$F0,$F0,$F0,$F0,$F0  ; $7E
        .byte   $20,$20,$FF,$FF,$92,$B2,$FF,$E0,$E0,$E0  ; $7F

BAGC1_DATA:
        .byte   $40,$60,$FF,$FD,$4D,$6D,$FF,$7F,$7F,$7F  ; $00
        .byte   $C0,$40,$FF,$BF,$B2,$B6,$FF,$03,$01,$01  ; $01
        .byte   $81,$81,$FF,$F7,$B7,$B7,$FF,$0F,$0F,$0F  ; $02
        .byte   $CF,$C0,$C8,$CC,$CC,$CE,$CF,$CF,$CF,$CF  ; $03
        .byte   $FC,$F8,$F8,$F0,$E0,$C0,$FF,$FF,$C0,$FF  ; $04
        .byte   $F3,$73,$73,$33,$13,$13,$F3,$F3,$03,$F3  ; $05
        .byte   $06,$02,$06,$FF,$FE,$06,$06,$06,$06,$06  ; $06
        .byte   $04,$04,$04,$FF,$FC,$04,$04,$04,$04,$04  ; $07
        .byte   $04,$04,$06,$FF,$FC,$04,$04,$0C,$04,$04  ; $08
        .byte   $FC,$F9,$FB,$FF,$FE,$0E,$0F,$0F,$0C,$08  ; $09
        .byte   $DF,$EF,$EF,$7F,$3F,$1F,$FF,$FF,$0F,$0F  ; $0A
        .byte   $0E,$0C,$0C,$2D,$AB,$CF,$FF,$FF,$FF,$FF  ; $0B
        .byte   $7B,$FB,$FF,$F7,$E7,$EF,$FE,$DE,$DC,$DD  ; $0C
        .byte   $F1,$E3,$E3,$C7,$C7,$C7,$E7,$E7,$CF,$EE  ; $0D
        .byte   $FF,$FF,$EE,$FF,$FF,$73,$71,$83,$FF,$FF  ; $0E
        .byte   $1F,$7F,$FD,$FD,$FF,$FF,$FF,$EF,$F7,$F7  ; $0F
        .byte   $FF,$FF,$FF,$FF,$DF,$FF,$FF,$FF,$FF,$FF  ; $10
        .byte   $FF,$FF,$FF,$FF,$7F,$7F,$FF,$FF,$FF,$7F  ; $11
        .byte   $00,$0F,$5E,$FC,$FC,$E0,$00,$00,$C0,$FF  ; $12
        .byte   $3B,$37,$37,$3E,$3C,$38,$3F,$3F,$30,$F0  ; $13
        .byte   $E0,$E0,$E0,$FF,$E0,$20,$20,$20,$20,$20  ; $14
        .byte   $40,$40,$60,$FF,$6F,$40,$40,$40,$40,$40  ; $15
        .byte   $C0,$C0,$C0,$FF,$DF,$C0,$C0,$C0,$C0,$C0  ; $16
        .byte   $81,$81,$81,$FF,$81,$81,$81,$81,$81,$81  ; $17
        .byte   $CF,$CE,$CE,$CC,$C8,$C8,$CF,$CF,$C0,$CF  ; $18
        .byte   $FF,$FF,$C0,$E0,$E0,$F0,$F8,$F8,$FC,$FD  ; $19
        .byte   $F3,$F3,$03,$13,$33,$33,$73,$F3,$F3,$F3  ; $1A
        .byte   $06,$06,$02,$FF,$FF,$02,$06,$02,$02,$06  ; $1B
        .byte   $04,$04,$04,$FF,$FF,$04,$04,$04,$04,$04  ; $1C
        .byte   $08,$08,$08,$FF,$FF,$0F,$0F,$0F,$0F,$0F  ; $1D
        .byte   $0B,$0F,$0F,$FE,$FC,$F9,$FB,$FF,$FE,$FE  ; $1E
        .byte   $EF,$7F,$3F,$1F,$DF,$CF,$EF,$7F,$3F,$9F  ; $1F
        .byte   $00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; $20
        .byte   $FF,$DF,$6E,$A4,$B0,$C1,$C1,$C3,$6E,$0E  ; $21
        .byte   $E0,$E0,$79,$4B,$83,$37,$7F,$DE,$9E,$3D  ; $22
        .byte   $EF,$7F,$FF,$FD,$FF,$F7,$F6,$E6,$DE,$D8  ; $23
        .byte   $FF,$FF,$FF,$DF,$DF,$9F,$7F,$7F,$BF,$7F  ; $24
        .byte   $F8,$F0,$F0,$E0,$E0,$E0,$C0,$C0,$C0,$E0  ; $25
        .byte   $7F,$19,$1F,$0F,$07,$07,$07,$07,$0F,$1F  ; $26
        .byte   $BF,$F3,$FF,$DF,$FF,$FF,$FF,$FF,$FF,$FF  ; $27
        .byte   $CF,$7F,$BD,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ; $28
        .byte   $F9,$FD,$CE,$DF,$DF,$FF,$FF,$FF,$FF,$FF  ; $29
        .byte   $F7,$F7,$F7,$E7,$D3,$F7,$B6,$E6,$64,$00  ; $2A
        .byte   $F7,$FE,$BC,$F8,$FB,$33,$37,$3E,$3C,$39  ; $2B
        .byte   $20,$20,$20,$FF,$FF,$E0,$E0,$E0,$E0,$E0  ; $2C
        .byte   $40,$40,$60,$FF,$FF,$40,$40,$40,$40,$40  ; $2D
        .byte   $40,$C0,$40,$FF,$FF,$C0,$C0,$C0,$C0,$C0  ; $2E
        .byte   $81,$81,$81,$FF,$DF,$81,$81,$81,$81,$81  ; $2F
        .byte   $CF,$CF,$C0,$C8,$CC,$CC,$CE,$CF,$CF,$CF  ; $30
        .byte   $FD,$FC,$F8,$F8,$F0,$E0,$C0,$FF,$FF,$C0  ; $31
        .byte   $F3,$F3,$73,$73,$33,$13,$13,$F3,$F3,$03  ; $32
        .byte   $06,$06,$02,$07,$FF,$FE,$06,$06,$06,$06  ; $33
        .byte   $04,$04,$04,$0C,$FF,$FF,$04,$04,$04,$04  ; $34
        .byte   $08,$08,$08,$0C,$FF,$FF,$08,$08,$08,$08  ; $35
        .byte   $0C,$0F,$0F,$18,$F8,$FF,$1F,$0E,$0C,$09  ; $36
        .byte   $0F,$FF,$FF,$0F,$0F,$FF,$3F,$1F,$DF,$CF  ; $37
        .byte   $00,$60,$38,$81,$E7,$FF,$FF,$FF,$FE,$FC  ; $38
        .byte   $7F,$FB,$F8,$FC,$EC,$FC,$F8,$E0,$E1,$E1  ; $39
        .byte   $FF,$FF,$FB,$FB,$7F,$F7,$F7,$E7,$E7,$E7  ; $3A
        .byte   $80,$C0,$FC,$FF,$3F,$3F,$FF,$FF,$FF,$FF  ; $3B
        .byte   $02,$02,$03,$03,$FF,$FF,$FE,$FF,$FF,$FF  ; $3C
        .byte   $18,$78,$F8,$FB,$FF,$7E,$FC,$FC,$FF,$FF  ; $3D
        .byte   $00,$00,$00,$00,$00,$00,$00,$00,$02,$1F  ; $3E
        .byte   $0F,$0F,$0E,$0F,$0F,$0F,$0F,$7F,$FF,$CF  ; $3F
        .byte   $CF,$CB,$C7,$EF,$FF,$F7,$F7,$FF,$FF,$FF  ; $40
        .byte   $0F,$87,$C7,$E3,$71,$60,$30,$19,$1D,$01  ; $41
        .byte   $FD,$F9,$F3,$F3,$FF,$FF,$FF,$FF,$FF,$FD  ; $42
        .byte   $30,$F0,$F0,$10,$1F,$FF,$F0,$70,$30,$90  ; $43
        .byte   $20,$20,$20,$60,$FF,$E7,$60,$20,$20,$20  ; $44
        .byte   $40,$40,$40,$E0,$FF,$CF,$C0,$C0,$C0,$C0  ; $45
        .byte   $C0,$C0,$C0,$C0,$FF,$DF,$C1,$40,$C0,$C0  ; $46
        .byte   $81,$81,$81,$C3,$FF,$9D,$81,$81,$81,$81  ; $47
        .byte   $BF,$3F,$1F,$0F,$0F,$07,$03,$FF,$FF,$03  ; $48
        .byte   $C0,$FF,$FF,$C0,$E0,$E0,$F0,$F8,$F8,$FC  ; $49
        .byte   $82,$82,$82,$83,$FF,$FF,$82,$82,$82,$82  ; $4A
        .byte   $06,$06,$06,$02,$FF,$FF,$06,$06,$02,$02  ; $4B
        .byte   $0C,$04,$0C,$0C,$FF,$FF,$04,$04,$04,$04  ; $4C
        .byte   $0F,$0F,$0F,$0F,$FF,$FF,$0C,$08,$08,$08  ; $4D
        .byte   $F8,$F8,$F8,$F8,$F8,$F8,$08,$08,$08,$08  ; $4E
        .byte   $E3,$E3,$F1,$F8,$F1,$F9,$F9,$FF,$7E,$3C  ; $4F
        .byte   $C0,$CF,$83,$C7,$C7,$E1,$A1,$E3,$C6,$8C  ; $50
        .byte   $BF,$FF,$FF,$73,$E3,$E3,$F7,$F7,$F7,$E7  ; $51
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$7F,$3F,$FF  ; $52
        .byte   $F8,$BC,$BC,$FE,$7F,$3F,$03,$00,$00,$00  ; $53
        .byte   $1F,$1F,$3F,$3F,$BF,$E3,$E3,$C3,$02,$02  ; $54
        .byte   $E0,$E0,$FC,$F8,$C0,$00,$00,$00,$00,$00  ; $55
        .byte   $1F,$17,$1F,$0F,$03,$00,$04,$00,$00,$00  ; $56
        .byte   $FC,$FE,$FE,$FF,$FF,$FF,$7F,$3F,$1F,$0F  ; $57
        .byte   $C3,$81,$C5,$C4,$80,$80,$87,$83,$83,$C3  ; $58
        .byte   $FF,$FF,$FF,$FF,$7D,$7E,$BE,$9F,$8F,$0F  ; $59
        .byte   $1F,$1F,$1F,$1F,$1F,$1F,$10,$10,$10,$10  ; $5A
        .byte   $E0,$E0,$E0,$E0,$FF,$FF,$30,$20,$20,$20  ; $5B
        .byte   $C0,$C0,$C0,$40,$FF,$FF,$C0,$C0,$40,$40  ; $5C
        .byte   $C0,$40,$C0,$40,$FF,$FF,$C0,$C0,$C0,$C0  ; $5D
        .byte   $81,$81,$81,$C1,$FF,$FF,$C3,$81,$81,$81  ; $5E
        .byte   $03,$FF,$FF,$03,$07,$07,$0F,$1F,$1F,$3F  ; $5F
        .byte   $FC,$FD,$FC,$F8,$F0,$F0,$E0,$C0,$FF,$FF  ; $60
        .byte   $82,$82,$82,$82,$83,$FF,$BF,$86,$82,$82  ; $61
        .byte   $02,$06,$06,$02,$07,$FF,$FE,$06,$06,$06  ; $62
        .byte   $04,$04,$04,$04,$04,$FF,$FC,$04,$04,$0C  ; $63
        .byte   $08,$08,$08,$08,$0C,$FF,$FF,$0F,$0F,$0F  ; $64
        .byte   $FF,$FF,$FE,$FC,$F9,$F1,$F8,$F0,$F0,$F1  ; $65
        .byte   $FF,$FF,$7F,$3F,$8F,$87,$83,$80,$00,$E0  ; $66
        .byte   $FD,$F0,$FC,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ; $67
        .byte   $7F,$01,$01,$00,$00,$F0,$FD,$FF,$FF,$FF  ; $68
        .byte   $FF,$FF,$DF,$CF,$0F,$EF,$E7,$E6,$EE,$FF  ; $69
        .byte   $BF,$9F,$0F,$07,$07,$07,$01,$03,$07,$0F  ; $6A
        .byte   $FD,$FD,$DF,$C6,$C2,$E2,$FF,$7E,$38,$FF  ; $6B
        .byte   $00,$00,$00,$00,$00,$00,$00,$00,$07,$07  ; $6C
        .byte   $3B,$39,$78,$78,$78,$78,$F8,$F8,$F8,$F8  ; $6D
        .byte   $07,$00,$80,$40,$00,$00,$80,$C0,$C0,$E0  ; $6E
        .byte   $E7,$F1,$FC,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ; $6F
        .byte   $FF,$FC,$F0,$B3,$87,$FF,$FF,$FF,$FF,$FF  ; $70
        .byte   $10,$10,$10,$10,$10,$1F,$1F,$1F,$1F,$1F  ; $71
        .byte   $20,$20,$20,$20,$60,$FF,$E7,$E0,$E0,$E0  ; $72
        .byte   $40,$40,$40,$40,$E0,$FF,$CF,$C0,$C0,$C0  ; $73
        .byte   $C0,$C0,$C0,$C0,$C0,$FF,$DF,$C1,$40,$C0  ; $74
        .byte   $81,$81,$81,$81,$81,$FF,$FD,$81,$81,$81  ; $75
        .byte   $3F,$BF,$3F,$1F,$0F,$0F,$07,$03,$FF,$FF  ; $76
        .byte   $FF,$C0,$FF,$FF,$C0,$E0,$E0,$F0,$F8,$F8  ; $77
        .byte   $82,$82,$82,$82,$83,$83,$FF,$BF,$82,$82  ; $78
        .byte   $06,$06,$06,$06,$02,$02,$FF,$3E,$06,$06  ; $79
        .byte   $0C,$04,$04,$0C,$04,$04,$FF,$FF,$04,$04  ; $7A
        .byte   $08,$08,$08,$08,$08,$0C,$FF,$FF,$08,$08  ; $7B
        .byte   $FF,$FF,$70,$BC,$C5,$F3,$FB,$FF,$FF,$FF  ; $7C
        .byte   $FF,$FF,$3F,$7F,$FF,$FF,$FF,$FF,$FF,$FF  ; $7D
        .byte   $F8,$FC,$FE,$FF,$FF,$FF,$CF,$FF,$FF,$FD  ; $7E
        .byte   $C7,$8F,$1F,$3F,$FF,$FF,$FF,$FF,$FF,$FF  ; $7F

BAGC0_DATA:
        .byte   $FF,$FF,$7F,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ; $00
        .byte   $FF,$FF,$FF,$FB,$FF,$FF,$FF,$FF,$FF,$BF  ; $01
        .byte   $E0,$C0,$80,$80,$80,$80,$80,$FF,$FF,$FF  ; $02
        .byte   $E1,$01,$00,$00,$00,$00,$00,$00,$00,$00  ; $03
        .byte   $3F,$7F,$EF,$4E,$7E,$3F,$3F,$3F,$3C,$3B  ; $04
        .byte   $FF,$FF,$BF,$FF,$FF,$7F,$8F,$8F,$83,$0F  ; $05
        .byte   $10,$10,$10,$10,$10,$10,$1F,$1F,$10,$10  ; $06
        .byte   $20,$20,$20,$20,$20,$60,$FF,$FF,$20,$20  ; $07
        .byte   $C0,$C0,$C0,$C0,$40,$40,$FF,$DF,$C0,$40  ; $08
        .byte   $C0,$C0,$C0,$C0,$C0,$40,$FF,$DF,$C0,$C0  ; $09
        .byte   $CF,$C0,$CF,$CF,$C0,$C8,$CC,$CC,$CE,$CF  ; $0A
        .byte   $FF,$03,$FF,$FF,$03,$07,$07,$0F,$1F,$1F  ; $0B
        .byte   $F8,$FC,$FD,$FC,$F8,$F0,$F0,$E0,$C0,$FF  ; $0C
        .byte   $82,$82,$82,$82,$82,$82,$FF,$FF,$82,$82  ; $0D
        .byte   $06,$02,$06,$06,$02,$02,$FF,$FF,$06,$06  ; $0E
        .byte   $04,$04,$04,$04,$04,$04,$FF,$FF,$0C,$04  ; $0F
        .byte   $08,$08,$08,$08,$08,$08,$FF,$FF,$0C,$08  ; $10
        .byte   $00,$00,$00,$00,$00,$00,$FF,$FF,$0F,$0F  ; $11
        .byte   $3F,$3F,$3F,$3F,$3F,$3F,$FF,$FF,$FF,$FF  ; $12
        .byte   $FE,$FF,$FF,$FF,$FF,$0F,$F1,$F0,$CE,$EF  ; $13
        .byte   $1F,$9D,$85,$C2,$E1,$F1,$F0,$7C,$13,$03  ; $14
        .byte   $FE,$FE,$EC,$04,$C8,$D9,$97,$E7,$FF,$FB  ; $15
        .byte   $9E,$BC,$FE,$FC,$F8,$FC,$FE,$FC,$FF,$FF  ; $16
        .byte   $03,$03,$06,$00,$00,$00,$00,$07,$FF,$FF  ; $17
        .byte   $70,$60,$E0,$E0,$C0,$80,$00,$00,$00,$00  ; $18
        .byte   $00,$00,$00,$00,$00,$00,$70,$F8,$FB,$B9  ; $19
        .byte   $FF,$FF,$FF,$FD,$7E,$7F,$9F,$3F,$7F,$FF  ; $1A
        .byte   $E0,$F0,$F8,$F8,$FC,$FE,$FF,$FF,$FF,$FF  ; $1B
        .byte   $0D,$8F,$FF,$7F,$7E,$3C,$DF,$FF,$FF,$FF  ; $1C
        .byte   $00,$00,$00,$00,$00,$00,$FF,$FF,$F0,$F0  ; $1D
        .byte   $00,$00,$00,$00,$00,$00,$FF,$FF,$10,$10  ; $1E
        .byte   $40,$40,$40,$40,$40,$40,$FF,$FF,$40,$40  ; $1F
        .byte   $00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; $20
        .byte   $40,$40,$40,$40,$40,$40,$FF,$FF,$C0,$C0  ; $21
        .byte   $81,$81,$81,$81,$81,$81,$FF,$FF,$81,$81  ; $22
        .byte   $CF,$CF,$CF,$CF,$CE,$CE,$CC,$C8,$C8,$CF  ; $23
        .byte   $1F,$3F,$BF,$3F,$1F,$0F,$0F,$07,$03,$FF  ; $24
        .byte   $0B,$F8,$00,$F3,$F3,$03,$13,$33,$33,$73  ; $25
        .byte   $FF,$00,$00,$FF,$FF,$ED,$ED,$FF,$FF,$86  ; $26
        .byte   $FF,$00,$00,$FF,$FF,$4D,$6D,$FF,$FC,$04  ; $27
        .byte   $FF,$00,$00,$FF,$FF,$B2,$B6,$FF,$FF,$04  ; $28
        .byte   $FF,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; $29
        .byte   $FF,$20,$20,$30,$3F,$3F,$3F,$3F,$3F,$3F  ; $2A
        .byte   $FF,$00,$00,$00,$FF,$FC,$FC,$FF,$FF,$F9  ; $2B
        .byte   $FF,$00,$00,$00,$FF,$63,$61,$F1,$E1,$9E  ; $2C
        .byte   $FF,$00,$00,$00,$FF,$FF,$FF,$FF,$DF,$03  ; $2D
        .byte   $FF,$00,$00,$00,$FF,$FF,$FF,$FF,$FE,$BE  ; $2E
        .byte   $FF,$00,$00,$00,$FF,$00,$01,$00,$00,$01  ; $2F
        .byte   $FF,$00,$00,$00,$FF,$08,$18,$18,$38,$30  ; $30
        .byte   $FF,$00,$00,$00,$FF,$00,$00,$00,$00,$00  ; $31
        .byte   $FF,$00,$00,$00,$FF,$01,$01,$03,$E1,$F1  ; $32
        .byte   $FF,$00,$00,$00,$FF,$C0,$80,$C0,$C0,$C0  ; $33
        .byte   $FF,$00,$00,$00,$FF,$3F,$3F,$3F,$3F,$3F  ; $34
        .byte   $FF,$20,$20,$3F,$3F,$32,$32,$3F,$3F,$20  ; $35
        .byte   $FF,$00,$00,$FF,$FF,$4D,$6D,$FF,$EF,$40  ; $36
        .byte   $FF,$00,$00,$FF,$FF,$49,$4D,$FF,$DF,$C0  ; $37
        .byte   $FF,$00,$00,$FF,$FF,$B7,$B7,$FF,$FF,$81  ; $38
        .byte   $01,$FF,$01,$FF,$FF,$03,$07,$07,$0F,$1F  ; $39
        .byte   $80,$80,$98,$9C,$8A,$84,$85,$83,$80,$80  ; $3A
        .byte   $03,$03,$23,$63,$C3,$C3,$83,$03,$03,$03  ; $3B
        .byte   $A6,$A2,$48,$EC,$F0,$1B,$1B,$53,$ED,$13  ; $3C
        .byte   $58,$D9,$FB,$7B,$FB,$7B,$FB,$FB,$F8,$F8  ; $3D
        .byte   $F8,$F8,$02,$07,$FF,$FF,$FF,$FE,$00,$00  ; $3E
        .byte   $F1,$71,$18,$1C,$0F,$1F,$3F,$1F,$01,$01  ; $3F
        .byte   $F4,$F6,$7F,$7C,$FE,$FD,$FF,$FF,$FF,$FF  ; $40
        .byte   $CF,$8F,$24,$7E,$1F,$B1,$B1,$94,$6E,$90  ; $41
        .byte   $FC,$FE,$CE,$E3,$E1,$F0,$F8,$FC,$FC,$FE  ; $42
        .byte   $F8,$30,$01,$83,$FF,$1F,$1F,$FF,$70,$78  ; $43
        .byte   $F3,$C3,$8C,$0E,$0F,$8F,$8F,$87,$00,$00  ; $44
        .byte   $E1,$F1,$39,$19,$D9,$D9,$D9,$99,$01,$03  ; $45
        .byte   $87,$8F,$9C,$98,$9B,$9B,$9B,$99,$80,$C0  ; $46
        .byte   $1F,$0C,$80,$C1,$FF,$F8,$F8,$FF,$0E,$1E  ; $47
        .byte   $3F,$7F,$73,$C7,$87,$0F,$1F,$3F,$3F,$7F  ; $48
        .byte   $F3,$F1,$24,$7E,$F8,$8D,$8D,$29,$76,$09  ; $49
        .byte   $2F,$6F,$FE,$3E,$7F,$BF,$FF,$FF,$FF,$FF  ; $4A
        .byte   $C7,$E3,$70,$38,$0F,$80,$81,$C7,$E3,$F7  ; $4B
        .byte   $1F,$1F,$40,$E0,$FF,$FF,$FF,$7F,$00,$00  ; $4C
        .byte   $FE,$FF,$03,$01,$FC,$FE,$FC,$FD,$00,$00  ; $4D
        .byte   $65,$45,$12,$37,$0F,$D8,$D8,$CA,$B7,$C8  ; $4E
        .byte   $B8,$96,$27,$61,$83,$FB,$DF,$57,$2F,$5F  ; $4F
        .byte   $C1,$19,$39,$39,$39,$C1,$C1,$C1,$C1,$01  ; $50
        .byte   $84,$86,$87,$87,$86,$86,$86,$86,$8E,$80  ; $51
        .byte   $83,$C3,$C3,$C3,$C3,$43,$03,$03,$03,$03  ; $52
        .byte   $F8,$CC,$08,$A2,$A6,$E6,$19,$18,$01,$E6  ; $53
        .byte   $7B,$7B,$FB,$DB,$58,$18,$3B,$5B,$1B,$3A  ; $54
        .byte   $FC,$F0,$F1,$C1,$E1,$F1,$F8,$FC,$07,$F9  ; $55
        .byte   $03,$F0,$F8,$F3,$F7,$EE,$CC,$18,$11,$F1  ; $56
        .byte   $7C,$3C,$3F,$F6,$F4,$F0,$F9,$F4,$F1,$F8  ; $57
        .byte   $3E,$76,$20,$8F,$CF,$CE,$31,$31,$00,$CE  ; $58
        .byte   $E7,$87,$8C,$F2,$F6,$FC,$F9,$FB,$F3,$F9  ; $59
        .byte   $FC,$F1,$03,$3D,$1E,$0E,$C3,$F3,$F1,$F8  ; $5A
        .byte   $03,$E1,$F0,$F8,$F8,$70,$63,$07,$8C,$F9  ; $5B
        .byte   $F9,$F9,$F9,$79,$01,$01,$79,$F9,$39,$89  ; $5C
        .byte   $9F,$9F,$9F,$9E,$80,$80,$9E,$9F,$9C,$91  ; $5D
        .byte   $C0,$87,$0F,$1F,$1F,$0E,$C6,$E0,$31,$9F  ; $5E
        .byte   $3F,$8F,$C0,$BC,$78,$70,$C3,$CF,$8F,$1F  ; $5F
        .byte   $C3,$C3,$E0,$24,$0E,$8C,$D1,$A3,$90,$CE  ; $60
        .byte   $7C,$6E,$04,$F1,$F3,$73,$8C,$8C,$00,$73  ; $61
        .byte   $3E,$3C,$FC,$6F,$2F,$0F,$9F,$2F,$8F,$1F  ; $62
        .byte   $C0,$0F,$1F,$CF,$EF,$77,$33,$18,$88,$8F  ; $63
        .byte   $3F,$0F,$8F,$83,$87,$8F,$1F,$3F,$E0,$9F  ; $64
        .byte   $DE,$DE,$DF,$DB,$1A,$18,$DC,$DA,$D8,$5C  ; $65
        .byte   $1F,$33,$10,$45,$65,$67,$98,$18,$80,$67  ; $66
        .byte   $C7,$C7,$C0,$C0,$C0,$C7,$C7,$C7,$C0,$C0  ; $67
        .byte   $39,$19,$C1,$C1,$C1,$39,$39,$39,$01,$C1  ; $68
        .byte   $FF,$FF,$FF,$80,$80,$86,$82,$82,$81,$84  ; $69
        .byte   $FF,$FF,$FF,$FF,$FF,$FA,$F4,$EA,$FB,$DB  ; $6A
        .byte   $FF,$FF,$FF,$FF,$FF,$53,$ED,$13,$1B,$3B  ; $6B
        .byte   $FF,$FF,$FF,$FF,$FF,$1E,$0C,$E0,$F1,$FB  ; $6C
        .byte   $FF,$FF,$FF,$FF,$FF,$1F,$47,$E3,$F8,$FE  ; $6D
        .byte   $FF,$FF,$FF,$FF,$FF,$7C,$00,$03,$FF,$FF  ; $6E
        .byte   $FF,$FF,$FF,$FF,$FF,$07,$03,$C3,$8F,$3D  ; $6F
        .byte   $FF,$FF,$FF,$FF,$FF,$BC,$58,$AC,$BE,$B7  ; $70
        .byte   $FF,$FF,$FF,$FF,$FF,$03,$00,$78,$1F,$8F  ; $71
        .byte   $FF,$FF,$FF,$FF,$FF,$C1,$00,$1E,$FF,$FF  ; $72
        .byte   $FF,$FF,$FF,$FF,$FF,$8F,$26,$70,$F0,$F9  ; $73
        .byte   $FF,$FF,$FF,$FF,$FF,$07,$03,$F3,$F9,$F9  ; $74
        .byte   $FF,$FF,$FF,$FF,$FF,$F1,$64,$0E,$0F,$9F  ; $75
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$7F,$1E,$83,$E0  ; $76
        .byte   $FF,$FF,$FF,$FF,$FF,$C0,$00,$1E,$F8,$F1  ; $77
        .byte   $FF,$FF,$FF,$FF,$FF,$3D,$1A,$35,$7D,$ED  ; $78
        .byte   $FF,$FF,$FF,$FF,$FF,$29,$76,$09,$8D,$9D  ; $79
        .byte   $FF,$FF,$FF,$FF,$FF,$3E,$00,$C0,$FF,$FF  ; $7A
        .byte   $FF,$FF,$FF,$FF,$FF,$0F,$0F,$F3,$FC,$F8  ; $7B
        .byte   $FF,$FF,$FF,$FF,$FF,$78,$30,$07,$8F,$DF  ; $7C
        .byte   $FF,$FF,$FF,$FF,$FF,$3F,$3F,$1F,$9F,$DE  ; $7D
        .byte   $FF,$FF,$FF,$FF,$FF,$5F,$2F,$57,$DF,$DB  ; $7E
        .byte   $FF,$FF,$FF,$D0,$C0,$C0,$C0,$C0,$C7,$C7  ; $7F

SCREEN_DATA:
; Row 0
        .byte   $0F,$00,$0F,$00,$0F,$00,$0F,$01,$0F,$02,$0F,$0B,$0F,$03,$0F,$04
        .byte   $10,$7F,$0F,$05,$0F,$06,$0F,$79,$0F,$07,$0F,$08,$0F,$09,$0F,$0E
        .byte   $0F,$0A,$0F,$0B,$0F,$03,$0F,$0C,$0F,$0D,$0F,$09,$0F,$0E,$0F,$0F
        .byte   $0F,$0B,$0F,$03,$0F,$04,$10,$7F,$0F,$05,$0F,$10,$0F,$79,$0F,$07
        .byte   $0F,$08,$0F,$09,$0F,$0E,$1F,$60,$0F,$11,$0F,$00,$0F,$00,$0F,$00
; Row 1
        .byte   $0F,$00,$0F,$00,$0F,$00,$0F,$12,$0F,$02,$0F,$13,$0F,$14,$0F,$13
        .byte   $0F,$15,$0F,$16,$0F,$13,$0F,$17,$0F,$18,$0F,$19,$10,$1D,$0F,$1A
        .byte   $0F,$1B,$0F,$13,$0F,$1C,$0F,$1D,$10,$25,$0F,$1E,$0F,$1F,$0F,$21
        .byte   $0F,$13,$0F,$14,$0F,$13,$0F,$15,$0F,$16,$0F,$1A,$0F,$17,$0F,$18
        .byte   $0F,$19,$10,$1D,$0F,$1A,$0F,$22,$0F,$23,$0F,$00,$0F,$00,$0F,$00
; Row 2
        .byte   $0F,$00,$0F,$00,$0F,$00,$1F,$5C,$0F,$24,$0F,$25,$0F,$28,$0F,$26
        .byte   $0F,$27,$0F,$28,$0F,$27,$0F,$29,$0F,$2A,$0F,$2A,$0F,$2B,$0F,$2C
        .byte   $1F,$63,$0F,$2D,$0F,$2E,$0F,$44,$0F,$2F,$0F,$30,$0F,$31,$1F,$63
        .byte   $0F,$32,$0F,$33,$0F,$34,$0F,$34,$0F,$35,$0F,$34,$0F,$36,$0F,$37
        .byte   $0F,$38,$0F,$36,$0F,$39,$0F,$3A,$1F,$68,$0F,$00,$0F,$00,$0F,$00
; Row 3
        .byte   $0F,$00,$0F,$00,$0F,$00,$0F,$3B,$0F,$3C,$1F,$5A,$0F,$3D,$0F,$3E
        .byte   $0F,$3F,$00,$03,$0F,$40,$0F,$41,$0F,$07,$0F,$42,$0F,$43,$1F,$4F
        .byte   $0F,$44,$0F,$45,$0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$46
        .byte   $0F,$47,$0F,$48,$00,$1E,$0F,$49,$0F,$4A,$10,$25,$0F,$4B,$0F,$4C
        .byte   $0F,$21,$0F,$4D,$0F,$4E,$0F,$4F,$1F,$73,$0F,$00,$0F,$00,$0F,$00
; Row 4
        .byte   $0F,$00,$0F,$00,$0F,$00,$0F,$50,$0F,$51,$1F,$1F,$0F,$52,$0F,$53
        .byte   $00,$29,$0F,$54,$0F,$55,$0F,$56,$0F,$43,$0F,$57,$0F,$00,$0F,$00
        .byte   $0F,$00,$0F,$58,$0F,$58,$0F,$59,$0F,$00,$0F,$00,$0F,$00,$0F,$5A
        .byte   $0F,$00,$0F,$00,$0F,$5B,$0F,$5C,$0F,$17,$0F,$5D,$0F,$5E,$0F,$5F
        .byte   $0F,$53,$0F,$60,$0F,$61,$1F,$02,$0F,$62,$0F,$00,$0F,$00,$0F,$00
; Row 5
        .byte   $0F,$00,$0F,$00,$0F,$00,$0F,$63,$0F,$51,$0F,$64,$0F,$65,$0F,$66
        .byte   $0F,$6E,$0F,$67,$0F,$68,$1F,$4F,$0F,$00,$0F,$00,$0F,$00,$0F,$00
        .byte   $0F,$00,$0F,$69,$0F,$6A,$1F,$6A,$0F,$6B,$0F,$00,$0F,$00,$0F,$00
        .byte   $0F,$00,$0F,$00,$0F,$6C,$0F,$00,$0F,$6D,$10,$3E,$0F,$6E,$0F,$6F
        .byte   $0F,$66,$0F,$70,$0F,$71,$1F,$02,$0F,$72,$0F,$00,$0F,$00,$0F,$00
; Row 6
        .byte   $0F,$00,$0F,$00,$0F,$00,$0F,$73,$0F,$51,$0F,$74,$0F,$75,$0F,$76
        .byte   $1F,$3F,$0F,$77,$0F,$78,$0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$79
        .byte   $0F,$7A,$1F,$60,$0F,$7B,$0F,$7C,$0F,$7D,$0F,$00,$0F,$00,$0F,$00
        .byte   $0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$7E,$0F,$7F,$0F,$1D
        .byte   $1F,$00,$1F,$01,$0F,$74,$1F,$02,$1F,$03,$0F,$00,$0F,$00,$0F,$00
; Row 7
        .byte   $0F,$00,$0F,$00,$0F,$00,$1F,$04,$0F,$51,$1F,$05,$1F,$06,$1F,$47
        .byte   $1F,$07,$1F,$08,$0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$46
        .byte   $1F,$09,$1F,$0A,$0F,$16,$1F,$0B,$1F,$0C,$1F,$0D,$0F,$00,$0F,$09
        .byte   $0F,$00,$0F,$00,$0F,$00,$1F,$0E,$1F,$0F,$0F,$00,$10,$25,$1F,$10
        .byte   $1F,$11,$0F,$66,$1F,$12,$1F,$13,$1F,$14,$0F,$00,$0F,$00,$0F,$00
; Row 8
        .byte   $0F,$00,$0F,$00,$0F,$00,$0F,$73,$1F,$15,$1F,$16,$0F,$3D,$1F,$17
        .byte   $1F,$18,$1F,$5B,$0F,$00,$0F,$00,$0F,$00,$0F,$00,$1F,$19,$1F,$1A
        .byte   $1F,$1B,$0F,$4E,$1F,$1C,$1F,$1D,$00,$0D,$1F,$1E,$0F,$00,$1F,$1F
        .byte   $0F,$00,$0F,$5A,$1F,$21,$1F,$22,$0F,$00,$0F,$00,$1F,$58,$1F,$23
        .byte   $1F,$24,$1F,$25,$1F,$50,$1F,$26,$1F,$27,$0F,$00,$0F,$00,$0F,$00
; Row 9
        .byte   $0F,$00,$0F,$00,$0F,$00,$1F,$39,$1F,$28,$1F,$29,$10,$09,$1F,$2A
        .byte   $1F,$2B,$1F,$2C,$1F,$2D,$1F,$2D,$1F,$2E,$10,$19,$1F,$2F,$1F,$30
        .byte   $1F,$77,$1F,$31,$1F,$32,$0F,$4C,$1F,$33,$1F,$34,$1F,$35,$0F,$12
        .byte   $1F,$36,$1F,$37,$1F,$37,$1F,$38,$1F,$39,$1F,$36,$1F,$3A,$1F,$3B
        .byte   $1F,$3C,$1F,$09,$1F,$3D,$1F,$3E,$10,$48,$0F,$00,$0F,$00,$0F,$00
; Row 10
        .byte   $0F,$00,$0F,$00,$0F,$00,$1F,$3F,$1F,$40,$1F,$04,$1F,$41,$1F,$42
        .byte   $1F,$43,$1F,$76,$1F,$44,$1F,$45,$1F,$7B,$1F,$46,$1F,$47,$10,$15
        .byte   $1F,$48,$1F,$49,$10,$6D,$1F,$4A,$1F,$4B,$1F,$4C,$0F,$2E,$1F,$4D
        .byte   $1F,$4E,$1F,$30,$1F,$4F,$1F,$50,$0F,$5B,$1F,$51,$1F,$52,$1F,$53
        .byte   $0F,$0D,$1F,$54,$1F,$55,$1F,$26,$1F,$56,$0F,$00,$0F,$00,$0F,$00
; Row 11
        .byte   $0F,$00,$0F,$00,$0F,$00,$1F,$57,$1F,$6E,$1F,$58,$1F,$59,$1F,$5A
        .byte   $0F,$69,$1F,$5B,$1F,$5C,$1F,$73,$1F,$5D,$1F,$5E,$0F,$00,$0F,$44
        .byte   $1F,$5F,$1F,$60,$10,$00,$1F,$61,$1F,$62,$1F,$63,$1F,$63,$1F,$64
        .byte   $1F,$65,$1F,$4F,$1F,$66,$1F,$67,$1F,$58,$1F,$68,$1F,$69,$1F,$6A
        .byte   $0F,$4E,$1F,$6B,$1F,$73,$1F,$6C,$10,$76,$0F,$00,$0F,$00,$0F,$00
; Row 12
        .byte   $0F,$00,$0F,$00,$0F,$00,$1F,$6D,$1F,$6E,$0F,$14,$1F,$6F,$1F,$70
        .byte   $1F,$71,$0F,$72,$1F,$72,$1F,$73,$0F,$00,$1F,$74,$1F,$75,$0F,$00
        .byte   $1F,$76,$1F,$77,$1F,$7A,$1F,$78,$1F,$79,$1F,$7A,$0F,$78,$1F,$7B
        .byte   $1F,$7C,$0F,$00,$0F,$00,$1F,$7D,$1F,$7E,$1F,$73,$1F,$7F,$10,$00
        .byte   $10,$01,$10,$00,$10,$02,$10,$03,$1F,$56,$0F,$00,$0F,$00,$0F,$00
; Row 13
        .byte   $0F,$00,$0F,$00,$0F,$00,$10,$04,$10,$05,$10,$17,$10,$06,$10,$07
        .byte   $10,$08,$1F,$0C,$10,$09,$10,$0A,$1F,$2D,$10,$0B,$10,$0C,$0F,$00
        .byte   $10,$0D,$0F,$00,$10,$0E,$0F,$7A,$10,$0F,$10,$10,$10,$11,$0F,$00
        .byte   $0F,$00,$0F,$00,$0F,$0F,$10,$12,$10,$13,$0F,$47,$10,$14,$10,$15
        .byte   $10,$16,$10,$16,$10,$17,$10,$18,$1F,$1E,$0F,$00,$0F,$00,$0F,$00
; Row 14
        .byte   $0F,$00,$0F,$00,$0F,$00,$10,$19,$10,$1A,$10,$4A,$10,$1B,$10,$1C
        .byte   $10,$1C,$10,$1D,$10,$1E,$10,$1F,$0F,$00,$10,$21,$10,$22,$0F,$5A
        .byte   $10,$23,$10,$24,$0F,$00,$10,$25,$10,$26,$1F,$2D,$10,$27,$10,$28
        .byte   $0F,$00,$10,$29,$10,$3B,$10,$2A,$10,$2B,$10,$3B,$10,$2C,$10,$2D
        .byte   $10,$2D,$10,$2E,$10,$2F,$10,$30,$00,$48,$0F,$00,$0F,$00,$0F,$00
; Row 15
        .byte   $0F,$00,$0F,$00,$0F,$00,$10,$31,$10,$32,$10,$4A,$10,$33,$10,$34
        .byte   $10,$34,$10,$35,$10,$36,$10,$37,$0F,$45,$10,$38,$10,$39,$1F,$27
        .byte   $10,$3A,$10,$3B,$1F,$36,$10,$3C,$10,$3D,$10,$3E,$10,$3E,$10,$3F
        .byte   $10,$40,$0F,$0C,$10,$41,$10,$42,$1F,$7E,$10,$43,$10,$44,$10,$5C
        .byte   $10,$45,$10,$46,$10,$47,$10,$30,$10,$48,$0F,$00,$0F,$00,$0F,$00
; Row 16
        .byte   $0F,$00,$0F,$00,$0F,$00,$10,$49,$10,$1A,$10,$4A,$10,$4B,$10,$34
        .byte   $10,$4C,$10,$4D,$10,$4E,$10,$4D,$10,$4F,$10,$50,$1F,$1F,$10,$51
        .byte   $10,$52,$00,$7F,$10,$53,$10,$54,$0F,$12,$10,$55,$10,$56,$10,$57
        .byte   $0F,$07,$10,$58,$10,$59,$1F,$0E,$1F,$58,$10,$5A,$10,$5B,$10,$5C
        .byte   $10,$5C,$10,$5D,$10,$5E,$10,$30,$10,$5F,$0F,$00,$0F,$00,$0F,$00
; Row 17
        .byte   $0F,$00,$0F,$00,$0F,$00,$10,$60,$10,$32,$10,$61,$10,$62,$10,$63
        .byte   $10,$63,$10,$64,$10,$6D,$1F,$73,$10,$65,$10,$66,$10,$67,$1F,$62
        .byte   $10,$68,$10,$69,$1F,$3A,$10,$6A,$10,$6B,$10,$3E,$10,$6C,$10,$6D
        .byte   $10,$6E,$0F,$78,$10,$6F,$10,$70,$1F,$58,$10,$71,$10,$72,$10,$73
        .byte   $10,$73,$10,$74,$10,$75,$00,$23,$10,$76,$0F,$00,$0F,$00,$0F,$00
; Row 18
        .byte   $0F,$00,$0F,$00,$0F,$00,$10,$77,$1F,$6E,$10,$78,$10,$79,$00,$0F
        .byte   $10,$7A,$10,$7B,$10,$7B,$1F,$73,$10,$7C,$10,$7D,$10,$7E,$10,$3C
        .byte   $10,$7F,$00,$00,$00,$7F,$00,$01,$00,$02,$00,$03,$00,$03,$00,$04
        .byte   $00,$05,$0F,$00,$1F,$7D,$0F,$00,$1F,$58,$00,$06,$00,$07,$00,$1F
        .byte   $00,$08,$00,$09,$00,$22,$00,$0A,$00,$0B,$0F,$00,$0F,$00,$0F,$00
; Row 19
        .byte   $0F,$00,$0F,$00,$0F,$00,$00,$0C,$0F,$24,$00,$0D,$00,$0E,$00,$0F
        .byte   $00,$0F,$00,$10,$00,$1E,$00,$11,$00,$12,$0F,$5A,$00,$13,$00,$14
        .byte   $00,$15,$00,$12,$00,$16,$00,$17,$00,$1D,$00,$18,$00,$19,$00,$32
        .byte   $00,$1A,$00,$1B,$00,$1C,$00,$1B,$00,$1D,$00,$1E,$00,$07,$00,$1F
        .byte   $00,$21,$00,$09,$00,$22,$00,$23,$00,$24,$0F,$00,$0F,$00,$0F,$00
; Row 20
        .byte   $0F,$00,$0F,$00,$0F,$00,$10,$2C,$00,$25,$00,$26,$00,$28,$00,$27
        .byte   $00,$28,$10,$6D,$00,$29,$00,$29,$00,$2A,$00,$2E,$00,$2B,$00,$2C
        .byte   $00,$2D,$00,$2D,$00,$2E,$00,$2F,$00,$2B,$00,$30,$00,$31,$00,$32
        .byte   $00,$32,$00,$33,$00,$34,$00,$30,$00,$29,$00,$29,$00,$35,$00,$36
        .byte   $00,$28,$00,$37,$00,$38,$1F,$13,$00,$39,$0F,$00,$0F,$00,$0F,$00
; Row 21
        .byte   $0F,$00,$0F,$00,$0F,$00,$00,$3A,$00,$3B,$1F,$57,$00,$3C,$00,$3D
        .byte   $00,$4C,$00,$3E,$00,$3F,$10,$21,$00,$40,$00,$41,$0F,$03,$00,$42
        .byte   $00,$43,$00,$44,$00,$4D,$00,$45,$00,$46,$00,$4D,$0F,$6D,$00,$47
        .byte   $00,$48,$1F,$62,$00,$49,$00,$4A,$00,$4B,$1F,$5C,$00,$4C,$00,$4D
        .byte   $0F,$7D,$00,$4E,$00,$4F,$10,$16,$00,$50,$0F,$00,$0F,$00,$0F,$00
; Row 22
        .byte   $0F,$00,$0F,$00,$0F,$00,$00,$51,$00,$52,$00,$4B,$00,$53,$00,$54
        .byte   $10,$69,$00,$55,$00,$56,$00,$74,$00,$57,$00,$58,$0F,$4E,$00,$59
        .byte   $00,$5A,$00,$5B,$0F,$69,$00,$5C,$00,$5D,$10,$52,$00,$5E,$00,$5F
        .byte   $10,$6F,$00,$60,$00,$61,$00,$62,$00,$5F,$00,$63,$00,$64,$0F,$6D
        .byte   $00,$65,$00,$66,$1F,$11,$00,$67,$00,$68,$0F,$00,$0F,$00,$0F,$00
; Row 23
        .byte   $0F,$00,$0F,$00,$0F,$00,$00,$69,$1F,$31,$00,$6A,$00,$6B,$00,$6A
        .byte   $00,$6C,$00,$6D,$00,$75,$00,$6E,$00,$6F,$00,$6C,$00,$70,$00,$71
        .byte   $00,$72,$0F,$5B,$00,$73,$00,$74,$00,$75,$00,$75,$00,$76,$00,$72
        .byte   $00,$77,$00,$78,$00,$79,$1F,$22,$00,$7A,$00,$7B,$1F,$4D,$00,$7C
        .byte   $00,$7D,$00,$6A,$00,$7E,$00,$7F,$0F,$23,$0F,$00,$0F,$00,$0F,$00
; Row 24
        .byte   $0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$00
        .byte   $0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$00
        .byte   $0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$00
        .byte   $0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$00
        .byte   $0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$00,$0F,$00

; -- Engine sprite char data ---------------------------------
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
        .byte   $00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; $7F -- blank

; -- BAGC2 sprite chars (overflow bank: slots 128+, attr $E8) --
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
; Do NOT include level.h before .org -- data would land in register file ($0000-$00FF)!

#include "level.h"            ; tile data and level map (must be after .org $1000)
#include "mixt_api.asm"

        .end