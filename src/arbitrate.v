module arbitrate(
    input clk,
    input rst,

    input [22:0] A_ram_addr,
    output [7:0] A_data_out,
    output A_busy,
    input A_in_valid,
    output A_out_valid,

    input [22:0] B_ram_addr,
    output [7:0] B_data_out,
    output B_busy,
    input B_in_valid,
    output B_out_valid,

    output reg [22:0] ram_addr,
    input [7:0] data_out,
    input busy,
    output in_valid,
    input out_valid
    );

localparam STATE_SIZE = 3;
localparam IDLE = 0,
            FETCH_A = 1,
            FETCH_B = 2,
            RELEASE_A = 3,
            RELEASE_B = 4;

reg [STATE_SIZE-1:0] state_d, state_q = IDLE;

reg [22:0] A_reg_addr_d, A_reg_addr_q;
reg [22:0] B_reg_addr_d, B_reg_addr_q;
reg A_busy_d, A_busy_q;
reg B_busy_d, B_busy_q;
reg A_out_valid_d, A_out_valid_q;
reg B_out_valid_d, B_out_valid_q;
reg [7:0] A_data_out_d, A_data_out_q;
reg [7:0] B_data_out_d, B_data_out_q;
reg in_valid_d, in_valid_q;

assign A_busy = A_busy_q;
assign B_busy = B_busy_q;
assign A_out_valid = A_out_valid_q;
assign B_out_valid = B_out_valid_q;
assign A_data_out = A_data_out_q;
assign B_data_out = B_data_out_q;
assign in_valid = in_valid_q;

always @(*) begin
    state_d = state_q;
    A_busy_d = A_busy_q;
    B_busy_d = B_busy_q;
    A_out_valid_d = 1'b0;
    B_out_valid_d = 1'b0;
    A_data_out_d = A_data_out_q;
    B_data_out_d = B_data_out_q;
    in_valid_d = 1'b0;
    A_reg_addr_d = A_reg_addr_q;
    B_reg_addr_d = B_reg_addr_q;

    if (A_in_valid) begin
        A_busy_d = 1'b1;
        A_reg_addr_d = A_ram_addr;
    end

    if (B_in_valid) begin
        B_busy_d = 1'b1;
        B_reg_addr_d = B_ram_addr;
    end

    if (state_q == IDLE) begin
        if (A_busy_q) begin
            state_d = FETCH_A;
        end
        else if (B_busy_q) begin
            state_d = FETCH_B;
        end
    end

    else if (state_q == FETCH_A) begin
        if (!busy) begin
            ram_addr = A_reg_addr_q;
            in_valid_d = 1'b1;
        end
        if (out_valid) begin
            A_data_out_d = data_out;
            A_out_valid_d = 1'b1;
            state_d = RELEASE_A;
        end
    end
    else if (state_q == RELEASE_A) begin
        A_busy_d = 1'b0;
        state_d = IDLE;
    end

    else if (state_q == FETCH_B) begin
        if (!busy) begin
            ram_addr = B_reg_addr_q;
            in_valid_d = 1'b1;
        end
        if (out_valid) begin
            B_data_out_d = data_out;
            B_out_valid_d = 1'b1;
            state_d = RELEASE_B;
        end
    end
    else if (state_q == RELEASE_B) begin
        B_busy_d = 1'b0;
        state_d = IDLE;
    end
end

always @(posedge clk) begin
    if (rst) begin
        state_q <= IDLE;
        A_busy_q <= 1'b0;
        B_busy_q <= 1'b0;
        A_out_valid_q <= 1'b0;
        B_out_valid_q <= 1'b0;
    end
    else begin
        state_q <= state_d;
        A_busy_q <= A_busy_d;
        B_busy_q <= B_busy_d;
        A_out_valid_q <= A_out_valid_d;
        B_out_valid_q <= B_out_valid_d;
    end
    A_data_out_q <= A_data_out_d;
    B_data_out_q <= B_data_out_d;
    in_valid_q <= in_valid_d;
    A_reg_addr_q <= A_reg_addr_d;
    B_reg_addr_q <= B_reg_addr_d;
end

endmodule // arbitrate