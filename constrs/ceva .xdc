## Acest fisier mapeaza codul Verilog la pinii fizici Nexys A7-100T

## 1. CEASUL (Clock signal - 100MHz)
## Pinul fizic E3 -> Numele din cod: clk
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];

## 2. BUTONUL DE RESET (Folosim butonul din Centru)
## Pinul fizic N17 -> Numele din cod: btnC
set_property -dict { PACKAGE_PIN N17   IOSTANDARD LVCMOS33 } [get_ports { btnC }];

## 3. UART (USB-RS232)
## RX (Date de la PC la FPGA) - Pin C4 -> Numele din cod: RsRx
set_property -dict { PACKAGE_PIN C4    IOSTANDARD LVCMOS33 } [get_ports { RsRx }];
## TX (Date de la FPGA la PC) - Pin D4 -> Numele din cod: RsTx
set_property -dict { PACKAGE_PIN D4    IOSTANDARD LVCMOS33 } [get_ports { RsTx }];

## 4. AFISAJ 7 SEGMENTE (Catozii - Segmentele A-G)
## Numele din cod: seg[0] ... seg[6]
set_property -dict { PACKAGE_PIN T10   IOSTANDARD LVCMOS33 } [get_ports { seg[0] }]; # CA
set_property -dict { PACKAGE_PIN R10   IOSTANDARD LVCMOS33 } [get_ports { seg[1] }]; # CB
set_property -dict { PACKAGE_PIN K16   IOSTANDARD LVCMOS33 } [get_ports { seg[2] }]; # CC
set_property -dict { PACKAGE_PIN K13   IOSTANDARD LVCMOS33 } [get_ports { seg[3] }]; # CD
set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 } [get_ports { seg[4] }]; # CE
set_property -dict { PACKAGE_PIN T11   IOSTANDARD LVCMOS33 } [get_ports { seg[5] }]; # CF
set_property -dict { PACKAGE_PIN L18   IOSTANDARD LVCMOS33 } [get_ports { seg[6] }]; # CG

## 5. AFISAJ 7 SEGMENTE (Anozii - Care cifra se aprinde)
## Numele din cod: an[0] ... an[3]
set_property -dict { PACKAGE_PIN J17   IOSTANDARD LVCMOS33 } [get_ports { an[0] }]; # AN0
set_property -dict { PACKAGE_PIN J18   IOSTANDARD LVCMOS33 } [get_ports { an[1] }]; # AN1
set_property -dict { PACKAGE_PIN T9    IOSTANDARD LVCMOS33 } [get_ports { an[2] }]; # AN2
set_property -dict { PACKAGE_PIN J14   IOSTANDARD LVCMOS33 } [get_ports { an[3] }]; # AN3

## 6. LED-uri (Optional - pentru debug daca vrei)
## Decomenteaza daca adaugi "output [4:0] led" in modul_principal
# set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
# set_property -dict { PACKAGE_PIN K15   IOSTANDARD LVCMOS33 } [get_ports { led[1] }];