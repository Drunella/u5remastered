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
    .endstruct
    flags .byte
    bank .byte
    reserved .byte
    offset_low .byte
    offset_high .byte
    size_low .byte
    size_high .byte
    size_upper .byte
.endstruct
