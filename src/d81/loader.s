; ----------------------------------------------------------------------------
; Copyright 2019 Drunella
;
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
;
;     http://www.apache.org/licenses/LICENSE-2.0
;
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.
; ----------------------------------------------------------------------------

; code mostly produced by:
; da65 V2.17 - Git 0576fe51
; Created:    2019-05-18 00:17:30
; Input file: build/source/xyzzy.prg


.setcpu "6502"

bankin_kernal   = $6C03
bankout_kernal  = $6C06
IO_load_file    = $6C24
init_music      = $720F
drive_selection = $6c33
kernal_SCNKEY   = $FF9F
kernal_SETLFS   = $FFBA
kernal_SETNAM   = $FFBD
kernal_OPEN     = $FFC0
kernal_CLOSE    = $FFC3
kernal_LOAD     = $FFD5
kernal_SAVE     = $FFD8


.segment "LOADER"

    ; ----------------------------------------------------------------------------
    loader_entry:
        ; copied from original
        lda #$04
        sta $0289  ; Maximum length of keyboard buffer. Values: 4: buffer size
        sta $0A20
        lda #$60
        sta $0126
        sta $0129
        lda #$EB
        sta $028A  ; Keyboard repeat switch. Bits: 11101011
        lda #$0E
        sta $FF00  ; c128 mmu 0b00001110, IO, kernal, RAM0. 48K RAM
        lda #$00
        sta $37
        sta $C8
        sta $79
        sta $71
        sec
        ror $78
        lda #$00
        sta $D020  ; Border Color black
        ldx #$20   ; Copy IRQ Handler
    :   lda irq_routine, x
        sta $0380, x
        dex
        bpl :-
        lda #$9E
        sta $0318
        lda #$03
        sta $0319  ; Execution address of non-maskable interrupt service routine to 039e (single rti)
        lda #$4C
        cmp $C024
        bne skip_c128  ; branch if no C128
        lda #$80
        sta $C8
        sta $79
        lda #$95
        sta $0318
        lda #$00
        sta $00
        sta $9D    ; c128: I/O messages: 192 = all, 128 = commands, 64 = errors, 0 = nil
        lda #$FF
        sta $D8    ; c128 Graphics mode code
        lda #$0B
        sta $D011  ; VIC Control Register 1
    skip_c128:
        lda #$06
        sta $01    ; memory mapping 0b00000110, io visible, no basic, kernal
        lda $C8
        bpl load_c64
        jmp load_c128

    load_c64:
        sei
        lda #$83
        sta $0302
        lda #$A4
        sta $0303
        lda #$48
        sta $028F
        lda #$EB
        sta $0290
        lda #$A5
        sta $0330
        lda #$F4
        sta $0331
        cli
        ; drive selection removed
        ldx #<name_UJ
        ldy #>name_UJ
        lda #$02
        jsr kernal_SETNAM
        lda #$0F
        tay
        ldx $ba    ; use last used drive
        jsr kernal_SETLFS
        jsr kernal_OPEN
        ldx #$11   ; wait
    :   lda #$FF
        sec
    :   pha
    :   sbc #$01
        bne :-
        pla
        sbc #$01
        bne :--
        dex
        bne :---
        lda #$0F
        jsr kernal_CLOSE

    load_c128:
        lda $C8
        bpl skip_m
        lda #$01   ; load m.prg
        ldx #<name_M
        ldy #>name_M
        jsr set_fileparams
        lda #$00
        jsr kernal_LOAD
        jsr init_music
        lda #$04   ; load subs.128.prg
        ldx #<name_SUBS128
        ldy #>name_SUBS128
        jsr set_fileparams
        lda #$00
        jsr kernal_LOAD
        lda $D5
        jmp :+

    skip_m:
        lda #$80
        sta $FFFE
        lda #$03
        sta $FFFF
        cli
        lda $C5
    :   pha

        ; load exo
        lda #$03
        ldx #<name_EXO
        ldy #>name_EXO
        jsr set_fileparams
        lda #$00
        jsr kernal_LOAD

        ; load temp.subs
        lda #$05
        ldx #<name_TEMPSUBS
        ldy #>name_TEMPSUBS
        jsr set_fileparams
        lda #$00
        jsr kernal_LOAD
        lda $ba    ; store drive_selection in temp.subs
        sta drive_selection
        pla
        cmp #$22
        bne normal_startup
        ldx #$01
        jsr IO_load_file
        .byte $51,$53,$00  ; QS for quickstart

    normal_startup:
        ldx #$00
        jsr IO_load_file
        .byte $53,$54,$2A,$00  ; ST* for startup
        jmp $8000

    ; ----------------------------------------------------------------------------
    ; A = File name length; X/Y = Pointer to file name.
    set_fileparams:
        jsr kernal_SETNAM
        lda #$08
        ldx $ba    ; read drive from last used drive
        ldy #$01
        jmp kernal_SETLFS

    ; ----------------------------------------------------------------------------
    name_UJ:
        .byte $55,$4A,$00  ; 'UJ'
    name_TEMPSUBS:
        .byte $54,$45,$4D,$50,$2A  ; 'TEMP*'
    name_M: 
        .byte $4D  ; 'M'
    name_SUBS128:
        .byte $53,$55,$42,$2A ; 'SUB*'
    name_EXO:
        .byte $45, $58, $4f  ; 'EXO'

    ; ----------------------------------------------------------------------------
    irq_routine:
        pha
        txa
        pha
        tya
        pha
        lda $FF00
        pha
        jsr bankin_kernal
        jsr kernal_SCNKEY
        lda $DC0D
        jsr bankout_kernal
        pla
        sta $FF00
        pla
        tay
        pla
        tax
        pla
        rti

