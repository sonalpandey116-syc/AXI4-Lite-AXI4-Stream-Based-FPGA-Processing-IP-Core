## =========================================================
## Digilent Basys 3 - XC7A35T-1CPG236C
## 100 MHz system clock
## =========================================================

## CLOCK
set_property -dict {PACKAGE_PIN W5 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports clk]

## CENTER BUTTON - RESET
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports btnC]

## SWITCHES SW0-SW2
set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS33} [get_ports {sw[0]}]
set_property -dict {PACKAGE_PIN V16 IOSTANDARD LVCMOS33} [get_ports {sw[1]}]
set_property -dict {PACKAGE_PIN W16 IOSTANDARD LVCMOS33} [get_ports {sw[2]}]

## LED0-LED7
set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN E19 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN U19 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN V19 IOSTANDARD LVCMOS33} [get_ports {led[3]}]
set_property -dict {PACKAGE_PIN W18 IOSTANDARD LVCMOS33} [get_ports {led[4]}]
set_property -dict {PACKAGE_PIN U15 IOSTANDARD LVCMOS33} [get_ports {led[5]}]
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports {led[6]}]
set_property -dict {PACKAGE_PIN V14 IOSTANDARD LVCMOS33} [get_ports {led[7]}]

set_load 5.000 [all_outputs]
set_property LOAD 5 [get_ports {led[0]}]
set_property LOAD 5 [get_ports {led[1]}]
set_property LOAD 5 [get_ports {led[2]}]
set_property LOAD 5 [get_ports {led[3]}]
set_property LOAD 5 [get_ports {led[4]}]
set_property LOAD 5 [get_ports {led[5]}]
set_property LOAD 5 [get_ports {led[6]}]
set_property LOAD 5 [get_ports {led[7]}]
