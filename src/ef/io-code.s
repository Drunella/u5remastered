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

.include "easyflash.i"
.include "io.i"
;.include "../exo/exodecrunch.i"
;.include "data_loader.exported.inc"

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

; imports
.import name_address_low
.import name_address_high
.import name_length

; imports
;.import EXO_decrunch
;.import load_prg
;.import load_block
.import save_prg_byte
;.import erase_prg
;.import load_destination_low
;.import load_destination_high
;.import save_source_low
;.import save_source_high
.import save_files_directory_entry
.import requested_fullname
.import alt_track
.import alt_sector
.import block_bank
.import count_directories
.import save_files_offset_high
.import save_files_offset_low
.import save_files_bank
.import save_directory_bank
.import erase_disallow
.import requested_filename
.import save_files_size_high
.import save_files_size_low
.import bank_strategy
.import load_strategy
.import requested_loadmode
.import requested_disk


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
        jsr $0126  ; sound off
        sei        ; no interrupts

        ; EFS_setlfs: load to loadable address
        ldy #$01
        jsr EFS_setlfs

        ; load return address to get file, copy and count
        pla
        sta copy_name_address_low
        pla
        sta copy_name_address_high
        jsr copy_filename
        ldx #<requested_fullname
        ldy #>requested_fullname
        jsr EFS_setnam

        ; process
        lda #$00
        jsr EFS_load
        bcc filefound

        ; not found, can happen, will very likely crash afterwards        
        cli
        jsr $0129  ; sound on
        sec
        jmp load_return

    filefound:
        cli
        jsr $0129  ; sound on

        lda requested_loadmode
        clc                            ; success
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

        ; copy address and size
        ;jsr getnext_name_character
        ;sta save_source_low
        ;jsr getnext_name_character
        ;sta save_source_high
        ;jsr getnext_name_character
        ;sta save_files_size_low
        ;jsr getnext_name_character
        ;sta save_files_size_high

        lda copy_name_address_high    ; return address on stack
        pha
        lda copy_name_address_low
        pha
        jsr $0129  ; sound on
        clc        ; success
        rts


    ; --------------------------------------------------------------------
    ; IO_read_block_entry
    ; y:track x:sector a:high destination address
    _IO_read_block_entry:
         ; save destination address
        sta load_destination_high
        lda #$00
        sta load_destination_low
        sta $fe

        txa
        pha        ; sector on stack
        tya
        pha        ; track on stack
        jsr $0126  ; sound off

        ; bank in block map
        lda #BLOCKMAP_BANK
        ;jsr start_search

        ; fe,ff now shows to the page area with the line data per disk
        lda requested_disk
        sec
        sbc #$41
        clc
        adc #>BLOCKMAP_ADDRESS
        sta $ff
        pla        ; track from stack
        ldy #$ff
        sec
        sbc ($fe), y ; corrected track now in A
        asl
        tay ; correct offset now in Y

        lda ($fe), y ; first element bank
        sta block_bank

        pla        ; sector from stack
        clc
        iny
        adc ($fe), y ; second element address
        tay          ; high offset in Y
        ldx #$00     ; low offset always zero
        lda #$D0     ; bank mode does not matter
        jsr EAPISetPtr

        lda block_bank
        jmp load_block
        ; C is cleared in load_block
        ; rts is called in load_block


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


    ; ====================================================================
    ; loading file utility, search in several efs dirs
    ; uses fe, ff in zeropage

    ; --------------------------------------------------------------------
    ; copies filename to temporary storage
    ; returns length in A
    copy_filename:
        ldy #$ff
    :   iny
        jsr getnext_name_character     ; next char in A
        sta requested_filename, y      ; and store
        bne :-
        iny
        tya
        rts


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
    ; loads block data to destination
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

        ; bank in and memory
        lda #$07
        sta $01
        lda #EASYFLASH_LED | EASYFLASH_16K
        sta EASYFLASH_CONTROL ; jsr SetMemConfiguration

        ; read byte
    load_block_loop:
        jsr EAPIReadFlashInc
        tay

        ; bank out and memory
        lda #$06
        sta $01
        lda #EASYFLASH_KILL
        sta EASYFLASH_CONTROL ; jsr SetMemConfiguration

        ; if C set last byte read
        bcs load_block_finish

        ; write byte to destination
        tya
    load_destination_low = load_destination + 1
    load_destination_high = load_destination + 2
    load_destination:
        sta $ffff
        inc load_destination_low
        bne :+
        inc load_destination_high
    :   bne load_block_loop

    load_block_finish:
        jsr $0129  ; sound on
        clc        ; indicate success
        rts

