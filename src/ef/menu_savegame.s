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

.import _IO_load_file_entry
.import _IO_save_file_entry

.export _loadgame_prtydata
.export _loadgame_slist
.export _loadgame_list
.export _loadgame_roster

.export _savegame_prtydata
.export _savegame_list
.export _savegame_slist
.export _savegame_roster

.export _scratch_tlist_britannia
.export _scratch_tlist_underworld


.segment "LOADSAVEGAME"

    ; bool __fastcall__ loadgame_prtydata(void);
    _loadgame_prtydata:
        ldx #$00   ; loadmode 0, return after loading
        jsr _IO_load_file_entry
        .byte $50, $52, $54, $59, $2e, $44, $41, $54, $41, $00  ; PRTY.DATA
        bcs :+     ; branch if not found
        lda #$01   ; true
        rts
    :   lda #$00
        rts


    ; bool __fastcall__ loadgame_slist(void);
    _loadgame_slist:
        ldx #$00   ; loadmode 0, return after loading
        jsr _IO_load_file_entry
        .byte $53, $4c, $49, $53, $54, $00
        bcs :+     ; branch if not found
        lda #$01   ; true
        rts
    :   lda #$00
        rts


    ; bool __fastcall__ loadgame_list(void);
    _loadgame_list:
        ldx #$00   ; loadmode 0, return after loading
        jsr _IO_load_file_entry
        .byte $4c, $49, $53, $54, $00
        bcs :+     ; branch if not found
        lda #$01   ; true
        rts
    :   lda #$00
        rts


    ; bool __fastcall__ loadgame_roster(void);
    _loadgame_roster:
        ldx #$00   ; loadmode 0, return after loading
        jsr _IO_load_file_entry
        .byte $52, $4f, $53, $54, $45, $52, $00
        bcs :+     ; branch if not found
        lda #$01   ; true
        rts
    :   lda #$00
        rts



    ; bool __fastcall__ savegame_prtydata(void);
    _savegame_prtydata:
        jsr _IO_save_file_entry
        .byte $53, $3a, $50, $52, $54, $59, $2e, $44, $41, $54, $41, $00 ; S:PRTY.DATA
        .byte $00, $bc ; location $bc00
        .byte $30, $00 ; length $0030
        bcs :+     ; branch if error
        lda #$01   ; true
        rts
    :   lda #$00
        rts


    ; bool __fastcall__ savegame_list(void);
    _savegame_list:
        jsr _IO_save_file_entry
        .byte $53, $3a, $4c, $49, $53, $54, $00 ; S:LIST
        .byte $00, $4a ; location $4a00
        .byte $00, $02 ; length $0200
        bcs :+     ; branch if error
        lda #$01   ; true
        rts
    :   lda #$00
        rts


    ; bool __fastcall__ savegame_slist(void);
    _savegame_slist:
        jsr _IO_save_file_entry
        .byte $53, $3a, $53, $4c, $49, $53, $54, $00 ; S:SLIST
        .byte $00, $4a ; location $4a00
        .byte $00, $02 ; length $0200
        bcs :+     ; branch if error
        lda #$01   ; true
        rts
    :   lda #$00
        rts


    ; bool __fastcall__ savegame_roster(void);
    _savegame_roster:
        jsr _IO_save_file_entry
        .byte $53, $3a, $52, $4f, $53, $54, $45, $52, $00 ; S:ROSTER
        .byte $00, $10 ; location $1000
        .byte $00, $04 ; length $0400
        bcs :+     ; branch if error
        lda #$01   ; true
        rts
    :   lda #$00
        rts


    ; bool __fastcall__ scratch_tlist_britannia(void);
    _scratch_tlist_britannia:
        ldy #$00
        jsr EFS_setlfs
        lda #name_tlist_britannia_end - name_tlist_britannia
        ldx #<name_tlist_britannia
        ldy #>name_tlist_britannia
        jsr EFS_setnam

        lda #$00
        jsr EFS_open
        jsr EFS_close

        lda #$01
        rts

    name_tlist_britannia:
        .byte $53, $3a, $42, $54, $4c, $49, $53, $54  ; S:BTLIST
    name_tlist_britannia_end:


    ; bool __fastcall__ scratch_tlist_underworld(void);
    _scratch_tlist_underworld:
        ldy #$00
        jsr EFS_setlfs
        lda #name_tlist_underworld_end - name_tlist_underworld
        ldx #<name_tlist_underworld
        ldy #>name_tlist_underworld
        jsr EFS_setnam

        lda #$00
        jsr EFS_open
        jsr EFS_close

        lda #$01
        rts

    name_tlist_underworld:
        .byte $53, $3a, $48, $54, $4c, $49, $53, $54  ; S:HTLIST
    name_tlist_underworld_end:

