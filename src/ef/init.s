; ----------------------------------------------------------------------------
; Copyright 2023 Drunella
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

.import __BOOTSTRAP_LOAD__
.import __BOOTSTRAP_RUN__
.import __BOOTSTRAP_SIZE__

.import __LOADER_LOAD__
.import __LOADER_RUN__
.import __LOADER_SIZE__

EASYFLASH_BANK    = $DE00
EASYFLASH_CONTROL = $DE02
EASYFLASH_LED     = $80
EASYFLASH_16K     = $07
EASYFLASH_KILL    = $04

LOADER_SOURCE = $bc00
LOADER_DEST = $c000
LOADER_START = $c000


.segment "ULTIMAX_VECTORS"

    vector_nmi:
        .addr dummy

    vector_reset:
        .addr ultimax_reset

    vector_irq:
        .addr dummy


.segment "ULTIMAX_STARTUP"

    ultimax_reset:
        ; the reset vector points here
        sei
        ldx #$ff
        txs
        cld

        ; enable VIC (e.g. RAM refresh)
        stx $d016

        ; write to RAM to make sure it starts up correctly (=> RAM datasheets)
    wait:
        sta $0100, x
        dex
        bne wait

        lda $d011  ; disable output
        and #$ef
        sta $d011

        ; copy the final start-up code to RAM (bottom of CPU stack)
        ldx #<__BOOTSTRAP_SIZE__ - 1
    copy:
        lda __BOOTSTRAP_LOAD__,x
        sta __BOOTSTRAP_RUN__,x    
        dex
        bpl copy
        jmp bootstrap

    dummy:
        rti


.segment "BOOTSTRAP"

    bootstrap:
        ; bank in 16k mode
        lda #EASYFLASH_LED | EASYFLASH_16K
        sta EASYFLASH_CONTROL

        ; screen black 
        lda #$00        ; border and screen black, no error messages
        sta $d020
        sta $d021
        sta $9d

        ; Check if one of the magic kill keys is pressed
        ; This should be done in the same way on any EasyFlash cartridge!
        ; Prepare the CIA to scan the keyboard
        lda #$7f
        sta $dc00   ; pull down row 7 (DPA)

        ldx #$ff
        stx $dc02   ; DDRA $ff = output (X is still $ff from copy loop)
        inx
        stx $dc03   ; DDRB $00 = input

        ; Read the keys pressed on this row
        lda $dc01   ; read coloumns (DPB)

        ; Restore CIA registers to the state after (hard) reset
        stx $dc02   ; DDRA input again
        stx $dc00   ; Now row pulled down

        ; Check if one of the magic kill keys was pressed
        and #$e0    ; only leave "Run/Stop", "Q" and "C="
        cmp #$e0
        bne kill    ; branch if one of these keys is pressed
 
        ; clear screen
;        lda #$20
;        ldx #$00
;    :   sta $0400, x
;        sta $0500, x
;        sta $0600, x
;        sta $0700, x
;        dex
;        bne :-

        ; c64 reset
        jsr $fda3  ; initialize i/o
        jsr $fd50  ; initialize memory
        jsr $fd15  ; set io vectors
        jsr $ff5b  ; more init ; necessary?
        cli

        ; screen black again
        lda #$00        ; border and screen black, no error messages
        sta $d020
        sta $d021
        sta $9d         ; no error messages

        ; copy application code, resides on 00:1:bc00 and start
        ldy #$03
    pagecopy:
        ldx #$00
    bytecopy:
        lda LOADER_SOURCE, x
        sta LOADER_DEST, x
        dex
        bne bytecopy
        inc bytecopy + 2  ; high byte of lda
        inc bytecopy + 5  ; high byte of sta
        dey
        bne pagecopy

        ; start
        jmp LOADER_START


    kill:
        lda #EASYFLASH_KILL
        sta EASYFLASH_CONTROL
        cli
        jmp ($fffc) ; reset
