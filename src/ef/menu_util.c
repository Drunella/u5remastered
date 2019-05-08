#include <stdbool.h>
#include <conio.h>

#include "menu_include.h"


void clear_menu(void)
{
    uint8_t y;

    for (y = 14; y < 25; ++y) {
        cclearxy(0, y, 40);
    }
    gotoxy(0, 18);
}


void menu_option(char key, char *desc)
{
    //textcolor(COLOR_GRAY2);
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
    __asm__("lda #4");
    __asm__("sta $de02");
}
