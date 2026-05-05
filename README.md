Universal Asynchronous Receiver/Transmitter (UART) converts parallel byte data as serial bit-streams (Tx) and recieves serial bit-streams of which is converted into parallel byte data.


Implementation of a full-duplex UART controller module 

Key Characteristics:
    - No common clock signal between Tx/Rx, but rather a shared baud rate.
    - Each payload sent contains the data bits, a parity bit (error correction), and start/stop bits