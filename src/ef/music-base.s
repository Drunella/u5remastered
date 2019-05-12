

.include "easyflash.i"


.import __MUSIC_IRQHANDLER_LOAD__
.import __MUSIC_IRQHANDLER_SIZE__
.import __MUSIC_IRQHANDLER_RUN__
.import __MUSIC_JUMPTABLE_LOAD__
.import __MUSIC_JUMPTABLE_SIZE__
.import __MUSIC_JUMPTABLE_RUN__

.import _swap_zerospace_variables

.export music_masterswitch
.export music_save_zeropage
.export _music_init_impl


; 0x0100, 22 bytes
.segment "MUSIC_DATA"

    music_masterswitch:
      .byte $ff    ; turned off

    music_save_zeropage:
      .res    $0a, $00



; 0x123
.segment "MUSIC_JUMPTABLE"

    ; 0x123
    _music_init:
        rts        ; purpose of this function is unknown
        nop
        nop

    ; 0x126
    _music_off:
        jmp music_off_impl

    ; 0x129
    _music_on:
        jmp music_on_impl



; 0x12c
.segment "MUSIC_IRQHANDLER"

    ; 33 bytes (max 34 bytes)
    music_interrupt:
        pha         
        txa         
        pha         
        tya         
        pha

    music_interrupt_lateentry:
        ; save banking setting
        lda $01
        pha
        cld        ; clear decimal mode
        lda #$06
        sta $01

        ; check if timer has generated an interrupt interrupt
        lda $dc0d
        bpl leave_interrupt ; branch if bit 7 (negative) is not set
 
        ; check if timer b triggered
        and #$02
        beq leave_interrupt ; branch if bit 2 is not set (x and 2 == 0)

        ; leave if music disabled
        lda music_masterswitch
        bmi leave_interrupt

        ; leave if music is turned off by user
        lda $79    ; music on/off
        bpl leave_interrupt

        ; bank in music bank
        jsr music_bankin

        ; forward music
        jsr forward_music

        ; bank out
        jsr music_bankout

    leave_interrupt:
        ; scan keyboard
        jsr $ff9f

        ; restore banking setting
        pla
        sta $01
        pla
        tay
        pla
        tax
        pla
        rti



; in temp area space
.segment "MUSIC_INIT"

    _music_init_impl:
        ; copy jumptable and interrupt
        ldx #<__MUSIC_JUMPTABLE_SIZE__
    :   lda __MUSIC_JUMPTABLE_LOAD__-1, x
        sta __MUSIC_JUMPTABLE_RUN__-1, x
        dex
        bne :-
        ldx #<__MUSIC_IRQHANDLER_SIZE__
    :   lda __MUSIC_IRQHANDLER_LOAD__-1, x
        sta __MUSIC_IRQHANDLER_RUN__-1, x 
        dex
        bne :-

        sei
        ; set nmi handler to single rti
        lda #<(__MUSIC_IRQHANDLER_RUN__ + __MUSIC_IRQHANDLER_SIZE__ - 1) ; single rti
        sta $0318
        lda #>(__MUSIC_IRQHANDLER_RUN__ + __MUSIC_IRQHANDLER_SIZE__ - 1) ; single rti
        sta $0319

        ; set execution address of interrupt service routine.
        lda #<music_interrupt_lateentry
        sta $0314
        lda #>music_interrupt_lateentry
        sta $0315

        ; set execution address of interrupt service routine at original vector
        ldx #<music_interrupt
        ldy #>music_interrupt
        stx $fffe
        sty $ffff

        lda #$ff
        sta music_masterswitch

        cli
        rts



; any place
.segment "MUSIC_CONTROL"

    music_activatecontrol:
        ; set CIA1 Timer B enable interrupts
        lda #$82
        sta $dc0d

        ; set CIA1 Timer B start timer
        lda #$01
        sta $dc0f

        ; disable all video interrupts
        lda #$00
        sta $d01a

        ; set execution address of interrupt service routine.
        lda #<music_interrupt_lateentry
        sta $0314
        lda #>music_interrupt_lateentry
        sta $0315

        ; set execution address of interrupt service routine at original vector
        ldx #<music_interrupt
        ldy #>music_interrupt
        stx $fffe 
        sty $ffff 

    music_leave:
        ; restore old bank setting
        jsr music_bankout
        pla
        sta $01

        ; return
        plp        ; clears interrupt flag
        rts


    music_on_impl:
        php
        sei

        ; save current bank setting
        lda $01
        pha
        lda #$06
        sta $01

        ; bank in music bank
        jsr music_bankin

        ; set music control to on
        lda #$00
        sta music_masterswitch

        jmp music_activatecontrol
        ; no rts, cli is set by plp on exit


    music_off_impl:
        php
        sei

        ; save current bank setting
        lda $01
        pha
        lda #$06
        sta $01

        ; bank in music bank
        jsr music_bankin

        ; mute sid chip
        nop ; ### todo
        nop
        nop

        ; set music control to off
        lda #$ff
        sta music_masterswitch
        
        jmp music_leave
        ; no rts, cli is set by plp on exit


    music_bankin:
        ; bank in music bank
        lda #$07
        sta $01
        lda #MUSIC_BANK
        jsr EAPISetBank
        lda #EASYFLASH_16K ; bank in without led
        sta EASYFLASH_CONTROL
        rts


    music_bankout:
        ; bank out
        lda #$06
        sta $01
        lda #EASYFLASH_KILL ; bank out
        sta EASYFLASH_CONTROL
        rts


    ; plays the music
    forward_music:
        ;lda $79    ; music on/off
        ;bpl @exit

        jsr _swap_zerospace_variables

        inc $7dff ; dummy work

;        jsr 0x741a ; 0x720c
;        jsr 0x78a6 ; transfer data to sid

        lda #$ff ; lda 0x7225 ; ### timer value low
        sta $dc06
        lda #$ff ; lda 0x7226 ; ### timer value high
        sta $dc07

        jsr _swap_zerospace_variables

    ;@exit:
        rts

