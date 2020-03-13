module spi (
    input clk,
    input rst,

    input miso,
    output mosi,
    output sck,

    input start,
    input[7:0] data_in,
    output[7:0] data_out,
    output busy
    );
 
localparam STATE_SIZE = 2;
localparam IDLE = 2'd0,
           MOSI = 2'd1,
           MISO = 2'd2,
           OOUT = 2'd3;
 
reg [STATE_SIZE-1:0] state_d, state_q;

reg [7:0] data_d, data_q;
reg sck_d, sck_q;
reg [2:0] ctr_d, ctr_q;
reg [7:0] data_out_d, data_out_q;

assign mosi = data_q[7];
assign sck = sck_q;
assign busy = state_q != IDLE;
assign data_out = data_out_q;
 
always @(*) begin
    sck_d = sck_q;
    data_d = data_q;
    ctr_d = ctr_q;
    data_out_d = data_out_q;
    state_d = state_q;
 
    case (state_q)

        IDLE: begin
            ctr_d = 3'b0;  // reset bit counter
            if (start == 1'b1) begin  // if start command
                data_d = data_in;  // copy data to send
                state_d = MOSI;  // change state
            end
        end

        MOSI: begin
            sck_d = 1'b1;  // reset to 0
            state_d = MISO;  // change state
        end

        MISO: begin
            sck_d = 1'b0;  // increment clock counter
            ctr_d = ctr_q + 1'b1;  // increment bit counter
            data_d = {data_q[6:0], miso};  // read in data (shift in)
            if (ctr_q == 3'b111) begin  // if we are on the last bit
                state_d = OOUT;  // change state
            end else begin
                state_d = MOSI;
            end
        end

        OOUT: begin
            data_out_d = data_q;  // output data
            state_d = IDLE;
        end

    endcase
end
 
always @(posedge clk) begin
    if (rst) begin
        ctr_q <= 3'b0;
        data_q <= 8'b0;
        sck_q <= 4'b0;
        state_q <= IDLE;
        data_out_q <= 8'b0;
    end else begin
        ctr_q <= ctr_d;
        data_q <= data_d;
        sck_q <= sck_d;
        state_q <= state_d;
        data_out_q <= data_out_d;
    end
end

endmodule
