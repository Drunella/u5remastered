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

; main.out underworld
; 0x826b   20004c         jsr 0x4c00  ; print text
; 0x826e   d7e8e1f4bf8d00             ; 'What'
; 0x8275   4cf894         jmp 0x94f8  ; continue
KEY_CONTINUE := $94f8
KARMA := $2a
KEY_RECENT := $82cc

.export _KARMA_test_key_underworld

.segment "KARMA_OUT"


_KARMA_test_key_underworld:

.include "karma.s"
