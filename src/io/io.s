; =============================================================================
; 00:1:1600 (LOROM, bank 0)

.include "../include/easyflash.inc"
.include "../include/io.inc"
.include "efs.inc"
.include "../include/exodecrunch.inc"


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
.export IO_request_disk_id_entry
.export IO_request_disk_char_entry
.export IO_load_file_entry
.export IO_save_file_entry
.export IO_read_block_entry
.export IO_read_block_alt_entry

; imports
.import load_prg
.import load_block
.import load_destination_low
.import load_destination_high


;.macro event_before
;    jsr $0126  ; copied from original copy
;.endmacro

;.macro event_after
;    jsr $0129  ; copied from original copy
;.endmacro


.segment "IO_CODE"


    ; --------------------------------------------------------------------
    IO_request_disk_id_entry:
        clc
        adc #$40   ; add 40 to get the character

    ; --------------------------------------------------------------------
    IO_request_disk_char_entry:
        sta requested_disk
        clc        ; disk request always succeeds
        rts

    ; --------------------------------------------------------------------
    ; IO_load_file_entry: load file
    ; filename after return address
    ; x: return mode (0, 1, >1)
    IO_load_file_entry:
        stx requested_loadmode
        pla                            ; load return address to copy opcode
        sta copy_name_address_low
        pla
        sta copy_name_address_high

        ldy #$ff
    load_file_copyname:
        iny
        jsr getnext_name_character     ; next char in A
        sta requested_filename, y      ; and store
        bne load_file_copyname

        ldx #$00
;        stx load_strategy              ; 0 will load a crunch or prg file
        stx load_offset_high           ; load offset is 0
        jsr load_file_from_ef          ; load file

        lda requested_loadmode
        beq load_return                ; 0: return
        cmp #$01
        beq load_jumptomain            ; 1: jump to $800
        jmp $a700                      ; >1: jumup to $a700
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
    IO_save_file_entry:
        pla                            ; load return address to copy opcode
        sta copy_name_address_low
        pla
        sta copy_name_address_high

        ; skip over "S:"
        jsr getnext_name_character
        jsr getnext_name_character

        ; copy filename
        ldy #$ff
    save_file_copyname:
        iny
        jsr getnext_name_character     ; next char in A
        sta requested_filename, y      ; and store
        bne save_file_copyname

        ; copy address and size
        jsr getnext_name_character
        sta save_address
        jsr getnext_name_character
        sta save_address+1
        jsr getnext_name_character
        sta save_size
        jsr getnext_name_character
        sta save_size+1

        ; identify where to save
        lda #$48   ; underworld
        cmp requested_disk
        beq save_utlist
        lda #$54   ; 'T' of britannia TLIST
        cmp requested_filename
        beq save_btlist

        ; prepare settings
        jsr start_saves_directory_search
        jmp check_erase
    save_btlist:
        jsr start_btlist_directory_search
        jmp check_erase
    save_utlist:
        jsr start_utlist_directory_search

    check_erase:
;        lda $ff    ; ### its not !! in ff is currently the high offset of directory start
;        sta erase_start_offset
        jsr count_directoryentries   ; number of directories in A
        cmp erase_max_directories
        bcc savenow
        ; erase sector
        lda save_directory_bank
        ldy erase_start_offset
        jsr EAPIEraseSector   ; erase

    savenow:
        ; ### save directory
        ; ### save file

        jsr finish_directory_search

        lda copy_name_address_high    ; return address on stack
        pha
        lda copy_name_address_low
        pha
        rts


    ; --------------------------------------------------------------------
    ; IO_read_block_entry
    ; y:track x:sector a:high destination address
    IO_read_block_entry:
         ; save destination address
        sta load_destination_high
        lda #$00
        sta load_destination_low
;        sta load_offset_low

        ; correct track offset
        ; britannia (0x42), underworld (0x48): 19/0 - 35/15
        ; towne (0x43), dwelling (0x44), castle (0x45), keep (0x56): 24/0 - 35/15
        ; dungeon (0x47): 25/0 - 35/15
        tya        ; track in A, Y is free now
        clc
        sbc #$13   ; reduce by 0x19

        ; if 0x42 we are done
        ldy #$42
        cpy requested_disk
        beq track_corrected

        ; if 0x42 we are done
        ldy #$48
        cpy requested_disk
        beq track_corrected

        clc
        sbc #$05   ; reduce by 5

        ; if 0x47, reduce by one
        ldy #$47
        cpy requested_disk
        bne track_corrected
        clc
        sbc #$01
    track_corrected:

        ; calculate offset, track is in A
        asl      ; multiply track with 16 and add sector
        asl
        asl
        asl
        sta load_offset_high  ; store in temp
        txa      ; sector was in X
        clc
        adc load_offset_high
        tax      ; offset in X

        ; set filename
        ldy #$06
    @repeat:
        lda read_block_filename, y
        sta requested_filename, y
        dey
        bne @repeat

        ; load strategy, destination address
        lda #$ff
        sta load_strategy      ; block file as load strategy
        jmp load_file_from_ef


    ; --------------------------------------------------------------------
    ; meaning of function unclear, copied from temp.subs
    ; parameter a, x
    ; some calculations to get the track and number from a
    IO_read_block_alt_entry:
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
        jsr IO_read_block_entry
        lda #$7f
        ldy alt_track
        ldx alt_sector
        inx
        jmp IO_read_block_entry


    ; ====================================================================
    ; load file

    ; --------------------------------------------------------------------
    ; finds the directory entry in all directories
    ; and sets the pointer fc,fd to the file entry
    ; and sets eapi len, addr and strategy but not bank
    ; must be set:
    ;   requested_disk + requested_filename
    ;   load_offset_high
    ;   load_strategy
    load_file_from_ef:
        lda #$00
        sta load_strategy ; load crunch file
        lda #EFS_FILES_BANKSTRATEGY
        sta bank_strategy
        lda #EFS_FILES_DIR_BANK
        ldy #>EFS_FILES_DIR_START
        jsr start_directory_search
        jsr find_directoryentry
        bcc filefound

        lda #$01 ; load prg file
        sta load_strategy

        ; search in saves
        jsr start_saves_directory_search
        jsr find_directoryentry
        bcc filefound

        ; search in britannia ulist
        jsr start_btlist_directory_search
        jsr find_directoryentry
        bcc filefound

        ; search in underworld ulist
        jsr start_utlist_directory_search
        jsr find_directoryentry
        bcc filefound

        ; not found
        jsr finish_directory_search
        sec 
        rts

    filefound:
        ldy load_offset_high
        jsr prepare_filentry    ; returns bank in A
        jsr EAPISetBank      ; now we cannot access the directory anymore

        lda load_strategy    ; if zero, we decrunch prg
        bne otherloader
        lda $a7              ; save zp variables (except $fc-$ff)
        pha
        lda $ae
        pha
        lda $af
        pha
        jsr EXO_decrunch
        pla
        sta $af
        pla
        sta $ae
        pla
        sta $a7
        clc        ; indicate success
        rts
    otherloader:
        bmi prgloader
        jmp load_block
    prgloader:
        jmp load_prg


    ; ====================================================================
    ; loading file utility, search in several ef
    ; uses fc, fd, fe, ff in zeropage

    ; --------------------------------------------------------------------
    ; set saves addresses and bank strategy and starts directory search
    start_saves_directory_search:
        lda #EFS_SAVES_MAXDIRECTORYENTRIES
        sta erase_max_directories
        lda #EFS_SAVES_BANKSTRATEGY
        sta bank_strategy
        lda #EFS_SAVES_BANK
        sta save_directory_bank
        ldy #>EFS_SAVES_DIR_START
        jmp start_directory_search


    ; --------------------------------------------------------------------
    ; set btlist addresses and bank strategy and starts directory search
    start_btlist_directory_search:
        lda #EFS_BTLIST_BANK
        sta save_directory_bank
        jmp start_tlist_directory_search


    ; --------------------------------------------------------------------
    ; set utlist addresses and bank strategy and starts directory search
    start_utlist_directory_search:
        lda #EFS_UTLIST_BANK
        sta save_directory_bank
    start_tlist_directory_search:
        lda #EFS_TLIST_MAXDIRECTORYENTRIES
        sta erase_max_directories
        lda #EFS_TLIST_BANKSTRATEGY
        sta bank_strategy
        ldy #>EFS_TLIST_DIR_START
        sty erase_start_offset
        jmp start_directory_search


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
        jsr EAPISetBank

        ; bank in and set ($fe) to one element before
        lda #$07
        sta $01
        lda #EASYFLASH_LED | EASYFLASH_16K
        sta EASYFLASH_CONTROL
        dey
        sty $ff
        lda #$e8   ; 0x00 - 0x18
        sta $fe
        rts


    ; --------------------------------------------------------------------
    ; banks out directory
    finish_directory_search:
        lda #EASYFLASH_KILL
        sta EASYFLASH_CONTROL
        lda #$06
        sta $01
        rts


    ; --------------------------------------------------------------------
    ; increases $fe, $ff to next entry
    ; uses A, status
    next_directory_entry:
        clc
        lda #$18   ; size of dir element
        adc $fe
        sta $fe
        bcc :+
        inc $ff
    :   rts


    ; --------------------------------------------------------------------
    ; returns C set if last entry
    ; returns C clear if there are more entries, if Z is set this entry is deleted
    ; uses A, Y, status
    ; sets fc,fd to next empty file space
    ; must not use X
    terminator_directory_entry:
        ; test if directory overflow
        lda $ff
        and #$1f
        cmp #$18
        bcs lastentry     ; if A >= $18
        
        ; test if directory terminator
        ldy #efs_directory::flags
        lda #$1f
        and ($fe), y
        beq moreentries     ; entry deleted, Z is set
        cmp #$1f
        beq lastentry
        lda #$01   ; clears the Z flag
    moreentries:
        ; set file bank and offset
        ldy #efs_directory::bank
        lda ($fe), y
        sta save_files_bank
        ldy #efs_directory::offset_low
        lda ($fe), y
        iny
        iny        ; efs_directory::size_low
        clc
        adc ($fe), y
        sta $fc
        dey        ; efs_directory::offset_high
        lda ($fe), y
        iny
        iny        ; efs_directory::size_high
        adc ($fe), y
        clc
        adc #$18
        sta $fd
        ; return
        clc
        rts
    lastentry:
        sec
        rts


    ; --------------------------------------------------------------------
    ; counts the number of entries in the directory
    ; leaves fd,ff pointer showing the next free entry :)
    ; must prepare with start_directory_search
    ; returns count in A
    ; uses A, X, Y, status
    count_directoryentries:
        ldx #$ff
        ; increase for next pointer
    :   inx
        jsr next_directory_entry

        ; test if more entries
        jsr terminator_directory_entry
        bcc :-     ; if not terminator entry (C clear) go to next
        txa
        rts


    ; --------------------------------------------------------------------
    ; name set in fixed location: requested_fullname
    ; A: directory bank, X: start address of directory
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
        beq nextname   ; if deleted (Z set) go directly to next name
        bcc morefiles  ; if not terminator entry (C clear) inspect entry
        rts ; c is still set

    morefiles:
        ; compare filename
        ldy #$ff
    nameloop:
        iny
        lda #$3f   ; '?'
        cmp requested_fullname, y  ; character in name is '?', go to next character
        beq nameloop
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
    ; bank is not changed
    ; fe,ff must be set to the directory entry
    ; bank_strategy must be set
    ; x is high offset
    ; returns bank in A
    prepare_filentry:
        ; low file address directly in code
        ldy #efs_directory::offset_low
        lda ($fe),y
        sta prepare_fileentry_offset_low

        ; high file address and offset
        txa                        ; high offset in A, X is free
        ldy #efs_directory::offset_high ; entry high offset
        adc ($fe),y                ; high address in A
        tax                        ; unmodified high address in X

        ; prepare bank
        rol                        ; isolate bank part of high offset
        rol                        ; three rol, and $7 for adding to bank
        rol
        and #$07
        ldy #efs_directory::bank   ; entry bank
        clc
        adc ($fe), y
        pha                        ; bank now on stack

        ; high offset
        txa        ; high offset in A
        and #$3f   ; only offset bits
        clc
        adc #$80   ; add $80 for correct memory range
        tay        ; high offset in Y

     prepare_fileentry_offset_low = prepare_fileentry_low + 1
     prepare_fileentry_low:
        ldx #$ff                    ; low offset in x, changed by source code
        lda bank_strategy          ; bank strategy
        jsr EAPISetPtr

        ; set size
        ldy #efs_directory::size_low
        lda ($fe), y
        tax
        ldy #efs_directory::size_high
        lda ($fe), y
        tay
        lda #$00
        jsr EAPISetLen

        pla                        ; get bank from stack
        rts


    ; ====================================================================
    ; library wide variables
    ; library variables must be initialized in initialize.s

.segment "IO_DATA"

.export requested_disk
.export read_block_filename
.export temporary_accumulator
    requested_fullname:
    requested_disk:
        .byte $41
    requested_filename:
        .byte $00, $00, $00, $00, $00, $00, $00
        .byte $00, $00, $00, $00, $00, $00, $00, $00
    read_block_filename:
        .byte "BLOCK", $00
    bank_strategy:
        .byte $00
    load_strategy:    ; 00: decrunch; ff: load block; 01: load prg
        .byte $00

;    load_offset:
;    load_offset_low:
;        .byte $00
    load_offset_high:
        .byte $00

    save_address:
        .word $0000
    save_size:
        .word $0000
    save_directory_bank:
        .byte $00
    save_files_bank:
        .byte $00
    erase_max_directories:
        .byte $00
    erase_start_offset:
        .byte $00

    requested_loadmode:
        .byte $00
    load_block_offset:
        .byte $00

    alt_track:  ; 6eac
        .byte $00
    alt_sector: ; 6ead
        .byte $00

    temporary_accumulator:
        .byte $00
