/*
 * Copyright (c) 2026 Alexander Co Abad 
 * SPDX-License-Identifier: Apache-2.0
 *
 * Merry Xmas / Maligayang Pasko - VGA Christmas tree for Tiny Tapeout.
 *
 * Scene (640x480, 2 bits per colour channel):
 *   - night sky with slowly falling snow
 *   - three-tier fir tree: scalloped branches, shaded layers, baubles,
 *     twinkling lights and a blinking five-point star
 *   - trunk planted in a snowy mound
 *   - red banner with a gold border carrying the greeting in a hand-drawn
 *     8x8 font scaled 2x (white / gold on dark red for maximum contrast)
 */

`default_nettype none

module tt_um_XmasTree_MaligayangPasko(
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered, so you can ignore it
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
);

  // ------------------------------------------------------------------
  // VGA plumbing
  // ------------------------------------------------------------------
  wire hsync;
  wire vsync;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  reg  [5:0] rgb;             // {R[1:0], G[1:0], B[1:0]}
  wire [1:0] R = video_active ? rgb[5:4] : 2'b00;
  wire [1:0] G = video_active ? rgb[3:2] : 2'b00;
  wire [1:0] B = video_active ? rgb[1:0] : 2'b00;

  // TinyVGA PMOD output mapping
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  // Unused outputs assigned to 0.
  assign uio_out = 0;
  assign uio_oe  = 0;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in, uio_in};

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );

  // ------------------------------------------------------------------
  // Frame counter (one tick per frame) drives all animation
  // ------------------------------------------------------------------
  reg       vsync_q;
  reg [8:0] frame;
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      vsync_q <= 1'b0;
      frame   <= 9'd0;
    end else begin
      vsync_q <= vsync;
      if (vsync & ~vsync_q) frame <= frame + 9'd1;
    end
  end

  // ------------------------------------------------------------------
  // Palette (2 bits per channel)
  // ------------------------------------------------------------------
  localparam [5:0] C_BLACK   = 6'b00_00_00;
  localparam [5:0] C_WHITE   = 6'b11_11_11;
  localparam [5:0] C_GOLD    = 6'b11_11_00;
  localparam [5:0] C_AMBER   = 6'b11_10_00;
  localparam [5:0] C_DKRED   = 6'b01_00_00;
  localparam [5:0] C_DKGREEN = 6'b00_01_00;
  localparam [5:0] C_GREEN   = 6'b00_10_00;
  localparam [5:0] C_LTGREEN = 6'b01_11_01;
  localparam [5:0] C_BROWN   = 6'b10_01_00;
  localparam [5:0] C_DKBROWN = 6'b01_00_00;
  localparam [5:0] C_SNOW    = 6'b11_11_11;
  localparam [5:0] C_SNOWSH  = 6'b10_10_11;

  // ------------------------------------------------------------------
  // Tree geometry
  // ------------------------------------------------------------------
  localparam [9:0] CX = 10'd320;
  wire [9:0] rel_x = (pix_x >= CX) ? (pix_x - CX) : (CX - pix_x);

  // Sawtooth along the width: makes the bottom of each tier scalloped,
  // like drooping branch tips.
  wire [3:0] saw   = rel_x[4] ? ~rel_x[3:0] : rel_x[3:0];
  wire [2:0] droop = saw[3:1];

  // Tier 1 (top)     y  52..150
  // Tier 2 (middle)  y 112..236
  // Tier 3 (bottom)  y 196..340
  // half-width = base + 0.625 * (y - top)
  wire [9:0] dy1 = pix_y - 10'd52;
  wire [9:0] dy2 = pix_y - 10'd112;
  wire [9:0] dy3 = pix_y - 10'd196;
  wire [9:0] hw1 = (dy1 >> 1) + (dy1 >> 3);
  wire [9:0] hw2 = 10'd24 + (dy2 >> 1) + (dy2 >> 3);
  wire [9:0] hw3 = 10'd52 + (dy3 >> 1) + (dy3 >> 3);

  wire in_t1 = (pix_y >= 10'd52)  && (pix_y < 10'd150 + droop) && (rel_x < hw1);
  wire in_t2 = (pix_y >= 10'd112) && (pix_y < 10'd236 + droop) && (rel_x < hw2);
  wire in_t3 = (pix_y >= 10'd196) && (pix_y < 10'd340 + droop) && (rel_x < hw3);
  wire in_tree = in_t1 | in_t2 | in_t3;

  // Upper tiers sit in front of lower ones
  wire [9:0] hw_sel = in_t1 ? hw1 : (in_t2 ? hw2 : hw3);

  // Dark band under every skirt, and a shadow cast onto the tier below it
  wire skirt  = in_t1 ? (pix_y + 10'd6 >= 10'd150 + droop) :
                in_t2 ? (pix_y + 10'd6 >= 10'd236 + droop) :
                        (pix_y + 10'd6 >= 10'd340 + droop);
  wire shadow = (~in_t1 & in_t2 & (pix_y < 10'd160 + droop)) |
                (~in_t1 & ~in_t2 & in_t3 & (pix_y < 10'd246 + droop));
  wire edge_dark = (rel_x + 10'd3 >= hw_sel);

  // Chevron-shaped branch texture, parallel to the tree's flanks
  wire [9:0] tex = pix_y - {1'b0, rel_x[9:1]};
  reg [5:0] foliage;
  always @(*) begin
    if (skirt | shadow | edge_dark) foliage = C_DKGREEN;
    else case (tex[3:2])
      2'd0: foliage = C_GREEN;
      2'd1: foliage = C_GREEN;
      2'd2: foliage = (pix_x < CX) ? C_LTGREEN : C_GREEN;
      default: foliage = C_DKGREEN;
    endcase
  end

  // ------------------------------------------------------------------
  // Twinkling lights (staggered lattice, two groups blink alternately)
  // ------------------------------------------------------------------
  wire [9:0] lx  = pix_x + (pix_y[5] ? 10'd16 : 10'd0);
  wire       lamp = (lx[4:2] == 3'd3) && (pix_y[4:2] == 3'd3) &&
                    ~(lx[1] & lx[0] & pix_y[1] & pix_y[0]) && ~(~lx[1] & ~lx[0] & ~pix_y[1] & ~pix_y[0]);
  wire [2:0] lhash = {lx[5] ^ pix_y[6], lx[6] ^ pix_y[5] ^ pix_y[7], lx[7] ^ lx[5]};
  wire       lamp_on = lamp & in_tree & (lhash[2] ^ frame[5]);
  reg [5:0] lamp_rgb;
  always @(*) begin
    case (lhash[1:0] + {1'b0, frame[4]})
      2'd0: lamp_rgb = 6'b11_00_00;  // red
      2'd1: lamp_rgb = 6'b11_11_00;  // yellow
      2'd2: lamp_rgb = 6'b00_10_11;  // cyan-blue
      default: lamp_rgb = 6'b11_01_11; // pink
    endcase
  end

  // ------------------------------------------------------------------
  // Baubles: a 12px ball at the centre of selected 32x32 cells.
  // Colours alternate every ~half second so they twinkle.
  // ------------------------------------------------------------------
  reg [2:0] ball;                        // {present, colour[1:0]}
  always @(*) begin
    case ({pix_x[9:5], pix_y[8:5]})
      {5'd9, 4'd3}: ball = {1'b1, 2'd0}; // (304,112)
      {5'd10, 4'd4}: ball = {1'b1, 2'd1}; // (336,144)
      {5'd8, 4'd5}: ball = {1'b1, 2'd2}; // (272,176)
      {5'd11, 4'd5}: ball = {1'b1, 2'd0}; // (368,176)
      {5'd10, 4'd6}: ball = {1'b1, 2'd3}; // (336,208)
      {5'd8, 4'd7}: ball = {1'b1, 2'd1}; // (272,240)
      {5'd11, 4'd7}: ball = {1'b1, 2'd2}; // (368,240)
      {5'd7, 4'd8}: ball = {1'b1, 2'd3}; // (240,272)
      {5'd9, 4'd8}: ball = {1'b1, 2'd0}; // (304,272)
      {5'd12, 4'd8}: ball = {1'b1, 2'd1}; // (400,272)
      {5'd7, 4'd9}: ball = {1'b1, 2'd0}; // (240,304)
      {5'd9, 4'd9}: ball = {1'b1, 2'd3}; // (304,304)
      {5'd12, 4'd9}: ball = {1'b1, 2'd2}; // (400,304)
      {5'd10, 4'd9}: ball = {1'b1, 2'd1}; // (336,304)
      default: ball = 3'd0;
    endcase
  end
  wire [3:0] ux = pix_x[4] ? pix_x[3:0] : ~pix_x[3:0];   // distance from cell centre
  wire [3:0] uy = pix_y[4] ? pix_y[3:0] : ~pix_y[3:0];
  reg  [2:0] bw;                         // half width of the ball on this row
  always @(*) begin
    case (uy)
      4'd0, 4'd1: bw = 3'd5;
      4'd2, 4'd3: bw = 3'd4;
      4'd4:       bw = 3'd3;
      4'd5:       bw = 3'd1;
      default:    bw = 3'd0;
    endcase
  end
  wire is_ball   = ball[2] && (uy <= 4'd5) && (ux <= {1'b0, bw});
  wire ball_hl   = ~pix_x[4] & ~pix_y[4] & (ux[3:1] == 3'd1) & (uy[3:1] == 3'd1);
  wire ball_dark = pix_x[4] & pix_y[4] & (ux[2] | uy[2]);
  wire [1:0] bcol = ball[1:0] + {1'b0, frame[5]};
  reg [5:0] ball_rgb;
  always @(*) begin
    if (ball_hl) ball_rgb = C_WHITE;
    else case (bcol)
      2'd0: ball_rgb = ball_dark ? 6'b10_00_00 : 6'b11_00_00;    // red
      2'd1: ball_rgb = ball_dark ? 6'b10_01_00 : 6'b11_10_00;    // gold
      2'd2: ball_rgb = ball_dark ? 6'b00_00_10 : 6'b01_10_11;    // blue
      default: ball_rgb = ball_dark ? 6'b10_10_10 : 6'b11_11_11; // silver
    endcase
  end

  // ------------------------------------------------------------------
  // Star (19 rows of 2px; table gives inner/outer half-width per row)
  // ------------------------------------------------------------------
  wire [9:0] sdy = pix_y - 10'd20;
  wire [4:0] srow = sdy[5:1];
  reg  [5:0] s_in, s_out;
  always @(*) begin
    s_in = 6'd0; s_out = 6'd0;
    case (srow)
      5'd0: begin s_in = 6'd0; s_out = 6'd0; end
      5'd1: begin s_in = 6'd0; s_out = 6'd1; end
      5'd2: begin s_in = 6'd0; s_out = 6'd2; end
      5'd3: begin s_in = 6'd0; s_out = 6'd3; end
      5'd4: begin s_in = 6'd0; s_out = 6'd3; end
      5'd5: begin s_in = 6'd0; s_out = 6'd4; end
      5'd6: begin s_in = 6'd0; s_out = 6'd15; end
      5'd7: begin s_in = 6'd0; s_out = 6'd16; end
      5'd8: begin s_in = 6'd0; s_out = 6'd13; end
      5'd9: begin s_in = 6'd0; s_out = 6'd11; end
      5'd10: begin s_in = 6'd0; s_out = 6'd8; end
      5'd11: begin s_in = 6'd0; s_out = 6'd8; end
      5'd12: begin s_in = 6'd0; s_out = 6'd9; end
      5'd13: begin s_in = 6'd0; s_out = 6'd9; end
      5'd14: begin s_in = 6'd3; s_out = 6'd10; end
      5'd15: begin s_in = 6'd6; s_out = 6'd10; end
      5'd16: begin s_in = 6'd9; s_out = 6'd11; end
      5'd17: begin s_in = 6'd0; s_out = 6'd0; end
      5'd18: begin s_in = 6'd0; s_out = 6'd0; end
      default: ;
    endcase
  end
  wire is_star = (pix_y >= 10'd20) && (pix_y < 10'd58) &&
                 (rel_x >= {4'b0, s_in}) && (rel_x < {4'b0, s_out});
  wire star_core = is_star && (rel_x < 10'd4) && (pix_y >= 10'd32) && (pix_y < 10'd46);
  wire [5:0] star_rgb = star_core ? (frame[4] ? C_WHITE : C_GOLD) :
                        (frame[4] ? C_GOLD : C_AMBER);

  // ------------------------------------------------------------------
  // Trunk and snowy mound
  // ------------------------------------------------------------------
  wire is_trunk = (pix_y >= 10'd330) && (rel_x < 10'd18);
  wire [5:0] trunk_rgb = (rel_x >= 10'd13) ? C_DKBROWN :
                         (((pix_x[2:0] + {2'b0, pix_y[4]}) == 3'd2) ? C_DKBROWN : C_BROWN);
  wire is_mound = (pix_y >= 10'd374 + {4'b0, rel_x[9:4]});
  wire [5:0] mound_rgb = C_SNOW;

  // ------------------------------------------------------------------
  // Falling snow (column-dependent phase, 2x2 flakes)
  // ------------------------------------------------------------------
  wire [9:0] fy = pix_y - {1'b0, frame};
  wire [8:0] sx = pix_x[9:1];
  wire [7:0] phase = {sx[0],sx[1],sx[2],sx[3],sx[4],sx[5],sx[6],sx[7]} ^ {sx[8], sx[4:2], 4'b0};
  wire is_flake = (fy[8:1] == phase) & (pix_y < 10'd380);

  // ------------------------------------------------------------------
  // Banner and text
  // ------------------------------------------------------------------
  wire in_banner  = (pix_x >= 10'd160) && (pix_x < 10'd480) && (pix_y >= 10'd390) && (pix_y < 10'd458);
  wire in_panel   = (pix_x >= 10'd162) && (pix_x < 10'd478) && (pix_y >= 10'd392) && (pix_y < 10'd456);

  wire line1 = (pix_y[9:4] == 6'd25);     // y 400..415 (MERRY CHRISTMAS!, 16 chars)
  wire line2 = (pix_y[9:4] == 6'd27);     // y 432..447
  wire [9:0] xs = line2 ? (pix_x + 10'd8) : pix_x;   // half-cell shift centres the 17-char line
  wire [5:0] ci = xs[9:4];                // character cell (16px wide)
  wire [2:0] fc = xs[3:1];                // font column (2x scaled)
  wire [2:0] fr = pix_y[3:1];             // font row    (2x scaled)

  reg [4:0] code;
  always @(*) begin
    code = 5'd0;
    if (line1) begin
      case (ci)
        6'd12: code = 5'd1; // M
        6'd13: code = 5'd2; // E
        6'd14: code = 5'd3; // R
        6'd15: code = 5'd3; // R
        6'd16: code = 5'd4; // Y
        6'd18: code = 5'd15; // C
        6'd19: code = 5'd16; // H
        6'd20: code = 5'd3; // R
        6'd21: code = 5'd8; // I
        6'd22: code = 5'd6; // S
        6'd23: code = 5'd17; // T
        6'd24: code = 5'd1; // M
        6'd25: code = 5'd5; // A
        6'd26: code = 5'd6; // S
        6'd27: code = 5'd14; // !
        default: ;
      endcase
    end else if (line2) begin
      case (ci)
        6'd12: code = 5'd1; // M
        6'd13: code = 5'd5; // A
        6'd14: code = 5'd7; // L
        6'd15: code = 5'd8; // I
        6'd16: code = 5'd9; // G
        6'd17: code = 5'd5; // A
        6'd18: code = 5'd4; // Y
        6'd19: code = 5'd5; // A
        6'd20: code = 5'd10; // N
        6'd21: code = 5'd9; // G
        6'd23: code = 5'd11; // P
        6'd24: code = 5'd5; // A
        6'd25: code = 5'd6; // S
        6'd26: code = 5'd12; // K
        6'd27: code = 5'd13; // O
        6'd28: code = 5'd14; // !
        default: ;
      endcase
    end
  end

  reg [7:0] glyph;
  always @(*) begin
    glyph = 8'h00;
    case ({code, fr})
      8'd0: glyph = 8'b00000000;
      8'd1: glyph = 8'b00000000;
      8'd2: glyph = 8'b00000000;
      8'd3: glyph = 8'b00000000;
      8'd4: glyph = 8'b00000000;
      8'd5: glyph = 8'b00000000;
      8'd6: glyph = 8'b00000000;
      8'd7: glyph = 8'b00000000;
      8'd8: glyph = 8'b10000010;
      8'd9: glyph = 8'b11000110;
      8'd10: glyph = 8'b10101010;
      8'd11: glyph = 8'b10010010;
      8'd12: glyph = 8'b10000010;
      8'd13: glyph = 8'b10000010;
      8'd14: glyph = 8'b10000010;
      8'd15: glyph = 8'b00000000;
      8'd16: glyph = 8'b11111110;
      8'd17: glyph = 8'b10000000;
      8'd18: glyph = 8'b10000000;
      8'd19: glyph = 8'b11111000;
      8'd20: glyph = 8'b10000000;
      8'd21: glyph = 8'b10000000;
      8'd22: glyph = 8'b11111110;
      8'd23: glyph = 8'b00000000;
      8'd24: glyph = 8'b11111100;
      8'd25: glyph = 8'b10000010;
      8'd26: glyph = 8'b10000010;
      8'd27: glyph = 8'b11111100;
      8'd28: glyph = 8'b10010000;
      8'd29: glyph = 8'b10001000;
      8'd30: glyph = 8'b10000100;
      8'd31: glyph = 8'b00000000;
      8'd32: glyph = 8'b10000010;
      8'd33: glyph = 8'b10000010;
      8'd34: glyph = 8'b01000100;
      8'd35: glyph = 8'b00101000;
      8'd36: glyph = 8'b00010000;
      8'd37: glyph = 8'b00010000;
      8'd38: glyph = 8'b00010000;
      8'd39: glyph = 8'b00000000;
      8'd40: glyph = 8'b00111000;
      8'd41: glyph = 8'b01000100;
      8'd42: glyph = 8'b10000010;
      8'd43: glyph = 8'b10000010;
      8'd44: glyph = 8'b11111110;
      8'd45: glyph = 8'b10000010;
      8'd46: glyph = 8'b10000010;
      8'd47: glyph = 8'b00000000;
      8'd48: glyph = 8'b01111100;
      8'd49: glyph = 8'b10000010;
      8'd50: glyph = 8'b10000000;
      8'd51: glyph = 8'b01111100;
      8'd52: glyph = 8'b00000010;
      8'd53: glyph = 8'b10000010;
      8'd54: glyph = 8'b01111100;
      8'd55: glyph = 8'b00000000;
      8'd56: glyph = 8'b10000000;
      8'd57: glyph = 8'b10000000;
      8'd58: glyph = 8'b10000000;
      8'd59: glyph = 8'b10000000;
      8'd60: glyph = 8'b10000000;
      8'd61: glyph = 8'b10000000;
      8'd62: glyph = 8'b11111110;
      8'd63: glyph = 8'b00000000;
      8'd64: glyph = 8'b01111100;
      8'd65: glyph = 8'b00010000;
      8'd66: glyph = 8'b00010000;
      8'd67: glyph = 8'b00010000;
      8'd68: glyph = 8'b00010000;
      8'd69: glyph = 8'b00010000;
      8'd70: glyph = 8'b01111100;
      8'd71: glyph = 8'b00000000;
      8'd72: glyph = 8'b01111100;
      8'd73: glyph = 8'b10000010;
      8'd74: glyph = 8'b10000000;
      8'd75: glyph = 8'b10011110;
      8'd76: glyph = 8'b10000010;
      8'd77: glyph = 8'b10000010;
      8'd78: glyph = 8'b01111100;
      8'd79: glyph = 8'b00000000;
      8'd80: glyph = 8'b10000010;
      8'd81: glyph = 8'b11000010;
      8'd82: glyph = 8'b10100010;
      8'd83: glyph = 8'b10010010;
      8'd84: glyph = 8'b10001010;
      8'd85: glyph = 8'b10000110;
      8'd86: glyph = 8'b10000010;
      8'd87: glyph = 8'b00000000;
      8'd88: glyph = 8'b11111100;
      8'd89: glyph = 8'b10000010;
      8'd90: glyph = 8'b10000010;
      8'd91: glyph = 8'b11111100;
      8'd92: glyph = 8'b10000000;
      8'd93: glyph = 8'b10000000;
      8'd94: glyph = 8'b10000000;
      8'd95: glyph = 8'b00000000;
      8'd96: glyph = 8'b10000100;
      8'd97: glyph = 8'b10001000;
      8'd98: glyph = 8'b10010000;
      8'd99: glyph = 8'b11100000;
      8'd100: glyph = 8'b10010000;
      8'd101: glyph = 8'b10001000;
      8'd102: glyph = 8'b10000100;
      8'd103: glyph = 8'b00000000;
      8'd104: glyph = 8'b01111100;
      8'd105: glyph = 8'b10000010;
      8'd106: glyph = 8'b10000010;
      8'd107: glyph = 8'b10000010;
      8'd108: glyph = 8'b10000010;
      8'd109: glyph = 8'b10000010;
      8'd110: glyph = 8'b01111100;
      8'd111: glyph = 8'b00000000;
      8'd112: glyph = 8'b00010000;
      8'd113: glyph = 8'b00010000;
      8'd114: glyph = 8'b00010000;
      8'd115: glyph = 8'b00010000;
      8'd116: glyph = 8'b00010000;
      8'd117: glyph = 8'b00000000;
      8'd118: glyph = 8'b00010000;
      8'd119: glyph = 8'b00000000;
      8'd120: glyph = 8'b01111100;
      8'd121: glyph = 8'b10000010;
      8'd122: glyph = 8'b10000000;
      8'd123: glyph = 8'b10000000;
      8'd124: glyph = 8'b10000000;
      8'd125: glyph = 8'b10000010;
      8'd126: glyph = 8'b01111100;
      8'd127: glyph = 8'b00000000;
      8'd128: glyph = 8'b10000010;
      8'd129: glyph = 8'b10000010;
      8'd130: glyph = 8'b10000010;
      8'd131: glyph = 8'b11111110;
      8'd132: glyph = 8'b10000010;
      8'd133: glyph = 8'b10000010;
      8'd134: glyph = 8'b10000010;
      8'd135: glyph = 8'b00000000;
      8'd136: glyph = 8'b11111110;
      8'd137: glyph = 8'b00010000;
      8'd138: glyph = 8'b00010000;
      8'd139: glyph = 8'b00010000;
      8'd140: glyph = 8'b00010000;
      8'd141: glyph = 8'b00010000;
      8'd142: glyph = 8'b00010000;
      8'd143: glyph = 8'b00000000;
      default: glyph = 8'h00;
    endcase
  end
  wire font_bit = (line1 | line2) & in_panel & glyph[3'd7 - fc];

  // ------------------------------------------------------------------
  // Compose
  // ------------------------------------------------------------------
  always @(*) begin
    // sky: deep blue, warming to steel blue near the horizon (dithered band)
    rgb = (pix_y < 10'd300) ? 6'b00_00_01 :
          (pix_y < 10'd330) ? ((pix_x[0] ^ pix_y[0]) ? 6'b00_00_10 : 6'b00_00_01) : 6'b00_00_10;
    if (is_flake)                         rgb = C_WHITE;
    if (is_mound)                         rgb = mound_rgb;
    if (is_trunk && ~is_mound)            rgb = trunk_rgb;
    if (in_tree)                          rgb = foliage;
    if (lamp_on)                          rgb = lamp_rgb;
    if (is_ball & in_tree)                rgb = ball_rgb;
    if (is_star)                          rgb = star_rgb;
    if (in_banner)                        rgb = C_GOLD;
    if (in_panel)                         rgb = C_DKRED;
    if (font_bit)                         rgb = line1 ? C_GOLD : C_WHITE;
  end

endmodule


