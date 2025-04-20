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

;.import __IO_WRAPPER_LOAD__
;.import __IO_WRAPPER_RUN__
;.import __IO_WRAPPER_SIZE__

.import __EAPI_START__


.import _load_eapi
;.import _wrapper_setnam
;.import _wrapper_load
;.import _wrapper_save


;.export _init_loader
;.export _init_loader_blank


.segment "LOADER_CALL"

    _init_loader:
        ; void __fastcall__ init_loader(void);
        jmp init_loader_body

/*    _init_loader_blank:
        ; void __fastcall__ init_loader_blank(void);
        jmp init_loader_blank_body*/



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
        lda #$cd
        jsr EFS_init_eapi

        lda #$36
        sta $01
        lda #$04   ; easyflash off
        sta $de02

        ; load menu
        lda #$01  ; channel (only 15 matters)
        ldy #$00  ; secondary address: relocate load
        jsr EFS_setlfs
        lda #menu_name_length
        ldx #<menu_name
        ldy #>menu_name
        jsr EFS_setnam
        ldx #$00
        ldy #$08
        lda #$00  ; load to x/y
        jsr EFS_load
        
    startup:
        jmp $0800


/*    init_loader_blank_body:
        ; load segment LOADER
        lda #<__LOADER_LOAD__
        sta source_address_low
        lda #>__LOADER_LOAD__
        sta source_address_high
        lda #<__LOADER_RUN__
        sta destination_address_low
        lda #>__LOADER_RUN__
        sta destination_address_high
        lda #<__LOADER_SIZE__
        sta bytes_to_copy_low
        lda #>__LOADER_SIZE__
        sta bytes_to_copy_high
        jsr copy_segment

        ; load eapi
        lda #>__EAPI_START__
        jsr _load_eapi

        ; load wrapper (IO_WRAPPER)
        lda #<__IO_WRAPPER_LOAD__
        sta source_address_low
        lda #>__IO_WRAPPER_LOAD__
        sta source_address_high
        lda #<__IO_WRAPPER_RUN__
        sta destination_address_low
        lda #>__IO_WRAPPER_RUN__
        sta destination_address_high
        lda #<__IO_WRAPPER_SIZE__
        sta bytes_to_copy_low
        lda #>__IO_WRAPPER_SIZE__
        sta bytes_to_copy_high
        jsr copy_segment

        rts
*/
/*
    copy_segment:
        lda bytes_to_copy_low
        beq copy_segment_loop
        inc bytes_to_copy_high
    copy_segment_loop:
    source_address_low = source_address + 1
    source_address_high = source_address + 2
    source_address:
        lda $ffff
    destination_address_low = destination_address + 1
    destination_address_high = destination_address + 2
    destination_address:
        sta $ffff
        ; increase source
        inc source_address_low
        bne :+
        inc source_address_high
    :   ; increase destination
        inc destination_address_low
        bne :+
        inc destination_address_high
    :   ; decrease size
        dec bytes_to_copy_low
        bne copy_segment_loop
        dec bytes_to_copy_high
        bne copy_segment_loop
        rts


    bytes_to_copy_low:
         .byte $ff
    bytes_to_copy_high:
         .byte $ff
*/

    loader_text:
        .byte $0c, $0f, $01, $04, $09, $0e, $07, $2e, $2e, $2e  ; "loading..."
    loader_text_end:
    loader_text_len = loader_text_end - loader_text


    menu_name:
        .byte $4d, $45, $4e, $55  ; "MENU"
    menu_name_end:
    menu_name_length = menu_name_end - menu_name

