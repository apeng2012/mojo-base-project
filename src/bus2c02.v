module bus2c02(
    input clk,
    input rst,

    output [7:0] c2c02_data,
    input [13:0] c2c02_addr,
    input c2c02_rd,

    /* connect module SDRAM */
    output reg [22:0] ram_addr,
    input [7:0] data_out,
    input busy,
    output in_valid,
    input out_valid,

    input init_sdram_data  // 1 表示 数据已经准备好，可以访问
    );

localparam STATE_SIZE = 2;
localparam IDLE = 0,
            FETCH = 1,
            RELEASE = 2;

reg [STATE_SIZE-1:0] state_d, state_q = IDLE;
reg [7:0] c2c02_data_d, c2c02_data_q;
reg in_valid_d, in_valid_q;

assign c2c02_data = c2c02_data_q;
assign in_valid = in_valid_q;


always @(*) begin
    state_d = state_q;
    in_valid_d = 1'b0;
    c2c02_data_d = c2c02_data_q;

    if (state_q == IDLE) begin
        if (!c2c02_rd && !c2c02_addr[13]) begin
            state_d = FETCH;
        end
    end

    else if (state_q == FETCH) begin
        if (init_sdram_data) begin
            if (!busy) begin
                ram_addr = {9'd0, c2c02_addr};
                in_valid_d = 1'b1;
            end
            if (out_valid) begin
                c2c02_data_d = data_out;
                state_d = RELEASE;
            end
        end
        else begin
            state_d = RELEASE;  // 数据没有准备好直接推出，等待下次访问
        end
    end

    else if (state_q == RELEASE) begin
        if (c2c02_rd) begin
            state_d = IDLE;
        end
    end
end


always @(posedge clk) begin
    if (rst) begin
        state_q <= IDLE;
    end
    else begin
        state_q <= state_d;
    end
    c2c02_data_q <= c2c02_data_d;
    in_valid_q <= in_valid_d;
end
endmodule
