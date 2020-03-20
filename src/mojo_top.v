module mojo_top(
    // 50MHz clock input
    input clk,
    // Input from reset button (active low)
    input rst_n,
    // cclk input from AVR, high when AVR is ready
    input cclk,
    // AVR SPI connections
    output spi_miso,
    input spi_ss,
    input spi_mosi,
    input spi_sck,
    // AVR ADC channel select
    output [3:0] spi_channel,
    // Serial connections
    input avr_tx, // AVR Tx => FPGA Rx
    output avr_rx, // AVR Rx => FPGA Tx
    input avr_rx_busy, // AVR Rx buffer full

    output [7:0] cpu_data,
    input [14:0] cpu_addr,
    input cpu_rw,
    input cpu_rom_sel_n,
    input cpu_m2,

    output [7:0] ppu_data,
    input [13:0] ppu_addr,
    input ppu_rd_n,
    input ppu_we_n,

    output flash_cs_n,
    output flash_sck,
    output flash_si,
    input flash_so,

    output sdram_clk,
    output sdram_cle,
    output sdram_dqm,
    output sdram_cs,
    output sdram_we,
    output sdram_cas,
    output sdram_ras,
    output [1:0] sdram_ba,
    output [12:0] sdram_a,
    inout [7:0] sdram_dq
    );

wire rst = ~rst_n; // make reset active high
wire avr_ready;
wire read_flash_over;
wire fpga_tx;

// these signals should be high-z when not used
assign spi_miso = 1'bz;
assign avr_rx = avr_ready ? fpga_tx : 1'bz;
assign spi_channel = 4'bzzzz;

wire [7:0] ppu_data_out_run;
assign ppu_data = ((!ppu_rd_n) && (!ppu_addr[13])) ? ppu_data_out_run : 8'bz;

wire [31:0] data_in, data_out;
wire [22:0] sdram_addr;
wire sdram_rw;  // 1 = write, 0 = read
wire sdram_busy;
wire in_valid;
wire out_valid;

wire [7:0] c6502_data;
assign cpu_data = (cpu_rw && (!cpu_rom_sel_n)) ? c6502_data : 8'bz;

wire [22:0] addr_init;
wire [22:0] addr_run;
wire in_valid_init;
wire in_valid_run;

assign sdram_addr = read_flash_over ? addr_run : addr_init;
assign in_valid = read_flash_over ? in_valid_run : in_valid_init;

wire [22:0] A_ram_addr;
wire [7:0] A_data_out;
wire A_busy;
wire A_in_valid;
wire A_out_valid;

wire [22:0] B_ram_addr;
wire [7:0] B_data_out;
wire B_busy;
wire B_in_valid;
wire B_out_valid;

wire fclk;  // 100MHz

clk_wiz clk_wiz (
    .CLK_IN1(clk),
    .CLK_OUT1(fclk)
);

cclk_detector cclk_detector (
    .clk(fclk),
    .rst(rst),
    .cclk(cclk),
    .ready(avr_ready)
);

decode_nec decode_nec (
    .clk(fclk),
    .rst(rst),

    .miso(flash_so),
    .mosi(flash_si),
    .sck(flash_sck),
    .cs(flash_cs_n),

    .addr(addr_init),
    .rw(sdram_rw),
    .data_in(data_in[7:0]),
    .data_out(data_out[7:0]),
    .busy(sdram_busy),
    .in_valid(in_valid_init),
    .out_valid(out_valid),

    .ready(avr_ready),
    .read_flash_over(read_flash_over),
    .tx(fpga_tx)
);

sdram sdram (
    .clk(fclk),
    .rst(rst),
    .sdram_clk(sdram_clk),
    .sdram_cle(sdram_cle),
    .sdram_cs(sdram_cs),
    .sdram_cas(sdram_cas),
    .sdram_ras(sdram_ras),
    .sdram_we(sdram_we),
    .sdram_dqm(sdram_dqm),
    .sdram_ba(sdram_ba),
    .sdram_a(sdram_a),
    .sdram_dq(sdram_dq),

    .addr(sdram_addr),
    .rw(sdram_rw),
    .data_in(data_in),
    .data_out(data_out),
    .busy(sdram_busy),
    .in_valid(in_valid),
    .out_valid(out_valid)
);

arbitrate arbitrate (
    .clk(fclk),
    .rst(rst),

    .A_ram_addr(A_ram_addr),
    .A_data_out(A_data_out),
    .A_busy(A_busy),
    .A_in_valid(A_in_valid),
    .A_out_valid(A_out_valid),

    .B_ram_addr(B_ram_addr),
    .B_data_out(B_data_out),
    .B_busy(B_busy),
    .B_in_valid(B_in_valid),
    .B_out_valid(B_out_valid),

    .ram_addr(addr_run),
    .data_out(data_out[7:0]),
    .busy(sdram_busy),
    .in_valid(in_valid_run),
    .out_valid(out_valid)
);

bus2c02 bus2c02 (
    .clk(fclk),
    .rst(rst),
    .c2c02_data(ppu_data_out_run),
    .c2c02_addr(ppu_addr),
    .c2c02_rd(ppu_rd_n),

    .ram_addr(B_ram_addr),
    .data_out(B_data_out),
    .busy(B_busy),
    .in_valid(B_in_valid),
    .out_valid(B_out_valid),

    .init_sdram_data(read_flash_over)
);

bus6502 bus6502 (
    .clk(fclk),
    .rst(rst),
    .c6502_data(c6502_data),
    .c6502_addr(cpu_addr),
    .c6502_rw(cpu_rw),
    .c6502_m2(cpu_m2),

    .ram_addr(A_ram_addr),
    .data_out(A_data_out),
    .busy(A_busy),
    .in_valid(A_in_valid),
    .out_valid(A_out_valid),

    .init_sdram_data(read_flash_over)
);
endmodule
