# Bill of Materials - FIR Accelerator Breakout Board

| Ref | Value | Description | Footprint | Qty |
|---|---|---|---|---|
| U1 | Caravel SoC | SKY130A Caravel QFN-64 | QFN-64 | 1 |
| R1 | 10k | RC filter resistor, GPIO[9] PWM output | R_0402 | 1 |
| C1 | 100nF | RC filter capacitor, f_c=159Hz | C_0402 | 1 |
| C2 | 100nF | Decoupling cap, VCCD | C_0402 | 1 |
| C3 | 100nF | Decoupling cap, VDDA | C_0402 | 1 |
| J1 | GPIO8_IN | Bitstream input header 2-pin | PinHeader_1x02_2.54mm | 1 |
| J2 | ANALOG_OUT | RC-filtered analog output header | PinHeader_1x02_2.54mm | 1 |
| J3 | UART_DEBUG | UART debug header 4-pin (VCC/TX/RX/GND) | PinHeader_1x04_2.54mm | 1 |
| J4 | PWR_3V3 | Power input header (3.3V/GND) | PinHeader_1x02_2.54mm | 1 |

## Notes

- RC lowpass filter on GPIO[9]: R1=10kΩ, C1=100nF → f_c = 1/(2π×10k×100n) = 159 Hz
- In LFSR test mode (CTRL[4]=1), no external input needed on GPIO[8]
- UART header connects to Caravel management core for firmware debug
- All decoupling caps should be placed as close to chip power pins as possible
