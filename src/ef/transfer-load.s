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

; transfer-load.s
; reprogrammed check disk and load block from temp.subs
; starts at $8d26

drive_number = $6c33
ultima4_character_data := $bd00

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

        lda disk_load_mode
        beq execute_disk_load_block
        clc
        rts

    execute_disk_load_block:
        jsr $0126  ; music off
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

    done_load_block:
        jsr $0129  ; music on
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

    disk_load_mode:
        .byte $00


    ; --------------------------------------------------------------------
    ; disk_check_type
    ; A: value
    _disk_check_type:
        sta disk_check_type_requested + 1
        lda #$00
        sta disk_load_mode
        lda $c8
        and #$01
        beq one_drive
        lda drive_number
        eor #$01
        sta drive_number
        jsr disk_check_type_loadid
        beq disk_inserted
        lda drive_number
        eor #$01
        sta drive_number
    one_drive:
        jsr disk_check_type_loadid
        beq disk_inserted
        jsr _disk_check_remastered
        bcc disk_inserted
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


    ; --------------------------------------------------------------------
    ; check for ultima remastered save file (s80)
    ; returns: C = 0 if exists, C = 1 if not (A = error code).
    _disk_check_remastered:
        ; load file
        jsr $0126  ; music off
        lda #remastered_filename_end - remastered_filename
        ldx #<remastered_filename
        ldy #>remastered_filename
        jsr $ffbd  ; SETNAM. Set file name parameters. A = File name length; X/Y = Pointer to file name.
        lda #$01
        ldy #$00
        ldx drive_number
        jsr $ffba  ; SETLFS. Set file parameters. A = Logical number; X = Device number; Y = Secondary address.

        lda #$0
        ldx #<ultima4_character_data
        ldy #>ultima4_character_data
        jsr $ffd5  ; LOAD
        bcc @found ; no error, file loaded

        lda #$00
        sta disk_load_mode  ; 0 means load blocks
        jsr $0129  ; music on
        sec        ; not found
        rts

    @found:
        lda #$01
        sta disk_load_mode  ; 1 means file loaded, do not load blocks

        ; simulate a found disk
        lda #$55          ; U
        sta $7f90
        lda #$34          ; 4
        sta $7f91
        lda #$43          ; C
        sta $7f98
        lda #$30          ; 
        sta $7fa2

        jsr $0129  ; music on
        clc        ; found
        rts

    remastered_filename:
        .byte "s80"
    remastered_filename_end:


