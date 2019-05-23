// ----------------------------------------------------------------------------
// Copyright 2019 Drunella
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// ----------------------------------------------------------------------------

#ifndef MENU_INCLUDE_H
#define MENU_INCLUDE_H

#include <stdint.h>

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
