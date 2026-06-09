/*

UART RX (8N1)

	- Converts serial connection to 8-bit byte.
	- Pulses "Data Valid" control signal HIGH when full byte is ready.
	- Reception sequence: idle HIGH -> start bit -> data bit LsB ... data bit MsB -> stop bit

Based on ATmega128/L Datasheet (doc2467) - "Data Reception – The USART Receiver"
	- https://ece353.engr.wisc.edu/serial-interfaces/uart-basics

	(1) IDLE:
		wait for rx line to go low (START bit)

	(2) START:
		wait half bit time (sample at half bit)
		confirm rx is still low 

	(3) DATA:
		sample 8 bits, one per bit time

	(4) STOP:
		confirm stop bit is high

	(5) CLEANUP:
		output byte and pulse data valid
*/






// =============================================================================
// Module:      uart_rx.sv
// Description: Parameterized UART receiver.
//              Uses mid-bit sampling (baud_tick_half) for noise immunity.
//              Detects framing errors and optional parity errors.
//              Handshakes via valid/ready interface (AXI-stream style).
//
// Parameters:
//   DATA_BITS - Number of data bits per frame (5–8, default: 8)
//   STOP_BITS - Number of stop bits           (1 or 2,  default: 1)
//   PARITY    - Parity mode                   ("NONE", "ODD", "EVEN")
//
// Interface:
//   rx_data        - Received parallel data byte
//   rx_valid       - Pulsed high for 1 cycle when rx_data is valid
//   rx_ready       - Asserted by upstream when it can accept data
//   rx_pin         - Serial input line
//   frame_err      - Pulsed high when stop bit is not high (framing error)
//   parity_err     - Pulsed high when parity check fails
// =============================================================================

module uart_rx #(
    parameter int    DATA_BITS = 8,
    parameter int    STOP_BITS = 1,
    parameter string PARITY    = "NONE"
)(
    input  logic                    clk,
    input  logic                    rst_n,

    // Baud ticks from baud_gen.sv
    input  logic                    baud_tick,       // Full-period tick
    input  logic                    baud_tick_half,  // Half-period tick (mid-bit sample)

	// Serial input
    input  logic                    rx_pin,

    // Data interface
	input  logic                    rx_ready,
    output logic [DATA_BITS-1:0]    rx_data,
    output logic                    rx_valid,

    // Error flags (1-cycle pulse on error)
    output logic                    frame_err,
    output logic                    parity_err
);

    /*------------------------------------------------------------------------- 
	Dual-Flop Synchronizer — metastability chain for serial input
			- FF1 may go metastable
			- FF2 samples 1 cycle later, FF1 has a clock period to settle
			- Improves MTBF exponentially
			- >2 FFs has diminishing returns in this use-case
	*/
    logic rx_sync0, rx_sync1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync0 <= 1'b1;
            rx_sync1 <= 1'b1;
        end else begin
            rx_sync0 <= rx_pin;
            rx_sync1 <= rx_sync0;
        end
    end

	// -------------------------------------------------------------------------
    // FSM states
    typedef enum logic [2:0] {
        IDLE   
        START    
        DATA   
        PARITY 
        STOP   
    } rx_state_t;

    rx_state_t state, next_state;

    // -------------------------------------------------------------------------
    // Internal signals
    logic [DATA_BITS-1:0]           shift_reg;
    logic [$clog2(DATA_BITS)-1:0]   bit_cnt;
    logic [$clog2(STOP_BITS+1)-1:0] stop_cnt;
    logic                           parity_calc;
    logic                           sample;          // Sample strobe for data bits

    // -------------------------------------------------------------------------
    // Parity check
    always_comb begin
        if (PARITY == "NONE")
            parity_calc = 1'b0;
        else begin
			// XORs all bits of the vector
            parity_calc = ^shift_reg;
            if (PARITY == "ODD")
                parity_calc = ~parity_calc;
        end
    end

    // -------------------------------------------------------------------------
    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // -------------------------------------------------------------------------
    // Datapath registers
    // -------------------------------------------------------------------------
    // Sample data bits on baud_tick (aligned to mid-bit after start detection)
    assign sample = baud_tick;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg  <= '0;
            bit_cnt    <= '0;
            stop_cnt   <= '0;
            rx_data    <= '0;
            rx_valid   <= 1'b0;
            frame_err  <= 1'b0;
            parity_err <= 1'b0;
        end else begin
            // Default pulse signals
            rx_valid   <= 1'b0;
            frame_err  <= 1'b0;
            parity_err <= 1'b0;

            case (state)
                IDLE: begin
                    bit_cnt  <= '0;
                    stop_cnt <= '0;
                end

                // baud_tick_half fires at mid-point of start bit
                // If line is still low it's a real start bit, not a glitch
                START: begin
                    if (baud_tick_half) begin
                        // Glitch filter: if line went high, false start — go back idle
                        // (handled in next-state logic)
                        bit_cnt <= '0;
                    end
                end

                DATA: begin
                    if (sample) begin
                        // Shift in LSB first
                        shift_reg <= {rx_sync1, shift_reg[DATA_BITS-1:1]};
                        bit_cnt   <= bit_cnt + 1'b1;
                    end
                end

                PARITY: begin
                    if (sample) begin
                        // Check received parity bit against calculated
                        if (PARITY != "NONE")
                            parity_err <= (rx_sync1 != parity_calc);
                    end
                end

                STOP: begin
                    if (sample) begin
                        stop_cnt <= stop_cnt + 1'b1;
                        if (!rx_sync1) begin
                            // Stop bit should be high — framing error
                            frame_err <= 1'b1;
                        end else if (stop_cnt == STOP_BITS[$clog2(STOP_BITS+1)-1:0] - 1) begin
                            rx_data  <= shift_reg;
                            rx_valid <= 1'b1;
                        end
                    end
                end

                default: ;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Next-state logic
    // -------------------------------------------------------------------------
    always_comb begin
        next_state = state;
        case (state)
            IDLE:
                // Falling edge on RX line = start bit beginning
                if (!rx_sync1)
                    next_state = START;

            START:
                if (baud_tick_half) begin
                    // Confirm start bit at mid-point
                    if (!rx_sync1)
                        next_state = DATA;
                    else
                        next_state = IDLE; // Glitch — abort
                end

            DATA:
                if (sample && (bit_cnt == DATA_BITS[$clog2(DATA_BITS)-1:0] - 1))
                    next_state = (PARITY != "NONE") ? PARITY : STOP;

            PARITY:
                if (sample)
                    next_state = STOP;

            STOP:
                if (sample && (stop_cnt == STOP_BITS[$clog2(STOP_BITS+1)-1:0] - 1))
                    next_state = IDLE;

            default:
                next_state = IDLE;
        endcase
    end



    // -------------------------------------------------------------------------
    // Parameter sanity checks
    // -------------------------------------------------------------------------
    initial begin
        assert (DATA_BITS >= 5 && DATA_BITS <= 8)
            else $fatal(1, "[uart_rx] DATA_BITS must be 5–8. Got %0d", DATA_BITS);
        assert (STOP_BITS >= 1 && STOP_BITS <= 2)
            else $fatal(1, "[uart_rx] STOP_BITS must be 1 or 2. Got %0d", STOP_BITS);
        assert (PARITY == "NONE" || PARITY == "ODD" || PARITY == "EVEN")
            else $fatal(1, "[uart_rx] PARITY must be NONE, ODD, or EVEN. Got %s", PARITY);
    end

endmodule