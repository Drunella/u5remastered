
#include <stdint.h>

#ifndef MENU_INCLUDE_H
#define MENU_INCLUDE_H

void clear_menu(void);
void menu_option(char key, char *desc);
void cart_kill(void);
void managesavegames(void);


bool __fastcall__ loadgame_prtydata(void);
bool __fastcall__ loadgame_slist(void);
bool __fastcall__ loadgame_list(void);
bool __fastcall__ loadgame_roster(void);
bool __fastcall__ savegame_prtydata(void);
bool __fastcall__ savegame_list(void);
bool __fastcall__ savegame_slist(void);
bool __fastcall__ savegame_roster(void);


void __fastcall__ load_basicfiles(void);
void __fastcall__ startupgame(uint8_t how);


#endif
