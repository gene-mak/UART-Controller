/*
Purpose: Baud rate generator is essentially a clock divider that divides the input clock by a factor of DIV_FACTOR.

Clock Divider (even integer division case only): 

    - For a 10 hz clk divided into a 1 hz clk, a total of 5 periods of the 10hz clk occur before the 1 hz clk will toggle. 
    A posedge defines 1 period cycle. so therefore CNT will count to 4 cycles (exclude 1st cycle since that initiates the 
    start of 1 hz clk period) before toggling the 1 hz clk.

                                    CNT_MAX = (BASE CLK / BAUD RATE) - 1


Restrictions: 
    - Non-exact baud rate (implementing fractional divider/accul in the future to improve by averaging)

*/

module baud_rate_gen#(
    parameter   BASE_CLK = 50_000_000   // DE-10 LITE - 50 MHz CLOCK
) (
    input  logic        clk_in,
    input  logic        rst,
    input  logic [1:0]  baud_rate_sel,
    output logic        clk_out
);  
    // localparam can't be overidden, parameters can. Used for derived equations.
    localparam  DIV_FACTOR = int(BASE_CLK/baud_rate);
    localparam  CNT_MAX    = (DIV_FACTOR/2)-1;
    localparam  CNT_WIDTH  = $clog2(CNT_MAX+1);

    typedef_enum_logic [1:0] {4800, 9600, 38400, 115200} baud_rate_t;
    baud_rate_t baud_rate; 

    logic [CNT_WIDTH-1:0] CNT;
    int                   

    always_comb begin : baud_rate_sel
        case (baud_rate_sel) begin
            2'b00 : baud_rate(0);   
            2'b01 : baud_rate(1);      
            2'b10 : baud_rate(2);      
            2'b11 : baud_rate(3);           
        endcase
    end 

    // async rst
    always_ff @(posedge clk or posedge rst) begin : clk_div
        if (rst) begin
            clk_out <= 1'b0;
            CNT <= '0;
        end else if (CNT == CNT_MAX) begin
            clk_out <= ~clk_out;
            CNT <= '0;
        end
        else CNT <= CNT + 1;
    end 

endmodule;







