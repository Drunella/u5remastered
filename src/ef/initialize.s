; =============================================================================
; 00:1:0000 (HIROM, bank 0)

.include "easyflash.inc"

TEMP_SUBS_SOURCE = $1600
TEMP_SUBS_TARGET = $6c00

TEMP_SUBS_LOADFILE = $6c24


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
        lda #0x0e
        sta 0xff00
        lda #0x00

        ; initialize vars
        lda #0x00   ; load accumulator with memory
        sta $37     ; ???
        sta $c8     ; information about c128
        sta $79     ; information about c128
        sta $71     ; ???
        sec
        ror $78     ; ???
        
        ; copy key board routine
    @repeat:
        ldx #$20
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
        lda #$06
        sta $01
        
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
        lda EASYFLASH_SOURCE, x
        sta EASYFLASH_TARGET, x
        lda EASYFLASH_SOURCE + 256, x
        sta EASYFLASH_TARGET + 256, x
        lda EASYFLASH_SOURCE + 512, x
        sta EASYFLASH_TARGET + 512, x
        dex
        bne @repeat_eapi
        jsr EAPI_INIT

        ; bank in 16k mode
        lda #EASYFLASH_LED | EASYFLASH_16K
        sta EASYFLASH_CONTROL
        
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
        dex
        bne @repeat_subs
        
        ; load startup.prg or qs.prg, depending on j pressed
        pla         ; key is on stack
        cmp #$22
        bne @quickstart
        ldx #$01    ; jump to 0x8000 after load, code will bank out on itself
        jsr TEMP_SUBS_LOADFILE
        .bytes "STARTUP", $00
    @quickstart        :
        ldx #$01    ; jump to 0x8000 after load, code will bank out on itself
        jsr TEMP_SUBS_LOADFILE
        .bytes "QS", $00


    irq_routine:
        ; probably need to take care of bank in/out ###
        pha
        txa
        pha
        tya
        pha
        lda $ff00  ; c128 mmu
        pha
        jsr $6c03  ; set memory banking: set kernal and io visible
        jsr $ff9f  ; ROM_SCNKEY - scan keyboard, matrix code $cb, shift key $028d, keys in keyboard buffer
        lda $dc0d  ; CIA1: CIA Interrupt Control Register
        jsr $6c06  ; set memory banking: set ram visible in all areas
        pla        
        sta $ff00  ; c128 mmu
        pla
        tay
        pla
        tax
        pla
        rti


; load and init eapi (visible at 00:01:1800 to 00:01:1AFF)
;does some checks
;probably checks if c128 or c64
;drive select
;loads files U5SIZ.O TEMP.SUBS 
;loads M if other drive selected
;jumps to TEMP.SUBS (0x6c24) and load ST* (STARTUP)
;jumps to 0x8000
;size: 992 bytes
--------------------------------------------------------------------------
      ;lda #0x04                   ; load accumulator with memory
      ;sta 0x0289       ; Maximum length of keyboard buffer. Values: 4: buffer size
      ;sta 0x0a20                  ; store accumulator in memory
      ;lda #0x60                   ; load accumulator with memory
      ;sta 0x0126                  ; store accumulator in memory
      ;sta 0x0129                  ; store accumulator in memory
      ;lda #0xeb                   ; load accumulator with memory
      ;sta 0x028a       ; Keyboard repeat switch. Bits: 11101011
      ;lda #0x0e                   ; load accumulator with memory
      ;sta 0xff00       ; c128 mmu 0b00001110, IO, kernal, RAM0. 48K RAM
      
      ;lda #0x00                   ; load accumulator with memory
      ;sta 0x37                    ; store accumulator in memory
      ;sta 0xc8                    ; store accumulator in memory
      ;sta 0x79                    ; store accumulator in memory
      ;sta 0x71                    ; store accumulator in memory
      ;sec                         ; set carry flag
      ;ror 0x78                    ; rotate one bit right (memory or accumulator)
      
      ;lda #0x00                   ; load accumulator with memory
      ;sta 0xd020       ; Border Color black
      
      ;ldx #0x20                   ; load index x with memory
      ;lda 0x23b5,x                ; load accumulator with memory
      ;sta 0x0380,x                ; store accumulator in memory
      ;dex                         ; decrement index x by one
      ;bpl 0x202e                  ; branch on result plus
      ;lda #0x9e                   ; load accumulator with memory
      ;sta 0x0318                  ; store accumulator in memory
      ;lda #0x03                   ; load accumulator with memory
      ;sta 0x0319      ; Execution address of non-maskable interrupt service routine to 039e (single rti)
      ;lda #0x4c                   ; load accumulator with memory
      ;cmp 0xc024                  ; compare memory and accumulator
      ;bne 0x2062                  ; branch on result not zero
      ;lda #0x80                   ; load accumulator with memory
      ;sta 0xc8                    ; store accumulator in memory
      ;sta 0x79                    ; store accumulator in memory
      ;lda #0x95                   ; load accumulator with memory
      ;sta 0x0318                  ; store accumulator in memory
      ;lda #0x00                   ; load accumulator with memory
      ;sta 0x00                    ; store accumulator in memory
      ;sta 0x9d                    ; store accumulator in memory
      ;lda #0xff                   ; load accumulator with memory
      ;sta 0xd8                    ; store accumulator in memory
      ;lda #0x0b                   ; load accumulator with memory
      ;sta 0xd011      ;VIC Control Register 1
      lda #0x06                   ; load accumulator with memory
      sta 0x01        ; memory mapping 0b00000110, io visible, no basic, kernal
      lda 0xc8                    ; load accumulator with memory
      bpl 0x206d                  ; branch on result plus
      jmp 0x20d5                  ; jump to new location
      sei                         ; set interrupt disable status
      lda #0x83                   ; load accumulator with memory
      sta 0x0302                  ; store accumulator in memory
      lda #0xa4                   ; load accumulator with memory
      sta 0x0303                  ; store accumulator in memory
      lda #0x48                   ; load accumulator with memory
      sta 0x028f                  ; store accumulator in memory
      lda #0xeb                   ; load accumulator with memory
      sta 0x0290                  ; store accumulator in memory
      lda #0xa5                   ; load accumulator with memory
      sta 0x0330                  ; store accumulator in memory
      lda #0xf4                   ; load accumulator with memory
      sta 0x0331                  ; store accumulator in memory
      cli                         ; clear interrupt disable bit
      jsr 0x2133      ; display text and wait for input
      ldx #0xd9                   ; load index x with memory
      ldy #0x21                   ; load index y with memory
      lda #0x02                   ; load accumulator with memory
      jsr 0xffbd      ;$FFBD - set file name  (UJ)  -> reset disk drive               
      lda #0x0f                   ; load accumulator with memory
      tay                         ; transfer accumulator to index y
      ldx #0x08                   ; load index x with memory
      jsr 0xffba      ;$FFBA - set file parameters  15,8,15
      jsr 0xffc0      ;$FFC0 - open file after SETLFS,SETNAM
      ldx #0x11                   ; load index x with memory
      lda #0xff                   ; load accumulator with memory
      sec                         ; set carry flag
      pha                         ; push accumulator on stack
      sbc #0x01                   ; subtract memory from accumulator with borrow
      bne 0x20aa                  ; branch on result not zero
      pla                         ; pull accumulator from stack
      sbc #0x01                   ; subtract memory from accumulator with borrow
      bne 0x20a9                  ; branch on result not zero
      dex                         ; decrement index x by one
      bne 0x20a6                ; branch on result not zero
      lda #0x0f                   ; load accumulator with memory
      jsr 0xffc3      ;$FFC3 - close a logical file             
       

loading file starts?
   lda #0x07                   ; load accumulator with memory
   ldx #0xdc                   ; load index x with memory
   ldy #0x21                   ; load index y with memory
   jsr 0x23d4      ; set filename, 8,8,1 (U5S*TEMP) -> U5SIZ.O
   lda #0x00                   ; load accumulator with memory
   jsr 0xffd5                  ; jump to new location saving return address
   lda 0xb000      ; load file decision
   cmp #0x02       ; compare drive selection
   beq 0x20d5                  ; branch on result zero
   sei                         ; set interrupt disable status
   bit 0x7700                  ; test bits in memory with accumulator
   cli                         ; clear interrupt disable bit
   lda 0xc8                    ; load accumulator with memory
   bpl 0x20fd                  ; branch on result plus
   lda #0x01                   ; load accumulator with memory
   ldx #0xe5                   ; load index x with memory
   ldy #0x21                   ; load index y with memory
   jsr 0x23d4      ; set filename, 8,8,1 (M)
   lda #0x00                   ; load accumulator with memory
   jsr 0xffd5      ; ROM_LOAD - load after call SETLFS,SETNAM    
   jsr 0x720f      ; jumpt table in m file, initialize music?
   lda #0x04                   ; load accumulator with memory
   ldx #0xe6                   ; load index x with memory
   ldy #0x21       
   jsr 0x23d4      ; set filename, 8,8,1 (SUB.*)  -> C128
   lda #0x00                   ; load accumulator with memory
   jsr 0xffd5      ; ROM_LOAD ;$FFD5 - load after call SETLFS,SETNAM
   lda 0xd5                    ; load accumulator with memory
   jmp 0x210b                  ; jump to new location
   sei                         ; set interrupt disable status
   lda #0x80                   ; load accumulator with memory
   sta 0xfffe                  ; store accumulator in memory
   lda #0x03                   ; load accumulator with memory
   sta 0xffff                  ; store accumulator in memory
   cli                         ; clear interrupt disable bit
   lda 0xc5                    ; load accumulator with memory
   pha                         ; push accumulator on stack
   lda #0x05                   ; load accumulator with memory
   ldx #0xe0                   ; load index x with memory
   ldy #0x21                   ; load index y with memory
   jsr 0x23d4      ; set filename, 8,8,1 (TEMP*) TEMP.SUBS
   lda #0x00                   ; load accumulator with memory
   jsr 0xffd5                  ; jump to new location saving return address
   pla                         ; pull accumulator from stack
   cmp #0x22                   ; compare memory and accumulator
   bne 0x2127                  ; branch on result not zero
   ldx #0x01                   ; load index x with memory
   jsr 0x6c24      ; load file with filename after call, null terminated string, return address is set to after params
                   ; QS
   ldx #0x00       ; return after load
   jsr 0x6c24      ; load file with filename after call, null terminated string, return address is set to after params
                   ; ST*
   jmp 0x8000                  ; jump to new location


routine copied to 0x0380
     pha                         ; push accumulator on stack
     txa                         ; transfer index x to accumulator
     pha                         ; push accumulator on stack
     tya                         ; transfer index y to accumulator
     pha                         ; push accumulator on stack
     lda 0xff00                  ; load accumulator with memory
     pha                         ; push accumulator on stack
     jsr 0x6c03       ; set memory banking: set kernal and io visible
     jsr 0xff9f       ; ROM_SCNKEY - scan keyboard          
     lda 0xdc0d       ; CIA1: CIA Interrupt Control Register
     jsr 0x6c06       ; set memory banking: set ram visible in all areas
     pla                         ; pull accumulator from stack
     sta 0xff00                  ; store accumulator in memory
     pla                         ; pull accumulator from stack
     tay                         ; transfer accumulator to index y
     pla                         ; pull accumulator from stack
     tax                         ; transfer accumulator to index x
     pla                         ; pull accumulator from stack
     rti                         ; return from interrupt

filename and file parameters standardized
       jsr 0xffbd       ; ROM_SETNAM $FFBD - set file name   
       lda #0x08                   ; load accumulator with memory
       ldx #0x08                   ; load index x with memory
       ldy #0x01                   ; load index y with memory
       jmp 0xffba       ; ROM_SETLFS ;$FFBA - set file parameters
