; ============================================================
; pop_intro_music.asm — Prince of Persia intro, EXL100 buzzer
;
; Standalone timer-interrupt music player
; Buzzer = bit 3 of P6 (xorp %$08,P6)
; Timer: F = 307200 / ((PT+1)*(DT+1)), sound = F/2
;
; Partition (forward-reading, 4 bytes per note):
;   .byte P2, P3, dur_hi, dur_lo
;   P2=$00, P3=$00 = end/loop
;   P2=$FF, P3=$00 = silence (timer still runs for duration)
; ============================================================

#include "c:/jeux/emulateur/exl/tasm/H/7020.equ"
#include "c:/jeux/emulateur/exl/tasm/H/3556.equ"

; SRAM variables ($C300-$C30F)
mus_ptr_lo      .equ    $C300   ; partition pointer (16-bit)
mus_ptr_hi      .equ    $C301
mus_dur_lo      .equ    $C302   ; remaining ticks (16-bit)
mus_dur_hi      .equ    $C303
mus_active      .equ    $C304   ; 0=silence, $08=sound

SCR             .equ    $7340

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
        eint

        ; (no display text - audio only test)

        ; Init music: pointer = start of tune
        movd    %pop_tune,TEMP4
        mov     TEMP4-1,A      ; HIGH byte
        sta     @mus_ptr_hi
        mov     TEMP4,A        ; LOW byte
        sta     @mus_ptr_lo
        clr     A
        sta     @mus_dur_lo
        sta     @mus_dur_hi
        sta     @mus_active

        ; Install timer ISR: BRTIME=hi byte, BRTIME+1=lo byte
        movd    %timer_isr,TEMP4
        mov     TEMP4-1,A      ; HIGH byte
        sta     @BRTIME
        mov     TEMP4,A        ; LOW byte
        sta     @BRTIME+1

        ; Start with slowest timer rate to trigger load_next
        movp    %$FF,P2
        movp    %$97,P3         ; ~50Hz
        eint

main_loop:
        br      @main_loop

; ── Timer ISR ─────────────────────────────────────────────────────────────
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
        jz      @isr_load_next  ; both zero → load next note
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
        jz      @isr_tune_end   ; $00 = end → loop
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

; ── Screen data ──────────────────────────────────────────────────────────
screen_data2:
        .byte   $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte   $00,$00,$00,$00,$00

; ── Partition: PoP intro (80 BPM, quarter=750ms) ─────────────────────────
; P2/P3 values computed: F = 307200/((P3&$1F+1)*(P2+1))/2 = note freq
; Durations in timer ticks at each note's own timer rate
;
; Accuracy: all notes within 3 cents of equal temperament

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
        .byte   $00             ; end → loop to pop_tune

#include "mixt_api.asm"

        .end