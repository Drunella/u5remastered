; =============================================================================
; can be wherever it wants to be

.include "../include/easyflash.inc"

.export get_crunched_byte


.segment "IO_CODE"

    get_crunched_byte:
        ; must preserve stat, X, Y
        ; return value in A
        php
        ;txa
        ;pha
        ;tya
        ;pha

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

        ; restore y, x, stat
        ;pla
        ;tay
        ;pla
        ;tax
        lda temporary_accumulator
        plp        
        rts
    temporary_accumulator:
        .byte $00
