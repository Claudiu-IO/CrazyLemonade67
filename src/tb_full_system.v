`timescale 1ns / 1ps

module tb_full_system;

    // --- 1. Semnale ---
    reg clk;
    reg rst_pin;
    reg uart_rx_in;     // Aici "PC-ul" trimite date la FPGA
    wire uart_tx_out;   // Aici FPGA-ul raspunde
    wire [15:0] led;

    // --- 2. Constante pentru UART (9600 Baud la 100MHz) ---
    // 100,000,000 / 9600 = 10416 ceasuri per bit
    // Durata unui bit = 10416 * 10ns = 104160ns
    localparam BIT_PERIOD = 104160; 

    // --- 3. Instantierea Modulului Principal (DUT) ---
    modulul_principal uut (
        .clk(clk),
        .rst_pin(rst_pin),
        .uart_rx_in(uart_rx_in),
        .uart_tx_out(uart_tx_out),
        .led(led)
    );

    // --- 4. Generator de Ceas ---
    always #5 clk = ~clk; // 10ns perioada (100MHz)

    // --- 5. TASK: Functia care mimeaza tastatura PC-ului ---
    task UART_WRITE_BYTE;
        input [7:0] i_Data;
        integer     ii;
        begin
            // Bit de START (0)
            uart_rx_in = 0;
            #(BIT_PERIOD);
            
            // Cei 8 biti de date (LSB first)
            for (ii=0; ii<8; ii=ii+1) begin
                uart_rx_in = i_Data[ii];
                #(BIT_PERIOD);
            end
            
            // Bit de STOP (1)
            uart_rx_in = 1;
            #(BIT_PERIOD);
        end
    endtask

    // --- 6. Scenariul de Test ---
    initial begin
        // Initializare
        clk = 0;
        rst_pin = 1; // Reset activ
        uart_rx_in = 1; // Linia UART sta in 1 cand e libera (Idle)
        
        // Tinem reset-ul putin
        #1000;
        rst_pin = 0; // Eliberam reset-ul
        #1000;

        // --- TEST 1: Intram in meniul START ---
        // FPGA-ul ne arata meniul. Noi trimitem 'S' (cod ASCII 83 sau 0x53)
        $display("PC: Trimit tasta 'S'...");
        UART_WRITE_BYTE("S");
        
        // Asteptam putin sa proceseze FPGA-ul (timp de procesare + printare text CRYPT)
        // Fiind serial, dureaza mult (milisecunde)
        #(BIT_PERIOD * 20); 

        // --- TEST 2: Trimitem litera 'A' pentru criptare ---
        $display("PC: Trimit tasta 'A'...");
        UART_WRITE_BYTE("A");

        // Asteptam sa vedem raspunsul pe linia uart_tx_out
        #(BIT_PERIOD * 20);

        $display("SIMULARE GATA.");
        $stop;
    end

endmodule
