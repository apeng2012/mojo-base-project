module bus2c02(
    input clk,
    input rst,

    output [7:0] c2c02_data,
    input [13:0] c2c02_addr,
    input c2c02_rd,

    output reg [12:0] blk_mem_addr,
    input [7:0] blk_mem_dout,

    input init_sdram_data  // 1 表示 数据已经准备好，可以访问
    );

localparam STATE_SIZE = 2;
localparam IDLE = 0,
            FETCH = 1,
            FETCH_T = 3,
            RELEASE = 2;

reg [STATE_SIZE-1:0] state_d, state_q = IDLE;
reg [7:0] c2c02_data_d, c2c02_data_q;
reg [13:0] old_addr_d, old_addr_q;
reg [13:0] tmp_addr_d, tmp_addr_q;

assign c2c02_data = c2c02_data_q;
//assign blk_mem_addr = c2c02_addr[12:0];


always @(*) begin
    state_d = state_q;
    c2c02_data_d = c2c02_data_q;
    old_addr_d = old_addr_q;
    tmp_addr_d = tmp_addr_q;

    if (state_q == IDLE) begin
        if (!c2c02_addr[13] && old_addr_q != c2c02_addr) begin
            tmp_addr_d = c2c02_addr;
            state_d = FETCH;
        end
    end

    else if (state_q == FETCH) begin
        if (init_sdram_data) begin
            blk_mem_addr = tmp_addr_q[12:0];
            state_d = FETCH_T;
        end
        else begin
            c2c02_data_d = 8'h00;
            state_d = IDLE;  // 数据没有准备好直接推出，等待下次访问
        end
    end

    else if (state_q == FETCH_T) begin
        c2c02_data_d = blk_mem_dout;
        old_addr_d = tmp_addr_q;
        state_d = IDLE;
    end
end


always @(posedge clk) begin
    if (rst) begin
        state_q <= IDLE;
        old_addr_q <= 14'h3FFF;
    end
    else begin
        state_q <= state_d;
        old_addr_q <= old_addr_d;
    end
    c2c02_data_q <= c2c02_data_d;
    tmp_addr_q <= tmp_addr_d;
end
endmodule
