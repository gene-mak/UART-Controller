


module;

	logic clk, rst;
	logic data_bit;

	int i,j;

	bit rx_serial_sig;

	// Instantiate DUT
	top_level #(.WIDTH(WIDTH), dut (
		.clk(clk),
		.rst(rst),
	)

endmodule