
; easyflash symbols

EASYFLASH_BANK    = $DE00
EASYFLASH_CONTROL = $DE02
EASYFLASH_LED     = $80
EASYFLASH_16K     = $07
EASYFLASH_KILL    = $04

EASYFLASH_SOURCE  = $B800  ; $A000 (hirom) + 1800
EASYFLASH_TARGET  = $7800

EFS_BANK          = 0
EFS_DIRECTORY_START = $A000

EAPIInit          = EASYFLASH_TARGET + 20
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
        