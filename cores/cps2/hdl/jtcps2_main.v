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
    Date: 18-1-2021 */

module jtcps2_main(
    input              rst,
    input              clk,
    input              cen16,
    input              cen16b,
    output             cpu_cen,
    // Timing
    input   [8:0]      V,
    input              LVBL,
    input              LHBL,
    // PPU
    output reg         ppu1_cs,
    output reg         ppu2_cs,
    output reg         ppu_rstn,
    input   [15:0]     mmr_dout,
    // Sound
    output             UDSWn,
    output             LDSWn,
    // cabinet I/O
    input   [9:0]      joystick1,
    input   [9:0]      joystick2,
    input   [9:0]      joystick3,
    input   [9:0]      joystick4,
    input   [3:0]      start_button,
    input   [3:0]      coin_input,
    input              service,
    input              tilt,
    // BUS sharing
    input              busreq,
    output             busack,
    output             RnW,
    // For RAM/ROM:
    output      [17:1] addr,
    output      [15:0] cpu_dout,
    // RAM access
    output             ram_cs,
    output             vram_cs,
    input       [15:0] ram_data,
    input              ram_ok,
    // ROM access
    output reg         rom_cs,
    output reg  [21:1] rom_addr,
    input       [15:0] rom_data,
    input              rom_ok,
    // DIP switches
    input              dip_test,
    input              dip_pause,
    // QSound
    output reg         eeprom_sclk,
    output reg         eeprom_sdi,
    input              eeprom_sdo,
    output reg         eeprom_scs,
    input       [ 7:0] main2qs_din,
    output reg  [23:1] main2qs_addr,
    output reg         main2qs_cs,
    input              main2qs_busakn,
    input              main2qs_waitn
);

wire [23:1] A;
wire        BERRn = 1'b1;

reg  [15:0] in0, in1, in2;

`ifdef SIMULATION
wire [24:0] A_full = {A,1'b0};
`endif

(*keep*) wire        BRn, BGACKn, BGn;
(*keep*) wire        ASn;
reg         io_cs, joy_cs, eeprom_cs,
            sys_cs, olatch_cs, dial_cs;
reg         pre_ram_cs, pre_vram_cs, reg_ram_cs, reg_vram_cs;
reg         dsn_dly;
reg         one_wait;
`ifdef CPS15
reg         io15_cs, joy3_cs, joy4_cs;
`endif

assign cpu_cen   = cen16;
// As RAM and VRAM share contiguous spaces in the SDRAM
// it is important to prevent overlapping
assign addr      = ram_cs ? {2'b0, A[15:1] } : A[17:1];

// high during DMA transfer
wire UDSn, LDSn;
assign UDSWn = RnW | UDSn;
assign LDSWn = RnW | LDSn;

// ram_cs and vram_cs signals go down before DSWn signals
// that causes a false read request to the SDRAM. In order
// to avoid that a little bit of logic is needed:
assign ram_cs  = dsn_dly ? reg_ram_cs  : pre_ram_cs;
assign vram_cs = dsn_dly ? reg_vram_cs : pre_vram_cs;

always @(posedge clk) begin
    if( rst ) begin
        reg_ram_cs  <= 0;
        reg_vram_cs <= 0;
        dsn_dly     <= 1;
    end else if(cen16) begin
        reg_ram_cs  <= pre_ram_cs;
        reg_vram_cs <= pre_vram_cs;
        dsn_dly     <= &{UDSWn,LDSWn}; // low if any DSWn was low
    end
end

// PAL BUF1 16H
// buf0 = A[23:16]==1001_0000 = 8'h90
// buf1 = A[23:16]==1001_0001 = 8'h91
// buf2 = A[23:16]==1001_0010 = 8'h92

(*keep*) reg [23:0] last_fail;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        rom_cs      <= 1'b0;
        pre_ram_cs  <= 1'b0;
        pre_vram_cs <= 1'b0;
        // dbus_cs     <= 1'b0;
        io_cs       <= 1'b0;
        sys_cs      <= 1'b0;
        one_wait    <= 1'b0;
        rom_addr    <= 21'd0;
        main2qs_cs   <= 0;
        main2qs_addr <= 23'd0;
    end else begin
        if( !ASn && BGACKn ) begin // PAL PRG1 12H
            rom_addr    <= A[21:1];
            rom_cs      <= A[23:22] == 2'b00;
            one_wait    <= A[23] | ~A[22]; // valid for CPS2?
            // dbus_cs     <= ~|A[23:18]; // all must be zero
            pre_vram_cs <= A[23:18] == 6'b1001_00 && A[17:16]!=2'b11;
            io_cs       <= A[23:19] == 5'b1000_0;
            pre_ram_cs  <= &A[23:16];
            // QSound
            //io15_cs      <= A[23:12] == 12'hf1C;
            main2qs_cs   <= A[23:20] == 4'h6  && A[19:17]==3'd0; // 60'0000-61'FFFF
            main2qs_addr <= A;
        end else begin
            rom_addr[4:1] <= last_fail[3:0]; // this is a trick so the compiler
                // won't get rid of last_fail, as I need to see it in signal tap
            rom_cs      <= 1'b0;
            pre_ram_cs  <= 1'b0;
            pre_vram_cs <= 1'b0;
            // dbus_cs     <= 1'b0;
            sys_cs      <= 1'b0;
            olatch_cs   <= 1'b0;
            one_wait    <= 1'b0;
            dial_cs     <= 1'b0;
        end
    end
end

// I/O
always @(*) begin
    ppu1_cs   = io_cs && A[8:6] == 3'b100; // CPS-A
    ppu2_cs   = io_cs && A[8:6] == 3'b101; // CPS-B
    in0_cs    = io_cs && A[8:3] == 6'h0;
    in1_cs    = io_cs && A[8:3] == 6'h1;
    in2_cs    = io_cs && A[8:3] == 6'h2;
    vol_cs    = io_cs && A[8:3] == 6'b000_110 && !RnW; // QSound volume
    // coin_cs  = io_cs && A[8:3] == 6'b001_000 && !RnW;
    eeprom_cs = io_cs && A[8:3] == 6'b001_000 && !RnW && !UDSWn;
end

// special registers
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ppu_rstn   <= 1'b0;
    end
    else if(cpu_cen) begin
        if( olatch_cs ) begin
            // coin counters and lockers should go in here too
            ppu_rstn <= ~cpu_dout[15];
        end
    end
end

// EEPROM control in CPS 1.5 games
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        eeprom_scs  <= 0;
        eeprom_sclk <= 0;
        eeprom_sdi  <= 0;
    end
    else if(cpu_cen) begin
        if( eeprom_cs && !LDSWn ) begin
            eeprom_scs  <= cpu_dout[7];
            eeprom_sclk <= cpu_dout[6];
            eeprom_sdi  <= cpu_dout[0];
        end
    end
end

// incremental encoder counter
wire [7:0] dial_dout;
`ifndef CPS15
wire       dial_rst  = dial_cs && !RnW && ~A[4];
wire       xn_y      = A[3];
wire       x_rst     = dial_rst & ~xn_y;
wire       y_rst     = dial_rst &  xn_y;
wire [1:0] x_in, y_in;
reg  [1:0] dial_pulse, last_LHBL;

// The dial update ryhtm is set to once every four lines
always @(posedge clk) begin
    last_LHBL <= LHBL;
    if( LHBL && !last_LHBL ) dial_pulse <= dial_pulse+2'd1;
end

jt4701 u_dial(
    .clk        ( clk       ),
    .rst        ( rst       ),
    .x_in       ( x_in      ),
    .y_in       ( y_in      ),
    .rightn     ( 1'b1      ),
    .leftn      ( 1'b1      ),
    .middlen    ( 1'b1      ),
    .x_rst      ( x_rst     ),
    .y_rst      ( y_rst     ),
    .csn        ( ~dial_cs  ),        // chip select
    .uln        ( ~A[1]     ),        // byte selection
    .xn_y       ( xn_y      ),        // select x or y for reading
    .cfn        (           ),        // counter flag
    .sfn        (           ),        // switch flag
    .dout       ( dial_dout )
);

jt4701_dialemu u_dial1p(
    .clk        ( clk           ),
    .rst        ( rst           ),
    .pulse      ( dial_pulse[1] ),
    .inc        ( ~joystick1[5] ),
    .dec        ( ~joystick1[6] ),
    .dial       ( x_in          )
);

jt4701_dialemu u_dial2p(
    .clk        ( clk           ),
    .rst        ( rst           ),
    .pulse      ( dial_pulse[1] ),
    .inc        ( ~joystick2[5] ),
    .dec        ( ~joystick2[6] ),
    .dial       ( y_in          )
);
`else
assign dial_dout = 8'd0;
`endif

always @(posedge clk) begin
    // This still doesn't cover all cases
    case( joymode )
        default: begin
            in0 <= { joystick2[7:0], joystick1[7:0] };
            in1 <= { joystick4[7:0], joystick3[7:0] };
            in2 <= { coin_input, start_button, 2'b11, ~dip_test, eeprom_sdi };
        end
        BUT6: begin
            in0 <= { joystick2[7:0], joystick1[7:0] };
            in1 <= { 10'h3FF, joystick2[8:6], 1'b1, joystick1[9:6] };
            in2 <= { 1'b1, joystick2[9],
                coin_input[1:0], start_button, 2'b11, ~dip_test, eeprom_sdi };
        end
        BUTX: begin // buttons only
            in0 <= { 4'hf, joystick2[7:4], 4'hf, joystick1[7:4] };
            in1 <= { joystick4[7:0], joystick3[7:0] };
            in2 <= { coin_input, start_button, 2'b11, ~dip_test, eeprom_sdi };
        end
    endcase
end

reg [15:0] sys_data;

always @(posedge clk) begin
    if( joy_cs ) sys_data <= { joystick2[7:0], joystick1[7:0] };
    `ifdef CPS15
    else if( joy3_cs )
        sys_data <= { 2{start_button[2], coin_input[2], joystick3[5:0] }};
    else if( joy4_cs )
        sys_data <= { 2{start_button[3], coin_input[3], joystick4[5:0] }};
    `endif
    else if(sys_cs) begin
        case( A[2:1] )
            2'b00: sys_data <=
            charger ? // Support for SFZ charger version
              { joystick2[9], joystick1[9], start_button[1:0],
               &coin_input[1:0], service, joystick2[8], joystick1[8], 8'hff } :
            // Regular CPS1 arcade:
            { tilt,
                `ifdef CPS15
                dip_test /* alternative test dip */,
                `else
                1'b1,
                `endif
                start_button[1:0],
                1'b1, service, coin_input[1:0], 8'hff };
            2'b01: sys_data <= { dipsw_a, 8'hff };
            2'b10: sys_data <= { dipsw_b, 8'hff };
            2'b11: sys_data <= { dipsw_c, 8'hff };
        endcase
    end
    else if( dial_cs && A[4] && RnW ) begin
            sys_data <= { 8'hff, dial_dout };
    end
    else sys_data <= 16'hffff;
end

// Data bus input
reg  [15:0] cpu_din;
reg         rom_ok2;

always @(posedge clk) begin
    if(rst) begin
        cpu_din <= 16'hffff;
        rom_ok2 <= 1'b0;
    end else begin
        rom_ok2 <= rom_ok;
        cpu_din <= (dial_cs | joy_cs | sys_cs) ? sys_data : (
                   (ram_cs | vram_cs )         ? ram_data : (
                    rom_cs                     ? rom_data : (
                    ppu2_cs                    ? mmr_dout : (
                    `ifdef CPS15
                    eeprom_cs                  ? {~15'd0, eeprom_sdo}  : (
                    main2qs_cs                 ? {8'hff, main2qs_din} :
                    `else
                    (
                    `endif
                                                 16'hFFFF )))));

    end
end

// DTACKn generation
wire       inta_n;
reg [2:0]  wait_cycles;
wire       bus_cs =   |{ rom_cs, pre_ram_cs, pre_vram_cs };
wire       bus_busy = |{ rom_cs & ~rom_ok2,
                    (pre_ram_cs|pre_vram_cs) & ~ram_ok
                    `ifdef CPS15
                    , main2qs_cs & ~main2qs_waitn
                    `endif
                     };
//                          wait_cycles[0] };
reg        DTACKn;
reg        last_LVBL;
(*keep*) reg [3:0] fail_cnt;

`ifdef CPS15
reg qs_busakn_s;

always @(posedge clk, posedge rst) begin
    if( rst )
        qs_busakn_s <= 1;
    else if(cpu_cen)
        qs_busakn_s <= main2qs_busakn;
end
`endif

reg fail_cnt_ok;

always @(posedge clk, posedge rst) begin : dtack_gen
    reg       last_ASn;
    if( rst ) begin
        DTACKn      <= 1'b1;
        wait_cycles <= 3'b111;
        fail_cnt    <= 4'd0;
        fail_cnt_ok <= 0;
        last_fail   <= 4'd0;
    end else /*if(cen16b)*/ begin
        if( rom_ok ) fail_cnt_ok <= 1;
        last_ASn <= ASn;
        if( (!ASn && last_ASn) || ASn
            `ifdef CPS15
            || (main2qs_cs && qs_busakn_s) // wait for Z80 bus grant
            `endif
        ) begin // for falling edge of ASn
            DTACKn <= 1'b1;
            wait_cycles <= 3'b111;
        end else if( !ASn  ) begin
            // The original hardware always waits for 250ns
            // on each bus access, except if one_wait signal is
            // set low. Then it waits on a secondary input, which
            // seems to be tied high on the schematics.
            if( cen16 ) begin
                wait_cycles[2] <= 1'b0;
                wait_cycles[1] <= wait_cycles[2];
            end
            if( !wait_cycles[1] ) wait_cycles[0] <= ~one_wait;
            if( bus_cs ) begin
                // we avoid accumulating delay by counting it
                // and skipping wait cycles when necessary
                // the resolution of this compensation is one CPU clock
                // Recovery is done by shortening the normal bus wait
                // by one cycle
                // Average delay can be displayed in simulation by defining the
                // macro REPORT_DELAY
                if( !wait_cycles[0] && bus_busy && fail_cnt_ok && cen16 && (~|fail_cnt) ) fail_cnt<=fail_cnt+1'd1;
                if (!bus_busy && (!wait_cycles[0] || (fail_cnt!=4'd0&&wait_cycles==3'b011) ) ) begin
                    DTACKn <= 1'b0;
                    if( wait_cycles[0] && fail_cnt_ok) fail_cnt<=fail_cnt-1'd1; // one bus cycle recovered
                end
            end
            else DTACKn <= 1'b0;
        end
        if( !LVBL && last_LVBL ) begin
            fail_cnt <= 4'd0;
            last_fail <= fail_cnt;
        end
    end
end

`ifdef REPORT_DELAY
// Note that the data for the first frame may be wrong because
// of SDRAM initialization
real dly_cnt, ticks;
always @(posedge clk) begin
    if( !LVBL && last_LVBL ) begin
        ticks <= 0;
        dly_cnt <= 0;
        if( ticks ) $display("INFO: average CPU delay = %.2f CPU clock ticks",dly_cnt/ticks);
    end else begin
        dly_cnt <= dly_cnt+fail_cnt;
        ticks <= ticks+1;
    end
end
`endif

// interrupt generation
reg        int1, // VBLANK
           int2; // ??
(*keep*) wire [2:0] FC;
assign inta_n = ~&{ FC[2], FC[1], FC[0], ~ASn }; // interrupt ack.

always @(posedge clk, posedge rst) begin : int_gen
    //reg last_V256;
    if( rst ) begin
        int1 <= 1'b1;
        int2 <= 1'b1;
    end else begin
        last_LVBL <= LVBL;
        //last_V256 <= V[8];

        if( !inta_n ) begin
            int1 <= 1'b1;
            int2 <= 1'b1;
        end
        else begin
            //if( V[8] && !last_V256 ) int2 <= 1'b0;
            if( !LVBL && last_LVBL ) int1 <= 1'b0;
        end
    end
end

assign busack = ~BGACKn;

jtframe_68kdma #(.BW(1)) u_arbitration(
    .clk        (  clk          ),
    .cen        ( cen16b        ),
    .rst        (  rst          ),
    .cpu_BRn    (  BRn          ),
    .cpu_BGACKn (  BGACKn       ),
    .cpu_BGn    (  BGn          ),
    .cpu_ASn    (  ASn          ),
    .cpu_DTACKn (  DTACKn       ),
    .dev_br     (  busreq       )
);

fx68k u_cpu(
    .clk        ( clk         ),
    .extReset   ( rst         ),
    .pwrUp      ( rst         ),
    .enPhi1     ( cen16       ),
    .enPhi2     ( cen16b      ),

    // Buses
    .eab        ( A           ),
    .iEdb       ( cpu_din     ),
    .oEdb       ( cpu_dout    ),


    .eRWn       ( RnW         ),
    .LDSn       ( LDSn        ),
    .UDSn       ( UDSn        ),
    .ASn        ( ASn         ),
    .VPAn       ( inta_n      ),
    .FC0        ( FC[0]       ),
    .FC1        ( FC[1]       ),
    .FC2        ( FC[2]       ),

    .BERRn      ( BERRn       ),
    // Bus arbitrion
    .HALTn      ( dip_pause   ),
    .BRn        ( BRn         ),
    .BGACKn     ( BGACKn      ),
    .BGn        ( BGn         ),

    .DTACKn     ( DTACKn      ),
    .IPL0n      ( 1'b1        ),
    .IPL1n      ( int1        ), // VBLANK
    .IPL2n      ( int2        ),

    // Unused
    .oRESETn    (             ),
    .oHALTEDn   (             ),
    .VMAn       (             ),
    .E          (             )
);

endmodule
