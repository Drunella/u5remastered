; ----------------------------------------------------------------------------
; Copyright 2025 Drunella
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


.include "easyflash.i"


.import __LOADER_LOAD__
.import __LOADER_RUN__
.import __LOADER_SIZE__

.import _load_eapi

;.import EXO_decrunch
;
;.export get_crunched_byte
;.export decrunch_table


.segment "LOADER_CALL"

    _init_loader:
        ; void __fastcall__ init_loader(void);
        jmp init_loader_body



.segment "LOADER"

    init_loader_body:
        ; lower character mode
        lda #$17
        sta $d018

        lda $d011  ; enable output
        ora #$10
        sta $d011

        ; write loading...
        ldx #$00
    :   lda loader_text, x
        sta $07e8 - loader_text_len, x  ; write text
        lda #$0c  ; COLOR_GRAY2
        sta $dbe8 - loader_text_len, x  ; write color
        inx
        cpx #loader_text_len
        bne :-

        ; load efs
        lda #$37
        sta $01
        lda #$87   ; led, 16k mode
        sta $de02
        lda #$00   ; EFSLIB_ROM_BANK
        sta $de00
        jsr EFS_init
        ; bcs error ###

        ; eapi / minieapi
;        jsr EFS_init_minieapi
        lda #>EAPI_DESTINATION  ; see memory.txt
        jsr EFS_init_eapi

        lda #$36
        sta $01
        lda #$04   ; easyflash off
        sta $de02

        ; load menu
        lda #$01  ; channel (only 15 matters)
        ldy #$01  ; secondary address: relocate load
        jsr EFS_setlfs
        lda #menu_name_length
        ldx #<menu_name
        ldy #>menu_name
        jsr EFS_setnam
;        ldx #$00
;        ldy #$08
        lda #$00  ; read
        jsr EFS_load
;        jsr EFS_open
;
;        jsr EXO_decrunch
;        jsr EFS_close
        
    startup:
        jmp $2000


    ; --------------------------------------------------------------------
    ; get_crunched_byte
    ; must preserve stat, X, Y
    ; return value in A
;    get_crunched_byte:
;        php
;        txa
;        pha
;        tya
;        pha
;        jsr EFS_chrin
;        sta get_byte_temp
;
;        lda $d020
;        tax
;        lda #$01
;        sta $d020
;        txa
;        sta $d020
;
;        pla
;        tay
;        pla
;        tax
;        lda get_byte_temp
;        plp
;        rts


    loader_text:
        .byte $0c, $0f, $01, $04, $09, $0e, $07, $2e, $2e, $2e  ; "loading..."
    loader_text_end:
    loader_text_len = loader_text_end - loader_text


    menu_name:
        .byte $41, $4d, $45, $4e, $55  ; "AMENU"
    menu_name_end:
    menu_name_length = menu_name_end - menu_name


    ; --------------------------------------------------------------------
    ; exo decrunch table

;.segment "EXO_DATA"
;
;    get_byte_temp:
;        .byte $00
;
;    decrunch_table:
;        .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
;        .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
;        .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
;.IFDEF EXTRA_TABLE_ENTRY_FOR_LENGTH_THREE
;        .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
;        .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
;        .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
;.ENDIF
;        .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
;        .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
;        .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
;        .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
;        .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
;        .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
;        .byte 0,0,0,0,0,0,0,0,0,0,0,0
