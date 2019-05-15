#include <stdbool.h>
#include <conio.h>
// #include <peekpoke.h>

#include "menu_include.h"


static void draw_game_info(void) {
    clrscr();
    cputs("\r\n");
    textcolor(COLOR_GRAY2);
    cputs("     Ultima V: Warriors of Destiny\r\n"
          "\r\n"
          "        Designed by Lord British\r\n"
          "\r\n");
    //textcolor(COLOR_GRAY1);
    cputs("   Commodore 64 conversion by Dr. Cat\r\n"
          "  Music composed by  Kenneth W. Arnold\r\n"
          "     EasyFlash version by Drunella\r\n"
          "\r\n"
          " Copyright (c) 1988 Origin Systems Inc."
          "\r\n");
}


void main(void)
{
    static bool repaint;
    
    //  initialize_basic files: eapi, exocrunch for later
    load_basicfiles();
    
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
            menu_option('Q', "Quit to basic");
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