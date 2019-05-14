; ====================================================================
; io library wide variables
; library variables must be initialized in loader.s

; definitions
decrunch_table = $7f00
.export decrunch_table

.export requested_disk
.export read_block_filename
.export save_files_directory_entry
.export save_files_flags
.export read_block_filename
.export save_files_directory_entry
.export requested_fullname
.export alt_track
.export alt_sector
.export block_bank
.export count_directories
.export save_files_offset_high
.export save_files_offset_low
.export save_files_bank
.export save_directory_bank
.export erase_disallow
.export requested_filename
.export save_files_size_high
.export save_files_size_low
.export bank_strategy
.export load_strategy
.export requested_loadmode
.export requested_disk


.segment "IO_DATA"

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
    load_strategy:    ; 00: decrunch; 01: load prg
        .byte $00

    save_directory_bank:
        .byte $00
    count_directories:
        .byte $00
    erase_disallow:
        .byte $00

    requested_loadmode:
        .byte $00

    block_bank:
        .byte $00

    alt_track:  ; 6eac
        .byte $00
    alt_sector: ; 6ead
        .byte $00
