//
// VerilogBoy simulator
// Copyright 2022 Wenting Zhang
//
// audiosim.cpp: Capture PDM output and pass through a filter then save to wave
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
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <assert.h>
#include <vector>
#include "audiosim.h"
#include "waveheader.h"

AUDIOSIM::AUDIOSIM(void) {
    sample_counter = 0;
    buffer.clear();
}

AUDIOSIM::~AUDIOSIM(void) {

}

void AUDIOSIM::save(const char *fname) {
    // Always delete any existing WAV so a fresh file is produced
    remove(fname);
    if (buffer.empty())
        return;
    FILE *fp = fopen(fname, "wb+");
    assert(fp);
    uint8_t header[44];
    waveheader(header, 48000, 16, buffer.size() / 2);
    fwrite(header, 44, 1, fp);
    fwrite(&buffer[0], sizeof(int16_t), buffer.size(), fp);
    fclose(fp);
    printf("Audio save to %s\n", fname);
}

void AUDIOSIM::apply(uint16_t left, uint16_t right) {
    sample_counter++;
    if (sample_counter == DECIMATION_M) {
        sample_counter = 0;
        // Hardware output is 16-bit unsigned (0 = silence, up to 0x7FFF),
        // which maps directly onto signed 16-bit PCM as a positive sample.
        buffer.push_back((int16_t)left);
        buffer.push_back((int16_t)right);
    }
}
