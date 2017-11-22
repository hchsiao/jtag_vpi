module test;

wire		tdo_pad_o = 1;
wire		tck_pad_i;
wire		tms_pad_i;
wire		tdi_pad_i;

reg		clk = 0;
reg		rst = 0;

initial begin
  //$dumpfile("jtag_dpi.vcd");
  //$dumpvars(0);
  $fsdbDumpfile("jtag_dpi.fsdb");
  $fsdbDumpvars();
end

always
	#20 clk <= ~clk;

initial begin
	#100 rst <= 1;
	#200 rst <= 0;
end

jtag_dpi #(.DEBUG_INFO(0))
jtag_dpi0
(
	.tms(tms_pad_i),
	.tck(tck_pad_i),
	.tdi(tdi_pad_i),
	.tdo(tdo_pad_o),

	.init_done(1'b1)
);

endmodule
