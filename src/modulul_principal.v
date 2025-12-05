`timescale 1ns / 1ps

module modulul_principal(
    input clk,              // Ceasul placi (100 MHz)
    input rst_pin,          // Buton Reset (ex: CPU_RESET sau BTNU)
    input load_btn,         // Buton incarcare switch-uri (ex: BTNC)
    input [15:0] sw,        // Cele 16 Switch-uri
    input uart_rx_in,       // USB-RS232 RX
    output uart_tx_out,     // USB-RS232 TX
    output [15:0] led,      // LED-uri (pt debug)
    output [6:0] seg,       // 7-Segmente Catozi
    output [7:0] an         // 7-Segmente Anozi
);

    // --- 1. SEMNALE INTERNE ---
    wire reset_clean;       // Reset curat
    wire load_clean;        // Load curat
    
    // Fire pentru UART RX (De la PC la FPGA)
    wire [7:0] rx_data_ascii;
    wire rx_done_tick;
    
    // Fire pentru UART TX (De la FPGA la PC)
    reg [7:0] tx_data_ascii;
    reg tx_start_tick;
    wire tx_done_tick;
    wire tx_active;

    // Fire pentru Enigma
    reg [4:0] enigma_in_index;  // 0-25
    reg enigma_valid_in;
    wire [4:0] enigma_out_index;// 0-25
    wire enigma_valid_out;
    
    // Fire pentru pozitii (pt afisare)
    wire [4:0] pos1_wire, pos2_wire, pos3_wire;

    // --- 2. LOGICA DE CONTROL (BUTOANE) ---
    // Pentru hackathon, simplificam (fara debouncer daca nu aveti timp)
    // Daca aveti debouncer, instantiati-l aici. Daca nu:
    assign reset_clean = rst_pin; 
    assign load_clean = load_btn;

    // --- 3. UART RECEIVER (PC -> FPGA) ---
    // Trebuie sa aveti modulul uart_rx in proiect!
    uart_rx #(
        .CLKS_PER_BIT(10416) // 100MHz / 9600 baud
    ) inst_rx (
        .clk(clk),
        .rx_serial(uart_rx_in),
        .rx_byte(rx_data_ascii),
        .rx_done(rx_done_tick)
    );

    // --- 4. LOGICA DE CONVERSIE ASCII -> INDEX (0-25) ---
    always @(posedge clk) begin
        if (rx_done_tick) begin
            // Verificam daca e Litera Mare (A-Z)
            if (rx_data_ascii >= 8'h41 && rx_data_ascii <= 8'h5A) begin
                enigma_in_index <= rx_data_ascii - 8'h41; // 'A'(65) -> 0
                enigma_valid_in <= 1;
            end 
            // Optional: Litera Mica (a-z) -> o transformam in mare
            else if (rx_data_ascii >= 8'h61 && rx_data_ascii <= 8'h7A) begin
                enigma_in_index <= rx_data_ascii - 8'h61; // 'a'(97) -> 0
                enigma_valid_in <= 1;
            end
            else begin
                enigma_valid_in <= 0; // Ignoram alte caractere (Enter, Spatiu)
            end
        end else begin
            enigma_valid_in <= 0;
        end
    end

    // --- 5. INSTANTIEREA NUCLEULUI ENIGMA (CRITIC) ---
    nucleu_enigma inst_enigma (
        .clk(clk),
        .rst(reset_clean),
        
        // AICI LEGĂM SWITCH-URILE LA NOILE INTRĂRI
        .start_pos1(sw[14:10]), // Rotor Stanga (I)
        .start_pos2(sw[9:5]),   // Rotor Mijloc (II)
        .start_pos3(sw[4:0]),   // Rotor Dreapta (III)
        .load_config(load_clean), // Cand apasam butonul, se incarca valorile
        
        .valid_in(enigma_valid_in),
        .char_in(enigma_in_index),
        
        .char_out(enigma_out_index),
        .valid_out(enigma_valid_out),
        
        // Legam pozitiile curente la fire ca sa le afisam
        .current_pos1(pos1_wire),
        .current_pos2(pos2_wire),
        .current_pos3(pos3_wire)
    );

    // --- 6. LOGICA DE CONVERSIE INDEX -> ASCII ---
    always @(posedge clk) begin
        if (enigma_valid_out) begin
            tx_data_ascii <= enigma_out_index + 8'h41; // 0 -> 'A'(65)
            tx_start_tick <= 1;
        end else begin
            tx_start_tick <= 0;
        end
    end

   // --- 7. UART TRANSMITTER (FPGA -> PC) ---
    uart_tx #(
        .CLKS_PER_BIT(10416)
    ) inst_tx (
        .clk(clk),
        // .reset_n(~reset_clean),  <--- STERGE LINIA ASTA COMPLET!
        .tx_start(tx_start_tick),
        .tx_din(tx_data_ascii),
        // .s_tick(1'b1), <--- STERGE SI ASTA daca nu ai port s_tick in codul tau
        .tx_active(tx_active), // <--- SCHIMBAT NUMELE: la tine e tx_active, nu o_busy
        .tx_serial(uart_tx_out), // <--- SCHIMBAT NUMELE: la tine e tx_serial, nu tx
        .tx_done(tx_done_tick)   // <--- SCHIMBAT NUMELE: la tine e tx_done, nu tx_done_tick
    );

    // --- 8. AFISARE PE 7-SEGMENTE ---
    // Vrem sa afisam pozitiile: R1 R2 R3 (ex: 01 05 24)
    // Modulul ssd_ctrl afiseaza un numar HEX de 16 biti.
    // Concatenam pozitiile: {0, pos1, pos2, pos3}
    // Obs: Asta va afisa in Hex (A=10, F=15). E ok pt hackathon.
    
    wire [15:0] display_number;
    assign display_number = {1'b0, pos1_wire, pos2_wire, pos3_wire}; 
    // Nota: Asta e o aproximare rapida. Ideal ar fi {pos1[3:0], pos2[3:0], pos3[3:0]} 
    // dar sunt numere pe 5 biti.
    // Varianta mai buna vizual (doar ultimii 4 biti din fiecare):
    wire [15:0] display_hex = {4'b0, pos1_wire[3:0], pos2_wire[3:0], pos3_wire[3:0]};

    // Trebuie sa aveti modulul ssd_ctrl in proiect!
    ssd_ctrl inst_ssd (
        .clk(clk),
        .number(display_hex), 
        .seg(seg),
        .an(an)
    );

    // --- 9. LED-uri DEBUG ---
    // Aprindem LED-urile corespunzatoare switch-urilor ca sa vedem ce am setat
    assign led = sw; 

endmodule