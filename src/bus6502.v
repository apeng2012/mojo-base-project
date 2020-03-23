module bus6502(
    input clk,
    input rst,

    output [7:0] c6502_data,
    input [14:0] c6502_addr,
    input c6502_rw,
    input c6502_m2,

    output [14:0] blk_mem_addr,
    input [7:0] blk_mem_dout,

    output test,  // 测试延时多长时间启动SDRAM读

    input init_sdram_data  // 1 表示 数据已经准备好，可以访问
    );

localparam STATE_SIZE = 2;
localparam IDLE = 0,
            FETCH = 1,
            FETCH_T = 3,
            RELEASE = 2;

reg [STATE_SIZE-1:0] state_d, state_q = IDLE;
reg is_sdram_ok_d, is_sdram_ok_q;
reg [7:0] c6502_data_d, c6502_data_q;
reg [3:0] delay_cnt_d, delay_cnt_q;
reg delay_flag_d, delay_flag_q;
reg test_d, test_q;
reg [14:0] bm_addr_d, bm_addr_q;

assign test = test_q;

assign c6502_data = c6502_data_q;
assign blk_mem_addr = bm_addr_q;

always @(*) begin
    state_d = state_q;
    is_sdram_ok_d = is_sdram_ok_q;
    c6502_data_d = c6502_data_q;
    delay_cnt_d = delay_cnt_q;
    test_d = test_q;
    delay_flag_d = 1'b0;
    bm_addr_d = bm_addr_q;

    if ((!is_sdram_ok_q) && (c6502_addr == 15'h7FFC) && (init_sdram_data)) begin
        is_sdram_ok_d = 1'b1;
    end

    case (state_q)
        IDLE: begin
            if (!c6502_m2) begin
                delay_flag_d = 1'b1;
                delay_cnt_d = delay_cnt_q + 4'd1;
                if (delay_cnt_q == 4'd10) begin
                    delay_cnt_d = 0;
                    test_d = !test_q;
                    if (c6502_rw) begin
                        bm_addr_d = c6502_addr;
                        state_d = FETCH;
                    end else begin
                        state_d = RELEASE;
                    end
                end
            end else if (delay_flag_q) begin
                delay_cnt_d = delay_cnt_q - 4'd1;
            end
        end

        FETCH: begin
            state_d = RELEASE;

            if (is_sdram_ok_q) begin

                state_d = FETCH_T;

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
            end

        end

        FETCH_T: begin
            c6502_data_d = blk_mem_dout;
            state_d = RELEASE;
        end

        RELEASE: begin
            if (c6502_m2) begin
                delay_cnt_d = delay_cnt_q + 4'd1;
                if (delay_cnt_q == 4'd10) begin
                    delay_cnt_d = 0;
                    state_d = IDLE;
                end
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
        delay_cnt_q <= 0;
    end
    else begin
        state_q <= state_d;
        is_sdram_ok_q <= is_sdram_ok_d;
        delay_cnt_q <= delay_cnt_d;
    end
    c6502_data_q <= c6502_data_d;
    test_q <= test_d;
    delay_flag_q <= delay_flag_d;
    bm_addr_q <= bm_addr_d;
end
endmodule
