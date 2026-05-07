# UART Module

Implementation of a full-duplex Universal Asynchronous Receiver/Transmitter (UART) controller converts parallel byte data as serial bit-streams (Tx) and receives serial bit-streams of which is converted into parallel byte data.

## Key Characteristics of UART:
- No common clock signal between Tx/Rx, but rather a shared baud rate.
- Each serial frame sent contains the data bits, a possible parity bit (even/odd), and a start/stop bit(s).
- A frame starts with a start bit followed by the LsB of the data bits. After the the MsB data bit has been transmitted, the parity bit is inserted after the data bits. The stop bits after the parity bits mark the completion of a single frame.
- When transmission is not taking place on the serial connection, the line is set to an idle (HIGH) state.

<img src="UART-Controller\images\ATmega128 Datasheet - frame format.png" width="50%">