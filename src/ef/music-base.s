; ----------------------------------------------------------------------------
; Copyright 2019 Drunella
;
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
;
;     http://www.apache.org/licenses/LICENSE-2.0
;
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.
; ----------------------------------------------------------------------------

.include "easyflash.i"
.include "music.i"

; segment boundaries
.import __MUSIC_IRQHANDLER_LOAD__
.import __MUSIC_IRQHANDLER_SIZE__
.import __MUSIC_IRQHANDLER_RUN__
.import __MUSIC_JUMPTABLE_LOAD__
.import __MUSIC_JUMPTABLE_SIZE__
.import __MUSIC_JUMPTABLE_RUN__

; imports from disassemble
.import _sid_transfer
.import _sid_process
.import _sid_cleargate
.import _sid_initialize
.import music_masterswitch
.import music_timer
.import music_activity
.import song_data
.import control_values
.import init_playsound

; exports
.export music_lastconfig
.export music_lastbank
.export _music_init_impl
.export _play_song



; ----------------------------------------------------------------------------

; 0x0100, 35 (0x23) bytes
.segment "MUSIC_DATA"

    music_save_zeropage:
        .res $0a, $00   ; 10 bytes

    music_unused:
        .res $17, $00

    ; do NOT change the size of the data before
    music_lastbank:    ; $0121
        .byte $00
    music_lastconfig:  ; $0122 (this address is referenced as value)
        .byte $00



; ----------------------------------------------------------------------------

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



; ----------------------------------------------------------------------------

; 0x380
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



; ----------------------------------------------------------------------------

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

        ; clear memory
        ldx #$00
        txa
    :   sta $7b00, x
        inx
        bne :-

        ; set jmp at 7b00 ### address should be inserted by variable
        jsr init_playsound
;        lda #$4c
;        sta $7b00
;        lda #<playsound
;        sta $7b01
;        lda #>playsound
;        sta $7b02

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
        lda #EASYFLASH_KILL  ; init default config
        sta music_lastconfig

        ; bank in music bank
        jsr music_bankin

        ; initialize
        jsr _swap_zerospace_variables
        lda #<song_data  ; load address of song data
        sta $50
        lda #>song_data
        sta $51   
        jsr _sid_initialize
        jsr _swap_zerospace_variables

        ; restore old bank setting
        jsr music_bankout
        pla
        sta $01
        plp        ; clears interrupt flag

        ; turn on
        jsr $0129

        ; wait for sound activity
        jsr _sid_initialize_waitforirq

        rts



; ----------------------------------------------------------------------------

.segment "MUSIC_CALL"

    subs128calls:
        rts             ; unknown call
        nop
        nop

        jmp _play_song

        rts             ; unknown call
        nop
        nop

        rts             ; unknown call
        nop
        nop

        rts             ; unknown call
        nop
        nop

        rts             ; unknown call
        nop
        nop

        rts             ; unknown call

; any place
.segment "MUSIC_CODE"

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
        jsr _sid_cleargate

        ; set music control to off
        lda #$ff
        sta music_masterswitch

        jmp music_leave
        ; no rts, cli is set by plp on exit


    music_bankin:
        ; save port
        jsr EAPIGetBank
        sta music_lastbank

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
        lda music_lastbank
        jsr EAPISetBank
        ;lda #EASYFLASH_KILL ; jsr GetMemConfiguration ; bank out
        lda music_lastconfig  ; usually #EASYFLASH_KILL, sometimes other
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


    ; swaps 10 values between zeropage and backup
    _swap_zerospace_variables:
        ldx #$0a
    :   lda $50, x   
        tay          
        lda music_save_zeropage, x 
        sta $50, x   
        tya          
        sta music_save_zeropage, x 
        dex          
        bpl :-
        rts          


     ; waits for activity
     _sid_initialize_waitforirq:
        ldx #$00
        ldy #$00
        lda music_activity
    :   cmp music_activity
        bne :+
        dey                         
        bne :-
        dex                         
        bne :-
    :   rts                         



;    ; music_info: move to struct later
;    music_info:
;        .byte $00, $00
;        .byte $01, $01
;        .byte $02, $02
;
;    music_frequency:
;        .word $0000
;        .word $0000
;        .word $0000
;
;    music_unknown_data:
;        .res $0a, $00
;
;    music_voice_decisions:
;        .word $0000
;        .word $0000
;        .word $0000


;    ; music_processing: ### struct
;    music_workplace_7219:
;    music_masterswitch:
;        .byte $ff    ; turned off
;    music_timer:
;        .res $02, $ff
;
;        .res 231, $00 ; ###
