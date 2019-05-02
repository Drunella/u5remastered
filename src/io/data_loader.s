; =============================================================================
; can be wherever it wants to be

.include "../include/easyflash.inc"

.export get_crunched_byte
.export load_prg
.export load_block
.export save_prg

.export load_destination_high
.export load_destination_low

.export save_source_low
.export save_source_high

;.import temporary_accumulator

temporary_accumulator = $fb


.segment "IO_CODE2"

    ; --------------------------------------------------------------------
    ; must preserve stat, X, Y
    ; return value in A
    get_crunched_byte:
        php

        ; process, bank in and memory
        lda #$07
        sta $01
        lda #EASYFLASH_LED | EASYFLASH_16K
        sta EASYFLASH_CONTROL
        ; read byte
        jsr EAPIReadFlashInc
        sta temporary_accumulator
        ; bank out and memory
        lda #EASYFLASH_KILL
        sta EASYFLASH_CONTROL
        lda #$06
        sta $01

        lda temporary_accumulator
        plp        
        rts


    ; --------------------------------------------------------------------
    ; high address byte is set in load_destination_high
    ; low address byte is set in load_destination_low (usually 0)
    ; eapi ptr set
    ; eapi bank set
    ; eapi size not set
    load_block:
        ; set length to 256
        lda #$00
        tax
        ldy #$01
        jsr EAPISetLen

        jmp data_loader


    ; --------------------------------------------------------------------
    ; address is loaded as 1. and 2. byte
    ; eapi ptr set
    ; eapi bank set
    ; eapi size set
    load_prg:
        ; bank in
        lda #$07
        sta $01
        lda #EASYFLASH_LED | EASYFLASH_16K
        sta EASYFLASH_CONTROL

        ; read address
        jsr EAPIReadFlashInc
        sta load_destination_low
        jsr EAPIReadFlashInc
        sta load_destination_high

        ;jmp data_loader


    ; --------------------------------------------------------------------
    ; loads data to destination
    data_loader:
        ; bank in and memory
        lda #$07
        sta $01
        lda #EASYFLASH_LED | EASYFLASH_16K
        sta EASYFLASH_CONTROL

        ; read byte
        jsr EAPIReadFlashInc
        sta temporary_accumulator

        ; bank out and memory
        lda #$06
        sta $01
        lda #EASYFLASH_KILL
        sta EASYFLASH_CONTROL

        ; if C set last byte read
        bcs data_loader_finish   

        ; write byte to destination
        lda temporary_accumulator
    load_destination_low = load_destination + 1
    load_destination_high = load_destination + 2
    load_destination:
        sta $ffff
        inc load_destination_low
        bne :+
        inc load_destination_high
    :   bne data_loader

    data_loader_finish:
        clc        ; indicate success
        rts


    ; --------------------------------------------------------------------
    ; reads data and writes to flash
    save_prg:
        ; bank out and memory
        lda #$06
        sta $01
        lda #EASYFLASH_KILL
        sta EASYFLASH_CONTROL

        ; read byte
    save_source_low = save_source + 1
    save_source_high = save_source + 2
    save_source:
        lda $ffff ; will be modified by code
        sta temporary_accumulator

        ; bank in and memory
        lda #$07
        sta $01
        lda #EASYFLASH_LED | EASYFLASH_16K
        sta EASYFLASH_CONTROL

        ; inc address
        inc save_source_low
        bne :+
        inc save_source_high
    
        ; and write to flash
    :   lda temporary_accumulator
        jmp EAPIWriteFlashInc
        ; no rts
