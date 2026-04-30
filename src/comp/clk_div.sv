/*
Purpose: Clock divider that divides the input clock by a factor of DIV_FACTOR.
Restrictions: Cant clock divide by 0 or 1
*/

module clk_div#(
    // parameters are used for value config.
    parameter DIV_FACTOR = 2
) (
    // wires? use logic
    input  logic        clk_in,
    input  logic        rst,
    output logic        clk_out
);  
    // localparam cant be overidden, parameters can. Used for derived equations.
    localparam  CNT_MAX     = (DIV_FACTOR/2)-1;
    localparam  CNT_WIDTH   = $clog2(CNT_MAX+1);

    logic [CNT_WIDTH-1:0] CNT;

    always_ff @(posedge clk_in or posedge rst) begin
        if(rst) begin
            clk_out <= 1'b0;
            CNT <= '0;
        end else if (CNT == CNT_MAX) begin
            clk_out <= ~clk_out;
            CNT <= '0;
        end else CNT <= CNT + 1;
    end
endmodule