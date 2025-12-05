`timescale 1ns / 1ps

module modulul_principal(
    input clk,              // 100 MHz
    input rst_pin,          // Reset (Btn SUS - M18)
    input uart_rx_in,       // RX (C4)
    output uart_tx_out,     // TX (D4)
    output [15:0] led       // Debug LEDs
);

    // --- 1. SETUP ---
    wire reset_clean = rst_pin;
    
    // Divizor ceas Enigma (12.5 MHz)
    reg [2:0] clk_cnt = 0;
    always @(posedge clk) clk_cnt <= clk_cnt + 1;
    wire clk_slow_enigma = clk_cnt[2];

    // Fire UART
    wire [7:0] rx_data;
    wire rx_done;
    reg [7:0] tx_data;
    reg tx_start;
    wire tx_done;       // Semnal critic: ne spune cand s-a terminat trimiterea
    wire tx_active;

    // Instantiere UART
    uart_rx #(.CLKS_PER_BIT(10416)) inst_rx (
        .clk(clk), .rx_serial(uart_rx_in), .rx_byte(rx_data), .rx_done(rx_done)
    );

    uart_tx #(.CLKS_PER_BIT(10416)) inst_tx (
        .clk(clk), .tx_start(tx_start), .tx_din(tx_data), .tx_active(tx_active), 
        .tx_serial(uart_tx_out), .tx_done(tx_done)
    );

    // --- 2. TEXTE (ROM) ---
    reg [7:0] char_to_send;
    reg [7:0] msg_index;
    reg [2:0] msg_select; 
    
    // Functie care returneaza litera de la indexul curent
    function [7:0] get_char_msg;
        input [2:0] sel;
        input [7:0] idx;
        begin
            case(sel)
                // 0: MENIU PRINCIPAL
                0: case(idx)
                   0: get_char_msg = 13;  1: get_char_msg = 10; // New Line
                   2: get_char_msg = "M"; 3: get_char_msg = "E"; 4: get_char_msg = "N"; 5: get_char_msg = "U";
                   6: get_char_msg = ":"; 7: get_char_msg = " "; 8: get_char_msg = "["; 9: get_char_msg = "P";
                   10: get_char_msg = "]"; 11: get_char_msg = "l"; 12: get_char_msg = "u"; 13: get_char_msg = "g";
                   14: get_char_msg = ","; 15: get_char_msg = " "; 16: get_char_msg = "["; 17: get_char_msg = "S";
                   18: get_char_msg = "]"; 19: get_char_msg = "t"; 20: get_char_msg = "a"; 21: get_char_msg = "r";
                   22: get_char_msg = "t"; 23: get_char_msg = ">"; 24: get_char_msg = 0; // NULL terminator
                   default: get_char_msg = 0;
                   endcase
                
                // 1: PLUGBOARD PROMPT
                1: case(idx)
                   0: get_char_msg = 13;  1: get_char_msg = 10;
                   2: get_char_msg = "P"; 3: get_char_msg = "l"; 4: get_char_msg = "u"; 5: get_char_msg = "g";
                   6: get_char_msg = "("; 7: get_char_msg = "A"; 8: get_char_msg = "B"; 9: get_char_msg = ")";
                   10: get_char_msg = ":"; 11: get_char_msg = 0;
                   default: get_char_msg = 0;
                   endcase
                
                // 3: CRYPT PROMPT
                3: case(idx)
                   0: get_char_msg = 13;  1: get_char_msg = 10;
                   2: get_char_msg = "C"; 3: get_char_msg = "R"; 4: get_char_msg = "Y"; 5: get_char_msg = "P";
                   6: get_char_msg = "T"; 7: get_char_msg = ":"; 8: get_char_msg = 0;
                   default: get_char_msg = 0;
                   endcase
                   
                default: get_char_msg = 0;
            endcase
        end
    endfunction

    // --- 3. STATE MACHINE ---
    localparam STATE_INIT       = 0;
    localparam STATE_PRINT_CHECK= 1; // Verifica ce litera urmeaza
    localparam STATE_PRINT_SEND = 2; // Da comanda la UART
    localparam STATE_PRINT_WAIT = 3; // Asteapta sa termine UART
    localparam STATE_MENU       = 4; // Asteapta tasta utilizator
    localparam STATE_PLUG_1     = 5;
    localparam STATE_PLUG_2     = 6;
    localparam STATE_CRYPT      = 7;

    reg [3:0] state = STATE_INIT;
    reg [3:0] return_state; // Unde ne intoarcem dupa printare
    
    // Memorie Plugboard
    reg [4:0] plugboard_mem [0:25];
    reg [4:0] pb_char1;
    integer i;
    
    // Semnale Enigma
    reg [4:0] enigma_in;
    reg enigma_valid;
    wire [4:0] enigma_out;
    wire enigma_valid_out;
    reg old_valid_out;
    wire [4:0] d1, d2, d3;

    always @(posedge clk) begin
        if (reset_clean) begin
            state <= STATE_INIT;
            tx_start <= 0;
            // Reset Plugboard 1-la-1
            for (i=0; i<26; i=i+1) plugboard_mem[i] <= i;
        end else begin
        
            // Fail-safe: tx_start trebuie sa fie impuls scurt
            if (tx_start == 1) tx_start <= 0;

            case (state)
                // --- INIT ---
                STATE_INIT: begin
                    msg_select <= 0; // Selectam textul MENIU
                    msg_index <= 0;
                    return_state <= STATE_MENU;
                    state <= STATE_PRINT_CHECK;
                end

                // --- LOGICA DE PRINTARE (MODIFICATA) ---
                STATE_PRINT_CHECK: begin
                    char_to_send = get_char_msg(msg_select, msg_index);
                    if (char_to_send == 0) begin
                        state <= return_state; // Text terminat -> Mergem la destinatie
                    end else begin
                        state <= STATE_PRINT_SEND;
                    end
                end

                STATE_PRINT_SEND: begin
                    // Trimitem doar daca UART e liber
                    if (tx_active == 0) begin
                        tx_data <= char_to_send;
                        tx_start <= 1; // Start transmisie
                        state <= STATE_PRINT_WAIT;
                    end
                end

                STATE_PRINT_WAIT: begin
                    // Asteptam semnalul tx_done (hardware-ul zice "Gata, am trimis bitii")
                    if (tx_done == 1) begin
                        msg_index <= msg_index + 1; // Trecem la litera urmatoare
                        state <= STATE_PRINT_CHECK;
                    end
                end

                // --- LOGICA MENIU ---
                STATE_MENU: begin
                    if (rx_done) begin
                        if (rx_data == "P" || rx_data == "p") begin
                            msg_select <= 1; msg_index <= 0;
                            return_state <= STATE_PLUG_1;
                            state <= STATE_PRINT_CHECK;
                        end
                        else if (rx_data == "S" || rx_data == "s") begin
                            msg_select <= 3; msg_index <= 0;
                            return_state <= STATE_CRYPT;
                            state <= STATE_PRINT_CHECK;
                        end
                    end
                end

                // --- PLUGBOARD LOGIC ---
                STATE_PLUG_1: begin
                    if (rx_done) begin
                        if (rx_data == "X" || rx_data == "x") begin
                            state <= STATE_INIT; // Iesire
                        end
                        else if (rx_data >= "A" && rx_data <= "Z") begin
                            // Echo la litera tastata
                            tx_data <= rx_data; tx_start <= 1;
                            
                            pb_char1 <= rx_data - "A";
                            state <= STATE_PLUG_2;
                        end
                    end
                end

                STATE_PLUG_2: begin
                    // Aici e trick-ul: trebuie sa asteptam sa se termine ECHO-ul de la litera 1
                    // Dar pt simplificare, UART-ul se descurca daca tastam incet.
                    if (rx_done) begin
                        if (rx_data >= "A" && rx_data <= "Z") begin
                            // Echo la litera 2
                            tx_data <= rx_data; tx_start <= 1;
                            
                            // Facem schimbul
                            plugboard_mem[pb_char1] <= rx_data - "A";
                            plugboard_mem[rx_data - "A"] <= pb_char1;
                            
                            state <= STATE_PLUG_1; // Cerem urmatoarea pereche
                        end
                    end
                end

                // --- CRYPT LOGIC ---
                STATE_CRYPT: begin
                    enigma_valid <= 0; // default 0
                    
                    // 1. Primire de la PC
                    if (rx_done) begin
                        if (rx_data == 27) state <= STATE_INIT; // ESC
                        else if (rx_data >= "A" && rx_data <= "Z") begin
                            enigma_in <= plugboard_mem[rx_data - "A"];
                            enigma_valid <= 1;
                        end
                    end
                    
                    // 2. Primire de la Enigma si trimitere la PC
                    if (enigma_valid_out && !old_valid_out) begin
                         tx_data <= plugboard_mem[enigma_out] + "A";
                         tx_start <= 1;
                    end
                end
            endcase
            
            old_valid_out <= enigma_valid_out;
        end
    end

    // --- ENIGMA ---
    nucleu_enigma inst_enigma (
        .clk(clk_slow_enigma), .rst(reset_clean),
        .start_pos1(5'd0), .start_pos2(5'd0), .start_pos3(5'd0), .load_config(1'b0),
        .valid_in(enigma_valid), .char_in(enigma_in),
        .char_out(enigma_out), .valid_out(enigma_valid_out),
        .current_pos1(d1), .current_pos2(d2), .current_pos3(d3)
    );
    
    // Debug pe LED-uri: arata starea curenta si ultima tasta primita
    assign led[3:0] = state;
    assign led[15:8] = rx_data;

endmodule