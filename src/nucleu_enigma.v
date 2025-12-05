module nucleu_enigma(
    input clk,
    input rst,
    input valid_in,          
    input [4:0] char_in,     
    output reg [4:0] char_out, 
    output reg valid_out     
);

    always @(posedge clk) begin
        if (valid_in) begin
            if (char_in == 25) 
                char_out <= 0; 
            else 
                char_out <= char_in + 1;
                
            valid_out <= 1; 
        end else begin
            valid_out <= 0;
        end
    end
endmodule