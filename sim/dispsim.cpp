//
// VerilogBoy simulator
// Copyright 2022 Wenting Zhang
//
// dispsim.cpp: Display simulation unit
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
#include <SDL.h>
#include "dispsim.h"

// 构造函数：创建 SDL 窗口、渲染器和像素缓冲区，准备显示内容。
DISPSIM::DISPSIM(void)
{
    // 创建窗口，大小为类中设定的显示尺寸。
    window = SDL_CreateWindow("VerilogBoy Simulation",
                              SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                              dispWidth, dispHeight, SDL_SWSURFACE);

    // 如果窗口创建失败，打印错误并直接返回，避免后续空指针访问。
    if (window == NULL)
    {
        fprintf(stderr, "Unable to create window\n");
        return;
    }

    // 创建渲染器，用于把纹理绘制到窗口上，并开启垂直同步。
    renderer = SDL_CreateRenderer(window, -1,
                                  SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);

    // 渲染器创建失败时，输出错误并结束初始化。
    if (renderer == NULL)
    {
        fprintf(stderr, "Unable to create renderer\n");
        return;
    }

    // 创建一个 32-bit 的像素表面，用作离屏帧缓冲区，大小为 LCD 有效显示区域。
    screen = SDL_CreateRGBSurface(SDL_SWSURFACE, contentWidth, contentHeight, 32,
                                  0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000);

    // 纹理矩形的起点和尺寸，表示将整个内容区域作为展示区域。
    textureRect.x = textureRect.y = 0;
    textureRect.w = contentWidth;
    textureRect.h = contentHeight;

    // 创建纹理，作为渲染器真正显示的缓存对象。
    texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888,
                                SDL_TEXTUREACCESS_STREAMING, contentWidth, contentHeight);

    // 缩放时关闭抗锯齿，以保持像素风格的清晰度。
    SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "0");

    // 若帧缓冲或纹理分配失败，直接退出初始化。
    if (screen == NULL || texture == NULL)
    {
        fprintf(stderr, "Unable to allocate framebuffer or texture\n");
        return;
    }

    // 初始化坐标计数器，准备接收后续的扫描线数据。
    xCounter = 0;
    yCounter = 0;

    // 先用蓝色填充屏幕，确保初始显示不为空白。
    SDL_FillRect(screen, &textureRect, 0xFF0000FF);

    // 立即执行一次渲染，把初始缓冲内容显示出来。
    renderCopy();

    // 记录当前时间，用于控制刷新频率。
    tick = SDL_GetTicks();
}

// 析构函数：释放 SDL 申请的窗口、纹理、渲染器和表面资源。
DISPSIM::~DISPSIM(void)
{
    if (screen != NULL)
    {
        SDL_FreeSurface(screen);
    }

    if (texture)
    {
        SDL_DestroyTexture(texture);
    }

    if (renderer)
    {
        SDL_DestroyRenderer(renderer);
    }

    if (window)
    {
        SDL_DestroyWindow(window);
    }
}

// 把 LCD 时序信号和像素数据输入到模拟器中，并在需要时刷新屏幕。
void DISPSIM::apply(const unsigned char lcd_data,
                    const unsigned char lcd_hs,
                    const unsigned char lcd_vs,
                    const unsigned char lcd_enable)
{
    // hsync 上升沿
    if (!last_hs && lcd_hs)
    {
        xCounter = 0; // 回车
        yCounter++;   // 换行
    }
    // vsync 上升沿
    if (!last_vs && lcd_vs)
    {
        // 注意：水平和垂直同步可能在同一时刻发生，必须一起处理。
        yCounter = 0;
    }

    // 如果 LCD 允许输出有效像素，则根据当前列/行写入颜色。
    if (lcd_enable)
    {
        xCounter++;

        // xCounter - HBP、yCounter - VBP 用来扣除扫描前的水平/垂直空白区，
        // 从而映射到实际显示区的坐标。
        setPixel(xCounter - HBP, yCounter - VBP, colorMap(lcd_data));
    }

    // 记录当前同步电平，供下一次判断上升沿使用。
    last_vs = lcd_vs;
    last_hs = lcd_hs;

    // 如果距离上次刷新已超过设定间隔，则重新把缓冲区提交到窗口。
    if ((SDL_GetTicks() - tick) > REFRESH_INTERVAL)
    {
        renderCopy();
        tick = SDL_GetTicks();
    }
}

// 修改窗口标题。
void DISPSIM::set_title(char *title)
{
    SDL_SetWindowTitle(window, title);
}

// 把离屏缓冲区中的图像复制进纹理，并在窗口中显示出来。
void DISPSIM::renderCopy(void)
{
    void *texturePixels;
    int texturePitch;

    // 锁定纹理，准备直接写入像素数据。
    SDL_LockTexture(texture, NULL, &texturePixels, &texturePitch);

    // 先清空纹理区域，避免残留旧帧内容。
    memset(texturePixels, 0, textureRect.y * texturePitch);

    // 指向纹理像素缓存的起始位置，并把屏幕缓冲区源数据逐行复制进去。
    uint8_t *pixels = (uint8_t *)texturePixels + textureRect.y * texturePitch;
    uint8_t *src = (uint8_t *)screen->pixels;

    // 计算左右空白带的大小，保证纹理和屏幕对齐。
    int leftPitch = textureRect.x << 2;
    int rightPitch = texturePitch - ((textureRect.x + textureRect.w) << 2);

    // 逐行复制屏幕缓冲区中的像素到纹理。
    for (int y = 0; y < textureRect.h; y++, src += screen->pitch)
    {
        memset(pixels, 0, leftPitch);
        pixels += leftPitch;
        memcpy(pixels, src, contentWidth << 2);
        pixels += contentWidth << 2;
        memset(pixels, 0, rightPitch);
        pixels += rightPitch;
    }

    // 最终清理末尾残留的数据，避免越界残留。
    memset(pixels, 0, textureRect.y * texturePitch);
    SDL_UnlockTexture(texture);

    // 清空渲染目标后，将纹理拷贝到窗口，并展示当前帧。
    SDL_RenderClear(renderer);
    SDL_RenderCopy(renderer, texture, NULL, NULL);
    SDL_RenderPresent(renderer);
}

// 在离屏缓冲区中写入一个像素。x/y 超出范围时忽略，避免越界访问。
void DISPSIM::setPixel(int x, int y, unsigned long pixel)
{
    uint32_t *pixels = (uint32_t *)screen->pixels;
    if ((x < 0) || (y < 0) || (x >= contentWidth) || (y >= contentHeight))
        return;
    pixels[y * contentWidth + x] = pixel;
}

// 把输入的像素编码映射成实际的 32-bit ARGB 颜色值。
unsigned long DISPSIM::colorMap(unsigned char pixel)
{
    if (pixel == 3)
        return 0xff212f25;
    else if (pixel == 2)
        return 0xff32513a;
    else if (pixel == 1)
        return 0xff658635;
    else if (pixel == 0)
        return 0xff8b9a26;
    else
        // 如果出现未定义的像素值，则返回白色作为兜底，提醒数据异常。
        return 0xffffffff;
}