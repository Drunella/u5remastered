; =============================================================================
; can be wherever it wants to be

.include "../include/easyflash.inc"

.export get_crunched_byte


.code

    get_crunched_byte:
        ; must preserve stat, X, Y
        ; return value in A
        php
        txa
        pha
        tya
        pha

        ; process, bank in
        lda #EASYFLASH_LED | EASYFLASH_16K
        sta EASYFLASH_CONTROL
        ; read byte
        jsr EAPIReadFlashInc
        sta temporary_accumulator
        ; bank out
        lda #EASYFLASH_KILL
        sta EASYFLASH_CONTROL

        ; restore y, x, stat
        pla
        tay
        pla
        tax
        lda temporary_accumulator
        plp        
        rts
    temporary_accumulator:
        .byte $00
