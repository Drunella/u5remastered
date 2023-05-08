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
#include <conio.h>

#include "menu_include.h"


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
          "     EasyFlash version by Drunella\r\n"
          "\r\n");
}


void main(void)
{
    static bool repaint;
    
    //  initialize_basic files: eapi, exocrunch for later
    load_basicfiles();
    
restart:
    repaint = true;
    bgcolor(COLOR_BLACK);
    bordercolor(COLOR_BLACK);
    draw_game_info();
    
    while (kbhit()) {
        cgetc();
    }
    
    for (;;) {
        
        if (repaint) {
            clear_menu();
            menu_option('G', "Start game");
            cputs("\r\n");
            menu_option('J', "Journey Onward");
            cputs("\r\n");
            menu_option('S', "Manage savegames");
            cputs("\r\n");
            menu_option('E', "Savegame editor");
            cputs("\r\n");
            menu_option('Q', "Quit to basic");
            draw_version();
        }
        
        repaint = false;
        
        switch (cgetc()) {
        case ' ':
        case 'g':
            clear_menu();
            startupgame(0); // does not return
            return;
        
        case 'j':
            clear_menu();
            startupgame(1); // does not return
            break;

        case 's':
            repaint = true;
            managesavegames();
            break;

        case 'e':
            repaint = true;
            savegameeditor();
            goto restart;
            break;
        
        case 'q':
            cart_kill();
            __asm__("lda #$37");
            __asm__("sta $01");
            __asm__("ldx #$ff");
            __asm__("txs");
            __asm__("jmp $fcfb");
            break;
        }
    }
}