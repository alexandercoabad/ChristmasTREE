<!---
This file is used to generate your project datasheet.
-->

## How it works

A 640x480 @ 60 Hz VGA scene (25.175 MHz pixel clock, 2 bits per colour channel) drawn purely
with combinational logic from the pixel counters - there is no frame buffer.

- **Tree**: three overlapping fir tiers with scalloped, drooping branch tips, dark skirts and
  chevron branch texture, a brown trunk, and a snowy mound.
- **Decorations**: 14 baubles that change colour about twice a second, twinkling lights, and a
  five-point star that blinks gold / amber / white.
- **Sky**: night sky with falling snow (each screen column has its own flake phase).
- **Greeting**: a red banner with a gold border showing `MERRY CHRISTMAS!` (gold) and
  `MALIGAYANG PASKO!` (white) in a hand-drawn 8x8 font scaled 2x.

All animation is driven by a frame counter that ticks once per VSYNC.

The logic is pipelined in two register stages (coordinates / tree geometry, then scene colour)
so it closes timing. The picture is therefore 2 pixels later than the sync pulses; the first
and last 2 columns are blanked.

## How to test

Connect a TinyVGA PMOD and a VGA monitor, apply a 25.175 MHz clock and release reset.
A snowy Christmas tree with the greeting banner should appear.

## External hardware

TinyVGA PMOD (https://github.com/mole99/tiny-vga) and a VGA monitor.
