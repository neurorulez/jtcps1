/*  This file is part of JTCPS1.
    JTCPS1 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCPS1 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCPS1.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 5-12-2020 */

module jtcps1_sdram #( parameter
           CPS     = 1,
           REGSIZE = 24,
           Z80_AW  = CPS==1 ? 16 : 19,
           PCM_AW  = CPS==1 ? 18 : 23
) (
    input           rst,
    input           clk,        // 96   MHz
    input           LVBL,

    input           downloading,
    output          dwnld_busy,
    output          cfg_we,

    // ROM LOAD
    input   [24:0]  ioctl_addr,
    input   [ 7:0]  ioctl_data,
    input           ioctl_wr,
    output  [21:0]  prog_addr,
    output  [15:0]  prog_data,
    output  [ 1:0]  prog_mask,
    output  [ 1:0]  prog_ba,
    output          prog_we,
    output          prog_rd,
    input           prog_rdy,
    output          prog_qsnd,

    // Kabuki decoder (CPS 1.5)
    output   [31:0] swap_key1,
    output   [31:0] swap_key2,
    output   [15:0] addr_key,
    output   [ 7:0] xor_key,

    // Main CPU
    input           main_rom_cs,
    output          main_rom_ok,
    input    [20:0] main_rom_addr,
    output   [15:0] main_rom_data,

    // VRAM
    input           vram_clr,
    input           vram_dma_cs,
    input           main_ram_cs,
    input           main_vram_cs,

    input    [ 1:0] dsn,
    input    [15:0] main_dout,
    input           main_rnw,

    output          main_ram_ok,
    output          vram_dma_ok,

    input    [16:0] main_ram_addr,
    input    [16:0] vram_dma_addr,

    output   [15:0] main_ram_data,
    output   [15:0] vram_dma_data,

    // Sound CPU and PCM
    input           snd_cs,
    input           pcm_cs,

    output          snd_ok,
    output          pcm_ok,

    input [Z80_AW-1:0] snd_addr,
    input [PCM_AW-1:0] pcm_addr,

    output    [7:0] snd_data,
    output    [7:0] pcm_data,

    // Graphics
    input           rom0_cs,
    input           rom1_cs,

    output          rom0_ok,
    output          rom1_ok,

    input    [19:0] rom0_addr,
    input    [19:0] rom1_addr,

    input           rom0_half,
    input           rom1_half,

    output   [31:0] rom0_data,
    output   [31:0] rom1_data,

    // Bank 0: allows R/W
    output   [21:0] ba0_addr,
    output          ba0_rd,
    output          ba0_wr,
    output   [15:0] ba0_din,
    output   [ 1:0] ba0_din_m,  // write mask
    input           ba0_rdy,
    input           ba0_ack,

    // Bank 1: Read only
    output   [21:0] ba1_addr,
    output          ba1_rd,
    input           ba1_rdy,
    input           ba1_ack,

    // Bank 2: Read only
    output   [21:0] ba2_addr,
    output          ba2_rd,
    input           ba2_rdy,
    input           ba2_ack,

    // Bank 3: Read only
    output   [21:0] ba3_addr,
    output          ba3_rd,
    input           ba3_rdy,
    input           ba3_ack,

    input   [31:0]  data_read,
    output    reg   refresh_en
);

localparam [21:0] PCM_OFFSET   = 22'h10_0000,
                  VRAM_OFFSET  = 22'h10_0000,
                  ZERO_OFFSET  = 22'h0;


wire [21:0] gfx0_addr, gfx1_addr;
wire [21:0] main_offset;
wire        ram_vram_cs;

assign gfx0_addr   = {rom0_addr, rom0_half, 1'b0 }; // OBJ
assign gfx1_addr   = {rom1_addr, rom1_half, 1'b0 };
assign ram_vram_cs = main_ram_cs | main_vram_cs;
assign main_offset = main_ram_cs ? ZERO_OFFSET : VRAM_OFFSET;
assign dwnld_busy  = downloading;
assign prog_rd     = 0;

always @(posedge clk)
    refresh_en <= ~LVBL;

jtcps1_prom_we #(
    .CPS       ( CPS           ),
    .REGSIZE   ( REGSIZE       ),
    .CPU_OFFSET( 22'd0         ),
    .PCM_OFFSET( PCM_OFFSET    )
) u_prom_we(
    .clk            ( clk           ),
    .downloading    ( downloading   ),
    .ioctl_addr     ( ioctl_addr    ),
    .ioctl_data     ( ioctl_data    ),
    .ioctl_wr       ( ioctl_wr      ),
    .prog_addr      ( prog_addr     ),
    .prog_data      ( prog_data     ),
    .prog_mask      ( prog_mask     ),
    .prog_bank      ( prog_ba       ),
    .prog_we        ( prog_we       ),
    .prog_rdy       ( prog_rdy      ),
    .cfg_we         ( cfg_we        ),
    // QSound & Kabuki keys
    .prom_we        ( prog_qsnd     ),
    .swap_key1      ( swap_key1     ),
    .swap_key2      ( swap_key2     ),
    .addr_key       ( addr_key      ),
    .xor_key        ( xor_key       )
);

// RAM and VRAM in bank 0
jtframe_ram_2slots #(
    .SLOT0_AW    ( 17            ), // Main CPU RAM
    .SLOT0_DW    ( 16            ),

    .SLOT1_AW    ( 17            ), // VRAM - read only access
    .SLOT1_DW    ( 16            )
) u_bank0 (
    .rst         ( rst           ),
    .clk         ( clk           ),

    .offset0     ( main_offset   ),
    .offset1     ( VRAM_OFFSET   ),

    .slot0_cs    ( ram_vram_cs   ),
    .slot0_wen   ( !main_rnw     ),
    .slot1_cs    ( vram_dma_cs   ),
    .slot1_clr   ( vram_clr      ),

    .slot0_ok    ( main_ram_ok   ),
    .slot1_ok    ( vram_dma_ok   ),

    .slot0_din   ( main_dout     ),
    .slot0_wrmask( dsn           ),

    .slot0_addr  ( main_ram_addr ),
    .slot1_addr  ( vram_dma_addr ),

    .slot0_dout  ( main_ram_data ),
    .slot1_dout  ( vram_dma_data ),

    // SDRAM interface
    .sdram_addr  ( ba0_addr      ),
    .sdram_rd    ( ba0_rd        ),
    .sdram_wr    ( ba0_wr        ),
    .sdram_ack   ( ba0_ack       ),
    .data_rdy    ( ba0_rdy       ),
    .data_write  ( ba0_din       ),
    .sdram_wrmask( ba0_din_m     ),
    .data_read   ( data_read     )
);

// Z80 code and samples in bank 1
jtframe_rom_2slots #(
    .SLOT0_AW    ( Z80_AW        ), // Sound CPU
    .SLOT0_DW    (  8            ),
    .SLOT0_OFFSET( ZERO_OFFSET   ),

    .SLOT1_AW    ( PCM_AW        ), // PCM
    .SLOT1_DW    (  8            ),
    .SLOT1_OFFSET( PCM_OFFSET    )
) u_bank1 (
    .rst         ( rst           ),
    .clk         ( clk           ),

    .slot0_cs    ( snd_cs        ),
    .slot1_cs    ( pcm_cs        ),

    .slot0_ok    ( snd_ok        ),
    .slot1_ok    ( pcm_ok        ),

    .slot0_addr  ( snd_addr      ),
    .slot1_addr  ( pcm_addr      ),

    .slot0_dout  ( snd_data      ),
    .slot1_dout  ( pcm_data      ),

    .sdram_addr  ( ba1_addr      ),
    .sdram_req   ( ba1_rd        ),
    .sdram_ack   ( ba1_ack       ),
    .data_rdy    ( ba1_rdy       ),
    .data_read   ( data_read     )
);

// GFX data in bank 2
jtframe_rom_2slots #(
    .SLOT0_AW    ( 22            ),
    .SLOT0_DW    ( 32            ),
    .SLOT0_OFFSET( ZERO_OFFSET   ),

    .SLOT1_AW    ( 22            ),
    .SLOT1_DW    ( 32            ),
    .SLOT1_OFFSET( ZERO_OFFSET   )
) u_bank2 (
    .rst         ( rst           ),
    .clk         ( clk           ),

    .slot0_cs    ( rom0_cs       ),
    .slot1_cs    ( rom1_cs       ),

    .slot0_ok    ( rom0_ok       ),
    .slot1_ok    ( rom1_ok       ),

    .slot0_addr  ( gfx0_addr     ),
    .slot1_addr  ( gfx1_addr     ),

    .slot0_dout  ( rom0_data     ),
    .slot1_dout  ( rom1_data     ),

    .sdram_addr  ( ba2_addr      ),
    .sdram_req   ( ba2_rd        ),
    .sdram_ack   ( ba2_ack       ),
    .data_rdy    ( ba2_rdy       ),
    .data_read   ( data_read     )
);

// M68000 code in bank 3
reg ba3_we;

always @(posedge clk, posedge rst ) begin
    if( rst )
        ba3_we <= 0;
    else begin
        if( ba3_ack )
            ba3_we <= 1;
        else if( ba3_rdy )
            ba3_we <= 0;
    end
end

jtframe_romrq #(.AW(21),.DW(16)) u_bank3(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .clr       ( 1'b0                   ),
    .offset    ( ZERO_OFFSET            ),
    .addr      ( main_rom_addr          ),
    .addr_ok   ( main_rom_cs            ),
    .sdram_addr( ba3_addr               ),
    .din       ( data_read              ),
    .din_ok    ( ba3_rdy                ),
    .dout      ( main_rom_data          ),
    .req       ( ba3_rd                 ),
    .data_ok   ( main_rom_ok            ),
    .we        ( ba3_we                 )
);

endmodule