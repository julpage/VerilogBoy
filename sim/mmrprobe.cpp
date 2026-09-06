//
// VerilogBoy simulator
// Copyright 2022 Wenting Zhang
//
// mmrprobe.cpp: A probe that prints out MMR access logs
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <assert.h>
#include "mmrprobe.h"

#include "Vboy___024root.h"
#include "Vboy.h"
extern Vboy *core;

MMRPROBE::MMRPROBE()
{
    last_addr = 0;
    last_wr = 0;
    last_rd = 0;
    last_data = 0;
    last_data_rd = 0;
    last_rd_addr = 0;
    have_last_rd = 0;
    rd_dirty = 0;
}

MMRPROBE::~MMRPROBE(void)
{
}

const char *regNames(uint16_t regAddr)
{
    switch (regAddr)
    {
    case 0xFF00:
        return "P1/JOYP";
    case 0xFF01:
        return "SB";
    case 0xFF02:
        return "SC";
    case 0xFF04:
        return "DIV";
    case 0xFF05:
        return "TIMA";
    case 0xFF06:
        return "TMA";
    case 0xFF07:
        return "TAC";
    case 0xFF0F:
        return "IF";
    case 0xFF10:
        return "NR10";
    case 0xFF11:
        return "NR11";
    case 0xFF12:
        return "NR12";
    case 0xFF13:
        return "NR13";
    case 0xFF14:
        return "NR14";
    case 0xFF16:
        return "NR21";
    case 0xFF17:
        return "NR22";
    case 0xFF18:
        return "NR23";
    case 0xFF19:
        return "NR24";
    case 0xFF1A:
        return "NR30";
    case 0xFF1B:
        return "NR31";
    case 0xFF1C:
        return "NR32";
    case 0xFF1D:
        return "NR33";
    case 0xFF1E:
        return "NR34";
    case 0xFF20:
        return "NR41";
    case 0xFF21:
        return "NR42";
    case 0xFF22:
        return "NR43";
    case 0xFF23:
        return "NR44";
    case 0xFF24:
        return "NR50";
    case 0xFF25:
        return "NR51";
    case 0xFF26:
        return "NR52";
    case 0xFF30:
    case 0xFF31:
    case 0xFF32:
    case 0xFF33:
    case 0xFF34:
    case 0xFF35:
    case 0xFF36:
    case 0xFF37:
    case 0xFF38:
    case 0xFF39:
    case 0xFF3A:
    case 0xFF3B:
    case 0xFF3C:
    case 0xFF3D:
    case 0xFF3E:
    case 0xFF3F:
        return "Wave RAM";
    case 0xFF40:
        return "LCDC";
    case 0xFF41:
        return "STAT";
    case 0xFF42:
        return "SCY";
    case 0xFF43:
        return "SCX";
    case 0xFF44:
        return "LY";
    case 0xFF45:
        return "LYC";
    case 0xFF46:
        return "DMA";
    case 0xFF47:
        return "BGP";
    case 0xFF48:
        return "OBP0";
    case 0xFF49:
        return "OBP1";
    case 0xFF4A:
        return "WY";
    case 0xFF4B:
        return "WX";
    case 0xFF4C:
        return "KEY0/SYS";
    case 0xFF4D:
        return "KEY1/SPD";
    case 0xFF4F:
        return "VBK";
    case 0xFF50:
        return "BANK";
    case 0xFF51:
        return "HDMA1";
    case 0xFF52:
        return "HDMA2";
    case 0xFF53:
        return "HDMA3";
    case 0xFF54:
        return "HDMA4";
    case 0xFF55:
        return "HDMA5";
    case 0xFF56:
        return "RP";
    case 0xFF68:
        return "BCPS/BGPI";
    case 0xFF69:
        return "BCPD/BGPD";
    case 0xFF6A:
        return "OCPS/OBPI";
    case 0xFF6B:
        return "OCPD/OBPD";
    case 0xFF6C:
        return "OPRI";
    case 0xFF70:
        return "SVBK/WBK";
    case 0xFF76:
        return "PCM12";
    case 0xFF77:
        return "PCM34";
    case 0xFFFF:
        return "IE";
    default:
        static char str[30];
        snprintf(str, sizeof(str), "%04x", regAddr);
        return str;
    }
}

void printAPU(uint16_t regAddr)
{
    if ((0xff10 <= regAddr) && (regAddr <= 0xff14))
    {
        printf("\tch1 left: %d\tactive: %d\tclk256LV: %d\n",
               core->rootp->boy__DOT__u_sound__DOT__u_channel1__DOT__u_length__DOT__length_left,
               core->rootp->boy__DOT__u_sound__DOT__u_channel1__DOT__active_length,
               core->rootp->boy__DOT__u_sound__DOT__apu_div & 1);
    }
    if ((0xff15 <= regAddr) && (regAddr <= 0xff19))
    {
        printf("\tch2 left: %d\tactive: %d\tclk256LV: %d\n",
               core->rootp->boy__DOT__u_sound__DOT__u_channel2__DOT__u_length__DOT__length_left,
               core->rootp->boy__DOT__u_sound__DOT__u_channel2__DOT__active_length,
               core->rootp->boy__DOT__u_sound__DOT__apu_div & 1);
    }
    if ((0xff1a <= regAddr) && (regAddr <= 0xff1e))
    {
        printf("\tch3 left: %d\tactive: %d\tclk256LV: %d\n",
               core->rootp->boy__DOT__u_sound__DOT__u_channel3__DOT__u_length__DOT__length_left,
               core->rootp->boy__DOT__u_sound__DOT__u_channel3__DOT__active_length,
               core->rootp->boy__DOT__u_sound__DOT__apu_div & 1);
    }
    if ((0xff1f <= regAddr) && (regAddr <= 0xff23))
    {
        printf("\tch4 left: %d\tactive: %d\tclk256LV: %d\n",
               core->rootp->boy__DOT__u_sound__DOT__u_channel4__DOT__u_length__DOT__length_left,
               core->rootp->boy__DOT__u_sound__DOT__u_channel4__DOT__active_length,
               core->rootp->boy__DOT__u_sound__DOT__apu_div & 1);
    }
}

void MMRPROBE::apply(uint8_t wr_data, uint16_t address,
                     uint8_t wr_enable, uint8_t rd_enable, uint8_t rd_data, uint16_t pc, uint64_t timeStamp)
{

    if (address < 0xff10 || 0xff3f < address)
        return;

    static uint64_t lastTimeStamp = 0;
    static uint16_t lastAddr = 0;
    static uint8_t lastRdData = 0;
    static bool lastIsRd = false;

    timeStamp /= 4;

    // Ignore ROM and HRAM RW
    if (last_wr && !wr_enable)
    {
        if ((address >= 0x8000) && (address <= 0xff7f))
        {
            printf("PC %04x: W_[%s] = %02x    %lu +%lu\n",
                   pc,
                   regNames(address),
                   wr_data,
                   timeStamp,
                   timeStamp - lastTimeStamp);
            // printf("%ld  %ld\n", timeStamp, lastTimeStamp);
            lastIsRd = false;
            lastTimeStamp = timeStamp;

            printAPU(address);
        }
    }
    else if (last_rd && !rd_enable)
    {
        if (lastIsRd && (address == lastAddr) && (lastRdData == rd_data))
            return;
        if ((address >= 0x8000) && (address <= 0xff7f) && (address != 0xff44))
        {
            printf("PC %04x: RD[%s] = %02x    %lu +%lu\n",
                   pc,
                   regNames(address),
                   rd_data,
                   timeStamp,
                   timeStamp - lastTimeStamp);

            lastIsRd = true;
            lastAddr = address;
            lastRdData = rd_data;
            lastTimeStamp = timeStamp;

            printAPU(address);
        }
    }
    last_rd = rd_enable;
    last_wr = wr_enable;
    last_data = wr_data;
}
