`timescale 1ns / 1ps

module nucleu_enigma(
    input clk,
    input rst,
    
    // Intrari date
    input valid_in,
    input [4:0] char_in,      // 0=A ... 25=Z
    
    // Intrari Configurare (Switch-uri)
    input [4:0] start_pos1,   // Rotor Stanga
    input [4:0] start_pos2,   // Rotor Mijloc
    input [4:0] start_pos3,   // Rotor Dreapta
    input load_config,        // Semnal de incarcare
    
    // Iesiri
    output reg [4:0] char_out,
    output reg valid_out,
    
    // Debugging (optional, pentru afisare pe 7-seg)
    output [4:0] current_pos1, 
    output [4:0] current_pos2,
    output [4:0] current_pos3
);
    
    // --- 1. DEFINIREA ROTOARELOR (LUT - Look Up Tables) ---
    // Functii "Hardcodate" pentru maparile Enigma I standard
    
    // ROTOR I
    function [4:0] rotor1_fwd; input [4:0] x;
        case (x) 0:rotor1_fwd=4; 1:rotor1_fwd=10; 2:rotor1_fwd=12; 3:rotor1_fwd=5; 4:rotor1_fwd=11; 5:rotor1_fwd=6; 6:rotor1_fwd=3; 7:rotor1_fwd=16; 8:rotor1_fwd=21; 9:rotor1_fwd=25; 10:rotor1_fwd=13; 11:rotor1_fwd=19; 12:rotor1_fwd=14; 13:rotor1_fwd=22; 14:rotor1_fwd=24; 15:rotor1_fwd=7; 16:rotor1_fwd=23; 17:rotor1_fwd=20; 18:rotor1_fwd=18; 19:rotor1_fwd=15; 20:rotor1_fwd=0; 21:rotor1_fwd=8; 22:rotor1_fwd=1; 23:rotor1_fwd=17; 24:rotor1_fwd=2; 25:rotor1_fwd=9; default:rotor1_fwd=0; endcase
    endfunction
    function [4:0] rotor1_rev; input [4:0] x;
        case (x) 0:rotor1_rev=20; 1:rotor1_rev=22; 2:rotor1_rev=24; 3:rotor1_rev=6; 4:rotor1_rev=0; 5:rotor1_rev=3; 6:rotor1_rev=5; 7:rotor1_rev=15; 8:rotor1_rev=21; 9:rotor1_rev=25; 10:rotor1_rev=1; 11:rotor1_rev=4; 12:rotor1_rev=2; 13:rotor1_rev=10; 14:rotor1_rev=12; 15:rotor1_rev=19; 16:rotor1_rev=7; 17:rotor1_rev=23; 18:rotor1_rev=18; 19:rotor1_rev=11; 20:rotor1_rev=17; 21:rotor1_rev=8; 22:rotor1_rev=13; 23:rotor1_rev=16; 24:rotor1_rev=14; 25:rotor1_rev=9; default:rotor1_rev=0; endcase
    endfunction

    // ROTOR II
    function [4:0] rotor2_fwd; input [4:0] x;
        case (x) 0:rotor2_fwd=0; 1:rotor2_fwd=9; 2:rotor2_fwd=3; 3:rotor2_fwd=10; 4:rotor2_fwd=18; 5:rotor2_fwd=8; 6:rotor2_fwd=17; 7:rotor2_fwd=20; 8:rotor2_fwd=23; 9:rotor2_fwd=1; 10:rotor2_fwd=11; 11:rotor2_fwd=7; 12:rotor2_fwd=22; 13:rotor2_fwd=19; 14:rotor2_fwd=12; 15:rotor2_fwd=2; 16:rotor2_fwd=16; 17:rotor2_fwd=6; 18:rotor2_fwd=25; 19:rotor2_fwd=13; 20:rotor2_fwd=15; 21:rotor2_fwd=24; 22:rotor2_fwd=5; 23:rotor2_fwd=21; 24:rotor2_fwd=14; 25:rotor2_fwd=4; default:rotor2_fwd=0; endcase
    endfunction
    function [4:0] rotor2_rev; input [4:0] x;
        case (x) 0:rotor2_rev=0; 1:rotor2_rev=9; 2:rotor2_rev=15; 3:rotor2_rev=2; 4:rotor2_rev=25; 5:rotor2_rev=22; 6:rotor2_rev=17; 7:rotor2_rev=11; 8:rotor2_rev=5; 9:rotor2_rev=1; 10:rotor2_rev=3; 11:rotor2_rev=10; 12:rotor2_rev=14; 13:rotor2_rev=19; 14:rotor2_rev=24; 15:rotor2_rev=20; 16:rotor2_rev=16; 17:rotor2_rev=6; 18:rotor2_rev=4; 19:rotor2_rev=13; 20:rotor2_rev=7; 21:rotor2_rev=23; 22:rotor2_rev=12; 23:rotor2_rev=8; 24:rotor2_rev=21; 25:rotor2_rev=18; default:rotor2_rev=0; endcase
    endfunction

    // ROTOR III
    function [4:0] rotor3_fwd; input [4:0] x;
        case (x) 0:rotor3_fwd=1; 1:rotor3_fwd=3; 2:rotor3_fwd=5; 3:rotor3_fwd=7; 4:rotor3_fwd=9; 5:rotor3_fwd=11; 6:rotor3_fwd=2; 7:rotor3_fwd=15; 8:rotor3_fwd=17; 9:rotor3_fwd=19; 10:rotor3_fwd=23; 11:rotor3_fwd=21; 12:rotor3_fwd=25; 13:rotor3_fwd=13; 14:rotor3_fwd=24; 15:rotor3_fwd=4; 16:rotor3_fwd=8; 17:rotor3_fwd=22; 18:rotor3_fwd=6; 19:rotor3_fwd=0; 20:rotor3_fwd=10; 21:rotor3_fwd=12; 22:rotor3_fwd=20; 23:rotor3_fwd=18; 24:rotor3_fwd=16; 25:rotor3_fwd=14; default:rotor3_fwd=0; endcase
    endfunction
    function [4:0] rotor3_rev; input [4:0] x;
        case (x) 0:rotor3_rev=19; 1:rotor3_rev=0; 2:rotor3_rev=6; 3:rotor3_rev=1; 4:rotor3_rev=15; 5:rotor3_rev=2; 6:rotor3_rev=18; 7:rotor3_rev=3; 8:rotor3_rev=16; 9:rotor3_rev=4; 10:rotor3_rev=20; 11:rotor3_rev=5; 12:rotor3_rev=21; 13:rotor3_rev=13; 14:rotor3_rev=25; 15:rotor3_rev=7; 16:rotor3_rev=24; 17:rotor3_rev=8; 18:rotor3_rev=23; 19:rotor3_rev=9; 20:rotor3_rev=22; 21:rotor3_rev=11; 22:rotor3_rev=17; 23:rotor3_rev=10; 24:rotor3_rev=14; 25:rotor3_rev=12; default:rotor3_rev=0; endcase
    endfunction

    // REFLECTOR B
    function [4:0] reflector_b; input [4:0] x;
        case (x) 0:reflector_b=24; 1:reflector_b=17; 2:reflector_b=20; 3:reflector_b=7; 4:reflector_b=16; 5:reflector_b=18; 6:reflector_b=11; 7:reflector_b=3; 8:reflector_b=15; 9:reflector_b=23; 10:reflector_b=13; 11:reflector_b=6; 12:reflector_b=14; 13:reflector_b=10; 14:reflector_b=12; 15:reflector_b=8; 16:reflector_b=4; 17:reflector_b=1; 18:reflector_b=5; 19:reflector_b=25; 20:reflector_b=2; 21:reflector_b=22; 22:reflector_b=21; 23:reflector_b=9; 24:reflector_b=0; 25:reflector_b=19; default:reflector_b=0; endcase
    endfunction

    // --- 2. MEMORIE POZITII ---
    reg [4:0] pos1 = 0;
    reg [4:0] pos2 = 0;
    reg [4:0] pos3 = 0;
    
    // Conectare la iesiri pentru debug
    assign current_pos1 = pos1;
    assign current_pos2 = pos2;
    assign current_pos3 = pos3;
    
    // --- 3. LOGICA COMBINATIONALA (CRIPTARE) ---
    // Aceasta calculeaza rezultatul INSTANT, pe baza pozitiei curente.
    wire [4:0] r3_in, r3_out;
    wire [4:0] r2_in, r2_out;
    wire [4:0] r1_in, r1_out;
    wire [4:0] refl_out;
    wire [4:0] r1_inv_in, r1_inv_out;
    wire [4:0] r2_inv_in, r2_inv_out;
    wire [4:0] r3_inv_in, r3_inv_out;

    // Drumul INAINTE (Intrare -> R3 -> R2 -> R1 -> Reflector)
    assign r3_in  = (char_in + pos3) % 26;
    assign r3_out = (rotor3_fwd(r3_in) + 26 - pos3) % 26;

    assign r2_in  = (r3_out + pos2) % 26;
    assign r2_out = (rotor2_fwd(r2_in) + 26 - pos2) % 26;

    assign r1_in  = (r2_out + pos1) % 26;
    assign r1_out = (rotor1_fwd(r1_in) + 26 - pos1) % 26;

    assign refl_out = reflector_b(r1_out);

    // Drumul INAPOI (Reflector -> R1 -> R2 -> R3 -> Iesire)
    assign r1_inv_in  = (refl_out + pos1) % 26;
    assign r1_inv_out = (rotor1_rev(r1_inv_in) + 26 - pos1) % 26;

    assign r2_inv_in  = (r1_inv_out + pos2) % 26;
    assign r2_inv_out = (rotor2_rev(r2_inv_in) + 26 - pos2) % 26;

    assign r3_inv_in  = (r2_inv_out + pos3) % 26;
    assign r3_inv_out = (rotor3_rev(r3_inv_in) + 26 - pos3) % 26;

    // --- 4. LOGICA SECVENTIALA (CEAS) ---
    always @(posedge clk) begin
        // A. RESETARE TOTALA (Prioritate maxima)
        if (rst) begin
            valid_out <= 0;
            char_out  <= 0;
            pos1 <= 0; 
            pos2 <= 0; 
            pos3 <= 0;
        end 
        
        // B. INCARCARE CONFIGURATIE (Switch-uri)
        else if (load_config) begin 
            pos1 <= start_pos1; 
            pos2 <= start_pos2; 
            pos3 <= start_pos3;
            valid_out <= 0; // Nu scoatem nimic cat timp incarcam
            char_out  <= 0;
        end 
        
        // C. PROCESARE DATE (Doar daca avem valid_in)
        else if (valid_in) begin
            // 1. Capturam rezultatul calculat mai sus
            char_out <= r3_inv_out;
            valid_out <= 1;

            // 2. Rotim rotoarele pentru urmatoarea tasta (Stil Odometru)
            if (pos3 == 25) begin
                pos3 <= 0;
                // Rotire Rotor 2 (Mijloc)
                if (pos2 == 25) begin
                    pos2 <= 0;
                    // Rotire Rotor 1 (Stanga)
                    if (pos1 == 25) pos1 <= 0; 
                    else pos1 <= pos1 + 1;
                end else begin
                    pos2 <= pos2 + 1;
                end
            end else begin
                pos3 <= pos3 + 1;
            end

        end 
        
        // D. IDLE (Nu se intampla nimic)
        else begin
            valid_out <= 0; // Resetam valid_out ca sa fie un puls scurt
        end
    end

endmodule