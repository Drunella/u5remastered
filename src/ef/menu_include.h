
#include <stdint.h>

#ifndef MENU_INCLUDE_H
#define MENU_INCLUDE_H


void clear_menu(void);
void menu_option(char key, char *desc);
void cart_kill(void);
void cart_bankin(void);
void cart_bankout(void);
void managesavegames(void);
bool disk_save_file(uint8_t device, char *filename, uint16_t loadaddr, void *buffer, uint16_t length);


bool __fastcall__ loadgame_prtydata(void);
bool __fastcall__ loadgame_slist(void);
bool __fastcall__ loadgame_list(void);
bool __fastcall__ loadgame_roster(void);
bool __fastcall__ savegame_prtydata(void);
bool __fastcall__ savegame_list(void);
bool __fastcall__ savegame_slist(void);
bool __fastcall__ savegame_roster(void);

void __fastcall__ IO_request_disk_char_entry(uint8_t disk);

void __fastcall__ load_basicfiles(void);
void __fastcall__ startupgame(uint8_t how);


#endif
