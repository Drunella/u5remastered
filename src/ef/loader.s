; =============================================================================
; 00:1:0000 (HIROM, bank 0)

.import __BOOTSTRAP_LOAD__
.import __BOOTSTRAP_RUN__
.import __BOOTSTRAP_SIZE__

EASYFLASH_BANK    = $DE00
EASYFLASH_CONTROL = $DE02
EASYFLASH_LED     = $80
EASYFLASH_16K     = $07
EASYFLASH_KILL    = $04


.segment "ULTIMAX_VECTORS"

    vector_nmi:
        .addr dummy

    vector_reset:
        .addr ultimax_reset

    vector_irq:
        .addr dummy


.segment "ULTIMAX_STARTUP"

    ultimax_reset:
        ; the reset vector points here
        sei
        ldx #$ff
        txs
        cld

        ; enable VIC (e.g. RAM refresh)
        lda #$08
        sta $d016

        ; write to RAM to make sure it starts up correctly (=> RAM datasheets)
    wait:
        sta $0100, x
        dex
        bne wait

        ; copy the final start-up code to RAM (bottom of CPU stack)
        ldx #<__BOOTSTRAP_SIZE__ - 1
    copy:
        lda __BOOTSTRAP_LOAD__,x
        sta __BOOTSTRAP_RUN__,x    
        dex
        bpl copy
        jmp bootstrap

    dummy:
        rti


.segment "BOOTSTRAP"

    bootstrap:
        ; bank in 16k mode
        lda #EASYFLASH_LED | EASYFLASH_16K
        sta EASYFLASH_CONTROL
        
        ; Check if one of the magic kill keys is pressed
        ; This should be done in the same way on any EasyFlash cartridge!
        ; screen black 
        lda #$00        ; border and screen black
        sta $d020
        sta $d021

        ; Prepare the CIA to scan the keyboard
        lda #$7f
        sta $dc00   ; pull down row 7 (DPA)

        ldx #$ff
        stx $dc02   ; DDRA $ff = output (X is still $ff from copy loop)
        inx
        stx $dc03   ; DDRB $00 = input

        ; Read the keys pressed on this row
        lda $dc01   ; read coloumns (DPB)

        ; Restore CIA registers to the state after (hard) reset
        stx $dc02   ; DDRA input again
        stx $dc00   ; Now row pulled down

        ; Check if one of the magic kill keys was pressed
        and #$e0    ; only leave "Run/Stop", "Q" and "C="
        cmp #$e0
        bne kill    ; branch if one of these keys is pressed

        ; same init stuff the kernel calls after reset
        ldx #$0
        stx $d016
        jsr $ff84   ; Initialise I/O

        ; initialize other stuff
        jsr $ff87   ; Initialise System Constants
        jsr $ff8a   ; Restore Kernal Vectors
        ;jsr $ff81   ; Initialize screen editor -> not needed

        ; start the application code, resides on 00:1:0000
        ; ### set bank if startup should not be in bank 00:1:0000
        cli
        jmp $a000

    kill:
        lda #EASYFLASH_KILL
        sta EASYFLASH_CONTROL
        cli
        jmp ($fffc) ; reset
