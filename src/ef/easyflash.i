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

; easyflash ultima 5 parameter

EAPI_SOURCE  = $B800  ; $A000 (hirom) + 1800
EAPI_DESTINATION  = $7800

EXO_SOURCE = $bc00
EXO_DESTINATION = $7b00

EFS_FILES_DIR_BANK  = 0
EFS_FILES_DIR_START = $A000
EFS_FILES_DATA_BANK  = 1
EFS_FILES_DATA_START = $8000
EFS_FILES_BANKSTRATEGY = $D0

BLOCKMAP_BANK = 47
BLOCKMAP_ADDRESS = $A000

EFS_MAXDIRECTORYENTRIES = $70
EFS_SAVES_BANK = 40
EFS_BTLIST_BANK = 48
EFS_UTLIST_BANK = 56

MUSIC_BANK = 18


; eapi functions

EASYFLASH_BANK    = $DE00
EASYFLASH_CONTROL = $DE02
EASYFLASH_LED     = $80
EASYFLASH_16K     = $07
EASYFLASH_KILL    = $04

EAPIInit          = EAPI_DESTINATION + 20
EAPIWriteFlash    = $df80
EAPIEraseSector   = $df83
EAPISetBank       = $df86
EAPIGetBank       = $df89
EAPISetPtr        = $df8c
EAPISetLen        = $df8f
EAPIReadFlashInc  = $df92
EAPIWriteFlashInc = $df95
EAPISetSlot       = $df98
EAPIGetSlot       = $df9b


; EFS lib

EFS_init    = $8000
EFS_init_minieapi = $8006
EFS_init_eapi = $8003
EFS_defragment = $8009
EFS_format = $800c

EFS_setlfs  = $DF00
EFS_setnam  = $DF06
EFS_load    = $DF0C
EFS_open    = $DF12
EFS_close   = $DF18
EFS_chrin   = $DF1E
EFS_readst  = $DF30
EFS_save    = $DF24
EFS_chrout  = $DF2A


; efs struct
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
