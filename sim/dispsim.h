//
// VerilogBoy simulator
// Copyright 2022 Wenting Zhang
//
// dispsim.h: Display simulation unit
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
#pragma once

// 这个类负责把 Game Boy 的 LCD 时序信号转换成一个可视化窗口，
// 并在 SDL 窗口中实时显示像素内容。
class DISPSIM {
public:
    // 实际有效显示内容区域：Game Boy LCD 160x144 像素。
    const int contentWidth = 160;
    const int contentHeight = 144;

    // 窗口显示大小，通常比内容区更大，方便调整比例和空白边框。
    const int dispWidth = 320;
    const int dispHeight = 288;

    // 构造/析构和核心方法。
    DISPSIM(void);
    ~DISPSIM(void);

    // 每帧接收一个像素数据以及同步信号，用于更新显示缓冲区。
    void apply(const unsigned char lcd_data,
               const unsigned char lcd_hs,
               const unsigned char lcd_vs,
               const unsigned char lcd_enable);

    // 设置窗口标题。
    void set_title(char *title);

private:
    // 水平/垂直同步前沿后需要扣掉边框空白区，以对齐到有效像素区域。
    static constexpr int HBP = 1;
    static constexpr int VBP = 2;

    // 多少毫秒触发一次渲染刷新，降低 CPU 占用并保持流畅显示。
    static constexpr int REFRESH_INTERVAL = 17;

    // SDL 相关对象：屏幕缓冲区、窗口、渲染器、纹理。
    SDL_Surface  *screen = NULL;
    SDL_Window   *window = NULL;
    SDL_Renderer *renderer = NULL;
    SDL_Texture  *texture = NULL;
    SDL_Rect textureRect;

    // 记录上一帧的同步状态，用于检测上升沿。
    unsigned char last_vs;
    unsigned char last_hs;

    // 当前正在写入的 X/Y 坐标计数器，用于把时序信号映射到屏幕坐标。
    int xCounter;
    int yCounter;

    // 用于控制刷新间隔的时间戳。
    int tick;

    // 将屏幕缓冲区复制到 SDL 纹理并呈现。
    void renderCopy(void);

    // 在指定位置写一个像素。
    void setPixel(int x, int y, unsigned long pixel);

    // 把 2-bit 或 4-bit 像素编码映射为实际颜色值。
    unsigned long colorMap(unsigned char pixel);
};
