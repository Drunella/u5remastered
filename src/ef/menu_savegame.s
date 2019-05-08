

.import IO_load_file_entry
.import IO_save_file_entry


.segment "LOADSAVEGAME"

    ; bool __fastcall__ loadsavegame_prtydata(void);
    loadgame_prtydata:
        ldx #$00   ; loadmode 0, return after loading
        jsr IO_load_file_entry
        .byte $50, $52, $54, $59, $2e, $44, $41, $54, $41, $00  ; PRTY.DATA
        bcs :+     ; branch if not found
        lda #$01   ; true
        rts
    :   lda #$00
        rts


    ; bool __fastcall__ loadsavegame_slist(void);
    loadgame_slist:
        ldx #$00   ; loadmode 0, return after loading
        jsr IO_load_file_entry
        .byte $53, $4c, $49, $53, $54, $00
        bcs :+     ; branch if not found
        lda #$01   ; true
        rts
    :   lda #$00
        rts


    ; bool __fastcall__ loadsavegame_list(void);
    loadgame_list:
        ldx #$00   ; loadmode 0, return after loading
        jsr IO_load_file_entry
        .byte $4c, $49, $53, $54, $00
        bcs :+     ; branch if not found
        lda #$01   ; true
        rts
    :   lda #$00
        rts


    ; bool __fastcall__ loadsavegame_roster(void);
    loadgame_roster:
        ldx #$00   ; loadmode 0, return after loading
        jsr IO_load_file_entry
        .byte $52, $4f, $53, $54, $45, $52, $00
        bcs :+     ; branch if not found
        lda #$01   ; true
        rts
    :   lda #$00
        rts



    ; bool __fastcall__ savegame_prtydata(void);
    savegame_prtydata:
        ldx #$00   ; loadmode 0, return after loading
        jsr IO_save_file_entry
        .byte $50, $52, $54, $59, $2e, $44, $41, $54, $41, $00 ; PRTY.DATA
        .byte $00, $bc ; location $bc00
        .byte $30, $00 ; length $0030
        bcs :+     ; branch if error
        lda #$01   ; true
        rts
    :   lda #$00
        rts


    ; bool __fastcall__ savegame_list(void);
    savegame_list:
        jsr IO_load_file_entry
        .byte $4c, $49, $53, $54, $00
        .byte $00, $4a ; location $4a00
        .byte $00, $02 ; length $0200
        bcs :+     ; branch if not found
        lda #$01   ; true
        rts
    :   lda #$00
        rts


    ; bool __fastcall__ savegame_slist(void);
    savegame_slist:
        jsr IO_load_file_entry
        .byte $53, $4c, $49, $53, $54, $00
        .byte $00, $4a ; location $4a00
        .byte $00, $02 ; length $0200
        bcs :+     ; branch if not found
        lda #$01   ; true
        rts
    :   lda #$00
        rts


    ; bool __fastcall__ savegame_roster(void);
    savegame_roster:
        jsr IO_save_file_entry
        .byte $52, $4f, $53, $54, $45, $52, $00 ; ROSTER
        .byte $00, $10 ; location $1000
        .byte $00, $04 ; length $0400
        bcs :+     ; branch if not found
        lda #$01   ; true
        rts
    :   lda #$00
        rts
