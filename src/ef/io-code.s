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

        ; load return address to copy opcode
        pla
        sta copy_name_address_low
        pla
        sta copy_name_address_high
        jsr copy_filename

        ; process
        ;goto filefound

        ; not found, can happen, may crash afterwards
        ;jsr finish_search
        jsr $0129  ; sound on
        sec
        jmp load_return

    filefound:
        ;jsr prepare_filentry    ; returns bank in A
        ;jsr EAPISetBank      ; now we cannot access the directory anymore

        ;lda load_strategy    ; if zero, we decrunch prg
        ;bne otherloader
        ;lda $a7              ; save zp variables (except $fc-$ff)
        ;pha
        ;jsr EXO_decrunch
        ;pla
        ;sta $a7
        jsr $0129  ; sound on
        jmp startorreturn
    ;otherloader:
    ;    jsr load_prg

    startorreturn:
        ; decide how to start (if) te loaded prg
        lda requested_loadmode
        clc        ; success
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
        ;jsr getnext_name_character
        ;jsr getnext_name_character

        ; copy filename
        ;jsr copy_filename

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
        ;jsr start_search
        ;jmp load_block
        rts ; ### temp
        ; C is cleared in load_block


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
    copy_filename:
        ldy #$ff
    :   iny
        jsr getnext_name_character     ; next char in A
        sta requested_filename, y      ; and store
        bne :-
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
    ; A: bank, Y: address high
    ; directory must be increased  before first usage
    ; set bank
    start_directory_search:
        dey
        sty $ff
        ldy #$e8   ; 0x00 - 0x18
        sty $fe
        ; no rts here


    ; --------------------------------------------------------------------
    ; A: bank
    ; set bank
    ; must not use X
    start_search:
        jsr EAPISetBank

        ; bank in and set ($fe) to one element before
        lda #$07
        sta $01
        lda #EASYFLASH_LED | EASYFLASH_16K
        sta EASYFLASH_CONTROL ; jsr SetMemConfiguration
        rts


    ; --------------------------------------------------------------------
    ; banks out directory or block search
    ; must not use X
    finish_search:
        lda #EASYFLASH_KILL
        sta EASYFLASH_CONTROL ; jsr SetMemConfiguration
        lda #$06
        sta $01
        rts


    ; --------------------------------------------------------------------
    ; increases $fe, $ff to next entry
    ; uses A, status
    ; must not use X
    next_directory_entry:
        clc
        lda #$18   ; size of dir element
        adc $fe
        sta $fe
        bcc :+
        inc $ff
    :   rts


    ; --------------------------------------------------------------------
    ; returns C set if current entry is empty (terminator)
    ; returns C clear if there are more entries
    ; uses A, Y, status
    ; sets fc,fd to next empty file space
    ; must not use X
    terminator_directory_entry:
        ; test if directory overflow, unneccessary
        ;lda $ff
        ;and #$1f
        ;cmp #$18
        ;bcs lastentry     ; if A >= $18
        
        ; test if directory terminator
        ldy #efs_directory::flags
        lda ($fe), y
;        beq moreentries     ; entry deleted, Z is set
        and #$1f
;        and ($fe), y
        cmp #$1f
        beq emptyentry
        clc
        rts
    emptyentry:
        sec
        rts


    ; --------------------------------------------------------------------
    ; name set in fixed location: requested_fullname
    ; set pointer fe,ff to matched directory entry
    ; C set on not found or other error
    ; C clear on found
    ; modified register: A, Y, status
    ; must prepare with start_directory_search
    find_directoryentry:
    nextname:
        ; increase for next pointer
        jsr next_directory_entry

        ; test if more entries
        jsr terminator_directory_entry
;        beq nextname   ; if deleted (Z set) go directly to next name
        bcc morefiles  ; if not terminator entry (C clear) inspect entry
        sec
        rts

    morefiles:
        ; check if deleted
        ldy #efs_directory::flags
        lda ($fe), y
        beq nextname    ; if deleted go directly to next name

        ; compare filename
        ldy #$ff
    nameloop:
        iny
;        lda #$3f   ; '?'
;        cmp requested_fullname, y  ; character in name is '?', go to next character
;        beq nameloop
        lda #$2a   ; '*'
        cmp requested_fullname, y  ; character in name is '*', we have a match
        beq namematch
        lda requested_fullname, y  ; compare character with character in entry
        cmp ($fe), y               ; if not equal nextname
        bne nextname
        lda #$0                    ; compare if both character are zero
        cmp ($fe), y               ; if not, next name
        beq namematch
        jmp nameloop
        
    namematch:
        clc
        rts


    ; --------------------------------------------------------------------
    ; sets eapi length and pointer to be ready to load file
    ; also sets save_files_offset and saves_file_bank to next entry
    ; bank is not changed
    ; fe,ff must be set to the directory entry
    ; bank_strategy must be set
    ; returns bank in A
    prepare_filentry:
        ; load offset, set pointer and store in buffer (load and save)
        ldy #efs_directory::offset_low
        lda ($fe), y
        sta save_files_offset_low  ; store offset in buffer
        tax
        iny        ; ldy #efs_directory::offset_high
        lda ($fe),y
        sta save_files_offset_high ; store offset in buffer
        clc
        adc #$80
        tay
        lda bank_strategy
        jsr EAPISetPtr ; x: low; y: high; a: bank strategy (load)

        ; load size, set and add to offset in buffer (load and save)
        ldy #efs_directory::size_low
        lda ($fe), y
        tax
        clc
        adc save_files_offset_low ; add to offset buffer
        sta save_files_offset_low
        iny        ; ldy #efs_directory::size_high
        lda ($fe), y
        tay
        adc save_files_offset_high ; add to offset buffer
        sta save_files_offset_high

        ; modify new offset to increase bank (only in A, save only)
        rol        ; prepare what to add to bank
        rol
        rol
        rol
        and #$0f   ; 3 bits + carry relevant for bank (4 bits)
        sta save_files_bank

        lda #$00   ; no file is larger than 0xffff
        jsr EAPISetLen ; size in A Y X (high to low)

        ; offset (only for save)
        lda save_files_offset_high
        and #$1f
        sta save_files_offset_high

        ; add to bank
        ldy #efs_directory::bank
        lda ($fe),y
        clc
        adc save_files_bank
        sta save_files_bank
        lda ($fe),y  ; load bank again (for load)
        rts


    ; --------------------------------------------------------------------
    ; save_directory
    ; saves a new directory entry at fe,ff
    ; can only be used in low ram
    ; correct bank must be set
    ; parameters
    ;    fe,ff: address of directory entry
    ;    save_files_directory_entry: completely filled
    save_directory:
        ; set bank

        ; set address in rom bank
        ldx $fe
        ldy $ff
        lda #$B0
        jsr EAPISetPtr ; X:low, Y:high, A:bank mode

        ; set size for directory entry
        inc save_files_size_low
        inc save_files_size_low

        ; write name, we will write some garbage after the 0 terminator
        ldy #$00
    :   lda save_files_directory_entry, y
        jsr EAPIWriteFlashInc
        iny
        cpy #$18
        bcc :-

        ; already done
        rts


    ; --------------------------------------------------------------------
    ; save_file
    ; saves file to flash
    ; can only be used in low ram
    ; parameters
    ;    save_files_directory_entry: directory entry must be filled
    ;    save_source_address
    save_file:
        ; set bank
;        lda save_files_bank
;        jsr EAPISetBank

        ; set pointer
;        ldx save_files_offset_low
;        lda save_files_offset_high
;        clc
;        adc #$80
;        tay
;        lda #$B0
;        jsr EAPISetPtr ; X:low, Y:high, A:bank mode
        
        ; write address
;        lda save_source_low
;        jsr EAPIWriteFlashInc
;        lda save_source_high
;        jsr EAPIWriteFlashInc

        ; write data
;        ldx save_files_size_low
;        ldy save_files_size_high
;        dex
;        dex        ; we know that no file size crosses a page boundary
;    save_file_repeat:
;        jsr save_prg_byte
;        dex
;        bne save_file_repeat
;        dey
;        beq finish
;        bmi finish
;        jmp save_file_repeat   ; branch if positive (max 0x79 !)
;finish:
        rts

    save_source_low = save_source + 1
    save_source_high = save_source + 2
    save_source:
        .byte $00, $00

    load_destination_low = load_destination + 1
    load_destination_high = load_destination + 2
    load_destination:
        .byte $00, $00
