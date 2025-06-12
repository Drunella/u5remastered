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

.include "easyflash.i"
.include "io.i"

.import read_block_filename
.import save_files_flags

.import _IO_load_file_entry
.import _music_init_impl

.export _initialize_game
.export _startup_game



.segment "LOADER"

    ; initialize and load everything
    ; mostly copied from xyzzy.prg from ultima 5 osi disk
    ; will never return
    ; void __fastcall__ startupgame(uint8_t how);
    ; how == 1 then quick start
    _startup_game:
        ; we will never return, reset stack
        ldx #$ff  ;
        txs

        ; put how to load on stack
        pha

        ; Maximum length of keyboard buffer.
        lda #$04
        sta $0289
        sta $0a20  ; ?

        ; fill non-bankable routines with rts
        lda #$60
        sta $0126
        sta $0129

        ; Keyboard repeat switch. Bits: 11101011
        lda #$eb
        sta $028a

        ; c128 mmu check could be omitted
        ; 0b00001110, IO, kernal, RAM0. 48K RAM
        ;lda #$0e
        ;sta $ff00
        ;lda #$00

        ; initialize vars
        lda #$00   ; load accumulator with memory
        sta $37    ; ???
        sta $c8    ; is not c128
        ;sta $79    ; music off
        sta $71    ; ???
        sec
        ror $78    ; ???

        lda #$80
        sta $79    ; music on

        ; check if this is a c128 (value $4c at this address) -> it should not
        ;lda #$4c
        ;cmp $c024

        ; memory mapping 0b00000110, io visible, no basic, kernal   
        ;lda #$06
        ;sta $01
        
        ; restore / set vectors
        sei
        lda #$83    ; Execution address of BASIC idle loop. ???
        sta $0302   ; default 0xa483
        lda #$a4         
        sta $0303        
        
        lda #$48    ; Execution address of routine that, based on the status of shift keys     ???
        sta $028f   ; sets the pointer at memory address $00F5-$00F6 to the appropriate
        lda #$eb    ; conversion table for converting keyboard matrix codes to PETSCII codes.
        sta $0290   ; default 0xeb48
        
        lda #$a5    ; Execution address of LOAD, routine loading files.
        sta $0330   ; default 0xf4a5
        lda #$f4    ; no fast loader
        sta $0331
        cli
        
        ;lda #$01    ; store ultima 5 drive setting selection (selected 1, 1541 or 1571) -> we hopefully do not need a drive
        ;sta $b000

        ; initialize other stuff
        jsr _initialize_game

        ; now bank out and set memory
        lda #EASYFLASH_KILL
        sta EASYFLASH_CONTROL ; jsr SetMemConfiguration
        lda #$36
        sta $01

        ; load temp.subs
        ldx #$00    ; return after load
        jsr _IO_load_file_entry
        .byte $54, $45, $4d, $50, $2e, $53, $55, $42, $53, $00  ; "TEMP.SUBS"

        ; load music
        ldx #$00    ; return after load
        jsr _IO_load_file_entry
        .byte $4d, $55, $53, $49, $43, $00  ; "MUSIC"

        ; and init interrupt handler
        jsr _music_init_impl

        ; Execution address of non-maskable interrupt service routine to 039e (single rti)
        ; set Execution address of interrupt service routine to 0x0380
        ; both done in music

        ; load startup.prg or qs.prg, depending on parameter pressed
        pla         ; how to load is on stack
        cmp #$01
        bne @regular
        ldx #$01    ; jump to 0x8000 after load
        jsr _IO_load_file_entry
        .byte $51, $53, $00  ; ; "QS"
    @regular:
        ldx #$00    ; return after load
        jsr _IO_load_file_entry
        .byte $53, $54, $2a, $00  ; "ST*"
        jmp $8000


    _initialize_game:
        ; bank in 16k mode
        lda #$37
        sta $01
        lda #EASYFLASH_LED | EASYFLASH_16K
        sta EASYFLASH_CONTROL ; jsr SetMemConfiguration

        ; work banked in
        ; ###

        ; now bank out but do not set memory
        lda #EASYFLASH_KILL
        sta EASYFLASH_CONTROL
        lda #$37
        sta $01

        ; set music return calls
        lda #$60   ; opcode rts
        sta $0123
        sta $0126
        sta $0129

        rts
