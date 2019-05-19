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

.include "io.i"

; jump table vectors must be changed via patch
;
; 6c09: IO_request_disk_id
;     param:
;        A: requested disk id in range 0x01 to 0x08
;     return:
;        C set: disk not inserted
;        C clear: disk inserted
;
; 6c2a: IO_request_disk_char
;     param:
;        A: requested disk id in range 0x41 to 0x48
;     return:
;        C set: disk not inserted
;        C clear: disk inserted
;
; 6c24: IO_load_file
;    param:
;        filename: after return address, null terminated
;        x: 0=return; x=1 jmp 0x0800; x>1 jmp 0xa700
;    return:
;        none
;
; 6c2d: IO_save_file
;    saves a file. parameter list, deletes the file and saves it then
;    param:
;        X: unknown
;        string: (after return address) null terminated filename, prepended with "S:"
;        word: (after return address) address
;        word: (after return address) size
;    return:
;        none
;
; 6c00: IO_read_block
;     param:
;         Y: track of disk
;         X: sector of disk
;         A: destination high address
;     return:
;         none
;
; 6c30: IO_read_block_alt
;     reads a block and the following block to a fixed address (0x7e, 0x7f)
;     param:
;         A: unknown
;         X: unknown
;     return:
;         none
;

; export the entry points of the functions
.export _IO_request_disk_id_entry
.export _IO_request_disk_char_entry
.export _IO_load_file_entry
.export _IO_save_file_entry
.export _IO_read_block_entry
.export _IO_read_block_alt_entry

.export get_crunched_byte
.export decrunch_table

; imports
.import EXO_decrunch


.segment "IO_CODE"

    ; --------------------------------------------------------------------
    _IO_request_disk_id_entry:
        clc
        adc #$40   ; add 40 to get the character

    ; --------------------------------------------------------------------
    _IO_request_disk_char_entry:
        sta requested_disk
        clc        ; disk request always succeeds
        rts

    ; --------------------------------------------------------------------
    ; IO_load_file_entry: load file
    ; filename after return address
    ; x: return mode (0, 1, >1)
    _IO_load_file_entry:
        stx requested_loadmode

        ; set fileparameter
        lda #$08
        ldx drive_id
        ldy #$01 
        jsr kernal_SETLFS

        ; copy name
        pla
        sta copy_name_address_low
        pla
        sta copy_name_address_high
        jsr copy_filename ; returns length in A

        ; set filename
        ldx #<requested_fullname
        ldy #>requested_fullname
        jsr kernal_SETNAM  ; A = File name length; X/Y = Pointer to file name.

        ; load
        jsr $0126  ; sound off
        lda #$00 
    :   jsr kernal_LOAD
        bcs :-     ; repeat on error

        ; ### decrunch if necessary X/Y last loaded byte
        jsr decrunch_prepare
     
        lda #$08
        jsr kernal_CLOSE
        jsr $0129  ; sound on

        ; decide how to start (if) te loaded prg
        lda requested_loadmode
        beq load_return                ; 0: return
        cmp #$01
        beq load_jumptomain            ; 1: jump to $800
        jmp $a700                      ; >1: jump to $a700
    load_jumptomain:
        jmp $8000
    load_return:
        lda copy_name_address_high    ; return address on stack
        pha
        lda copy_name_address_low
        pha
        rts
    requested_loadmode:
        .byte $00


    ; --------------------------------------------------------------------
    ; IO_save_file_entry
    ; read parameter from after return address
    ; string: (after return address) null terminated filename, prepended with "S:"
    ; word: (after return address) address
    ; word: (after return address) size
    _IO_save_file_entry:
        jsr $0126  ; sound off

        pla                            ; load return address to copy opcode
        sta copy_name_address_low
        pla
        sta copy_name_address_high

        ; skip over "S:"
        jsr getnext_name_character
        jsr getnext_name_character

        ; copy filename
        jsr copy_filename
        sta $ff    ; length of filename now in fc
        clc
        adc #$02
        ldx #<requested_deletename
        ldy #>requested_deletename
        jsr kernal_SETNAM

        ; delete
        lda #$0f  
        ldx drive_id
        ldy #$0f  
        jsr kernal_SETLFS
        jsr kernal_OPEN
        lda #$0f  
        jsr kernal_CLOSE
        
        ; copy address and size
        jsr getnext_name_character
        sta save_source_low
        jsr getnext_name_character
        sta save_source_high
        jsr getnext_name_character
        sta save_files_size_low
        jsr getnext_name_character
        sta save_files_size_high

        ; prepare saving
        lda #$08  
        ldx drive_id
        ldy #$00  
        jsr kernal_SETLFS

        ; set name
        lda $ff
        ldx #<requested_fullname
        ldy #>requested_fullname
        jsr kernal_SETNAM

        ; save parameter
        ; copy address and size
        jsr getnext_name_character  ; address low
        sta $fe
        jsr getnext_name_character  ; address high
        sta $ff
        jsr getnext_name_character  ; size low
        sta $fc
        jsr getnext_name_character  ; size high
        sta $fd
    :   clc
        lda $fe
        adc $fc
        tax
        lda $ff
        adc $fd
        tay
        lda #$fe
        jsr kernal_SAVE  ; A = Address of zero page w start address; X/Y = End address of memory + 1
        bcs :-
        
        ; close
        jsr $0129  ; music on
        lda #$08  
        jsr kernal_CLOSE

        ; leave
        lda copy_name_address_high    ; return address on stack
        pha
        lda copy_name_address_low
        pha
        rts


    ; --------------------------------------------------------------------
    ; meaning of function unclear, copied from temp.subs
    ; parameter a, x
    ; some calculations to get the track and number from a
    _IO_read_block_alt_entry:
        sta alt_sector
        sta alt_track
        txa
        lsr a
        ror alt_track
        lsr alt_track
        lsr alt_track
        lda alt_sector
        and #$07
        asl a
        sta alt_sector
        lda #$7e
        ldy alt_track
        ldx alt_sector
        jsr _IO_read_block_entry
        lda #$7f
        ldy alt_track
        ldx alt_sector
        inx
        jmp _IO_read_block_entry
    alt_track:
        .byte $00
    alt_sector:
        .byte $00


    ; --------------------------------------------------------------------
    ; IO_read_block_entry
    ; y:track x:sector a:high destination address
    ; modify track and sector and call original_load_block
    _IO_read_block_entry:
        sta $fc
        lda requested_disk
        sec
        sbc #$41
        asl
        clc
        adc #<load_block_jumptable
        sta $fe
        lda #$00
        adc #>load_block_jumptable
        sta $ff
        jmp ($fe)
    load_block_jumptable:
        .addr disk_dungeon
        .addr disk_britannia
        .addr disk_underworld
        .addr disk_towne
        .addr disk_dwelling
        .addr disk_castle
        .addr disk_keep

    disk_dungeon:  ; sectors 0-15
        clc
        tya
        adc #dungeon_track_correction
        tay
        clc
        lda $fc
        jmp original_load_block
        ; no rts

    disk_britannia:  ; sectors 0-15
        clc
        tya
        adc #britannia_track_correction
        tay
        clc
        lda $fc
        jmp original_load_block
        ; no rts

    disk_underworld:  ; sectors 16-31
        clc
        tya
        adc #underworld_track_correction
        tay
        clc
        txa
        adc #$10   ; sector correction
        tax
        lda $fc
        jmp original_load_block
        ; no rts

    disk_towne:  ; sectors 0-15
        clc
        tya
        adc #towne_track_correction
        tay
        clc
        lda $fc
        jmp original_load_block
        ; no rts

    disk_dwelling:  ; sectors 16-31
        clc
        tya
        adc #dwelling_track_correction
        tay
        clc
        txa
        adc #$10   ; sector correction
        tax
        lda $fc
        jmp original_load_block
        ; no rts

    disk_castle:  ; sectors 0-15
        clc
        tya
        adc #castle_track_correction
        tay
        clc
        lda $fc
        jmp original_load_block
        ; no rts

    disk_keep:  ; sectors 16-31
        clc
        tya
        adc #keep_track_correction
        tay
        clc
        txa
        adc #$10   ; sector correction
        tax
        lda $fc
        jmp original_load_block
        ; no rts


    ; ====================================================================
    ; loading file utility, search in several efs dirs
    ; uses fe, ff in zeropage

    ; --------------------------------------------------------------------
    ; returns next character in A
    getnext_name_character:
    copy_name_address_low = copy_name_address + 1
    copy_name_address_high = copy_name_address + 2
        inc copy_name_address_low   ; first increase address
        bne copy_name_address
        inc copy_name_address_high
    copy_name_address:
        lda $ffff                            ; then load
        rts


    ; --------------------------------------------------------------------
    ; copies filename to temporary storage
    ; return length in A
    copy_filename:
        ldy #$ff
    :   iny
        jsr getnext_name_character     ; next char in A
        sta requested_filename, y      ; and store
        bne :-
        iny       ; additional increase for leading drive letter
        tya
        rts


    ; --------------------------------------------------------------------
    ; checks if decrunch necessary and decrunches
    ; X/Y address of last byte loaded + 1
    decrunch_prepare:
        ; increase address by one byte
;        inx
;        bne :+
;        iny
        stx copy_address_low
        sty copy_address_high
        
        ; check if decrunch necessary
        ldx #<name_list
        ldy #>name_list
        jsr compare_filename
        ldx #<name_slist
        ldy #>name_slist
        jsr compare_filename
        ldx #<name_btlist
        ldy #>name_btlist
        jsr compare_filename
        ldx #<name_utlist
        ldy #>name_utlist
        jsr compare_filename
        ldx #<name_roster
        ldy #>name_roster
        jsr compare_filename
        ldx #<name_prtydata
        ldy #>name_prtydata
        jsr compare_filename

        ; decrunch
        jsr EXO_decrunch
        rts


    ; --------------------------------------------------------------------
    ; gets next byte to decrunch, moves backwars
    ; must not change X, Y, C
    get_crunched_byte:
        lda copy_address_low    ; decrease
        bne :+
        dec copy_address_high
    :   dec copy_address_low
    copy_address_low = * + 1
    copy_address_high = * + 2
        lda $ffff               ; load
        rts


    ; --------------------------------------------------------------------
    ; compare filename 
    ; name address in x,y
    compare_filename:
        stx $fe
        sty $ff

        ; compare filename
        ldy #$ff
        sty $fc  ; 0xff means decrunch necessary
    nameloop:
        iny
        lda #$2a   ; '*'
        cmp requested_fullname, y  ; character in name is '*', we have a match
        beq namematch
        lda requested_fullname, y  ; compare character with character in entry
        cmp ($fe), y               ; if not equal nextname
        bne nomatch
        lda #$0                    ; compare if both character are zero
        cmp ($fe), y               ; if not, next name
        beq namematch
        jmp nameloop
    namematch: ; if match we return double, as no decrnch
        tsx
        dex
        dex
        txs
    nomatch:
        rts


    ; --------------------------------------------------------------------
    ; variables
    requested_deletename:
        .byte $53, $3a  ; "S:"
    requested_fullname:
    requested_disk:
        .byte $41
    requested_filename:
        .res 15, $00

    save_files_size_low:
        .byte $ff
    save_files_size_high:
        .byte $ff
    save_source_low:
        .byte $ff
    save_source_high:
        .byte $ff

    name_list:
        .byte $42, $4c, $49, $53, $54, $00  ; 'BLIST'
    name_slist:
        .byte $42, $53, $4c, $49, $53, $54, $00  ; 'BSLIST'
    name_utlist:
        .byte $48, $54, $4c, $49, $53, $54, $00  ; 'HTLIST'
    name_btlist:
        .byte $42, $54, $4c, $49, $53, $54, $00  ; 'BTLIST'
    name_roster:
        .byte $42, $50, $52, $4f, $53, $54, $45, $52, $00  ; 'BROSTER'
    name_prtydata:
        .byte $42, $50, $52, $54, $59, $2e, $44, $41, $54, $41, $00  ; 'BPRTY.DATA'
