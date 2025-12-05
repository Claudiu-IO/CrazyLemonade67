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
    wire tx_done;       
    wire tx_active;

    // --- DETECTOR DE FRONT & PULSE STRETCHER ---
    reg old_rx_done; 
    reg [4:0] pulse_timer = 0; // Timer pentru a lungi semnalul catre Enigma

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
    
    function [7:0] get_char_msg;
        input [2:0] sel;
        input [7:0] idx;
        begin
            case(sel)
                // MENIU PRINCIPAL
                0: case(idx)
                   0: get_char_msg = 13;  1: get_char_msg = 10; 
                   2: get_char_msg = "M"; 3: get_char_msg = "E"; 4: get_char_msg = "N"; 5: get_char_msg = "U";
                   6: get_char_msg = ":"; 7: get_char_msg = " "; 8: get_char_msg = "["; 9: get_char_msg = "P";
                   10: get_char_msg = "]"; 11: get_char_msg = "l"; 12: get_char_msg = "u"; 13: get_char_msg = "g";
                   14: get_char_msg = ","; 15: get_char_msg = " "; 16: get_char_msg = "["; 17: get_char_msg = "S";
                   18: get_char_msg = "]"; 19: get_char_msg = "t"; 20: get_char_msg = "a"; 21: get_char_msg = "r";
                   22: get_char_msg = "t"; 23: get_char_msg = ">"; 24: get_char_msg = 0; 
                   default: get_char_msg = 0;
                   endcase
                // PLUGBOARD
                1: case(idx)
                   0: get_char_msg = 13;  1: get_char_msg = 10;
                   2: get_char_msg = "P"; 3: get_char_msg = "l"; 4: get_char_msg = "u"; 5: get_char_msg = "g";
                   6: get_char_msg = "("; 7: get_char_msg = "A"; 8: get_char_msg = "B"; 9: get_char_msg = ")";
                   10: get_char_msg = ":"; 11: get_char_msg = 0;
                   default: get_char_msg = 0;
                   endcase
                // CRYPT
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
    localparam STATE_PRINT_CHECK= 1; 
    localparam STATE_PRINT_SEND = 2; 
    localparam STATE_PRINT_WAIT = 3; 
    localparam STATE_MENU       = 4; 
    localparam STATE_PLUG_1     = 5;
    localparam STATE_PLUG_2     = 6;
    localparam STATE_CRYPT      = 7;

    reg [3:0] state = STATE_INIT;
    reg [3:0] return_state; 
    
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
        old_rx_done <= rx_done;
        
        if (reset_clean) begin
            state <= 0;
            tx_start <= 0;
            pulse_timer <= 0;
  
        end else begin
        
            if (tx_start == 1) tx_start <= 0;

            // --- PULSE STRETCHER LOGIC (NOU) ---
            // Tinem semnalul valid sus timp de 16 ceasuri (160ns)
            // Asta garanteaza ca ceasul lent (80ns) il prinde
            if (pulse_timer > 0) begin
                enigma_valid <= 1;
                pulse_timer <= pulse_timer - 1;
            end else begin
                enigma_valid <= 0;
            end

            case (state)
                // INIT & PRINT logic
                STATE_INIT: begin
                    msg_select <= 0; msg_index <= 0;
                    return_state <= STATE_MENU; state <= STATE_PRINT_CHECK;
                end
                STATE_PRINT_CHECK: begin
                    char_to_send = get_char_msg(msg_select, msg_index);
                    if (char_to_send == 0) state <= return_state; 
                    else state <= STATE_PRINT_SEND;
                end
                STATE_PRINT_SEND: begin
                    if (tx_active == 0) begin
                        tx_data <= char_to_send; tx_start <= 1; state <= STATE_PRINT_WAIT;
                    end
                end
                STATE_PRINT_WAIT: begin
                    if (tx_done == 1) begin
                        msg_index <= msg_index + 1; state <= STATE_PRINT_CHECK;
                    end
                end

                // MENIU
                STATE_MENU: begin
                    if (rx_done && !old_rx_done) begin
                        if (rx_data == "P" || rx_data == "p") begin
                            msg_select <= 1; msg_index <= 0;
                            return_state <= STATE_PLUG_1; state <= STATE_PRINT_CHECK;
                        end
                        else if (rx_data == "S" || rx_data == "s") begin
                            msg_select <= 3; msg_index <= 0;
                            return_state <= STATE_CRYPT; state <= STATE_PRINT_CHECK;
                        end
                    end
                end

                // PLUGBOARD
                STATE_PLUG_1: begin
                    if (rx_done && !old_rx_done) begin
                        if (rx_data == "X" || rx_data == "x") state <= STATE_INIT; 
                        else if (rx_data >= "A" && rx_data <= "Z") begin
                            tx_data <= rx_data; tx_start <= 1; 
                            pb_char1 <= rx_data - "A";
                            state <= STATE_PLUG_2;
                        end
                    end
                end
                STATE_PLUG_2: begin
                    if (rx_done && !old_rx_done) begin
                        if (rx_data >= "A" && rx_data <= "Z") begin
                            tx_data <= rx_data; tx_start <= 1; 
                            plugboard_mem[pb_char1] <= rx_data - "A";
                            plugboard_mem[rx_data - "A"] <= pb_char1;
                            state <= STATE_PLUG_1; 
                        end
                    end
                end

                // CRIPTARE CU FIX PENTRU CLOCK LENT
                STATE_CRYPT: begin
                    // 1. Primire de la PC
                    if (rx_done && !old_rx_done) begin
                        if (rx_data == 27) state <= STATE_INIT; 
                        else if (rx_data >= "A" && rx_data <= "Z") begin
                            enigma_in <= plugboard_mem[rx_data - "A"];
                            
                            // AICI E SCHIMBAREA: Nu setam enigma_valid direct, ci pornim timerul
                            pulse_timer <= 16; // 160ns puls -> Destul pentru ceasul de 80ns
                        end
                    end
                    
                    // 2. Primire de la Enigma
                    if (enigma_valid_out && !old_valid_out) begin
                         tx_data <= plugboard_mem[enigma_out] + "A";
                         tx_start <= 1;
                    end
                end
            endcase
            
            old_valid_out <= enigma_valid_out;
        end
    end

    // Instantiere Enigma
    nucleu_enigma inst_enigma (
        .clk(clk_slow_enigma), .rst(reset_clean),
        .start_pos1(5'd0), .start_pos2(5'd0), .start_pos3(5'd0), .load_config(1'b0),
        .valid_in(enigma_valid), .char_in(enigma_in),
        .char_out(enigma_out), .valid_out(enigma_valid_out),
        .current_pos1(d1), .current_pos2(d2), .current_pos3(d3)
    );
    
    // Led 3-0: Arata in ce STARE se afla masina (Init, Menu, Crypt, etc)
    assign led[3:0]   = state;
    
    // Led 7-4: Le punem pe ZERO ca sa scapam de "Z"-ul albastru
    assign led[7:4]   = 4'b0000;
    
    // Led 15-8: Arata ultimul caracter primit prin UART (ASCII)
    // Nota: Va fi ROSU (X) la inceput pana cand primesti prima tasta. E normal.
    assign led[15:8]  = rx_data;

endmodule