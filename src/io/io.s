; =============================================================================
; 00:1:1600 (LOROM, bank 0)

.include "../include/easyflash.inc"
.include "../include/io.inc"
.include "efs.inc"
.include "../include/exodecrunch.inc"
.include "data_loader.exported.inc"

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
;.import load_prg
;.import load_block
;.import save_prg
;.import load_destination_low
;.import load_destination_high
;.import save_source_low
;.import save_source_high

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

        jsr copy_filename
;        ldy #$ff
;    load_file_copyname:
;        iny
;        jsr getnext_name_character     ; next char in A
;        sta requested_filename, y      ; and store
;        bne load_file_copyname

;        ldx #$00
;        stx load_strategy              ; 0 will load a crunch or prg file
;        stx load_offset_high           ; load offset is 0
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
        jsr copy_filename
;        ldy #$ff
;    save_file_copyname:
;        iny
;        jsr getnext_name_character     ; next char in A
;        sta requested_filename, y      ; and store
;        bne save_file_copyname

        ; copy address and size
        jsr getnext_name_character
        sta save_source_low
        jsr getnext_name_character
        sta save_source_high
        jsr getnext_name_character
        sta save_files_size_low
        jsr getnext_name_character
        sta save_files_size_high

        ; identify where to save
        lda #$48   ; underworld
        cmp requested_disk
        beq save_utlist
        lda #$54   ; 'T' of britannia TLIST
        cmp requested_filename
        beq save_btlist
        ; ### if file is LIST, SLIST or ROSTER do not check for erase ###
        ; ### check erase only if PRTY.DATA

        ; prepare settings for save files
        lda #EFS_SAVES_BANK
        sta save_directory_bank
        lda #EFS_SAVES_MAXDIRECTORYENTRIES
        sta erase_max_directories
        jmp save_file_step2
    save_btlist:
        ; prepare settings for btlist
        lda #EFS_BTLIST_BANK
        sta save_directory_bank
        jmp save_file_step15
    save_utlist:
        ; prepare settings for utlist
        lda #EFS_UTLIST_BANK
        sta save_directory_bank
    save_file_step15:
        lda #EFS_TLIST_MAXDIRECTORYENTRIES
        sta erase_max_directories

    save_file_step2:
        ; locate file and delete
        lda #$b0
        sta bank_strategy
        ldy #$80   ; all saves are in low banks
        lda save_directory_bank
        jsr start_directory_search
        jsr find_directoryentry
        bcs save_file_step3   ; file not found
        jsr erase_file

    save_file_step3:
        ; check if bank needs to be erased
        lda save_directory_bank
        sta save_files_bank
        ldy #$80   ; all saves are in low banks
        jsr start_directory_search
        jsr count_directoryentries
        cmp erase_max_directories
        bcc save_file_step4
        ; erase sector and set fe,ff
        lda save_directory_bank
        sta save_files_bank
        ldy #$80   ; all saves are in low banks
        sty $ff
        jsr EAPIEraseSector   ; erase
        lda #$00
        sta save_files_offset_low
        lda #$18
        sta save_files_offset_high
        
    save_file_step4:
        jsr save_directory
        jsr save_file
        jsr finish_search

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
        sta $fe

        ; bank in block map
        lda #EFS_BLOCKMAP_BANK
        jsr start_search

        ; fe,ff now shows to the page area with the line data per disk
        lda requested_disk
        sec
        sbc #$41
        clc
        adc #>EFS_BLOCKMAP_ADDRESS
        sta $ff
        tya
        ldy #$ff
        sec
        sbc ($fe), y ; corrected track now in A
        ;asl
        asl
        tay ; correct offset now in Y

        lda ($fe), y ; first element bank
        sta block_bank

;        iny
;        lda ($fe), y ; second element bank-mode
;        sta bank_strategy

        txa
        clc
        iny
        adc ($fe), y ; third element address
        tay          ; high offset in Y
        ldx #$00     ; low offset always zero
        lda #$D0     ; bank mode does not matter
        jsr EAPISetPtr

        lda block_bank
        jsr start_search
        jmp load_block

;;        sta load_offset_low
;
;        ; correct track offset
;        ; britannia (0x42), underworld (0x48): 19/0 - 35/15
;        ; towne (0x43), dwelling (0x44), castle (0x45), keep (0x56): 24/0 - 35/15
;        ; dungeon (0x47): 25/0 - 35/15
;        tya        ; track in A, Y is free now
;        clc
;        sbc #$13   ; reduce by 0x19
;
;        ; if 0x42 we are done
;        ldy #$42
;        cpy requested_disk
;        beq track_corrected
;
;        ; if 0x42 we are done
;        ldy #$48
;        cpy requested_disk
;        beq track_corrected
;
;        clc
;        sbc #$05   ; reduce by 5
;
;        ; if 0x47, reduce by one
;        ldy #$47
;        cpy requested_disk
;        bne track_corrected
;        clc
;        sbc #$01
;    track_corrected:
;
;        ; calculate offset, track is in A
;        asl      ; multiply track with 16 and add sector
;        asl
;        asl
;        asl
;;        sta load_offset_high  ; store in temp
;        txa      ; sector was in X
;        clc
;;        adc load_offset_high
;        tax      ; offset in X
;
;        ; set filename
;        ldy #$06
;    @repeat:
;        lda read_block_filename, y
;        sta requested_filename, y
;        dey
;        bne @repeat

        ; load strategy, destination address
;        lda #$ff
;        sta load_strategy      ; block file as load strategy
;        jmp load_file_from_ef
;        rts


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

        ; search for save file
        lda #$01 ; load prg file
        sta load_strategy
        lda #$B0 ; bank strategy llll...
        sta bank_strategy

        ; search in saves
        lda #EFS_SAVES_BANK
        ldy #$80   ; all saves are in low bank
        jsr start_directory_search
        jsr find_directoryentry
        bcc filefound

        ; search in britannia tlist
        lda #EFS_BTLIST_BANK
        ldy #$80   ; all saves are in low bank
        jsr start_directory_search
        jsr find_directoryentry
        bcc filefound

        ; search in underworld tlist
        lda #EFS_UTLIST_BANK
        ldy #$80   ; all saves are in low bank
        jsr start_directory_search
        jsr find_directoryentry
        bcc filefound

        ; not found
        jsr finish_search
        sec 
        rts

    filefound:
 ;       ldy load_offset_high
        jsr prepare_filentry    ; returns bank in A
        jsr EAPISetBank      ; now we cannot access the directory anymore

        lda load_strategy    ; if zero, we decrunch prg
        bne otherloader
        lda $a7              ; save zp variables (except $fc-$ff)
        pha
        ;lda $ae
        ;pha
        ;lda $af
        ;pha
        jsr EXO_decrunch
        ;pla
        ;sta $af
        ;pla
        ;sta $ae
        pla
        sta $a7
        clc        ; indicate success
        rts
    otherloader:
;        bmi prgloader
;        jmp load_block
;    prgloader:
        jmp load_prg


    ; ====================================================================
    ; loading file utility, search in several ef
    ; uses fc, fd, fe, ff in zeropage

    ; --------------------------------------------------------------------
    ; set saves addresses and bank strategy and starts directory search
;    start_saves_directory_search:
;        lda #EFS_SAVES_MAXDIRECTORYENTRIES
;        sta erase_max_directories
;;        lda #EFS_SAVES_BANKSTRATEGY
;;        sta bank_strategy
;        lda #EFS_SAVES_BANK
;        sta save_directory_bank
;        ldy #$80
;        jmp start_directory_search


    ; --------------------------------------------------------------------
    ; set btlist addresses and bank strategy and starts directory search
;    start_btlist_directory_search:
;        lda #EFS_BTLIST_BANK
;        sta save_directory_bank
;        jmp start_tlist_directory_search


    ; --------------------------------------------------------------------
    ; set utlist addresses and bank strategy and starts directory search
;    start_utlist_directory_search:
;        lda #EFS_UTLIST_BANK
;        sta save_directory_bank
;    start_tlist_directory_search:
;        lda #EFS_TLIST_MAXDIRECTORYENTRIES
;        sta erase_max_directories
;        lda #EFS_TLIST_BANKSTRATEGY
;        sta bank_strategy
;        ldy #>EFS_TLIST_DIR_START
;        sty erase_start_offset
;        jmp start_directory_search


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
        sta EASYFLASH_CONTROL
        rts


    ; --------------------------------------------------------------------
    ; banks out directory or block search
    ; must not use X
    finish_search:
        lda #EASYFLASH_KILL
        sta EASYFLASH_CONTROL
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
 ;       and ($fe), y
        cmp #$1f
        beq emptyentry
;        lda #$01   ; clears the Z flag
;    moreentries:
;        ; set file bank and offset
;        ldy #efs_directory::bank
;        lda ($fe), y
;        sta save_files_bank
;
;        ldy #efs_directory::offset_low
;        lda ($fe), y
;        ldy #efs_directory::size_low
;        clc
;        adc ($fe), y
;        sta save_files_offset_low
;        
;        ldy #efs_directory::offset_high
;        lda ($fe), y
;        ldy #efs_directory::size_high
;        adc ($fe), y
;        clc
;        ;adc #$18
;        sta save_files_offset_high
        ; return
        clc
        rts
    emptyentry:
        sec
        rts


    ; --------------------------------------------------------------------
    ; counts the number of entries in the directory
    ; leaves fd,ff pointer showing the next free entry :)
    ; must prepare with start_directory_search
    ; returns count in A
    ; uses A, X, Y, status
    count_directoryentries:
        lda #$00
        sta save_files_offset_low
        lda #$18
        sta save_files_offset_high
        lda #$ff
        sta count_directories
        ; increase for next pointer
    again:
        inc count_directories
        jsr next_directory_entry

        ; test if more entries
        jsr terminator_directory_entry
        bcs :+     ; if erminator entry (C set) leave
        jsr prepare_filentry
        jmp again
    :   lda count_directories
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
        ; load offset, set pointer and store in buffer
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
        jsr EAPISetPtr ; x: low; y: high; a: bank strategy

        ; load size, set and add to offset in buffer
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
        rol        ; prepare what to add to bank
        rol
        rol
        rol
        and #$15   ; 3 bits + carry relevant for bank
        sta save_files_bank

        lda #$00   ; no file is larger than 0xffff
        jsr EAPISetLen

        ; offset
        lda save_files_offset_high
        and #$1f
        sta save_files_offset_high

        ldy #efs_directory::bank
        lda ($fe),y
        clc
        adc save_files_bank
        sta save_files_bank
        lda ($fe),y

;        ldy #efs_directory::offset_low
;        lda ($fe),y
;        tax
;        iny        ; ldy #efs_directory::offset_high
;        lda ($fe),y
;        clc
;        adc #$80
;        tay
;        lda bank_strategy
;        jsr EAPISetPtr ; x: low; y: high; a: bank strategy
;
;        ; set size
;        ldy #efs_directory::size_low
;        lda ($fe), y
;        tax
;        iny        ; ldy #efs_directory::size_high
;        lda ($fe), y
;        tay
;        lda #$00   ; no file is larger than 0xffff
;        jsr EAPISetLen

;        ldy #efs_directory::bank
;        lda ($fe),y
;        sta save_files_bank
        rts


    ; --------------------------------------------------------------------
    ; erase_file
    ; erases the file that fe,ff points to
    ; can only be used for files in low ram
    ; parameters
    ;    fe,ff: address of directory entry
    erase_file:
        lda #efs_directory::flags
        clc
        adc $fe
        tax        ; low address in x
        lda #$00
        adc $ff
        tay        ; high address in y
        lda #$00
        jmp EAPIWriteFlash ; erase flag of file
        ; no rts


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
;        lda #$0
;        ldy #$0
;        ldx #$18
;        jsr EAPISetLen 

        ; write name, we will write some garbage after the 0 terminator
        ldy #$00
    :   lda save_files_directory_entry, y
        jsr EAPIWriteFlashInc
        iny
        cpy #$18
        bcc :-

        ; already done
;        dec save_files_size_low
;        dec save_files_size_low
        rts

    ; --------------------------------------------------------------------
    ; yx_decrease
    ; decreases 16 bit value defined by yx (x is low)
    ; if zero, returns N flag set
    ; must not change X, Y, N outside
    ; uses A
;.macro yx_decrease
;        dex
;        bpl :+
;        dey
;    :   
;.endmacro


    ; --------------------------------------------------------------------
    ; save_file
    ; saves file to flash
    ; can only be used in low ram
    ; parameters
    ;    save_files_directory_entry: directory entry must be filled
    ;    save_source_address
    save_file:
        ; set bank
        lda save_files_bank
        jsr EAPISetBank

        ; set pointer
        ldx save_files_offset_low
        lda save_files_offset_high
        clc
        adc #$80
        tay
        lda #$B0
        jsr EAPISetPtr ; X:low, Y:high, A:bank mode
        
        ; write address
        lda save_source_low
        jsr EAPIWriteFlashInc
        lda save_source_high
        jsr EAPIWriteFlashInc

        ; write data
        ldx save_files_size_low
        ldy save_files_size_high
        dex
        dex        ; we know that no file size crosses a page boundary
    save_file_repeat:
        jsr save_prg
        dex
        bne save_file_repeat
        dey
        beq finish
        bmi finish
        jmp save_file_repeat   ; branch if positive (max 0x79 !)
finish:
        rts
;    save_source_address_low = save_source_address + 1
;    save_source_address_low = save_source_address + 2
;    save_source_address:
;        lda $ffff ; will be modified by code


    ; ====================================================================
    ; library wide variables
    ; library variables must be initialized in initialize.s

.segment "IO_DATA"

.export requested_disk
.export read_block_filename
;.export temporary_accumulator
.export save_files_directory_entry
.export save_files_flags

    ; order reflects precisely a directory entry
    save_files_directory_entry:
    requested_fullname:
    requested_disk:
        .byte $41
    requested_filename:
        .byte $00, $00, $00, $00, $00, $00, $00
        .byte $00, $00, $00, $00, $00, $00, $00, $00
    save_files_flags:
        .byte $00
    save_files_bank:
        .byte $00
    save_files_bank_high:
        .byte $00
    save_files_offset_low:
        .byte $00
    save_files_offset_high:
        .byte $00
    save_files_size_low:
        .byte $00
    save_files_size_high:
        .byte $00
    save_files_size_upper:
        .byte $00

    read_block_filename:
        .byte "BLOCK", $00
    bank_strategy:
        .byte $00
    load_strategy:    ; 00: decrunch; ff: load block; 01: load prg
        .byte $00

    save_directory_bank:
        .byte $00
    erase_max_directories:
        .byte $00
    count_directories:
        .byte $00

    requested_loadmode:
        .byte $00
;    load_block_offset:
;        .byte $00

;    block_track:
;        .byte $00
;    block_sector:
;        .byte $00
    block_bank:
        .byte $00

    alt_track:  ; 6eac
        .byte $00
    alt_sector: ; 6ead
        .byte $00
