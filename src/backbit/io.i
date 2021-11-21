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


kernal_SETLFS = $ffba
kernal_SETNAM = $ffbd
kernal_LOAD   = $ffd5
kernal_CLOSE  = $ffc3
kernal_SAVE   = $ffd8
kernal_OPEN   = $ffc0

;decrunch_table = $7f00

drive_id = $6c33
original_load_block = $6eae

britannia_track_original = 19
britannia_track_height = 17
britannia_track_correction = 22
britannia_sector_correction = 0
underworld_track_original = 19
underworld_track_height = 17
underworld_track_correction = 22
underworld_sector_correction = 16

towne_track_original = 24
towne_track_height = 12
towne_track_correction = 34
towne_sector_correction = 0
dwelling_track_original = 24
dwelling_track_height = 12
dwelling_track_correction = 34
dwelling_sector_correction = 16

castle_track_original = 24
castle_track_height = 12
castle_track_correction = 4
castle_sector_correction = 0
keep_track_original = 24
keep_track_height = 12
keep_track_correction = 4
keep_sector_correction = 16

dungeon_track_original = 25
dungeon_track_height = 11
dungeon_track_correction = $f8  ; -8
dungeon_sector_correction = 0
