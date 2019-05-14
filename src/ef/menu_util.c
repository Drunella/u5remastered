#include <stdbool.h>
#include <conio.h>
#include <stdio.h>

#include "menu_include.h"


#define MENU_START 13


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
    __asm__("lda #$07");
    __asm__("sta $01");
    __asm__("lda #$87"); // led & 16k
    __asm__("sta $DE02");
}


void cart_bankout()
{
    __asm__("lda #$06");
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
