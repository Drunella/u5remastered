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

; list of relevant files that cannot be decrunched
; PRTY.DATA (britannia)
; LIST (britannia)
; SLIST (britannia)
; TLIST (britannia)
; ROSTER (britannia)
; STORY1.TXT (dwelling)
; STORY2.TXT (dwelling)
; STORY3.TXT (dwelling)
; STORY4.TXT (dwelling)
; BLANK.PRTY (britannia, osi)
; CREATE1.TXT (osi)
; M9 (osi)


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
        bcc :+     ; no error, continue
        cmp #$04   ; file not found
        beq load_return
        bcs :-     ; repeat on other error

        ; store last loaded address X/Y
    :   stx copy_address_low
        sty copy_address_high

        ; close
        lda #$08
        jsr kernal_CLOSE

        ; decompress or simply load
        lda #$80   ; bit 7 set
        bit requested_loadmode
        bmi skip_decrunch  ; bit 7 is set: no decrunch
        lda $ff00  ; for c128 to decrunch we need ram only
        pha
        ora #$30   ; set c000-feff to ram
        sta $ff00
        ldx #decrunch_buffer_size ; buffer size
    :   jsr get_crunched_byte
        dex
        bne :-
        jsr EXO_decrunch  ; decrunch
        pla        ; restore c128 mmu
        sta $ff00
    skip_decrunch:
        jsr $0129  ; sound on

        ; decide how to start the loaded prg
        lda requested_loadmode
        and #$7f
        beq load_success               ; 0: return
        cmp #$01
        beq load_jumptomain            ; 1: jump to $800
        jmp $a700                      ; >1: jump to $a700
    load_jumptomain:
        jmp $8000
    load_success:
        clc
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
        sta $ff    ; length of filename now in ff
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
        lda #$08  
        jsr kernal_CLOSE
        jsr $0129  ; music on

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
        sta $ff    ; save address
        stx $fe
        lda requested_disk
        sec
        sbc #$41
        tax
        
        ; load track corrections
        tya
        clc
        adc track_corrections, x
        tay

        ; load sector corrections
        lda sector_corrections, x
        clc
        adc $fe
        tax
        lda $ff    ; load address

        ; execute
        jmp original_load_block
        ; no rts

    track_corrections:
        .byte $00
        .byte britannia_track_correction
        .byte towne_track_correction
        .byte dwelling_track_correction
        .byte castle_track_correction
        .byte keep_track_correction
        .byte dungeon_track_correction
        .byte underworld_track_correction

    sector_corrections:
        .byte $00
        .byte britannia_sector_correction
        .byte towne_sector_correction
        .byte dwelling_sector_correction
        .byte castle_sector_correction
        .byte keep_sector_correction
        .byte dungeon_sector_correction
        .byte underworld_sector_correction



    ; ====================================================================
    ; loading file utility

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
    ; gets next byte to decrunch, moves backwards
    ; and processes data through a 8 byte ring buffer
    ; to comply with safety offset up to 8
    ; must not change X, Y, C, O
    ; maximum safety buffer is 6
    get_crunched_byte:
        txa
        pha
        ; load byte from buffer to temp
        ldx decrunch_pointer
        lda decrunch_buffer, x
        sta decrunch_temp
        ; decrease pointer to source
        lda copy_address_low
        bne :+
        dec copy_address_high
    :   dec copy_address_low
        ; copy byte from source to buffer
    copy_address_low = * + 1
    copy_address_high = * + 2
        lda $ffff               ; load
        sta decrunch_buffer, x
        ; inc buffer
        inc decrunch_pointer
        lda #(decrunch_buffer_size - 1)  ; buffer size of 8 bytes
        and decrunch_pointer
        sta decrunch_pointer
        ; restore X
        pla
        tax
        lda decrunch_temp
        rts

;    get_crunched_byte:
;        lda copy_address_low    ; decrease
;        bne :+
;        dec copy_address_high
;    :   dec copy_address_low
;        lda decrunch_buffer+5
;        pha                     ; put old byte on
;        lda decrunch_buffer+4
;        sta decrunch_buffer+5
;        lda decrunch_buffer+3
;        sta decrunch_buffer+4
;        lda decrunch_buffer+2
;        sta decrunch_buffer+3
;        lda decrunch_buffer+1
;        sta decrunch_buffer+2
;        lda decrunch_buffer+0
;        sta decrunch_buffer+1
;    copy_address_low = * + 1
;    copy_address_high = * + 2
;        lda $ffff               ; load
;        sta decrunch_buffer
;        pla                     ; release first byte
;        rts


    ; --------------------------------------------------------------------
    ; compare filename 
    ; name address in x,y
;    compare_filename:
;        stx $fe
;        sty $ff
;
;        ; compare filename
;        ldy #$ff
;        sty $fc  ; 0xff means decrunch necessary
;    nameloop:
;        iny
;        lda #$2a   ; '*'
;        cmp requested_fullname, y  ; character in name is '*', we have a match
;        beq namematch
;        lda requested_fullname, y  ; compare character with character in entry
;        cmp ($fe), y               ; if not equal nextname
;        bne nomatch
;        lda #$0                    ; compare if both character are zero
;        cmp ($fe), y               ; if not, next name
;        beq namematch
;        jmp nameloop
;    namematch: ; if match we return double, as no decrnch
;        tsx
;        dex
;        dex
;        txs
;    nomatch:
;        rts



.segment "IO_DATA"

    ; --------------------------------------------------------------------
    ; variables
    decrunch_buffer_size = $08
    decrunch_temp:
        .byte $00
    decrunch_pointer:
        .byte $00
    decrunch_buffer:
        .res decrunch_buffer_size, $00

    requested_deletename:
        .byte $53, $3a  ; "S:"
    requested_fullname:
    requested_disk:
        .byte $41
    requested_filename:
        .res 15, $00

    decrunch_table:
        .res 156, $00
    
;    save_files_size_low:
;        .byte $ff
;    save_files_size_high:
;        .byte $ff
;    save_source_low:
;        .byte $ff
;    save_source_high:
;        .byte $ff

;    name_list:
;        .byte $42, $4c, $49, $53, $54, $00  ; 'BLIST'
;    name_slist:
;        .byte $42, $53, $4c, $49, $53, $54, $00  ; 'BSLIST'
;    name_utlist:
;        .byte $48, $54, $4c, $49, $53, $54, $00  ; 'HTLIST'
;    name_btlist:
;        .byte $42, $54, $4c, $49, $53, $54, $00  ; 'BTLIST'
;    name_roster:
;        .byte $42, $50, $52, $4f, $53, $54, $45, $52, $00  ; 'BROSTER'
;    name_prtydata:
;        .byte $42, $50, $52, $54, $59, $2e, $44, $41, $54, $41, $00  ; 'BPRTY.DATA'
