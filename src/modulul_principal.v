`timescale 1ns / 1ps

module modulul_principal(
    input clk,              // Ceasul placii (100 MHz)
    input rst_pin,          // Buton Reset (M18 - BTNU)
    input load_btn,         // Buton incarcare (N17 - BTNC)
    input [15:0] sw,        // Cele 16 Switch-uri
    input uart_rx_in,       // USB-RS232 RX
    output uart_tx_out,     // USB-RS232 TX
    output [15:0] led,      // LED-uri (pt debug)
    output [6:0] seg,       // 7-Segmente Catozi
    output [7:0] an         // 7-Segmente Anozi
);

    // --- 1. SEMNALE INTERNE ---
    wire reset_clean;       
    wire load_clean;        
    
    // Fire pentru UART
    wire [7:0] rx_data_ascii;
    wire rx_done_tick;
    reg [7:0] tx_data_ascii;
    reg tx_start_tick;
    wire tx_done_tick;
    wire tx_active;

    // Fire pentru Enigma
    reg [4:0] enigma_in_index;  
    reg enigma_valid_in;
    wire [4:0] enigma_out_index;
    wire enigma_valid_out;
    
    // Fire pentru pozitii
    wire [4:0] pos1_wire, pos2_wire, pos3_wire;

    // --- 2. DIVIZOR DE CEAS (SOLUTIA PENTRU TIMING ERROR) ---
    // Numaram ceasurile pentru a crea unul mai lent pentru Enigma
    // 100 MHz / 8 = 12.5 MHz. Suficient de lent ca sa nu mai ai erori.
    reg [2:0] clk_cnt = 0;
    always @(posedge clk) begin
        clk_cnt <= clk_cnt + 1;
    end
    wire clk_slow_enigma;
    assign clk_slow_enigma = clk_cnt[2]; // Bitul 2 divide frecventa la 8

    // --- 3. LOGICA DE CONTROL ---
    assign reset_clean = rst_pin; 
    assign load_clean = load_btn;

    // --- 4. UART RECEIVER (Ramane la 100MHz!) ---
    uart_rx #(
        .CLKS_PER_BIT(10416) // 100MHz / 9600 baud
    ) inst_rx (
        .clk(clk),
        .rx_serial(uart_rx_in),
        .rx_byte(rx_data_ascii),
        .rx_done(rx_done_tick)
    );

    // --- 5. LOGICA CONVERSIE ASCII -> INDEX ---
    // Aceasta trebuie sa mearga pe ceasul rapid sa prinda UART-ul, 
    // dar transferul catre Enigma (lenta) e ok pt ca valid-ul sta 1 ceas
    always @(posedge clk) begin
        if (rx_done_tick) begin
            if (rx_data_ascii >= 8'h41 && rx_data_ascii <= 8'h5A) begin
                enigma_in_index <= rx_data_ascii - 8'h41; 
                enigma_valid_in <= 1;
            end 
            else if (rx_data_ascii >= 8'h61 && rx_data_ascii <= 8'h7A) begin
                enigma_in_index <= rx_data_ascii - 8'h61; 
                enigma_valid_in <= 1;
            end
            else begin
                enigma_valid_in <= 0; 
            end
        end else begin
            enigma_valid_in <= 0;
        end
    end

    // --- 6. NUCLEUL ENIGMA (Ruleaza pe CEASUL LENT) ---
    nucleu_enigma inst_enigma (
        .clk(clk_slow_enigma),    // <--- AICI ESTE SECRETUL FIX-ULUI!
        .rst(reset_clean),
        
        .start_pos1(sw[14:10]), 
        .start_pos2(sw[9:5]),   
        .start_pos3(sw[4:0]),   
        .load_config(load_clean),
        
        .valid_in(enigma_valid_in),
        .char_in(enigma_in_index),
        
        .char_out(enigma_out_index),
        .valid_out(enigma_valid_out),
        
        .current_pos1(pos1_wire),
        .current_pos2(pos2_wire),
        .current_pos3(pos3_wire)
    );

    // --- 7. CONVERSIE INDEX -> ASCII ---
    // Trebuie sa sincronizam semnalul de la ceasul lent la cel rapid
    // Dar pentru un proiect simplu, fiindca Enigma e lenta, merge direct
    reg valid_out_old;
    always @(posedge clk) begin
        valid_out_old <= enigma_valid_out;
        
        // Detectam frontul pozitiv al semnalului valid de la Enigma
        if (enigma_valid_out && !valid_out_old) begin
            tx_data_ascii <= enigma_out_index + 8'h41;
            tx_start_tick <= 1;
        end else begin
            tx_start_tick <= 0;
        end
    end

    // --- 8. UART TRANSMITTER (Ramane la 100MHz!) ---
    uart_tx #(
        .CLKS_PER_BIT(10416)
    ) inst_tx (
        .clk(clk),
        .tx_start(tx_start_tick),
        .tx_din(tx_data_ascii),
        .tx_active(tx_active), 
        .tx_serial(uart_tx_out), 
        .tx_done(tx_done_tick)   
    );

    // --- 9. AFISARE SI LED-URI ---
    wire [15:0] display_hex = {4'b0, pos1_wire[3:0], pos2_wire[3:0], pos3_wire[3:0]};

    ssd_ctrl inst_ssd (
        .clk(clk),
        .number(display_hex), 
        .seg(seg),
        .an(an)
    );

    assign led = sw; 

endmodule