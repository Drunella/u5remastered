
; easyflash symbols

EASYFLASH_BANK    = $DE00
EASYFLASH_CONTROL = $DE02
EASYFLASH_LED     = $80
EASYFLASH_16K     = $07
EASYFLASH_KILL    = $04

EAPI_SOURCE  = $B800  ; $A000 (hirom) + 1800
EAPI_DESTINATION  = $7800

EFS_FILES_DIR_BANK  = 0
EFS_FILES_DIR_START = $A000
EFS_FILES_DATA_BANK  = 1
EFS_FILES_DATA_START = $8000
EFS_FILES_BANKSTRATEGY = $D0

BLOCKMAP_BANK = 39
BLOCKMAP_ADDRESS = $8000

EFS_MAXDIRECTORYENTRIES = $70
EFS_SAVES_BANK = 40
EFS_BTLIST_BANK = 48
EFS_UTLIST_BANK = 56


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
        