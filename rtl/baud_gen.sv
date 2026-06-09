/*
Purpose: Baud rate generator is essentially a clock divider that divides the input clock by a factor of DIV_FACTOR.

    - TX Module requires a tick at the baud rate while the RX Module needs to oversample the baud rate (typical 16x)
      to detect and sample at the middle of a bit. Embedding 2 seperate counters in RX and TX will utlize more logic
      and risk the baud rate generators drifting out of sync over time.


Clock Divider (even integer division case only): 

    - For a 10 hz clk divided into a 1 hz clk, a total of 5 periods of the 10hz clk occur before the 1 hz clk will toggle. 
    A posedge defines 1 period cycle. so therefore CNT will count to 4 cycles (exclude 1st cycle since that initiates the 
    start of 1 hz clk period) before toggling the 1 hz clk.

                                    CNT_MAX = (BASE CLK / BAUD RATE) - 1


Restrictions: 
    - Non-exact baud rate (implementing fractional divider/accul in the future to improve by averaging)
*/


module baud_gen #(
    parameter int unsigned BASE_CLK  = 50_000_000,   // DE-10 LITE - MAX10_CLK1_50
    parameter int unsigned BAUD_RATE = 115_200
)(
    input  logic clk,
    input  logic rst_n,    // active low so it comes out of rst intentionally w/ a assertion
    output logic baud_tick,         // - Pulses high 1 cycle every baud period
    output logic baud_tick_half     // - Pulses high 1 cycle at the midpoint of a baud period 
                                    //   (used by RX FSM for mid-bit sampling)
);

    // all math done at elaboration
    localparam int unsigned BAUD_DIV      = BASE_CLK / BAUD_RATE;
    localparam int unsigned BAUD_DIV_HALF = BAUD_DIV >> 1;
    localparam int unsigned CNT_W         = $clog2(BAUD_DIV);

    logic [CNT_W-1:0] cnt;

    always_ff @(posedge clk or negedge rst_n) begin : baud_tick_counter
        // active-low rst
        if (!rst_n) 
            cnt <= '0;
        else if (cnt == CNT_W'(BAUD_DIV - 1))
            cnt <= '0;
        else
            cnt <= cnt + 1'b1;
    end

    assign baud_tick      = (cnt == CNT_W'(BAUD_DIV - 1));
    assign baud_tick_half = (cnt == CNT_W'(BAUD_DIV_HALF - 1));



    // -------------------------------------------------------------------------
    // Parameter sanity checks (elaboration time)
    // -------------------------------------------------------------------------
    initial begin
        assert (BAUD_DIV >= 2)
            else $fatal(1, "[uart_baud_gen] BASE_CLK/BAUD_RATE must be >= 2. Got %0d", BAUD_DIV);
        assert (BAUD_RATE > 0)
            else $fatal(1, "[uart_baud_gen] BAUD_RATE must be > 0");
    end

endmodule



