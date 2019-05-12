

.include "easyflash.i"
.include "music.i"


.import __MUSIC_IRQHANDLER_LOAD__
.import __MUSIC_IRQHANDLER_SIZE__
.import __MUSIC_IRQHANDLER_RUN__
.import __MUSIC_JUMPTABLE_LOAD__
.import __MUSIC_JUMPTABLE_SIZE__
.import __MUSIC_JUMPTABLE_RUN__

.import _swap_zerospace_variables
.import _sid_transfer
.import _sid_process
.import _sid_mute
.import _sid_initialize

.export music_masterswitch ; ### rename
.export music_timer        ; ### rename

.export _music_init_impl
.export _play_song

.export music_save_zeropage

.export music_info
.export music_voice_decisions
.export music_workplace_7219


; 0x0100, 22 bytes
.segment "MUSIC_DATA"

    music_save_zeropage:
        .res $0a, $00



; 0x123
.segment "MUSIC_JUMPTABLE"

    ; 0x123
    _music_init:
        rts        ; purpose of this function is unknown, probably initialization
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
        ; SCNKEY. Query keyboard; put current matrix code into memory address $00CB,
        ; current status of shift keys into memory address $028D and PETSCII code into keyboard buffer.
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

        php
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

        ; save current bank setting
        lda $01
        pha
        lda #$06
        sta $01

        ; bank in music bank
        jsr music_bankin

        ; initialize
        jsr _swap_zerospace_variables
        jsr _sid_initialize
        jsr _swap_zerospace_variables

        ; restore old bank setting
        jsr music_bankout
        pla
        sta $01
        plp        ; clears interrupt flag

        ; wait for sound activity
        ; ###
        ; _sid_initialize_waitforirq

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

        lda #$9a    ; timer value wfrom m.prg init
        sta $dc06
        lda #$42
        sta $dc07

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
        jsr _sid_mute

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
        jsr _swap_zerospace_variables
        jsr _sid_process
        jsr _sid_transfer

        lda music_timer ; timer value low
        sta $dc06
        lda music_timer+1 ; timer value high
        sta $dc07

        jsr _swap_zerospace_variables
        rts


    ; play song
    _play_song:
         stx song_information_3cd
         stx song_information_3cc
         lda $79
         bpl play_song_leave
         ldy #$ff
         tya                
    :    cpx song_information_3ce
         beq play_song_leave
         dey                
         bne :-
         sbc #$01
         bne :-
    play_song_leave:                            
         rts                


    ; ------------------------------------------------------------------------

    ; music_info: move to struct later
    music_info:
        .byte $00, $00
        .byte $01, $01
        .byte $02, $02

    music_frequency:
        .word $0000
        .word $0000
        .word $0000

    music_unknown_data:
        .res $0a, $00

    music_voice_decisions:
        .word $0000
        .word $0000
        .word $0000


    ; music_processing: ### struct
    music_workplace_7219:
    music_masterswitch:
        .byte $ff    ; turned off
    music_timer:
        .res $02, $ff

        .res 231, $00 ; ###
