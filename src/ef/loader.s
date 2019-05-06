; =============================================================================
; 00:1:0000 (HIROM, bank 0)

.include "easyflash.i"
.include "io.i"
;.include "../io/io.exported.inc"

.import read_block_filename
.import save_files_flags
.import requested_disk

.import IO_load_file_entry


;TEMP_SUBS_SOURCE = $9300  ; banked in memory
;TEMP_SUBS_DESTINATION = $6c00


.segment "LOADER"

    ; initialize and load everything
    ; mostly copied from xyzzy.prg from ultima 5 osi disk
    
    initialize_start:
        ; Maximum length of keyboard buffer.
        lda #$04
        sta $0289
        sta $0a20  ; ?

        ; fill non-bankable routines with rti
        lda #$60
        sta $0126
        sta $0129

        ; Keyboard repeat switch. Bits: 11101011
        lda #$eb
        sta $028a

        ; c128 mmu check could be omitted
        ; 0b00001110, IO, kernal, RAM0. 48K RAM
        ;lda #$0e
        ;sta $ff00
        ;lda #$00

        ; initialize vars
        lda #$00   ; load accumulator with memory
        sta $37    ; ???
        sta $c8    ; information about c128
        sta $79    ; information about c128
        sta $71    ; ???
        sec
        ror $78    ; ???
        
        ; copy key board routine
        ldx #$20   ; calculate this value ###
    @repeat:
        lda irq_routine, x
        sta $0380, x
        dex
        bpl @repeat
        
        ; Execution address of non-maskable interrupt service routine to 039e (single rti)
        lda #$9e
        sta $0318
        lda #$03
        sta $0319

        ; check if this is a c128 (value $4c at this address) -> it should not
        ;lda #$4c
        ;cmp $c024

        ; memory mapping 0b00000110, io visible, no basic, kernal   
        ;lda #$06
        ;sta $01
        
        ; restore / set vectors
        sei
        lda #$83    ; Execution address of BASIC idle loop. ???
        sta $0302   ; default 0xa483
        lda #$a4         
        sta $0303        
        
        lda #$48    ; Execution address of routine that, based on the status of shift keys     ???
        sta $028f   ; sets the pointer at memory address $00F5-$00F6 to the appropriate
        lda #$eb    ; conversion table for converting keyboard matrix codes to PETSCII codes.
        sta $0290   ; default 0xeb48
        
        lda #$a5    ; Execution address of LOAD, routine loading files.
        sta $0330   ; default 0xf4a5
        lda #$f4    ; no fast loader
        sta $0331
        cli
        
        lda #$01    ; store ultima 5 drive setting selection (selected 1, 1541 or 1571) -> we hopefully do not need a drive
        sta $b000

        ; original ultima 5 loader initializes the disk drive here
        ; we might too, simply copying the code
        ; ###
        
        ; load here 128.sub and m
        ; maybe I find a way to play music on c64
        ; ###
        
        ; set Execution address of interrupt service routine to 0x0380
        sei
        lda #$80
        sta $fffe
        lda #$03
        sta $ffff
        cli

        ; check if quickstart
        ; ### without loading there is probably no time
        ; ### should come as function parameter
        lda $c5     ; key matrix code, for quickstart
        pha
        
        ; copy code
        jsr load_basicfiles
        
        ; now bank out and set memory
        lda #EASYFLASH_KILL
        sta EASYFLASH_CONTROL
        lda #$06
        sta $01

        ; load temp.subs
        ldx #$00    ; return after load
        jsr IO_load_file_entry
        .byte $54, $45, $4d, $50, $2e, $53, $55, $42, $53, $00  ; "TEMP.SUBS"

        ; load io.add
        ldx #$00    ; return after load
        jsr IO_load_file_entry
        .byte $49, $4f, $2e, $41, $44, $44, $00  ; ; "IO.ADD"

        ; load startup.prg or qs.prg, depending on j pressed
        pla         ; key is on stack
        cmp #$22
        bne @regular
        ldx #$01    ; jump to 0x8000 after load
        jsr IO_load_file
        .byte $51, $53, $00  ; ; "QS"
    @regular:
        ldx #$00    ; return after load
        jsr IO_load_file
        .byte $53, $54, $2a, $00  ; "ST*"
        jmp $8000


    irq_routine:
        ; probably need to take care of bank in/out ###
        pha
        txa
        pha
        tya
        pha
        lda $ff00  ; c128 mmu ### not necessary
        pha
        jsr $6c03  ; set memory banking: set kernal and io visible
        jsr $ff9f  ; ROM_SCNKEY - scan keyboard, matrix code $cb, shift key $028d, keys in keyboard buffer
        lda $dc0d  ; CIA1: CIA Interrupt Control Register
        jsr $6c06  ; set memory banking: set ram visible in all areas
        pla        
        sta $ff00  ; c128 mmu ### not necessary
        pla
        tay
        pla
        tax
        pla
        rti


    load_basicfiles:
        ; bank in 16k mode
        lda #$07
        sta $01
        lda #EASYFLASH_LED | EASYFLASH_16K
        sta EASYFLASH_CONTROL

        ; copy code
        ldx #$00
        ; eapi
    :   lda EAPI_SOURCE + $0000, x
        sta EAPI_DESTINATION + $0000, x
        lda EAPI_SOURCE + $0100, x
        sta EAPI_DESTINATION + $0100, x
        lda EAPI_SOURCE + $0200, x
        sta EAPI_DESTINATION + $0200, x

        ; exomizer
        lda EXO_SOURCE, x
        sta EXO_DESTINATION, x

        dex
        bne :-

        ; initialize eapi
        jsr EAPIInit

        ; prepare directory entry io area
        ldy #$18
        lda #$00
    :   dey
        sta requested_disk, y
        bne :-

        lda #$41
        sta requested_disk

        lda #$62   ; prg with roml only
        sta save_files_flags

        lda #$42   ; 'B'
        sta read_block_filename
        lda #$4c   ; 'L'
        sta read_block_filename+1
        lda #$4f   ; 'O'
        sta read_block_filename+2
        lda #$43   ; 'C'
        sta read_block_filename+3
        lda #$4b   ; 'K'
        sta read_block_filename+4
        lda #$53   ; 'S'
        sta read_block_filename+5
        lda #$0   ; '\0'
        sta read_block_filename+6

        ; now bank out but do not set memory
        lda #EASYFLASH_KILL
        sta EASYFLASH_CONTROL
        lda #$07
        sta $01

        rts