module modul_principal(
    input clk,          // Pin E3 (Ceas 100MHz)
    input btnC,         // Buton Reset (Pin N17)
    input RsRx,         // UART RX (Pin C4)
    output RsTx,        // UART TX (Pin D4)
    output [6:0] seg,   // Pentru 7 segmente
    output [3:0] an     // Anozii 7 segmente
);

    // Semnale interne (firele care leaga modulele intre ele)
    wire rst_clean;
    wire [7:0] rx_byte;
    wire rx_done;
    wire [7:0] tx_byte;
    wire tx_busy;
    
    // Semnale pentru Enigma
    wire [4:0] enigma_in;
    wire [4:0] enigma_out;
    wire enigma_ready;

    // 1. Curatam butonul de reset (folosind fisierul butoane.v)
    debouncer instanta_btn (
        .clk(clk),
        .btn_in(btnC),
        .btn_out(rst_clean)
    );

    // 2. UART Receiver (Primim date de la PC)
    uart_rx instanta_rx (
        .clk(clk),
        .rx_serial(RsRx),
        .rx_byte(rx_byte),
        .rx_done(rx_done)
    );

    // 3. Logica de conversie ASCII -> Index (0-25)
    // Acceptam doar litere mari (A=65 ... Z=90)
    wire is_capital = (rx_byte >= 65 && rx_byte <= 90);
    assign enigma_in = rx_byte - 65; // 'A' devine 0

    // 4. INSTANTIERE NUCLEU ENIGMA (Aici e schimbarea de nume!)
    nucleu_enigma instanta_nucleu (
        .clk(clk),
        .rst(rst_clean),
        .valid_in(rx_done && is_capital), // Procesam doar daca e litera mare valida
        .char_in(enigma_in),
        .char_out(enigma_out),
        .valid_out(enigma_ready)
    );

    // 5. Logica de conversie Index -> ASCII (pt trimitere inapoi)
    assign tx_byte = enigma_out + 65; // 0 devine 'A'

    // 6. UART Transmitter (Trimitem date la PC)
    uart_tx instanta_tx (
        .clk(clk),
        .tx_start(enigma_ready), // Trimitem cand Nucleul a terminat
        .tx_din(tx_byte),
        .tx_active(tx_busy),
        .tx_serial(RsTx),
        .tx_done()
    );

    // 7. Afisare pe 7 Segmente (Debug visual)
    ssd_ctrl instanta_afisaj (
        .clk(clk),
        .number({3'b0, enigma_ready, 4'b0, rx_byte}), // Afisam ultima litera primita
        .seg(seg),
        .an(an)
    );

endmodule