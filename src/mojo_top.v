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
    input flash_so
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

wire [7:0] c6502_data;
assign cpu_data = (cpu_rw && (!cpu_rom_sel_n)) ? c6502_data : 8'bz;

wire fclk;  // 100MHz

wire blk_mem_we;
wire [7:0] blk_mem_din;
wire [7:0] blk_mem_dout;
wire [12:0] blk_mem_addr;
wire [12:0] blk_mem_addr_init;
wire [12:0] blk_mem_addr_run;

assign blk_mem_addr = read_flash_over ? blk_mem_addr_run : blk_mem_addr_init;

wire blk_mem_prg_we;
wire [7:0] blk_mem_prg_din;
wire [7:0] blk_mem_prg_dout;
wire [14:0] blk_mem_prg_addr;
wire [14:0] blk_mem_prg_addr_init;
wire [14:0] blk_mem_prg_addr_run;

assign blk_mem_prg_addr = read_flash_over ? blk_mem_prg_addr_run : blk_mem_prg_addr_init;



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

    .bm_prg_we(blk_mem_prg_we),
    .bm_prg_addr(blk_mem_prg_addr_init),
    .bm_prg_din(blk_mem_prg_din),
    .bm_prg_dout(blk_mem_prg_dout),

    .bm_we(blk_mem_we),
    .bm_addr(blk_mem_addr_init),
    .bm_din(blk_mem_din),
    .bm_dout(blk_mem_dout),

    .ready(avr_ready),
    .read_flash_over(read_flash_over),
    .tx(fpga_tx)
);

blk_mem_gen blk_mem_gen (
    .clka(fclk),
    .wea(blk_mem_we),
    .addra(blk_mem_addr),
    .dina(blk_mem_din),
    .douta(blk_mem_dout)
);

blk_mem_prg blk_mem_prg (
    .clka(fclk),
    .wea(blk_mem_prg_we),
    .addra(blk_mem_prg_addr),
    .dina(blk_mem_prg_din),
    .douta(blk_mem_prg_dout)
);

bus2c02 bus2c02 (
    .clk(fclk),
    .rst(rst),
    .c2c02_data(ppu_data_out_run),
    .c2c02_addr(ppu_addr),
    .c2c02_rd(ppu_rd_n),

    .blk_mem_addr(blk_mem_addr_run),
    .blk_mem_dout(blk_mem_dout),

    .init_sdram_data(read_flash_over)
);

bus6502 bus6502 (
    .clk(fclk),
    .rst(rst),
    .c6502_data(c6502_data),
    .c6502_addr(cpu_addr),
    .c6502_rw(cpu_rw),
    .c6502_m2(cpu_m2),

    .blk_mem_addr(blk_mem_prg_addr_run),
    .blk_mem_dout(blk_mem_prg_dout),

    .init_sdram_data(read_flash_over)
);
endmodule
