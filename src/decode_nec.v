module decode_nec #(
    parameter CLK_RATE = 50000000,
    parameter SERIAL_BAUD_RATE = 500000
    )(
    input clk,
    input rst,

    input miso,
    output mosi,
    output sck,
    output cs,

    input ready,  // avr ready

    output read_flash_over,

    output tx  // AVR Serial Signals
    );

localparam BYTES_CTR_SIZE = 15;
localparam STATE_SIZE = 5;
localparam IDLE = 0,
CMD = 1,
CMD_T = 2,
ADDR_dummy = 3,
ADDR_dummy_T = 4,
READ_PRG_1 = 5,
READ_PRG_1_T = 6,
READ_PRG_1_W = 7,
READ_CHR_1 = 8,
READ_CHR_1_T = 9,
NES_chk = 10,
NES_header = 11,
NES_header_T = 12,
RESULT_TX = 13,
RESULT_TX_T = 14,
OVER = 15,
READ_SDRAM1 = 16,
TEST_READ_FLASH_16 = 17,
TEST_READ_FLASH_16_T = 18,
TEST_TX_16 = 19,
TEST_TX_16_T = 20,
TEST_TX_DELAY = 21,
TEST_LOOP = 22,
FAILURE = 23;

reg [STATE_SIZE-1:0] state_d, state_q;
reg start_d, start_q;
reg [7:0] spi_in_data_d, spi_in_data_q;
reg [7:0] uart_dout_d, uart_dout_q;
reg new_tx_data_d, new_tx_data_q;
reg cs_d, cs_q;
reg [BYTES_CTR_SIZE-1:0] bytes_ctr_d, bytes_ctr_q;
reg [11:0] test_loop_cnt_d, test_loop_cnt_q;
reg [23:0] delay_cnt_d, delay_cnt_q;

wire spi_busy;
wire [7:0] spi_out_data;
wire block_nouse;
wire tx_busy;

assign block_nouse = 1'b0;
assign read_flash_over = (state_q == OVER) ? 1'b1 : 1'b0;
assign cs = cs_q;


spi spi (
    .clk(clk),
    .rst(rst),

    .miso(miso),
    .mosi(mosi),
    .sck(sck),

    .start(start_q),
    .busy(spi_busy),

    .data_in(spi_in_data_q),
    .data_out(spi_out_data)
);

parameter CLK_PER_BIT = $rtoi($ceil(CLK_RATE/SERIAL_BAUD_RATE));
serial_tx #(.CLK_PER_BIT(CLK_PER_BIT)) serial_tx (
    .clk(clk),
    .rst(rst),

    .tx(tx),
    .block(block_nouse),
    .busy(tx_busy),
    .data(uart_dout_q),
    .new_data(new_tx_data_q)
);

always @(*) begin
    state_d = state_q;
    start_d = 1'b0;
    spi_in_data_d = spi_in_data_q;
    uart_dout_d = uart_dout_q;
    new_tx_data_d = new_tx_data_q;
    cs_d = cs_q;
    bytes_ctr_d = bytes_ctr_q;
    test_loop_cnt_d = test_loop_cnt_q;
    delay_cnt_d = delay_cnt_q;

    case (state_q)
        IDLE: begin
            if ((spi_busy == 1'b0) && (ready == 1'b1)) begin
                cs_d = 1'b0;
                state_d = CMD;
            end
        end

        CMD: begin
            spi_in_data_d = 8'h03;
            start_d = 1'b1;
            if (spi_busy == 1'b1) begin
                state_d = CMD_T;
            end
        end

        CMD_T: begin
            if (spi_busy == 1'b0) begin
                bytes_ctr_d = 15'h7FFF;
                state_d = ADDR_dummy;
            end
        end

        ADDR_dummy: begin
            spi_in_data_d = 8'h00;
            start_d = 1'b1;
            if (spi_busy == 1'b1) begin
                bytes_ctr_d = bytes_ctr_q + 15'd1;
                state_d = ADDR_dummy_T;
            end
        end

        ADDR_dummy_T: begin
            if (spi_busy == 1'b0) begin
                if (bytes_ctr_q == 15'd2) begin
                    bytes_ctr_d = 15'h7FFF;
                    test_loop_cnt_d = 12'hFFF;
                    state_d = TEST_READ_FLASH_16;
                    // state_d = NES_header;
                end else begin
                    state_d = ADDR_dummy;
                end
            end
        end


        TEST_READ_FLASH_16: begin
            start_d = 1'b1;
            if (spi_busy == 1'b1) begin
                bytes_ctr_d = bytes_ctr_q + 15'd1;
                state_d = TEST_READ_FLASH_16_T;
            end
        end
        TEST_READ_FLASH_16_T: begin
            if (spi_busy == 1'b0) begin
                uart_dout_d = spi_out_data;
                state_d = TEST_TX_16;
            end
        end
        TEST_TX_16: begin
            if (!tx_busy) begin
                new_tx_data_d = 1'b1;
                state_d = TEST_TX_16_T;
            end
        end
        TEST_TX_16_T: begin
            if (tx_busy) begin
                new_tx_data_d = 1'b0;
                if (bytes_ctr_q == 15'd15) begin
                    bytes_ctr_d = 15'h7FFF;
                    delay_cnt_d = 24'd1;
                    state_d = TEST_TX_DELAY;
                end else begin
                    state_d = TEST_READ_FLASH_16;
                end
            end
        end
        TEST_TX_DELAY: begin
            delay_cnt_d = delay_cnt_q + 24'd1;
            if (delay_cnt_q == 24'd0) begin
                test_loop_cnt_d = test_loop_cnt_q + 12'd1;
                state_d = TEST_LOOP;
            end
        end
        TEST_LOOP: begin
            if (test_loop_cnt_q == 12'd63) begin
                cs_d = 1'b1;
                state_d = OVER;
            end else begin
                state_d = TEST_READ_FLASH_16;
            end
        end


        OVER: begin
        end

        default: begin
		  end
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        state_q <= IDLE;
        start_q <= 1'b0;
        new_tx_data_q <= 1'b0;
        cs_q <= 1'b1;
    end else begin
        state_q <= state_d;
        start_q <= start_d;
        new_tx_data_q <= new_tx_data_d;
        cs_q <= cs_d;
    end

    spi_in_data_q <= spi_in_data_d;
    uart_dout_q <= uart_dout_d;
    bytes_ctr_q <= bytes_ctr_d;
    test_loop_cnt_q <= test_loop_cnt_d;
    delay_cnt_q <= delay_cnt_d;
end

endmodule
