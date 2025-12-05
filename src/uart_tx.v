module uart_tx #(
    parameter CLKS_PER_BIT = 10416 
)(
    input clk,
    input tx_start,          
    input [7:0] tx_din,      
    output reg tx_active,    
    output reg tx_serial,  
    output reg tx_done       
);
    localparam IDLE=0, START=1, DATA=2, STOP=3;
    reg [2:0] state = IDLE;
    reg [15:0] clk_count = 0;
    reg [2:0] bit_index = 0;
    reg [7:0] data_temp = 0;

    always @(posedge clk) begin
        case (state)
            IDLE: begin
                tx_serial <= 1;
                tx_done <= 0;
                tx_active <= 0;
                clk_count <= 0;
                bit_index <= 0;
                if (tx_start == 1) begin
                    state <= START;
                    tx_active <= 1;
                    data_temp <= tx_din;
                end
            end
            START: begin
                tx_serial <= 0; // Bitul de start este activ in 0, active-low
                if (clk_count < CLKS_PER_BIT-1) begin
                    clk_count <= clk_count + 1;
                end else begin
                    clk_count <= 0;
                    state <= DATA;
                end
            end
            DATA: begin
                tx_serial <= data_temp[bit_index];
                if (clk_count < CLKS_PER_BIT-1) begin
                    clk_count <= clk_count + 1;
                end else begin
                    clk_count <= 0;
                    if (bit_index < 7)
                        bit_index <= bit_index + 1;
                    else
                        state <= STOP;
                end
            end
            STOP: begin
                tx_serial <= 1; // Bitul de stop este activ in 1, active-high
                if (clk_count < CLKS_PER_BIT-1) begin
                    clk_count <= clk_count + 1;
                end else begin
                    tx_done <= 1;
                    tx_active <= 0;
                    state <= IDLE;
                end
            end
        endcase
    end
endmodule