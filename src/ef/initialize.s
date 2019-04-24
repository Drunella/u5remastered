; =============================================================================
; 00:1:0000 (HIROM, bank 0)

.include "../include/easyflash.inc"
.include "../include/io.inc"

TEMP_SUBS_SOURCE = $9500  ; banked in memory
TEMP_SUBS_TARGET = $6c00

STARTUP_TARGET = $2000


;.segment "EF_NAME"
;
    ; set name at 
    ;   00:1:1B00 Magic ”EF-Name:”, PETSCII (65 66 2d 6e 41 4d 45 3a)
;    .byte $65, $66, $2d, $6e, $41, $4d, $45, $3a
    ;   00:1:1B08 Name in upper/lower case PETSCII, up to 16 characters, no gfxsymbols, padded to 16 bytes with binary 0 (Ultima 5 Remastered)
;    .byte "Ultima 5 Rem.", $00, $00, $00
    ;   00:1:1B18 filled with 0xff
;    .res  232, $ff


.segment "INITIALIZE"

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
        ldx #$20   ; calculate this address ###
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
        lda $c5     ; key matrix code, for quickstart
        pha
        
        ; load eapi
        ldx #$00
    @repeat_eapi:
        lda EASYFLASH_SOURCE + $0000, x
        sta EASYFLASH_TARGET + $0000, x
        lda EASYFLASH_SOURCE + $0100, x
        sta EASYFLASH_TARGET + $0100, x
        lda EASYFLASH_SOURCE + $0200, x
        sta EASYFLASH_TARGET + $0200, x
        lda EASYFLASH_SOURCE + $0300, x   ; for exomizer
        sta EASYFLASH_TARGET + $0300, x
        dex
        bne @repeat_eapi

        ; load temp.subs
        ldx #$00
    @repeat_subs:
        lda TEMP_SUBS_SOURCE + $0000, x
        sta TEMP_SUBS_TARGET + $0000, x
        lda TEMP_SUBS_SOURCE + $0100, x
        sta TEMP_SUBS_TARGET + $0100, x
        lda TEMP_SUBS_SOURCE + $0200, x
        sta TEMP_SUBS_TARGET + $0200, x
        lda TEMP_SUBS_SOURCE + $0300, x
        sta TEMP_SUBS_TARGET + $0300, x
        lda TEMP_SUBS_SOURCE + $0400, x
        sta TEMP_SUBS_TARGET + $0400, x
        lda TEMP_SUBS_SOURCE + $0500, x
        sta TEMP_SUBS_TARGET + $0500, x
        lda TEMP_SUBS_SOURCE + $0600, x
        sta TEMP_SUBS_TARGET + $0600, x
        lda TEMP_SUBS_SOURCE + $0700, x
        sta TEMP_SUBS_TARGET + $0700, x
        lda TEMP_SUBS_SOURCE + $0800, x
        sta TEMP_SUBS_TARGET + $0800, x
        lda TEMP_SUBS_SOURCE + $0900, x
        sta TEMP_SUBS_TARGET + $0900, x
        lda TEMP_SUBS_SOURCE + $0a00, x
        sta TEMP_SUBS_TARGET + $0a00, x
        dex
        bne @repeat_subs

        ; load startup
        ldx #(irq_routine - startup_entry - 1)
    @repeat_startup:
        lda startup_entry, x
        sta STARTUP_TARGET, x
        dex
        bpl @repeat_startup

        ; leave rom area
        jmp STARTUP_TARGET


    startup_entry:
        ; initialize eapi
        jsr EAPIInit
        
        ; now bank out and set memory
        lda #EASYFLASH_KILL
        sta EASYFLASH_CONTROL
        lda #$06
        sta $01

        ; load startup.prg or qs.prg, depending on j pressed
        pla         ; key is on stack
        cmp #$22
        bne @regular
        ldx #$01    ; jump to 0x8000 after load
        jsr IO_load_file
        .byte "QS", $00
    @regular:
        ldx #$00    ; return after load
        jsr IO_load_file
        .byte "STARTUP", $00
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
