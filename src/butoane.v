module butoane(
    input clk,
    input btn_in,
    output reg btn_out
);
    parameter TIMER_LIMIT = 1000000; // 10ms
    reg [19:0] counter = 0;
    reg btn_prev = 0;
    reg btn_stable = 0;

    always @(posedge clk) begin
        if (btn_in == btn_stable) counter <= 0;
        else begin
            counter <= counter + 1;
            if (counter == TIMER_LIMIT) begin
                btn_stable <= btn_in;
                counter <= 0;
            end
        end
        btn_prev <= btn_stable;
        if (btn_stable == 1 && btn_prev == 0) btn_out <= 1;
        else btn_out <= 0;
    end
endmodule