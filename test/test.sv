module test;

wire		tdo_pad_o;
wire		tck_pad_i;
wire		tms_pad_i;
wire		tdi_pad_i;

reg		clk = 0;
reg		rst = 0;
bit   initialized = 0;

initial begin
  //$dumpfile("jtag_dpi.vcd");
  //$dumpvars(0);
  $fsdbDumpfile("jtag_dpi.fsdb");
  $fsdbDumpvars();
end

always
	#1 clk <= ~clk;

initial begin
	#10 rst <= 1;
	#20 rst <= 0;
  initialized <= 1;
end

jtag_dpi #(.DEBUG_INFO(0))
jtag_dpi0
(
	.tms(tms_pad_i),
	.tck(tck_pad_i),
	.tdi(tdi_pad_i),
	.tdo(tdo_pad_o),

	.init_done(initialized)
);
logic       s_test_logic_reset;
logic       s_run_test_idle;
logic       s_shift_dr;
logic       s_pause_dr;
logic       s_update_dr;
logic       s_capture_dr;
logic       s_extest_select;
logic       s_sample_preload_select;
logic       s_mbist_select;
logic       s_debug_select;
logic       s_tdi;
logic       s_debug_tdo;

adbg_tap_top cluster_tap_i (
            // JTAG pads
            .tms_pad_i(tms_pad_i), 
            .tck_pad_i(tck_pad_i), 
            .trstn_pad_i(1'b1), 
            .tdi_pad_i(tdi_pad_i), 
            .tdo_pad_o(tdo_pad_o), 
            .tdo_padoe_o(tdo_padoe_o),

            .test_mode_i(test_mode_i),

            // TAP states
    .test_logic_reset_o(s_test_logic_reset),
    .run_test_idle_o(s_run_test_idle),
            .shift_dr_o(s_shift_dr),
            .pause_dr_o(s_pause_dr), 
            .update_dr_o(s_update_dr),
            .capture_dr_o(s_capture_dr),
            
            // Select signals for boundary scan or mbist
            .extest_select_o(s_extest_select), 
            .sample_preload_select_o(s_sample_preload_select),
            .mbist_select_o(s_mbist_select),
            .debug_select_o(s_debug_select),
            
            // TDO signal that is connected to TDI of sub-modules.
            .tdi_o(s_tdi), 
            
            // TDI signals from sub-modules
            .debug_tdo_i(s_debug_tdo),    // from debug module
            .bs_chain_tdo_i(1'b0), // from Boundary Scan Chain
            .mbist_tdo_i(1'b0)     // from Mbist Chain
          );

endmodule
