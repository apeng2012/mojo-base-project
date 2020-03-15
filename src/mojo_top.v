module mojo_top(
    // 50MHz clock input
    input clk,
    // Input from reset button (active low)
    input rst_n,
    // cclk input from AVR, high when AVR is ready
    input cclk,
    // Outputs to the 8 onboard LEDs
    output led,
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

    input [7:0] cpu_data,
    input [14:0] cpu_addr,
    input cpu_rw,
    input cpu_rom_sel_n,
    output cpu_irq_oc,
    input cpu_m2,

    inout [7:0] ppu_data,
    input [13:0] ppu_addr,
    input ppu_rd_n,
    input ppu_we_n,

    output vram_cs_n,
    output vram_a10_n,

    output flash_cs_n,

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

assign led = read_flash_over;

assign cpu_irq_oc = 1'bz;

assign vram_cs_n = ~ppu_addr[13];
assign vram_a10_n = ppu_addr[10];

wire flash_sck;  // ppu_data[2];
wire flash_si;  // ppu_data[1];
wire flash_so;  // ppu_data[3];

wire [7:0] ppu_data_out;
wire [7:0] ppu_data_out_run;
assign ppu_data_out = ((!ppu_rd_n) && (!ppu_addr[13])) ? ppu_data_out_run : 8'bz;
assign ppu_data = read_flash_over ? ppu_data_out : {5'bz, flash_sck, flash_si, 1'bz};
assign flash_so = ppu_data[3];

wire [31:0] data_in, data_out;
wire [22:0] sdram_addr;
wire sdram_rw;  // 1 = write, 0 = read
wire sdram_busy;
wire in_valid;
wire out_valid;


cclk_detector cclk_detector (
    .clk(clk),
    .rst(rst),
    .cclk(cclk),
    .ready(avr_ready)
);

decode_nec decode_nec (
    .clk(clk),
    .rst(rst),

    .miso(flash_so),
    .mosi(flash_si),
    .sck(flash_sck),
    .cs(flash_cs_n),

    .addr(sdram_addr),
    .rw(sdram_rw),
    .data_in(data_in[7:0]),
    .data_out(data_out[7:0]),
    .busy(sdram_busy),
    .in_valid(in_valid),
    .out_valid(out_valid),

    .ready(avr_ready),
    .read_flash_over(read_flash_over),
    .tx(fpga_tx)
);

sdram sdram (
    .clk(clk),
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

endmodule