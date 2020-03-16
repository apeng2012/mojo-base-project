module bus6502(
    input clk,
    input rst,

    output [7:0] c6502_data,
    input [14:0] c6502_addr,
    input c6502_rw,
    input c6502_cs,

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
reg is_sdram_ok_d, is_sdram_ok_q;
reg [7:0] c6502_data_d, c6502_data_q;
reg in_valid_d, in_valid_q;

assign c6502_data = c6502_data_q;
assign in_valid = in_valid_q;

always @(*) begin
    state_d = state_q;
    is_sdram_ok_d = is_sdram_ok_q;
    in_valid_d = 1'b0;
    c6502_data_d = c6502_data_q;

    if ((!is_sdram_ok_q) && (c6502_addr == 15'h7FFC) && (init_sdram_data)) begin
        is_sdram_ok_d = 1'b1;
    end

    case (state_q)
        IDLE: begin
            if ((!c6502_cs) && (c6502_rw)) begin
                if (is_sdram_ok_q) begin

                    if (!busy) begin
                        ram_addr = {8'd1, c6502_addr};
                        in_valid_d = 1'b1;
                    end
                    if (out_valid) begin
                        c6502_data_d = data_out;
                        state_d = RELEASE;
                    end

                end else begin

                    case (c6502_addr)
                        15'h7FF9: c6502_data_d = 8'h4C;
                        15'h7FFA: c6502_data_d = 8'h00;
                        15'h7FFB: c6502_data_d = 8'hC0;
                        15'h7FFC: c6502_data_d = 8'h00;
                        15'h7FFD: c6502_data_d = 8'hC0;
                        15'h7FFE: c6502_data_d = 8'h00;
                        15'h7FFF: c6502_data_d = 8'hC0;
                        default: c6502_data_d = 8'hEA;  // 6502 nop
                    endcase
                    state_d = RELEASE;

                end
            end
        end

        RELEASE: begin
            if (c6502_cs) begin
                state_d = IDLE;
            end
        end

        default: begin
        end
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        state_q <= IDLE;
        is_sdram_ok_q <= 1'b0;
    end
    else begin
        state_q <= state_d;
        is_sdram_ok_q <= is_sdram_ok_d;
    end
    c6502_data_q <= c6502_data_d;
    in_valid_q <= in_valid_d;
end
endmodule
