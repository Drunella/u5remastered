#include <stdbool.h>
#include <stdio.h>
#include <conio.h>

#include "menu_include.h"


#define DEV_X 20
#define DEV_Y 18

static void print_device(uint8_t device) 
{
    cclearxy(DEV_X, DEV_Y, 3);
    gotoxy(DEV_X, DEV_Y);
    textcolor(COLOR_WHITE);
    cprintf("%d", device); // ### crashes, stack related?
}


static uint8_t select_device(void) 
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

/*
#define SURE_X 24
#define SURE_Y 21

static bool sure(void)
{
    char c;

    textcolor(COLOR_YELLOW);
    cputsxy(SURE_X, SURE_Y, ". Sure? ");
    textcolor(COLOR_WHITE);
    cursor(1);
    c = cgetc();
    cursor(0);
    cclearxy(SURE_X, SURE_Y, 10);
    return c == 'y';
}
*/

void managesavegames(void) 
{
    static bool repaint;
    static uint8_t device = 8;

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
            // ### backup_to_disk(device);
            repaint = true;
            break;

        case 'r':
            // ### restore_from_disk(device);
            repaint = true;
            break;

        case 0x5f:
            return;
        }
    }
}
