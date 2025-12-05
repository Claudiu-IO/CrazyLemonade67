module uart_rx #(
    parameter CLKS_PER_BIT = 10416
)(
    input clk,
    input rx_serial,
    output reg [7:0] rx_byte,
    output reg rx_done
);
    localparam IDLE=0, START=1, DATA=2, STOP=3;
    reg [2:0] state = IDLE;
    reg [15:0] clk_count = 0;
    reg [2:0] bit_index = 0;
    
    always @(posedge clk) begin
        case (state)
            IDLE: begin
                rx_done <= 0;
                clk_count <= 0;
                bit_index <= 0;
                if (rx_serial == 0) state <= START;
            end
            START: begin
                if (clk_count == (CLKS_PER_BIT-1)/2) begin
                    if (rx_serial == 0) begin
                        clk_count <= 0;
                        state <= DATA;
                    end else state <= IDLE;
                end else clk_count <= clk_count + 1;
            end
            DATA: begin
                if (clk_count == CLKS_PER_BIT-1) begin
                    clk_count <= 0;
                    rx_byte[bit_index] <= rx_serial;
                    if (bit_index < 7) bit_index <= bit_index + 1;
                    else state <= STOP;
                end else clk_count <= clk_count + 1;
            end
            STOP: begin
                if (clk_count == CLKS_PER_BIT-1) begin
                    rx_done <= 1;
                    state <= IDLE;
                end else clk_count <= clk_count + 1;
            end
        endcase
    end
endmodule