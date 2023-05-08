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

// ----------------------------------------------------------------------------
// Based on code from
// (C) 2006-2015 Per Olofsson, available under an Apache 2.0 license.
// https://github.com/MagerValp/u4remastered.git
// ----------------------------------------------------------------------------

#include <stdbool.h>
#include <stdio.h>
#include <conio.h>
#include <string.h>

#include "menu_include.h"


#define DEV_X 20
#define DEV_Y 13

#define MENU_START_X 12
#define MENU_START_Y 15


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



/*bool sure(uint8_t x, uint8_t y)
{
    char c;

    textcolor(COLOR_GRAY2);
    cputsxy(x, y, "Are you sure? ");
    cursor(1);
    c = cgetc();
    cursor(0);
    cclearxy(x, y, 16);
    return c == 'y';
}*/


void backup_to_disk(uint8_t device)
{
    // S:PRTY.DATA (bc00, 0030)
    // S:LIST (4a00, 0200)
    // S:SLIST (4a00, 0200)
    // S:ROSTER (1000, 0400)

    bool ok;
    clear_menu();
    textcolor(COLOR_GRAY2);
    cart_bankout();
    IO_request_disk_char_entry(0x42); // britannia disk
    
    cputs("Backing up PRTY.DATA ...\r\n");
    ok = loadgame_prtydata();
    if (!ok) goto disk_error1;

    cputs("Backing up SLIST ...\r\n");
    ok = loadgame_slist();
    if (!ok) goto disk_error1;
    // $7c00 is a free area to temporary save SLIST
    memcpy ((void*)0x7c00, (void*)0x4a00, 0x0200);

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
    ok = disk_save_file(device, "list", 0x4a00, (void*)0x4a00, 0x0200);
    if (!ok) goto disk_error2;
    memcpy ((void*)0x4a00, (void*)0x7c00, 0x0200);

    cputs("Saving SLIST ...\r\n");
    ok = disk_save_file(device, "slist", 0x4a00, (void*)0x4a00, 0x0200);
    if (!ok) goto disk_error2;

    cputs("Saving ROSTER ...\r\n");
    ok = disk_save_file(device, "roster", 0x1000, (void*)0x1000, 0x0400);
    if (!ok) goto disk_error2;
    cputs("finished.\r\n");

disk_end:
    IO_request_disk_char_entry(0x41); // osi disk
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
    cart_bankout();

    // load from disk
    cputs("Loading PRTY.DATA ...\r\n");
    size = cbm_load("prty.data", device, NULL);
    if (size == 0) goto flash_error1;
    
    cputs("Loading SLIST ...\r\n");
    size = cbm_load("slist", device, NULL);
    if (size == 0) goto flash_error1;
    // $7c00 is a free area to temporary save SLIST
    memcpy((void*)0x7c00, (void*)0x4a00, 0x0200);
    
    cputs("Loading LIST ...\r\n");
    size = cbm_load("list", device, NULL);
    if (size == 0) goto flash_error1;
    
    cputs("Loading ROSTER ...\r\n");
    size = cbm_load("roster", device, NULL);
    if (size == 0) goto flash_error1;
    
    // save to flash
    IO_request_disk_char_entry(0x42); // britannia disk
    
    cputs("Storing PRTY.DATA ...\r\n");
    ok = savegame_prtydata();
    if (!ok) goto flash_error2;

    cputs("Storing LIST ...\r\n");
    ok = savegame_list();
    if (!ok) goto flash_error2;

    cputs("Storing SLIST ...\r\n");
    memcpy((void*)0x4a00, (void*)0x7c00, 0x0200);
    ok = savegame_slist();
    if (!ok) goto flash_error2;

    cputs("Storing ROSTER ...\r\n");
    ok = savegame_roster();
    if (!ok) goto flash_error2;

    cputs("finished.\r\n");

flash_end:
    IO_request_disk_char_entry(0x41); // osi disk
    cputs("\r\n");
    menu_option(0x5f, "Back to menu");
    while (cgetc() != 0x5f);
    return;

flash_error1:
    cputs("Error reading from disk!\r\n");
    goto flash_end;
flash_error2:
    cputs("Error writing to flash!\r\n");
    goto flash_end;
    
}


void managesavegames(void) 
{
    static bool repaint;
    bool really;
    static uint8_t device = 8;
    cart_bankout();

    repaint = true;
    for (;;) {

        if (repaint) {
            clear_menu();
            menu_option('D', "Device #");
            cputs("\r\n");
            menu_option('B', "Backup flash to disk");
            cputs("\r\n");
            menu_option('R', "Restore flash from disk");
            cputs("\r\n");
            menu_option(0x5f, "Back to main menu");
            print_device(device);
        }
        repaint = false;

        switch (cgetc()) {
        case 'd':
            device = select_device();
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

        case 0x5f:
            return;
        }
    }
}
