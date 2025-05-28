// ----------------------------------------------------------------------------
// Copyright 2023 Drunella
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


#include <stdbool.h>
#include <stdio.h>
#include <conio.h>
#include <string.h>
#include <ctype.h>
#include <stdint.h>
#include <stdlib.h>


static uint8_t last_device;


void loadsave_device(uint8_t d)
{
    last_device = d;
}

bool savegame_prtydata()
{
    uint8_t result;
    
    cbm_open(1, last_device, 15, "s:bprty.data");
    cbm_close(1);

    result = cbm_save("bprty.data", last_device, (void*)0xbc00, 0x0030);
    if (result == 0) return true;
    return false;
}

bool savegame_roster()
{
    uint8_t result;
    
    cbm_open(1, last_device, 15, "s:broster");
    cbm_close(1);

    result = cbm_save("broster", last_device, (void*)0x1000, 0x0400);
    if (result == 0) return true;
    return false;
}

bool loadgame_prtydata()
{
    uint16_t amount = cbm_load("bprty.data", last_device, NULL);
    if (amount == 0) return false;
    return true;
}

bool loadgame_roster()
{
    uint16_t amount = cbm_load("broster", last_device, NULL);
    if (amount == 0) return false;
    return true;
}

void soft_reset()
{
    __asm__("jmp $fce2");
}
