;
; efs entry

.struct efs_directory
    .struct name
        .byte
        .byte
        .byte
        .byte
        .byte
        .byte
        .byte
        .byte
        .byte
        .byte
        .byte
        .byte
        .byte
        .byte
        .byte
        .byte
        .byte
        .byte
        .byte
        .byte
    .endstruct
    flags .byte
    bank .byte
    reserved .byte
    offset .word
    .struct size 
        lower .word
        high .byte
    .endstruct
.endstruct