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


void loadsave_device(uint8_t d);
bool savegame_prtydata();
bool savegame_roster();
bool loadgame_prtydata();
bool loadgame_roster();
void soft_reset(void);


#endif
