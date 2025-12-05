clock_pulse.v :
module clock_pulse #( parameter COUNT_MAX = 100000000 )(
    input clk,
    output reg tick
);
    reg [31:0] counter = 0;
    always @(posedge clk) begin
        if (counter == COUNT_MAX - 1) begin
            counter <= 0;
            tick <= 1;
        end else begin
            counter <= counter + 1;
            tick <= 0;
        end
    end
endmodule
