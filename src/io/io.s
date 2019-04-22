; =============================================================================
; 00:1:1600 (LOROM, bank 0)

.include "../include/easyflash.inc"
.include "../include/io.inc"


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

; export the get crunched byte function for exomizer
.export get_crunched_byte


.segment "IO_CODE"

    IO_request_disk_id_entry:
        clc
        adc #$40   ; add 40 to get the character

    IO_request_disk_char_entry:
        sta requested_disk
        clc        ; disk request always succeeds
        rts


    IO_load_file_entry:
        ; read parameter from after return address
        ; filename after return address
        ; x: return mode (0, 1, >1)
        rts


    IO_save_file_entry:
        ; read parameter from after return address
        rts


    IO_read_block_entry:
        ; y:track x:sector a:high destination address
        pha

        ; set filename
        ldx #$06
    @repeat:
        lda read_block_filename, x
        sta requested_filename, x
        dex
        bne @repeat
        
        ; correct track offset
        ; britannia (0x42), underworld (0x48): 19/0 - 35/15
        ; towne (0x43), dwelling (0x44), castle (0x45), keep (0x56): 24/0 - 35/15
        ; dungeon (0x47): 25/0 - 35/15
      ; reduce by 19
      ; if 0x42 or 0x48 
      ;   accept
      ; reduce by 5
      ; if 0x47
      ;   reduce by 1
      ; accept
        asl      ; multiply track with 16 and add sector
        asl
        asl
        asl
        sta $ff  ; store in temp
        txa
        clc
        adc $ff
        tax      ; offset in X

        ; address high byte
        pla

        ; load file
        jmp load_file_from_ef
        rts


    IO_read_block_alt_entry:
        ; meaning of function unclear, copied from temp.subs
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
    alt_track:  ; 6eac
        .byte $00
    alt_sector: ; 6ead
        .byte $00


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


    load_file_from_ef:
        ; name in fixed location: requested_disk + requested_filename
        ; X: 0  for prg, 0-255 for blocks
        ; A: 0  for prg, address from prg file
        ;    >0 A is address high byte
        ; ###

    temporary_accumulator:
        .byte $00
    requested_disk:
        .byte $00
    requested_filename:
        .byte $00, $00, $00, $00, $00, $00, $00
        .byte $00, $00, $00, $00, $00, $00, $00, $00
    read_block_filename:
        .byte "BLOCK", $00


