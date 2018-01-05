/*
 * TCP/IP controlled VPI JTAG Interface.
 * Based on Julius Baxter's work on jp_vpi.c
 *
 * Copyright (C) 2012 Franck Jullien, <franck.jullien@gmail.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation  and/or other materials provided with the distribution.
 * 3. Neither the names of the copyright holders nor the names of any
 *    contributors may be used to endorse or promote products derived from this
 *    software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

`define CMD_RESET		0
`define CMD_TMS_SEQ		1
`define CMD_SCAN_CHAIN		2
`define CMD_SCAN_CHAIN_FLIP_TMS	3
`define CMD_STOP_SIMU		4

`define XFERT_MAX_SIZE  512

module jtag_dpi
#(parameter DEBUG_INFO = 0,
	parameter TP = 1,
	parameter TCK_HALF_PERIOD = 35, // Clock half period (Clock period = 100 ns => 10 MHz)
  parameter CMD_DELAY = 5
)
(
	output reg	tms,
	output reg	tck,
	output reg	tdi,
	input		tdo,
	input		init_done);

typedef struct {
	int cmd;
	byte buffer_out[`XFERT_MAX_SIZE];
	byte buffer_in[`XFERT_MAX_SIZE];
	int length;
	int nb_bits;
} vpi_cmd;

import "DPI-C" context function int check_for_command(output vpi_cmd cmd);
import "DPI-C" context function int send_result_to_server(input vpi_cmd cmd);
import "DPI-C" context function int dpi_get_time_ms();
import "DPI-C" context function void sim_finish_callback();

bit flip_tms;
bit enabled;
int ercd;

vpi_cmd cmd_buff;

initial
begin
  if($test$plusargs("jtag_vpi_enable")) begin
    enabled = 1;
  end
  else begin
    enabled = 0;
    $display("WARN: jtag_vpi is not enabled");
  end

	tck		<= #TP 1'b0;
	tdi		<= #TP 1'b0;
	tms		<= #TP 1'b0;

	// Insert a #delay here because we need to
	// wait until the PC isn't pointing to flash anymore
	// (this is around 20k ns if the flash_crash boot code
	// is being booted from, else much bigger, around 10mil ns)
	wait(init_done)
		if(enabled) main;
end

task main;
begin
	$display("JTAG debug module with VPI interface enabled\n");

  // Debugger is responsible for this
	//reset_tap;
	//goto_run_test_idle_from_reset;

	while (1) begin

		// Check for incoming command
		// wait until a command is sent
		// poll with a delay here
		cmd_buff.cmd = -1;

		while (cmd_buff.cmd == -1)
		begin
			if (DEBUG_INFO)
        $display("Start polling, time = %d", dpi_get_time_ms());
      #CMD_DELAY ercd = check_for_command(cmd_buff);
			if (DEBUG_INFO)
        $display("End polling, time = %d", dpi_get_time_ms());
		end

		// now switch on the command
		case (cmd_buff.cmd)

		`CMD_RESET :
		begin
      if (DEBUG_INFO) begin
				$display("%t ----> CMD_RESET %h\n", $time, cmd_buff.length);
        $display("time = %d", dpi_get_time_ms());
      end
			reset_tap;
			goto_run_test_idle_from_reset;
		end

		`CMD_TMS_SEQ :
		begin
      if (DEBUG_INFO) begin
				$display("%t ----> CMD_TMS_SEQ\n", $time);
        $display("time = %d", dpi_get_time_ms());
      end
			do_tms_seq;
		end

		`CMD_SCAN_CHAIN :
		begin
      if (DEBUG_INFO) begin
				$display("%t ----> CMD_SCAN_CHAIN\n", $time);
        $display("time = %d", dpi_get_time_ms());
      end
			flip_tms = 0;
			do_scan_chain;
      if (DEBUG_INFO)
        $display("Start returning data, time = %d", dpi_get_time_ms());
			ercd = send_result_to_server(cmd_buff);
		end

		`CMD_SCAN_CHAIN_FLIP_TMS :
		begin
      if(DEBUG_INFO) begin
				$display("%t ----> CMD_SCAN_CHAIN\n", $time);
        $display("time = %d", dpi_get_time_ms());
      end
			flip_tms = 1;
			do_scan_chain;
      if (DEBUG_INFO)
        $display("Start returning data, time = %d", dpi_get_time_ms());
			ercd = send_result_to_server(cmd_buff);
		end

		`CMD_STOP_SIMU :
		begin
      if(DEBUG_INFO) begin
				$display("%t ----> End of simulation\n", $time);
        $display("time = %d", dpi_get_time_ms());
      end
			destroy;
		end

		default:
		begin
			$display("Somehow got to the default case in the command case statement.");
			$display("Command was: %x", cmd_buff.cmd);
			$display("Exiting...");
			destroy;
		end

		endcase // case (cmd_buff.cmd)

	end // while (1)
end

endtask // main


// Generation of the TCK signal
task gen_clk;
input [31:0] number;
integer i;

begin
	for (i = 0; i < number; i = i + 1)
	begin
		#TCK_HALF_PERIOD tck <= 1;
		#TCK_HALF_PERIOD tck <= 0;
	end
end

endtask

// TAP reset
task reset_tap;
begin
	if (DEBUG_INFO)
		$display("(%0t) Task reset_tap", $time);
	tms <= #1 1'b1;
	gen_clk(5);
end

endtask


// Goes to RunTestIdle state
task goto_run_test_idle_from_reset;
begin
	if (DEBUG_INFO)
		$display("(%0t) Task goto_run_test_idle_from_reset", $time);
	tms <= #1 1'b0;
	gen_clk(1);
end

endtask

// 
task do_tms_seq;

integer		i,j;
logic [7:0]	data;
integer		nb_bits_rem;
integer		nb_bits_in_this_byte;

begin
	if (DEBUG_INFO)
		$display("(%0t) Task do_tms_seq of %d bits (length = %d)",
      $time, cmd_buff.nb_bits, cmd_buff.length);

	// Number of bits to send in the last byte
	nb_bits_rem = cmd_buff.nb_bits % 8;
	nb_bits_rem = nb_bits_rem>0 ? nb_bits_rem : 8;

	for (i = 0; i < cmd_buff.length; i = i + 1)
	begin
		// If we are in the last byte, we have to send only
		// nb_bits_rem bits. If not, we send the whole byte.
		nb_bits_in_this_byte = (i == (cmd_buff.length - 1)) ? nb_bits_rem : 8;

		data = cmd_buff.buffer_out[i];
		for (j = 0; j < nb_bits_in_this_byte; j = j + 1)
		begin
			tms <= #1 1'b0; // TODO: what for???
			if (data[j] == 1) begin
				tms <= #1 1'b1;
                        end
			gen_clk(1);
		end
	end

	tms <= #1 1'b0;
end

endtask


// 
task do_scan_chain;

integer		_bit;
integer		nb_bits_rem;
integer		nb_bits_in_this_byte;
integer		index;
logic [7:0] data;

begin
	if(DEBUG_INFO)
		$display("(%0t) Task do_scan_chain of %d bits (length = %d)",
      $time, cmd_buff.nb_bits, cmd_buff.length);

	// Number of bits to send in the last byte
	nb_bits_rem = cmd_buff.nb_bits % 8;
	nb_bits_rem = nb_bits_rem>0 ? nb_bits_rem : 8;

	for (index = 0; index < cmd_buff.length; index = index + 1)
	begin
		// If we are in the last byte, we have to send only
		// nb_bits_rem bits if it's not zero.
		// If not, we send the whole byte.
		nb_bits_in_this_byte = (index == (cmd_buff.length - 1)) ? nb_bits_rem : 8;

		data = cmd_buff.buffer_out[index];
		for (_bit = 0; _bit < nb_bits_in_this_byte; _bit = _bit + 1)
		begin
			tdi <= 1'b0; // TODO
			if (data[_bit] == 1'b1) begin
				tdi <= 1'b1;
			end

			// On the last bit, set TMS to '1'
			if (((_bit == (nb_bits_in_this_byte - 1)) && (index == (cmd_buff.length - 1))) && (flip_tms == 1)) begin
				tms <= 1'b1;
			end

			#TCK_HALF_PERIOD tck <= 1;
			data[_bit] <= tdo;
			#TCK_HALF_PERIOD tck <= 0;
		end
		cmd_buff.buffer_in[index] = data;
	end

	tdi <= 1'b0;
	tms <= 1'b0;
end

endtask

//
task destroy;
  sim_finish_callback();
  $finish();
endtask

endmodule
