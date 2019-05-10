; =============================================================================
; transfer-load.s
; reprogrammed check disk and load block from temp.subs
; starts at $8d26

drive_number = $6c33

.export _disk_load_block
.export _disk_check_type


.segment "TRANSFER_LOAD"

    ; --------------------------------------------------------------------
    ; read disk block
    ; Y: track
    ; X: sector
    ; A: address high byte
    _disk_load_block:
        pha
        lda #$31
        sta disk_load_block_filename + 1
        pla
        sta $4b
        txa
        ldx #$0a
        jsr disk_load_block_setdigit
        tya
        ldx #$07
        jsr disk_load_block_setdigit
        lda #$00
        sta $4c
        sta $4a
        jsr $0126
        lda #$01
        ldx #<disk_load_block_hash
        ldy #>disk_load_block_hash
        jsr $ffbd  ; SETNAM. Set file name parameters. A = File name length; X/Y = Pointer to file name.
        lda #$05
        tay
        ldx drive_number
        jsr $ffba  ; SETLFS. Set file parameters. A = Logical number; X = Device number; Y = Secondary address.
        jsr $ffc0  ; OPEN
        lda #$0c
        ldx #<disk_load_block_filename
        ldy #>disk_load_block_filename
        jsr $ffbd  ; SETNAM. Set file name parameters. A = File name length; X/Y = Pointer to file name.
        lda #$0f
        tay
        ldx drive_number
        jsr $ffba  ; SETLFS. Set file parameters. A = Logical number; X = Device number; Y = Secondary address.
        jsr $ffc0  ; OPEN
        ldx #$05
        jsr $ffc6  ; CHKIN. Define file as default input. (Must call OPEN beforehands.)
        
    :   jsr $ffcf  ; CHRIN. Read byte from default input (for keyboard, read a line from the screen)
        ldy $4c
        sta ( $4a ), y
        inc $4c
        bne :-
        clc
        php
        lda #$0f
        jsr $ffc3  ; CLOSE. Close file.
        lda #$05
        jsr $ffc3  ; CLOSE. Close file.
        jsr $ffe7  ; CLALL
        jsr $0129
        plp
        rts

    ; --------------------------------------------------------------------
    ; A: value, X: offset in string        
    disk_load_block_setdigit:
        stx param1 + 1
        tax
        beq param1
        sed
        lda #$00
        clc
    :   adc #$01
        dex
        bne :-
        cld
    param1:
        ldx #$00
        pha
        lsr
        lsr
        lsr
        lsr
        ora #$30
        sta disk_load_block_filename, x
        pla
        and #$0f
        ora #$30
        inx
        sta disk_load_block_filename, x
        rts

    disk_load_block_hash:
        ;     '#'
        .byte $23
    disk_load_block_filename:
        ;     'U' '1' ' ' '5' ' ' '0' ' ' '0' '0' ' ' '0' '0' 
        .byte $55,$31,$20,$35,$20,$30,$20,$30,$30,$20,$30,$30,$00


    ; --------------------------------------------------------------------
    ; disk_check_type
    ; A: value, X: offset in string
    _disk_check_type:
        sta disk_check_type_requested + 1
        lda $c8
        and #$01
        beq one_drive
        lda $6c33
        eor #$01
        sta $6c33
        jsr disk_check_type_loadid
        beq disk_inserted
        lda $6c33
        eor #$01
        sta $6c33
    one_drive:
        jsr disk_check_type_loadid
        beq disk_inserted
        sec
        rts
    disk_inserted:
        clc
        rts

    disk_check_type_loadid:
        lda #$7f
        ldy #$12
        ldx #$00
        jsr _disk_load_block
        lda $7fa2
    disk_check_type_requested:
        cmp #$ff
        rts
       