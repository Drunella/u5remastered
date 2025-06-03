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


#include <stdbool.h>
#include <stdio.h>
#include <conio.h>
#include <string.h>
#include <ctype.h>
#include <stdint.h>
#include <stdlib.h>
#include "save_util.h"


#pragma code-name ("SAVEGAME")
#pragma data-name ("DASAVEGAME")
#pragma rodata-name ("ROSAVEGAME")


#define DEV_X 20
#define DEV_Y 13

#define MENU_START_X 12
#define MENU_START_Y 13

#define LIST_STORAGE 0x4a00
#define SLIST_STORAGE 0x4800


uint8_t __fastcall__ SYS_get_system();
uint8_t __fastcall__ SYS_get_sid();


uint8_t version[3] = {
#include "../../version.txt"
};

static uint8_t* original_drive = (uint8_t*)0x00ba;


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


static void draw_game_info(void) {
    clrscr();
    textcolor(COLOR_GRAY2);
    cputs("     Ultima V: Warriors of Destiny\r\n"
          "\r\n"
          "        Designed by Lord British\r\n"
          "\r\n");
    //textcolor(COLOR_GRAY1);
    cputs("   Commodore 64 conversion by Dr. Cat\r\n"
          "  Music composed by  Kenneth W. Arnold\r\n"
          "\r\n"
          " Copyright (c) 1988 Origin Systems Inc.\r\n"
          "\r\n"
          "        D81 version by Drunella\r\n"
          "\r\n");
}


void clear_menu(void)
{
    uint8_t y;

    for (y = MENU_START_Y; y < 25; ++y) {
        cclearxy(0, y, 40);
    }
    gotoxy(0, MENU_START_Y);
}

void menu_option(char key, char *desc)
{
    textcolor(COLOR_GRAY2);
    cputs("       (");
    textcolor(COLOR_WHITE);
    cputc(key);
    textcolor(COLOR_GRAY2);
    cputs(")  ");
    cputs(desc);
    cputs("\r\n");
}


static void print_device(uint8_t device) 
{
    cclearxy(DEV_X, DEV_Y, 3);
    gotoxy(DEV_X, DEV_Y);
    textcolor(COLOR_WHITE);
    cprintf("%d", device); // ### crashes, stack related?
}


static uint8_t select_device()
{
    uint8_t device = 0;
    uint8_t input_len = 0;
    char c;

    for (;;) {
        if (input_len) {
            print_device(device);
        } else {
            cclearxy(DEV_X, DEV_Y, 3);
            gotoxy(DEV_X, DEV_Y);
        }

        cursor(1);
        c = cgetc();
        cursor(0);

        if (c == CH_ENTER) {
            if (device >= 4 && device <= 30) {
                return device;
            }
        } else if (c == CH_DEL && input_len > 0) {
            device /= 10;
            --input_len;
        } else if (c >= '0' && c <= '9' && input_len < 2) {
            device = device * 10 + c - '0';
            ++input_len;
        }
    }
}



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


void backup_to_disk(uint8_t device)
{
    // S:PRTY.DATA (bc00, 0030)
    // S:LIST (4a00, 0200)
    // S:SLIST (4a00, 0200)
    // S:ROSTER (1000, 0400)

    bool ok;
    clear_menu();
    textcolor(COLOR_GRAY2);
    
    cputs("Backing up PRTY.DATA ...\r\n");
    ok = loadgame_prtydata();
    if (!ok) goto disk_error1;

    cputs("Backing up SLIST ...\r\n");
    ok = loadgame_slist();
    if (!ok) goto disk_error1;
    memcpy ((void*)SLIST_STORAGE, (void*)LIST_STORAGE, 0x0200);

    cputs("Backing up LIST ...\r\n");
    ok = loadgame_list();
    if (!ok) goto disk_error1;

    cputs("Backing up ROSTER ...\r\n");
    ok = loadgame_roster();
    if (!ok) goto disk_error1;

    // save
    cputs("Saving PRTY.DATA ...\r\n");
    ok = disk_save_file(device, "prty.data", 0xbc00, (void*)0xbc00, 0x0030);
    if (!ok) goto disk_error2;

    cputs("Saving LIST ...\r\n");
    ok = disk_save_file(device, "list", LIST_STORAGE, (void*)LIST_STORAGE, 0x0200);
    if (!ok) goto disk_error2;

    cputs("Saving SLIST ...\r\n");
    memcpy ((void*)LIST_STORAGE, (void*)SLIST_STORAGE, 0x0200);
    ok = disk_save_file(device, "slist", LIST_STORAGE, (void*)LIST_STORAGE, 0x0200);
    if (!ok) goto disk_error2;

    cputs("Saving ROSTER ...\r\n");
    ok = disk_save_file(device, "roster", 0x1000, (void*)0x1000, 0x0400);
    if (!ok) goto disk_error2;
    cputs("finished.\r\n");

disk_end:
    cputs("\r\n");
    menu_option(0x5f, "Back to menu");
    while (cgetc() != 0x5f);
    return;

disk_error1:
    cputs("Error or not found!\r\n");
    goto disk_end;
disk_error2:
    cputs("Error writing to disk!\r\n");
    goto disk_end;
}


void restore_from_disk(uint8_t device)
{
    // S:PRTY.DATA (bc00, 0030)
    // S:LIST (4a00, 0200)
    // S:SLIST (4a00, 0200)
    // S:ROSTER (1000, 0400)

    bool ok;
    unsigned int size;
    clear_menu();
    textcolor(COLOR_GRAY2);

    // load from disk
    cputs("Loading PRTY.DATA ...\r\n");
    size = cbm_load("prty.data", device, NULL);
    if (size == 0) goto flash_error1;
    
    cputs("Loading SLIST ...\r\n");
    size = cbm_load("slist", device, NULL);
    if (size == 0) goto flash_error1;
    memcpy((void*)SLIST_STORAGE, (void*)LIST_STORAGE, 0x0200);
    
    cputs("Loading LIST ...\r\n");
    size = cbm_load("list", device, NULL);
    if (size == 0) goto flash_error1;
    
    cputs("Loading ROSTER ...\r\n");
    size = cbm_load("roster", device, NULL);
    if (size == 0) goto flash_error1;
    
    // save to d81
    
    cputs("Storing PRTY.DATA ...\r\n");
    ok = savegame_prtydata();
    if (!ok) goto flash_error2;

    cputs("Storing LIST ...\r\n");
    ok = savegame_list();
    if (!ok) goto flash_error2;

    cputs("Storing SLIST ...\r\n");
    memcpy((void*)LIST_STORAGE, (void*)SLIST_STORAGE, 0x0200);
    ok = savegame_slist();
    if (!ok) goto flash_error2;

    cputs("Storing ROSTER ...\r\n");
    ok = savegame_roster();
    if (!ok) goto flash_error2;

    // scratch tlist
    scratch_tlist_britannia();
    scratch_tlist_underworld();
    
    cputs("finished.\r\n");

flash_end:
//    IO_request_disk_char_entry(0x41); // osi disk
    cputs("\r\n");
    menu_option(0x5f, "Back to menu");
    while (cgetc() != 0x5f);
    return;

flash_error1:
    cputs("Error reading from disk!\r\n");
    goto flash_end;
flash_error2:
    cputs("Error writing to remastered disk!\r\n");
    goto flash_end;
}


void main(void) 
{
    static bool repaint;
    bool really;
    static uint8_t device = 8;
    uint8_t temp;

    if (*original_drive == 8) device = 9;
    loadsave_device(*original_drive);
    repaint = true;
    bgcolor(COLOR_BLACK);
    bordercolor(COLOR_BLACK);
    draw_game_info();

    for (;;) {

        if (repaint) {
            clear_menu();
            menu_option('D', "Device #");
            cputs("\r\n");
            menu_option('B', "Backup to other disk");
            cputs("\r\n");
            menu_option('R', "Restore from other disk");
            cputs("\r\n");
            menu_option('Q', "Quit");
            draw_version();
            print_device(device);
        }
        repaint = false;

        switch (cgetc()) {
        case 'd':
            temp = select_device();
            if (*original_drive != temp) device = temp;
            repaint = true;
            break;

        case 'b':
            really = sure(MENU_START_X, MENU_START_Y + 1);
            if (really) backup_to_disk(device);
            repaint = true;
            break;

        case 'r':
            really = sure(MENU_START_X, MENU_START_Y + 3);
            if (really) restore_from_disk(device);
            repaint = true;
            break;

        case 'q':
            textcolor(COLOR_LIGHTBLUE);
            bgcolor(COLOR_BLUE);
            bordercolor(COLOR_LIGHTBLUE);
            clrscr();
#ifdef __C128__
            asm("jmp $ff3d");
#endif            
#ifdef __C64__
            soft_reset();
#endif
            exit(0);
        }
    }
}
