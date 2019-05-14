

;.include "music.i"


;.import music_save_zeropage
;.import music_masterswitch
;.import music_timer
;.import music_activity

;.export _swap_zerospace_variables
;.export _sid_initialize_waitforirq



;.segment "MUSIC_SOURCE"

;    ; swaps 10 values between zeropage and backup
;    _swap_zerospace_variables:
;        ldx #$0a
;    :   lda $50, x   
;        tay          
;        lda music_save_zeropage, x 
;        sta $50, x   
;        tya          
;        sta music_save_zeropage, x 
;        dex          
;        bpl :-
;        rts          


;     _sid_initialize_waitforirq:
;        ldx #$00
;        ldy #$00
;        lda music_activity
;    :   cmp music_activity
;        bne :+
;        dey                         
;        bne :-
;        dex                         
;        bne :-
;    :   rts                         


;    ; mute sid ### ?
;    _sid_mute:
;        rts


;    ; prepare new data for sid
;    _sid_process:
;;        jsr 0x741a ; 0x720c process
;        inc $7dff ; dummy
;        rts


;    ; transfer new data to sid
;    _sid_transfer:
;;        jsr 0x78a6 ; transfer data to sid
;        inc $7dff ; dummy
;        rts




;    ; initialize implementation ###
;    _sid_initialize:
;        lda #<song_data
;        sta $50
;        lda #>song_data
;        sta $51
;        lda #$00                   
;        sta song_information_3cd
;        sta song_information_3cc
;        lda #$03                   
;        sta music_workplace_7219 + $11
;        ldx #$00                   
;    :   lda music_info, x
;        asl a                       
;        sta music_voice_decisions, x
;        lda music_info, x
;        ora #$08                   
;        sta music_voice_decisions+1, x
;        inx                         
;        inx                         
;        dec music_workplace_7219 + $11
;        bne :-
;        ldx #$18                   
;        lda #$00                   
;    :   sta $d400,x          ; sid register
;        dex                         
;        bpl :-
;        lda #$ff                   
;        sta song_information_3ce
;        lda $50                    
;        sta music_workplace_7219 + $11
;        lda $51                    
;        sta music_workplace_7219 + $12
;        ldy #$00                   
;        lda ($50),y          ; load
;        inc $50                    
;        bne :+
;        inc $51                    
;    :   tax                  ; sound data byte in X
;        beq :+++
;    :   inc $50                    
;        bne :+
;        inc $51                    
;    :   dex                         
;        bne :--
;    :   lda ($50),y          ; sound data byte in A
;        inc $50                    
;        bne :+
;        inc $51                    
;    :   sta music_workplace_7219 + $0f            ; sound data byte in address
;        tax                         
;        beq :++
;        ldy #$01             ; fillsong address database
;    :   clc                         
;        lda ($50),y                
;        adc music_workplace_7219 + $11
;        sta music_workplace_7219 + $1a, y
;        dey                         
;        lda ($50),y                
;        adc music_workplace_7219 + $12
;        sta music_workplace_7219 + $1c, y
;        iny                         
;        iny                         
;        iny                         
;        dex                         
;        bne :-
;    :   lda #$9a
;        sta music_timer            ; first timer value
;        lda #$42                   
;        sta music_timer+1          ; first timer value
;        lda #$00                   
;        sta music_workplace_7219 + $13
;        sta music_workplace_7219 + $14
;        sta music_masterswitch
;        rts
;    song_data:
;       .incbin "build/source/72345cf81545f1c65bfda189bb0b7bf9.prg", $aa2

