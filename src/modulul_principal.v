`timescale 1ns / 1ps

module modulul_principal(
    input clk,              // 100 MHz
    input rst_pin,          // Reset
    input uart_rx_in,       // RX
    output uart_tx_out,     // TX
    output [15:0] led       // Debug LEDs
);

    // --- 1. SETĂRI UART & CEAS ---
    wire reset_clean = rst_pin;
    
    // Divizor de ceas pentru Enigma (Slow Clock - 12.5 MHz)
    reg [2:0] clk_cnt = 0;
    always @(posedge clk) clk_cnt <= clk_cnt + 1;
    wire clk_slow_enigma = clk_cnt[2];

    // UART Signals
    wire [7:0] rx_data;
    wire rx_done;
    reg [7:0] tx_data;
    reg tx_start;
    wire tx_done;
    wire tx_active;

    // Instantiere UART RX
    uart_rx #(.CLKS_PER_BIT(10416)) inst_rx (
        .clk(clk), .rx_serial(uart_rx_in), .rx_byte(rx_data), .rx_done(rx_done)
    );

    // Instantiere UART TX
    uart_tx #(.CLKS_PER_BIT(10416)) inst_tx (
        .clk(clk), .tx_start(tx_start), .tx_din(tx_data), .tx_active(tx_active), 
        .tx_serial(uart_tx_out), .tx_done(tx_done)
    );


    // PLUGBOARD (Harta de mapare 0-25)
    // Initial: 0->0, 1->1 (fara modificari)
    reg [4:0] plugboard_mem [0:25];
    integer i;
    
    // ROTOARE (Ordinea)
    reg [1:0] rotor_order [0:2]; // 3 pozitii, valori 1,2,3
    
    // State Machine
    localparam STATE_INIT       = 0;
    localparam STATE_MENU       = 1;
    localparam STATE_WAIT_KEY   = 2;
    localparam STATE_PLUG_1     = 3; // Asteapta prima litera
    localparam STATE_PLUG_2     = 4; // Asteapta a doua litera
    localparam STATE_ROTOR      = 5;
    localparam STATE_CRYPT      = 6;
    localparam STATE_PRINT      = 7; // Printeaza un mesaj

    reg [3:0] state = STATE_INIT;
    reg [3:0] return_state;      // Unde ne intoarcem dupa print
    
    // Buffer pentru literele de plugboard
    reg [4:0] pb_char1;
    reg [4:0] pb_char2;
    reg [3:0] rotor_idx_count;

    // --- 3. LOGICA TEXTELOR (ROM SIMPLU) ---
    reg [7:0] char_to_send;
    reg [7:0] msg_index;
    reg [1:0] msg_select; // 0=Menu, 1=PlugPrompt, 2=RotorPrompt, 3=CryptMsg
    
    // Functie primitiva pentru a selecta caracterul din mesaj
    function [7:0] get_char_msg;
        input [1:0] sel;
        input [7:0] idx;
        begin
            case(sel)
                0: case(idx) // Meniu Principal
                   0: get_char_msg = "M"; 1: get_char_msg = "E"; 2: get_char_msg = "N"; 3: get_char_msg = "U";
                   4: get_char_msg = ":"; 5: get_char_msg = " "; 6: get_char_msg = "["; 7: get_char_msg = "P";
                   8: get_char_msg = "]"; 9: get_char_msg = "l"; 10: get_char_msg = "u"; 11: get_char_msg = "g";
                   12: get_char_msg = ","; 13: get_char_msg = " "; 14: get_char_msg = "["; 15: get_char_msg = "R";
                   16: get_char_msg = "]"; 17: get_char_msg = "o"; 18: get_char_msg = "t"; 19: get_char_msg = ",";
                   20: get_char_msg = " "; 21: get_char_msg = "["; 22: get_char_msg = "S"; 23: get_char_msg = "]";
                   24: get_char_msg = "t"; 25: get_char_msg = "a"; 26: get_char_msg = "r"; 27: get_char_msg = "t";
                   28: get_char_msg = 13;  29: get_char_msg = 10; 30: get_char_msg = ">"; 31: get_char_msg = 0;
                   default: get_char_msg = 0;
                   endcase
                1: case(idx) // Plugboard Prompt
                   0: get_char_msg = "P"; 1: get_char_msg = "l"; 2: get_char_msg = "u"; 3: get_char_msg = "g";
                   4: get_char_msg = "("; 5: get_char_msg = "A"; 6: get_char_msg = "B"; 7: get_char_msg = ")";
                   8: get_char_msg = ":"; 9: get_char_msg = " "; 10: get_char_msg = 0;
                   default: get_char_msg = 0;
                   endcase
                2: case(idx) // Rotor Prompt
                   0: get_char_msg = "R"; 1: get_char_msg = "o"; 2: get_char_msg = "t"; 3: get_char_msg = "(";
                   4: get_char_msg = "1"; 5: get_char_msg = "2"; 6: get_char_msg = "3"; 7: get_char_msg = ")";
                   8: get_char_msg = ":"; 9: get_char_msg = " "; 10: get_char_msg = 0;
                   default: get_char_msg = 0;
                   endcase
                3: case(idx) // Crypt Mode
                   0: get_char_msg = "C"; 1: get_char_msg = "R"; 2: get_char_msg = "Y"; 3: get_char_msg = "P";
                   4: get_char_msg = "T"; 5: get_char_msg = ":"; 6: get_char_msg = " "; 7: get_char_msg = 0;
                   default: get_char_msg = 0;
                   endcase
            endcase
        end
    endfunction

    // --- 4. MAȘINA DE STĂRI PRINCIPALĂ (CLI) ---
    
    // Enigma Signals connection
    reg [4:0] enigma_in;
    reg enigma_valid;
    wire [4:0] enigma_out;
    wire enigma_valid_out;
    wire [4:0] p1, p2, p3; // pozitii (nefolosite la afisare aici pt simplitate)

    always @(posedge clk) begin
        if (reset_clean) begin
            state <= STATE_INIT;
            tx_start <= 0;
            // Reset plugboard la 1-la-1
            for (i=0; i<26; i=i+1) plugboard_mem[i] <= i;
            rotor_order[0] <= 1; rotor_order[1] <= 2; rotor_order[2] <= 3;
        end else begin
            tx_start <= 0; // Puls default
            enigma_valid <= 0;

            case (state)
                // --- INITIALIZARE ---
                STATE_INIT: begin
                    state <= STATE_PRINT;
                    msg_select <= 0; // MENIU
                    msg_index <= 0;
                    return_state <= STATE_WAIT_KEY;
                end

                // --- TRIMITERE MESAJE SERIALE (PRINT) ---
                STATE_PRINT: begin
                    if (!tx_active && !tx_start) begin
                        char_to_send = get_char_msg(msg_select, msg_index);
                        if (char_to_send == 0) begin
                            state <= return_state; // Am terminat mesajul
                        end else begin
                            tx_data <= char_to_send;
                            tx_start <= 1;
                            msg_index <= msg_index + 1;
                        end
                    end
                end

                // --- ASTEPTARE COMANDA (MENIU) ---
                STATE_WAIT_KEY: begin
                    if (rx_done) begin
                        if (rx_data == "P" || rx_data == "p") begin
                            state <= STATE_PRINT; msg_select <= 1; msg_index <= 0; // Print Plug prompt
                            return_state <= STATE_PLUG_1;
                        end
                        else if (rx_data == "R" || rx_data == "r") begin
                            state <= STATE_PRINT; msg_select <= 2; msg_index <= 0; // Print Rotor prompt
                            return_state <= STATE_ROTOR;
                            rotor_idx_count <= 0;
                        end
                        else if (rx_data == "S" || rx_data == "s") begin
                            state <= STATE_PRINT; msg_select <= 3; msg_index <= 0; // Print Crypt prompt
                            return_state <= STATE_CRYPT;
                        end
                        else begin
                             // Retiparire meniu la tasta gresita
                             state <= STATE_INIT;
                        end
                    end
                end

                // --- CONFIGURARE PLUGBOARD ---
                STATE_PLUG_1: begin
                    if (rx_done) begin
                        // Daca apasa ENTER sau X, iese
                        if (rx_data == 13 || rx_data == "X" || rx_data == "x") state <= STATE_INIT;
                        else if (rx_data >= "A" && rx_data <= "Z") begin
                            pb_char1 <= rx_data - "A";
                            tx_data <= rx_data; tx_start <= 1; // Echo
                            state <= STATE_PLUG_2;
                        end
                        else if (rx_data >= "a" && rx_data <= "z") begin
                            pb_char1 <= rx_data - "a";
                            tx_data <= rx_data; tx_start <= 1; // Echo
                            state <= STATE_PLUG_2;
                        end
                    end
                end

                STATE_PLUG_2: begin
                    if (rx_done) begin
                        if (rx_data >= "A" && rx_data <= "Z") begin
                             pb_char2 <= rx_data - "A";
                             // APLICA SWAP IN MEMORIE
                             plugboard_mem[pb_char1] <= rx_data - "A";
                             plugboard_mem[rx_data - "A"] <= pb_char1;
                             
                             tx_data <= rx_data; tx_start <= 1; // Echo
                             state <= STATE_PLUG_1; // Mai cere o pereche
                        end
                        else if (rx_data >= "a" && rx_data <= "z") begin
                             pb_char2 <= rx_data - "a";
                             // APLICA SWAP IN MEMORIE
                             plugboard_mem[pb_char1] <= rx_data - "a";
                             plugboard_mem[rx_data - "a"] <= pb_char1;

                             tx_data <= rx_data; tx_start <= 1; // Echo
                             state <= STATE_PLUG_1;
                        end
                    end
                end

                // --- CONFIGURARE ROTOARE (Doar stocare valori, nu reconfigurare fizica inca) ---
                STATE_ROTOR: begin
                    if (rx_done) begin
                        if (rx_data >= "1" && rx_data <= "3") begin
                            rotor_order[rotor_idx_count] <= rx_data - "0"; // Stocheaza 1, 2 sau 3
                            tx_data <= rx_data; tx_start <= 1; // Echo
                            
                            if (rotor_idx_count == 2) state <= STATE_INIT; // Daca am bagat 3 cifre, iesim
                            else rotor_idx_count <= rotor_idx_count + 1;
                        end
                        else if (rx_data == "X" || rx_data == "x") state <= STATE_INIT;
                    end
                end

                // --- MODUL DE CRIPTARE (Tastare continua) ---
                STATE_CRYPT: begin
                    if (rx_done) begin
                        if (rx_data == 27) begin // ESCAPE key -> Back to menu
                            state <= STATE_INIT;
                        end
                        else begin
                            // 1. Convertim ASCII -> Index
                            if (rx_data >= "A" && rx_data <= "Z") begin
                                enigma_in <= plugboard_mem[rx_data - "A"]; // Trecem prin Plugboard
                                enigma_valid <= 1;
                            end 
                            else if (rx_data >= "a" && rx_data <= "z") begin
                                enigma_in <= plugboard_mem[rx_data - "a"]; // Trecem prin Plugboard
                                enigma_valid <= 1;
                            end
                            // Altfel ignoram (spatii, enter)
                        end
                    end
                end
            endcase
        end
    end

    reg old_valid_out;
    wire [4:0] final_char_index;
    
    // Mapam iesirea Enigmei inapoi prin Plugboard
    assign final_char_index = plugboard_mem[enigma_out]; 

    always @(posedge clk) begin
        old_valid_out <= enigma_valid_out;
        if (enigma_valid_out && !old_valid_out) begin
            // Avem un caracter nou criptat!
            tx_data <= final_char_index + "A"; // Index -> ASCII
            tx_start <= 1;
        end
    end
    
    nucleu_enigma inst_enigma (
        .clk(clk_slow_enigma),
        .rst(reset_clean),
        // Configuratiile initiale (hardcodate la AAA pt simplitate, sau le poti lega la switchuri daca vrei)
        .start_pos1(0), .start_pos2(0), .start_pos3(0),
        .load_config(0), 
        
        .valid_in(enigma_valid),
        .char_in(enigma_in),
        
        .char_out(enigma_out),
        .valid_out(enigma_valid_out),
        
        .current_pos1(p1), .current_pos2(p2), .current_pos3(p3)
    );
    
    // Debug LEDs - arata starea curenta
    assign led[3:0] = state;
    assign led[15] = clk_slow_enigma;

endmodule