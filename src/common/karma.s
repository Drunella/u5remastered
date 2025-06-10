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


    ; --------------------------------------------------------------------
    _KARMA_test_karma:
        ; test
        lda KEY_RECENT
        cmp #$0b  ; CTRL + K
        beq _KARMA_print_karma

        ; unknown key: 'What'
        jsr $4c00
        .byte $d7, $e8, $e1, $f4, $bf, $8d, $00
        jmp KEY_CONTINUE


    ; --------------------------------------------------------------------
    _KARMA_print_karma:
        lda <KARMA
        lsr a
        lsr a
        lsr a
        lsr a
        clc
        adc #$b0
        sta karma_10
        lda <KARMA
        and #$0f
        clc
        adc #$b0
        sta karma_1
        
        jsr $4c00
        .byte $cb, $e1, $f2, $ed, $e1, $a0
      karma_10:
        .byte $b0
      karma_1:
        .byte $b0, $8d, $00
        
        jmp KEY_CONTINUE

