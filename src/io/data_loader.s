; =============================================================================
; can be wherever it wants to be

.include "../include/easyflash.inc"

.export get_crunched_byte
.export load_prg
.export load_block
.export load_block_highdestination


.segment "IO_CODE"

    get_crunched_byte:
        ; must preserve stat, X, Y
        ; return value in A
        php

        ; process, bank in and memory
        lda #$07
        sta $01
        lda #EASYFLASH_LED | EASYFLASH_16K
        sta EASYFLASH_CONTROL
        ; read byte
        jsr EAPIReadFlashInc
        sta temporary_accumulator
        ; bank out and memory ###
        lda #EASYFLASH_KILL
        sta EASYFLASH_CONTROL
        lda #$06
        sta $01

        lda temporary_accumulator
        plp        
        rts
    temporary_accumulator:
        .byte $00


    load_block:
        ; high address byte is set in load_block_highdestination
        ; eapi ptr set
        ; eapi bank set
        ; return C clear on success
        ldy #$ff
    repeat_block_loader:
        ; bank in and memory
        lda #$07
        sta $01
        lda #EASYFLASH_LED | EASYFLASH_16K
        sta EASYFLASH_CONTROL
        ; read byte
        jsr EAPIReadFlashInc
        tax
        ; bank out and memory
        lda #$06
        sta $01
        lda #EASYFLASH_KILL
        sta EASYFLASH_CONTROL
        txa
    load_block_highdestination = block_loader_copy + 2
:       iny
    block_loader_copy:
        sta $ff00,y
        bne :-
        clc        ; indicate sucess
        rts


    load_prg:
        ; address is loaded as 1. and 2. byte
        ; eapi ptr set
        ; eapi bank set
        ; return C clear on success
        lda #$07
        sta $01
        lda #EASYFLASH_LED | EASYFLASH_16K
        sta EASYFLASH_CONTROL
        ; read address
        jsr EAPIReadFlashInc
        sta load_prg_lowdestination
        jsr EAPIReadFlashInc
        sta load_prg_highdestination

    repeat_prg_loader:
        ; bank in and memory
        lda #$07
        sta $01
        lda #EASYFLASH_LED | EASYFLASH_16K
        sta EASYFLASH_CONTROL
        ; read byte
        jsr EAPIReadFlashInc

        ; ### stop condition ### -> broken

        tax
        ; bank out and memory
        lda #$06
        sta $01
        lda #EASYFLASH_KILL
        sta EASYFLASH_CONTROL
        txa
    load_prg_lowdestination = prg_loader_copy + 1
    load_prg_highdestination = prg_loader_copy + 2
    prg_loader_copy:
        sta $ffff
        inc load_prg_lowdestination
        bcc :+
        inc load_prg_highdestination
:       bne repeat_prg_loader
        clc        ; indicate sucess
        rts
