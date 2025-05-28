; ----------------------------------------------------------------------------
; Copyright 2023 Drunella
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

.feature c_comments
.localchar '@'


.export _SYS_get_sid
.export _SYS_get_system


.segment "EDITOR"


    ; uint8_t __fastcall__ _SYS_get_system()
    _SYS_get_system:
        sei
        ldy #$04
    ld_DEY:
        ldx #$88     ; DEY = $88
    waitline:
        cpy $d012
        bne waitline
        dex
        bmi ld_DEY + 1
    cycle_wait_loop:
        lda $d012 - $7f,x
        dey
        bne cycle_wait_loop
        and #$03
        ldx #$00
        cli
        rts



    ; uint8_t __fastcall__ _SYS_get_sid()
    ; from http://unusedino.de/ec64/technical/c=hacking/ch20.html
    _SYS_get_sid:
        sei
        lda #11
        sta $d011

        ;sid setup here
        lda #$20
        sta $d40e
        sta $d40f

        lda #%00110001
        sta $d412

        ldx #0
        stx sid_measure

    @loop:
        lda $d41b
        cmp sid_measure
        bcc @ahead
        sta sid_measure
    @ahead:
        dex
        bne @loop

        lda #%00110000
        sta $d412

        cli
        lda #27
        sta $d011

        lda sid_measure
        bmi @sid8580
        bpl @sid6581

        lda #$ff  ; detection error
        rts

    @sid8580:
        lda #$02
        rts

    @sid6581:
        lda #$01
        rts

    sid_measure:
        .byte 0

