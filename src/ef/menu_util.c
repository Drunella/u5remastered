// ----------------------------------------------------------------------------
// Copyright 2025 Drunella
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

// ----------------------------------------------------------------------------
// Based on code from
// (C) 2006-2015 Per Olofsson, available under an Apache 2.0 license.
// https://github.com/MagerValp/u4remastered.git
// ----------------------------------------------------------------------------

#include <stdbool.h>
#include <conio.h>
#include <stdio.h>
#include <string.h>

#include "menu_include.h"

#define MENU_START 13


uint8_t version[3] = {
#include "../../version.txt"
};


void clear_menu(void)
{
    uint8_t y;

    for (y = 12; y < 25; ++y) {
        cclearxy(0, y, 40);
    }
    gotoxy(0, MENU_START);
}


void menu_option(char key, char *desc)
{
    textcolor(COLOR_GRAY2);
    cputs("       (");
    textcolor(COLOR_WHITE);
    cputc(key);
    textcolor(COLOR_GRAY2);
    cputs(")  ");
    //textcolor(COLOR_GRAY2);
    //cprintf("%s\r\n", desc);
    cputs(desc);
    cputs("\r\n");
}


void cart_kill()
{
    __asm__("lda #$37"); // default
    __asm__("sta $01");
    __asm__("lda #4");
    __asm__("sta $de02");
}


void cart_bankin()
{
    __asm__("lda #$37");
    __asm__("sta $01");
    __asm__("lda #$87"); // led & 16k
    __asm__("sta $DE02");
}


void cart_bankout()
{
    __asm__("lda #$36");
    __asm__("sta $01");
    __asm__("lda #$04"); // none
    __asm__("sta $DE02");
}


bool disk_save_file(uint8_t device, char *filename, uint16_t loadaddr, void *buffer, uint16_t length)
{
    char namebuf[32];

    sprintf(namebuf, "s0:%s", filename);
    cbm_open(1, device, 15, namebuf);
    cbm_close(1);

    sprintf(namebuf, "%s,w,p", filename);
    if (cbm_open(1, device, 2, namebuf)) {
        return false;
    }

    if (cbm_write(1, &loadaddr, 2) != 2) {
        cbm_close(1);
        return false;
    }

    if (cbm_write(1, buffer, length) != length) {
        cbm_close(1);
        return false;
    }

    cbm_close(1);
    return true;
}


#pragma code-name ("EDITOR")
#pragma rodata-name ("ROEDITOR")


bool sure(uint8_t x, uint8_t y)
{
    char c;

    textcolor(COLOR_GRAY2);
    cputsxy(x, y, "Are you sure? ");
    cursor(1);
    c = cgetc();
    cursor(0);
    cclearxy(x, y, 16);
    return c == 'y';
}


uint8_t get_version_major(void)
{
    return version[0];
}

uint8_t get_version_minor(void)
{
    return version[1];
}

uint8_t get_version_patch()
{
    return version[2];
}


char* get_system_string()
{
    uint8_t s = SYS_get_system();
    switch(s) {
        case 0: return "EU-PAL"; break;
        case 1: return "NTSC-old"; break;
        case 2: return "PAL-N"; break;
        case 3: return "NTSC-new"; break;
        default: return "Unknown"; break;
    }
}

char* get_sid_string()
{
    uint8_t s = SYS_get_sid();
    switch(s) {
        case 1: return "SID6581"; break;
        case 2: return "SID8580"; break;
        default: return ""; break;
    }
}


void draw_version(void)
{
    char text[8];
    uint8_t n;
    char* system;

    system = get_system_string();
    cputsxy(0, 24, system);
    cputs(" C64");
    system = get_sid_string();
    if (strlen(system) > 0) {
        cputs(", ");
        cputs(system);
    }

    n = sprintf(text, "v%d.%d.%d", get_version_major(), get_version_minor(), get_version_patch());
    cputsxy(39-n, 24, text);
}
