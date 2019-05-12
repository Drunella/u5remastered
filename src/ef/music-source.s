

.import music_save_zeropage

.export _swap_zerospace_variables


.segment "MUSIC_SOURCE"

    ; swapts 10 values between zeropage to backup
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
