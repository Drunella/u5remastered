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

#ifdef EASYFLASH
#include "../ef/menu_include.h"
#endif

#ifdef D81
#include "../d81/save_util.h"
#endif


#define NAME_STARTX 1
#define NAME_STARTY 3
#define NAME_BASE 0x00

#define STATS_STARTX 10
#define STATS_STARTY 3
#define STATS_BASE 0x20

#define CONSUME_STARTX 10
#define CONSUME_STARTY 12
#define CONSUME_BASE 0x40

#define INVENTORY_STARTX 21
#define INVENTORY_STARTY 3
#define INVENTORY_HEIGHT 16
#define INVENTORY_BASE 0x80
#define INVENTORY_ITEMS 120

#define LEGENDE_STARTY 20

#define DUNGEON_ROOM_DATA (8 + 80 + 256)


typedef struct  {
    uint8_t location;
    uint8_t gender;
    uint8_t vocation;
    uint8_t status;
    uint8_t strength; // changeable
    uint8_t dexterity; // changeable
    uint8_t intelligence; // changeable
    uint8_t current_mp;
    uint16_t current_hp;
    uint16_t maximum_hp;
    uint16_t experience; // changeable
    uint8_t level;
    uint8_t dummy;
} character_stats_t;

typedef struct {
    // 0x1000
    char names[16][8];             // 128

    // 0x1080
    character_stats_t stats[16];   // 256
    
    // 0x1180
    uint16_t food; // changeable
    uint16_t gold; // changeable
    uint8_t keys; // changeable
    uint8_t gems; // changeable
    uint8_t torches; // changeable
    uint8_t grapple; // changeable
    uint8_t carpets; // changeable
    uint8_t shadowlord_falsehood;
    uint8_t shadowlord_hatred;
    uint8_t shadowlord_cowardice;
    uint16_t ordained_shrines;
    uint16_t completed_shrines;    // 16

    // 0x1190
    uint8_t equipment[16][6];  // changeable, 96

    // 0x11f0    
    uint8_t shard_falsehood;
    uint8_t shard_hatred;
    uint8_t shard_cowardice;
    uint8_t spyglasses; // changeable
    uint8_t capeplans; // changeable
    uint8_t sextants; // changeable
    uint8_t pocketwatch;
    uint8_t skullkeys; // changeable
    uint8_t amulet;
    uint8_t crown;
    uint8_t sceptre;
    uint8_t blackbadge;
    uint8_t sandalwood;
    uint8_t dummy1[3];             // 16, (512)
    
    // 0x1200
    uint8_t armors[0x10]; // changeable, 16
    uint8_t weapons[0x1a]; // changeable
    uint8_t rings[3]; // changeable
    uint8_t amulets[3]; // changeable, 32
    uint8_t dungeons_sealed[8];
    uint8_t shrines_destroyed[8];  // 16

    // 0x1240
    uint8_t spells[0x30]; // changeable, 48
    
    // 0x1270
    uint8_t scrolls[8]; // changeable
    uint8_t potions[8]; // changeable

    // 0x1280
    uint8_t moonstone_x[8];
    uint8_t moonstone_y[8];
    uint8_t moonstone_flag[8];
    uint8_t moonstone_z[8];

    // 0x12a0
    uint8_t reagents[8];          // 56, (680)
    
    // 0x12a8
    uint8_t dungeonrooms[DUNGEON_ROOM_DATA];
    
} roster_t;

typedef struct {
    char* text;
    void* addr;
    uint8_t index;
    uint8_t type;
} inventory_t;


#pragma code-name ("EDITOR")
#pragma data-name ("DAEDITOR")
#pragma rodata-name ("ROEDITOR")


static uint8_t index_offset = 0;
static roster_t* roster;


inventory_t inventory[INVENTORY_ITEMS] = {
    { "Dagger",     (void*)0x1210, 0x80, 0x01 },
    { "Sling",      (void*)0x1211, 0x81, 0x01 }, 
    { "Club",       (void*)0x1212, 0x82, 0x01 },
    { "Flmng Oil",  (void*)0x1213, 0x83, 0x01 },
    { "Main Gauch", (void*)0x1214, 0x84, 0x01 },
    { "Spear",      (void*)0x1215, 0x85, 0x01 },
    { "Thrwng Axe", (void*)0x1216, 0x86, 0x01 },
    { "Sht. Sword", (void*)0x1217, 0x87, 0x01 },
    { "Mace",       (void*)0x1218, 0x88, 0x01 },
    { "Morn. Star", (void*)0x1219, 0x8a, 0x01 },
    { "Bow",        (void*)0x121a, 0x8b, 0x01 },
    { "Arrows",     (void*)0x121b, 0x8c, 0x01 },
    { "Crossbow",   (void*)0x121c, 0x8d, 0x01 },
    { "Quarrels",   (void*)0x121d, 0x8e, 0x01 },
    { "Long Sword", (void*)0x121e, 0x8f, 0x01 },
    { "2H Hammer",  (void*)0x121f, 0x90, 0x01 },
    { "2H Axe",     (void*)0x1220, 0x91, 0x01 },
    { "2H Sword",   (void*)0x1221, 0x92, 0x01 },
    { "Halberd",    (void*)0x1222, 0x93, 0x01 },
    { "Chaos Swrd", (void*)0x1223, 0x94, 0x01 },
    { "Magic Bow",  (void*)0x1224, 0x99, 0x01 },
    { "Silver Swd", (void*)0x1225, 0x95, 0x01 },
    { "Magic Axe",  (void*)0x1226, 0x96, 0x01 },
    { "Glass Swrd", (void*)0x1227, 0x97, 0x01 },
    { "Jewel Swrd", (void*)0x1228, 0x98, 0x01 },
    { "Myst. Swrd", (void*)0x1229, 0x9a, 0x01 },

    { "Leath Helm", (void*)0x1200, 0x9b, 0x02 },
    { "Chain Coif", (void*)0x1201, 0x9c, 0x02 },
    { "Iron Helm",  (void*)0x1202, 0x9d, 0x02 },
    { "Spkd. Helm", (void*)0x1203, 0x9e, 0x02 },
    { "Sm. Shield", (void*)0x1204, 0x9f, 0x02 },
    { "Lg. shield", (void*)0x1205, 0xa0, 0x02 },
    { "Spkd. Shld", (void*)0x1206, 0xa1, 0x02 },
    { "Shld/Magic", (void*)0x1207, 0xa2, 0x02 },
    { "Shld/Jewel", (void*)0x1208, 0xa3, 0x02 },
    { "Cloth",      (void*)0x1209, 0xa4, 0x02 },
    { "Leather",    (void*)0x120a, 0xa5, 0x02 },
    { "Ring Mail",  (void*)0x120b, 0xa6, 0x02 },
    { "Scale",      (void*)0x120c, 0xa7, 0x02 },
    { "Chain",      (void*)0x120d, 0xa8, 0x02 },
    { "Plate",      (void*)0x120e, 0xa9, 0x02 },
    { "Myst. Armr", (void*)0x120f, 0xaa, 0x02 },

    { "Inv. Ring",  (void*)0x122a, 0xab, 0x03 },
    { "Prot. Ring", (void*)0x122b, 0xac, 0x03 },
    { "Regen Ring", (void*)0x122c, 0xad, 0x03 },

    { "Am/Turning", (void*)0x122d, 0xae, 0x04 },
    { "Sp. Collar", (void*)0x122e, 0xaf, 0x04 },
    { "Ankh",       (void*)0x122f, 0xb0, 0x04 },

    { "Sulfur Ash", (void*)0x12a0, 0xb1, 0x05 },
    { "Ginseng",    (void*)0x12a1, 0xb2, 0x05 },
    { "Garlic",     (void*)0x12a2, 0xb3, 0x05 },
    { "Sp. Silk",   (void*)0x12a3, 0xb4, 0x05 },
    { "Blood Moss", (void*)0x12a4, 0xb5, 0x05 },
    { "Blk. Pearl", (void*)0x12a5, 0xb6, 0x05 },
    { "Nighshade",  (void*)0x12a6, 0xb7, 0x05 },
    { "Mandrake",   (void*)0x12a7, 0xb8, 0x05 },

    { "In Lor",     (void*)0x1240, 0xb9, 0x06 },
    { "Grav Por",   (void*)0x1241, 0xba, 0x06 },
    { "An Zu",      (void*)0x1242, 0xbb, 0x06 },
    { "An Nox",     (void*)0x1243, 0xbc, 0x06 },
    { "Mani",       (void*)0x1244, 0xbd, 0x06 },
    { "An Ylem",    (void*)0x1245, 0xbe, 0x06 },
    { "An Sanct",   (void*)0x1246, 0xbf, 0x06 },
    { "An Xen Cor", (void*)0x1247, 0xc0, 0x06 },
    { "Rel Hur",    (void*)0x1248, 0xc1, 0x06 },
    { "In Wis",     (void*)0x1249, 0xc2, 0x06 },
    { "Kal Xen",    (void*)0x124a, 0xc3, 0x06 },
    { "In Xen Man", (void*)0x124b, 0xc4, 0x06 },
    { "Vas Lor",    (void*)0x124c, 0xc5, 0x06 },
    { "Vas Flam",   (void*)0x124d, 0xc6, 0x06 },
    { "In Flam Gr", (void*)0x124e, 0xc7, 0x06 },
    { "In Nox Gr",  (void*)0x124f, 0xc8, 0x06 },
    { "In Zu Grav", (void*)0x1250, 0xc9, 0x06 },
    { "In Por",     (void*)0x1251, 0xca, 0x06 },
    { "An Grav",    (void*)0x1252, 0xcb, 0x06 },
    { "In Sanct",   (void*)0x1253, 0xcc, 0x06 },
    { "In Sanct G", (void*)0x1254, 0xcd, 0x06 },
    { "Vas Por",    (void*)0x1255, 0xce, 0x06 },
    { "Des Por",    (void*)0x1256, 0xcf, 0x06 },
    { "Wis Quas",   (void*)0x1257, 0xd0, 0x06 },
    { "In Bet Xen", (void*)0x1258, 0xd1, 0x06 },
    { "An Ex Por",  (void*)0x1259, 0xd2, 0x06 },
    { "In Ex Por",  (void*)0x125a, 0xd3, 0x06 },
    { "Vas Mani",   (void*)0x125b, 0xd4, 0x06 },
    { "In Zu",      (void*)0x125c, 0xd5, 0x06 },
    { "Rel Tym",    (void*)0x125d, 0xd6, 0x06 },
    { "In Vas P Y", (void*)0x125e, 0xd7, 0x06 },
    { "Quas An Wi", (void*)0x125f, 0xd8, 0x06 },
    { "In An",      (void*)0x1260, 0xd9, 0x06 },
    { "Wis An Yle", (void*)0x1261, 0xda, 0x06 },
    { "An Xen Ex",  (void*)0x1262, 0xdb, 0x06 },
    { "Rel Xen Be", (void*)0x1263, 0xdc, 0x06 },
    { "Sanct Lo",   (void*)0x1264, 0xdd, 0x06 },
    { "Xen Corp",   (void*)0x1265, 0xde, 0x06 },
    { "In Quas Xe", (void*)0x1266, 0xdf, 0x06 },
    { "In Quas Wi", (void*)0x1267, 0xe0, 0x06 },
    { "In Nox Hur", (void*)0x1268, 0xe1, 0x06 },
    { "In Quas Co", (void*)0x1269, 0xe2, 0x06 },
    { "In Mani Co", (void*)0x126a, 0xe3, 0x06 },
    { "Kal Xen Co", (void*)0x126b, 0xe4, 0x06 },
    { "In Vas G C", (void*)0x126c, 0xe5, 0x06 },
    { "In Flam Hu", (void*)0x126d, 0xe6, 0x06 },
    { "Vas Rel Po", (void*)0x126e, 0xe7, 0x06 },
    { "An Tym",     (void*)0x126f, 0xe8, 0x06 },

    { "Vas Lor",    (void*)0x1270, 0xe9, 0x07 }, // Vas Lor
    { "Rel Hur",    (void*)0x1271, 0xea, 0x07 }, // Rel Hur
    { "In Sanct",   (void*)0x1272, 0xeb, 0x07 }, // In Sanct
    { "In An",      (void*)0x1273, 0xec, 0x07 }, // In An
    { "In Quas Wi", (void*)0x1274, 0xed, 0x07 }, // In Quas Wis
    { "Kal Xen Co", (void*)0x1275, 0xee, 0x07 }, // Kal Xen Corp
    { "In Mani Co", (void*)0x1276, 0xef, 0x07 }, // In Mani Corp
    { "An Tym",     (void*)0x1277, 0xf0, 0x07 }, // An Tym

    { "Blue Ptn",   (void*)0x1278, 0xf1, 0x08 },
    { "Yellow Ptn", (void*)0x1279, 0xf2, 0x08 },
    { "Red Prn",    (void*)0x127a, 0xf3, 0x08 },
    { "Green Ptn",  (void*)0x127b, 0xf4, 0x08 },
    { "Orange Ptn", (void*)0x127c, 0xf5, 0x08 },
    { "Purple Ptn", (void*)0x127d, 0xf6, 0x08 },
    { "Black Ptn",  (void*)0x127e, 0xf7, 0x08 },
    { "White Ptn",  (void*)0x127f, 0xf8, 0x08 },

};


char* getsection(uint8_t c)
{
    switch(c) {
        case 0x01: return "Weap";
        case 0x02: return "Armr";
        case 0x03: return "Ring";
        case 0x04: return "Amul";
        case 0x05: return "Reag";
        case 0x06: return "Spll";
        case 0x07: return "Scrl";
        case 0x08: return "Potn";
        default: break;
    }
    return "?   ";
}


char* getvocation(uint8_t c)
{
    switch(c) {
        case 0xc1: return "Avatar ";
        case 0xc2: return "Bard   ";
        case 0xc6: return "Fighter";
        case 0xcd: return "Mage   ";
        default: break;
    }
    return "?      ";
}


#ifdef D81
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
#endif


uint16_t swap16(uint16_t value)
{
    return (value>>8) | (value<<8);
}

uint16_t str2bcd(char* t)
{
    uint8_t len;
    uint16_t value;
    
    if (t == NULL) return 0;
    len = strlen(t);
    if (len == 0) return 0;

    value = t[0] - 0x30;
    if (len >= 2) {
        value <<= 4;
        value += t[1] - 0x30;
    }
    if (len >= 3) {
        value <<= 4;
        value += t[2] - 0x30;
    }
    if (len >= 4) {
        value <<= 4;
        value += t[3] - 0x30;
    }
    
    return value;
}


void bcd8strxy(uint8_t x, uint8_t y, uint8_t value)
{
    char text[3];

    text[0] = ((value >> 4) & 0x0f) + 0x30;
    text[1] = (value & 0x0f) + 0x30;
    text[2] = 0;

    cputsxy(x, y, text);
}

void bcd16strxy(uint8_t x, uint8_t y, uint16_t value)
{
    uint8_t* code;
    char text[5];

    // in ultima 16 bit bcd are big endian
    code = (uint8_t*)&value; // high byte
    text[0] = ((*code >> 4) & 0x0f) + 0x30;
    text[1] = (*code & 0x0f) + 0x30;
    
    code = (uint8_t*)(&value) + 1; // low byte
    text[2] = ((*code >> 4) & 0x0f) + 0x30;
    text[3] = (*code & 0x0f) + 0x30;
    
    text[4] = 0;
    
    cputsxy(x, y, text);
}


bool getbcdxy(uint8_t x, uint8_t y, uint8_t len, uint16_t* original)
{
    char c;
    uint8_t n;
    bool changed = false;
    char content[16];

    textcolor(COLOR_GRAY2);
    cclearxy(0,LEGENDE_STARTY,40);
    cclearxy(0,LEGENDE_STARTY+1,40);

    //              0123456789012345678901234567890123456789
    cputsxy( 0,LEGENDE_STARTY, "( )cancel (     )accept       (   )clear");
    textcolor(COLOR_WHITE);
    cputcxy(1, LEGENDE_STARTY, 0x5f);
    cputsxy(11, LEGENDE_STARTY, "Enter");
    cputsxy(31, LEGENDE_STARTY, "CLR");

    n = 0;
    content[0] = 0;

    for (;;) {
        gotoxy(x, y);
        cclearxy(x, y, len);
        cputsxy(x, y, content);

        cursor(1);
        c = cgetc();
        cursor(0);

        if (c == CH_ENTER) {
            // enter
            if (strlen(content) > 0) {
                *original = str2bcd(content);
                changed = true;
            }
            break;

        } else if (c == CH_DEL) {
            // del
            if (n > 0) content[n-1] = 0;
            n--;

        } else if (c == CH_HOME || c == 0x93) {
            // clear
            content[0] = 0;
            n = 0;

        } else if (c == 0x5f) {
            // cancel
            break;

        } else if (c >= '0' && c <= '9') {
            if (n < len) {
                content[n] = c;
                content[n+1] = 0;
                n++;
            }
        }

    }

    textcolor(COLOR_GRAY2);
    return changed;
}


bool process_field_bcd16(uint8_t x, uint8_t y, uint16_t* data, bool selected, bool edit)
{
    bool changed = false;
    uint16_t v = *data;
    if (edit && selected) {
        changed = getbcdxy(x, y, 4, &v);
        if (changed) *data = swap16(v); // in ultima 16 bit bcd are big endian
        //gotoxy(0,24); cprintf("v=$%04x", v);
    }
    if (selected) revers(1);
    textcolor(COLOR_WHITE);
    cclearxy(x, y, 4);
    bcd16strxy(x, y, *data);
    textcolor(COLOR_GRAY2);
    revers(0);
    return changed;
}

bool process_field_bcd8(uint8_t x, uint8_t y, uint8_t* data, bool selected, bool edit)
{
    bool changed = false;
    uint16_t v = *data;
    if (edit && selected) {
        changed = getbcdxy(x, y, 2, &v);
        if (changed) *data = (uint8_t)v;
        //gotoxy(0,24); cprintf("v=$%02x  ", v);
    }
    if (selected) revers(1);
    textcolor(COLOR_WHITE);
    cclearxy(x, y, 2);
    bcd8strxy(x, y, *data);
    textcolor(COLOR_GRAY2);
    revers(0);
    return changed;
}


void draw_character_name(uint8_t x, uint8_t y, char* raw, bool selected)
{
    uint8_t i;
    char c;
    char name[9];
    
    memset(name, 32, 9); name[8] = 0;
    for (i=0; i<8; i++) {
        c = raw[i];
        if (c < 0x80) { name[i] = c - 0x20; break; }
        else if (c >= 0xe0) name[i] = c & 0x7f - 0x20;
        else if (c > 0x20) name[i] = c & 0x7f + 0x20;
    }

    if (selected) revers(1);
    cputsxy(x, y, name);
    revers(0);
}

void draw_character_names(uint8_t selected)
{
    uint8_t i;
    
    for (i=0; i<16; i++) {
        draw_character_name(NAME_STARTX, NAME_STARTY+i, roster->names[i], selected == i+1);
    }
}

bool draw_character_stats(uint8_t character, uint8_t selected, bool edit)
{   
    bool change = false; 
    character_stats_t* stats = &roster->stats[character - 1];

    draw_character_name(STATS_STARTX, STATS_STARTY, roster->names[character - 1], false);
    cputsxy(STATS_STARTX, STATS_STARTY+1, getvocation(stats->vocation));
    cputcxy(STATS_STARTX+9, STATS_STARTY+2, stats->status);
    
    change |= process_field_bcd8(STATS_STARTX+8, STATS_STARTY+3, &stats->strength, selected == 32+1, edit); // ### base
    if (selected == 32+1 && edit && stats->strength > 0x30) stats->strength = 0x30;
    change |= process_field_bcd8(STATS_STARTX+8, STATS_STARTY+4, &stats->dexterity, selected == 32+2, edit);
    if (selected == 32+2 && edit && stats->dexterity > 0x30) stats->dexterity = 0x30;
    change |= process_field_bcd8(STATS_STARTX+8, STATS_STARTY+5, &stats->intelligence, selected == 32+3, edit);
    if (selected == 32+3 && edit && stats->intelligence > 0x30) stats->intelligence = 0x30;
    change |= process_field_bcd16(STATS_STARTX+6, STATS_STARTY+6, &stats->experience, selected == 32+4, edit);
    bcd8strxy(STATS_STARTX+8, STATS_STARTY+7, stats->level);
    return change;
}

bool draw_consumables(uint8_t selected, bool edit)
{    
    bool change = false;

    change |= process_field_bcd16(CONSUME_STARTX+6, CONSUME_STARTY, &roster->food, selected == 64+1, edit); // ### base
    change |= process_field_bcd16(CONSUME_STARTX+6, CONSUME_STARTY+1, &roster->gold, selected == 64+2, edit);
    change |= process_field_bcd8(CONSUME_STARTX+8, CONSUME_STARTY+2, &roster->keys, selected == 64+3, edit);
    change |= process_field_bcd8(CONSUME_STARTX+8, CONSUME_STARTY+3, &roster->gems, selected == 64+4, edit);
    change |= process_field_bcd8(CONSUME_STARTX+8, CONSUME_STARTY+4, &roster->torches, selected == 64+5, edit);
    change |= process_field_bcd8(CONSUME_STARTX+8, CONSUME_STARTY+5, &roster->skullkeys, selected == 64+6, edit);
    bcd8strxy(CONSUME_STARTX+8, CONSUME_STARTY+6, *(uint8_t*)(0xbc28)); // karma
    
    return change;
}


bool draw_inventory(uint8_t index, bool edit)
{
    bool change;
    uint8_t i, pos, n, selected;

    change = false;
    if ((index & INVENTORY_BASE) == 0) {
        index = 0;
        index_offset = 0;
        selected = 0xff;
    } else {
        index = index & 0x7f;
        index--;
        selected = index;
    }

    // start offset
    if (index >= index_offset+INVENTORY_HEIGHT) index_offset += index - (index_offset+INVENTORY_HEIGHT) + 1;
    if (index < index_offset) {
        if (index_offset - index >= index_offset) index_offset = 0;
        else index_offset -= index_offset - index;
    }

    // draw
    for (i=0; i<INVENTORY_HEIGHT; i++) {
        if (i+index_offset < INVENTORY_ITEMS) {
            pos = i+index_offset;
            if (selected == pos) revers(1);
            gotoxy(INVENTORY_STARTX,INVENTORY_STARTY+i);
            n = cprintf("%s:", getsection(inventory[pos].type));
            n += cprintf("%s", inventory[pos].text);
            cclearxy(INVENTORY_STARTX+n, INVENTORY_STARTY+i, 16-n);
            textcolor(COLOR_WHITE);
            revers(0);
            change |= process_field_bcd8(INVENTORY_STARTX+16, INVENTORY_STARTY+i, (uint8_t*)inventory[pos].addr, selected == pos, edit);
            textcolor(COLOR_GRAY2);
        } else {
            cclearxy(INVENTORY_STARTX, INVENTORY_STARTY+i, 18);
        }
    }

    // draw pseudo scrollbar
    if (index_offset > 0) {
        cputcxy(39, INVENTORY_STARTY+1, 0xf1); 
    } else { 
        cputcxy(39, INVENTORY_STARTY+1, 0xdd);
    }
    if (index_offset+INVENTORY_HEIGHT < INVENTORY_ITEMS) {
        cputcxy(39, INVENTORY_STARTY+INVENTORY_HEIGHT-2, 0xf2); 
    } else {
        cputcxy(39, INVENTORY_STARTY+INVENTORY_HEIGHT-2, 0xdd);
    }

    return change;
}


void draw_editor_frame()
{
    textcolor(COLOR_GRAY2);

    cputsxy(0, 0, "     Ultima V: Warriors of Destiny\r\n");

    chlinexy(1, 2, 38);
    chlinexy(1, 19, 38);
    cvlinexy(0, 3, 16);
    cvlinexy(9, 3, 16);
    cvlinexy(20, 3, 16);
    cvlinexy(39, 3, 16);
    chlinexy(10, 11, 10);
    
    // corners
    cputcxy(0, 2, 0xf0);  // upper left
    cputcxy(39,2, 0xee);  // upper right
    cputcxy(0, 19,0xed);  // lower left
    cputcxy(39,19,0xfd);  // lower right

    cputsxy(STATS_STARTX, STATS_STARTY+2, "Status:");
    cputsxy(STATS_STARTX, STATS_STARTY+3, "Str:");
    cputsxy(STATS_STARTX, STATS_STARTY+4, "Dex:");
    cputsxy(STATS_STARTX, STATS_STARTY+5, "Int:");
    cputsxy(STATS_STARTX, STATS_STARTY+6, "Exp:");
    cputsxy(STATS_STARTX, STATS_STARTY+7, "Lvl:");
    
    cputsxy(CONSUME_STARTX, CONSUME_STARTY+0, "Food:");
    cputsxy(CONSUME_STARTX, CONSUME_STARTY+1, "Gold:");
    cputsxy(CONSUME_STARTX, CONSUME_STARTY+2, "Keys:");
    cputsxy(CONSUME_STARTX, CONSUME_STARTY+3, "Gems:");
    cputsxy(CONSUME_STARTX, CONSUME_STARTY+4, "Torch:");
    cputsxy(CONSUME_STARTX, CONSUME_STARTY+5, "Skull:");
    cputsxy(CONSUME_STARTX, CONSUME_STARTY+6, "Karma:");
    
}

void draw_editor_help(bool change)
{

    //              0123456789012345678901234567890123456789
#ifdef EASYFLASH
    cputsxy(0, LEGENDE_STARTY, "( )exit  (     )change    (    )navigate");
#endif

#ifdef D81
    cputsxy(0, LEGENDE_STARTY, "( )reset (     )change    (    )navigate");
#endif

    //              0123456789012345678901234567890123456789
    cputsxy(0, LEGENDE_STARTY+1, "( )eset Rooms and Other"); //               (S)ave
    if (change) cputsxy(34, LEGENDE_STARTY+1, "( )ave"); else cclearxy(34, LEGENDE_STARTY+1, 6);

    cputsxy(2, 2, "[  ]"); // F1
    cputsxy(11, 2, "[  ]");  // F3
    cputsxy(11, 11, "[  ]");  // F5
    cputsxy(22, 2, "[  ]");  // F7

    textcolor(COLOR_WHITE);
    cputsxy(2+1, 2, "F1");
    cputsxy(11+1, 2, "F3");
    cputsxy(11+1, 11, "F5");
    cputsxy(22+1, 2, "F7");
    cputcxy(1, LEGENDE_STARTY+1, 'R');
    if (change) cputsxy(35, LEGENDE_STARTY+1, "S");
    cputcxy(1, LEGENDE_STARTY, 0x5f);
    cputsxy(10, LEGENDE_STARTY, "Enter");
    cputsxy(27, LEGENDE_STARTY, "CRSR");
    textcolor(COLOR_GRAY2);
}

void draw_editor_message(char* m)
{
    cclearxy(0, 24, 40);
    if (m != NULL) cputsxy(0,24, m);
}


uint8_t next_index(uint8_t index, uint8_t step)
{
    uint8_t base;

    if (index & INVENTORY_BASE) {
        base = INVENTORY_BASE;
        index &= 0x7f;
    } else {
        base = index & 0xe0;
        index &= 0x1f;
    }

    if (base == NAME_BASE) { // character
        index += step;
        if (index > 16) index = 16;
    } else if (base == STATS_BASE) { // stats
        index += step;
        if (index > 4) index = 4;
    } else if (base == CONSUME_BASE) { // consumables
        index += step;
        if (index > 6) index = 6;
    } else if (base == INVENTORY_BASE) { // inventory
        index += step;
        if (index > INVENTORY_ITEMS) index = INVENTORY_ITEMS;
    }

    //gotoxy(0,24); cprintf("i=%02x ", index|base);
    return index | base;
}

uint8_t prev_index(uint8_t index, uint8_t step)
{
    uint8_t base;
    
    if (index & INVENTORY_BASE) {
        base = INVENTORY_BASE;
        index &= 0x7f;
    } else {
        base = index & 0xe0;
        index &= 0x1f;
    }

    if (index > step) index -= step;
    else index = 1;

    //gotoxy(0,24); cprintf("i=%02x ", index|base);
    return index | base;
}


bool load_savegame(void)
{
    bool ok;
    ok = true;

    cclearxy(0, 24, 40);

    // load from flash
#ifdef EASYFLASH
    cart_bankout();
    IO_request_disk_char_entry(0x42); // britannia disk
#endif

    //cputsxy(0, 24, "Loading PRTY.DATA");
    ok = loadgame_prtydata();
    if (!ok) goto load_error;
    
    //cputsxy(0, 24, "Loading ROSTER");
    ok = loadgame_roster();
    if (!ok) goto load_error;

load_end:
#ifdef EASYFLASH
    IO_request_disk_char_entry(0x41); // osi disk
    cart_bankout();
#endif
    return ok;
    
load_error:
    cputsxy(0,24, "Error loading savegame or not found!");
    ok = false;
    goto load_end;
    
}

bool save_savegame(void)
{
    bool ok;
    ok = true;

    cclearxy(0, 24, 40);

#ifdef EASYFLASH
    // save to flash
    cart_bankout();
    IO_request_disk_char_entry(0x42); // britannia disk
#endif

    //cputsxy(0, 24, "Saving PRTY.DATA ...\r\n");
    ok = savegame_prtydata();
    if (!ok) goto save_error;

    //cputsxy(0, 24, "Saving ROSTER ...\r\n");
    ok = savegame_roster();
    if (!ok) goto save_error;

save_end:
#ifdef EASYFLASH
    IO_request_disk_char_entry(0x41); // osi disk
    cart_bankout();
#endif
    return ok;

save_error:
    cputsxy(0,24, "Error saving savegame!");
    ok = false;
    goto save_end;

}


void savegameeditor(void)
{
    uint8_t repaint;
    bool ok, changed, edit;
    uint8_t retval, index, character;

    // init
    bgcolor(COLOR_BLACK);
    bordercolor(COLOR_BLACK);
    clrscr();
    textcolor(COLOR_GRAY2);
    repaint = 0xff;
    index = 1;
    character = 1;
    changed = false;
    edit = false;

    // show menu
    ok = load_savegame();
    roster = (roster_t*)(0x1000);
    
    draw_editor_frame();

    while (kbhit()) cgetc();

    for (;;) {
        if (repaint > 0) {
            if (ok) {
                if (repaint==0xff || (repaint&0xe0)==NAME_BASE) draw_character_names(index);
                if (repaint==0xff || (repaint&0xe0)==STATS_BASE) changed |= draw_character_stats(character, index, edit);
                if (repaint==0xff || (repaint&0xe0)==CONSUME_BASE) changed |= draw_consumables(index, edit);
                if (repaint==0xff || (repaint&INVENTORY_BASE)==INVENTORY_BASE) changed |= draw_inventory(index, edit);
            }
            draw_editor_help(changed);
            repaint = 0;
            edit = false;
        }

        retval = cgetc();
        switch (retval) {
            case 0x11: // down
                index = next_index(index, 1);
                repaint = index;
                break;
            case 0x1d: // right
                index = next_index(index, 7);
                repaint = index;
                break;
            case 0x91: // up
                index = prev_index(index, 1);
                repaint = index;
                break;
            case 0x9d: // left
                index = prev_index(index, 7);
                repaint = index;
                break;
            case 0x0d: // enter
                while (kbhit()) cgetc();
                edit = true;
                if ((index&0xe0) == NAME_BASE) {
                    character = index & 0x1f;
                    repaint = 0xff;
                } else {
                    repaint = index;
                }
                break;

            case 0x85: // F1
                index = 1;
                repaint = 0xff;
                break;

            case 0x86: // F2
                index = STATS_BASE + 1;
                repaint = 0xff;
                break;

            case 0x87: // F3
                index = CONSUME_BASE + 1;
                repaint = 0xff;
                break;

            case 0x88: // F4
                index = INVENTORY_BASE + 1;
                repaint = 0xff;
                break;

            case 'r': // reset rooms
                if (ok) {
                    cputsxy(0,23, "Untested! Use only outside of a dungeon!");
                    if (sure(0, 24)) {
                        memset(roster->dungeonrooms, 0, sizeof(roster->dungeonrooms));
                        changed = true;
                        repaint = 1;
                    } else {
                        repaint = 1;
                    }
                    cclearxy(0, 23, 40);
                }
                break;

            case 's': // save
                if (ok && changed && sure(0, 24)) {
                    draw_editor_message(NULL);
                    save_savegame();
                    changed = false;
                    repaint = 1;
                }                
                break;

            case 0x5f: // back arrow
                if (changed) {
                    if (sure(0, 24)) {
                        clrscr();
                        return;
                    }
                } else {
                    clrscr();
                    return;
                }

        }

    }
}

#ifdef D81
void main()
{
    loadsave_device(*((uint8_t*)0xba));
    savegameeditor();
    soft_reset();
}
#endif
