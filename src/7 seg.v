module ssd_ctrl(
    input clk,
    input [15:0] number, // Numarul de 4 cifre Hex
    output reg [6:0] seg, // Segmentele (A-G)
    output reg [3:0] an   // Anozii
);
    // 1. Divizor de ceas pentru refresh
    reg [19:0] refresh_counter = 0;
    
    always @(posedge clk) begin
        refresh_counter <= refresh_counter + 1;
    end

    // Selectam care cifra e activa bazat pe counter
    wire [1:0] digit_select;
    assign digit_select = refresh_counter[19:18];

    reg [3:0] hex_digit;

    // 2. Multiplexare Anozi si selectie cifra
    always @(*) begin
        case (digit_select)
            2'b00: begin
                an = 4'b1110; // Cifra 0 (Dreapta) activa (Active 0)
                hex_digit = number[3:0];
            end
            2'b01: begin
                an = 4'b1101; // Cifra 1
                hex_digit = number[7:4];
            end
            2'b10: begin
                an = 4'b1011; // Cifra 2
                hex_digit = number[11:8];
            end
            2'b11: begin
                an = 4'b0111; // Cifra 3 (Stanga)
                hex_digit = number[15:12];
            end
            default: begin
                an = 4'b1111;
                hex_digit = 0;
            end
        endcase
    end

    // 3. Decodor Hex -> 7 Segmente (0 = Aprins, 1 = Stins)
    always @(*) begin
        case (hex_digit)
            4'h0: seg = 7'b1000000; // 0
            4'h1: seg = 7'b1111001; // 1
            4'h2: seg = 7'b0100100; // 2
            4'h3: seg = 7'b0110000; // 3
            4'h4: seg = 7'b0011001; // 4
            4'h5: seg = 7'b0010010; // 5
            4'h6: seg = 7'b0000010; // 6
            4'h7: seg = 7'b1111000; // 7
            4'h8: seg = 7'b0000000; // 8
            4'h9: seg = 7'b0010000; // 9
            4'hA: seg = 7'b0001000; // A
            4'hB: seg = 7'b0000011; // b
            4'hC: seg = 7'b1000110; // C
            4'hD: seg = 7'b0100001; // d
            4'hE: seg = 7'b0000110; // E
            4'hF: seg = 7'b0001110; // F
            default: seg = 7'b1111111; // Stins
        endcase
    end
endmodule