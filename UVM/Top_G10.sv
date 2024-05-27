/*
------------x-----------------------------------x-x---------------------------------------
-> This is a top file, which includes neccesary files for building the boxes
-> Used for generating a clock signal
-> Used for Creating a Global Config space for connecting the Verification Boxes and DUT Virtually..
----------------------x------------------------------------------x-------------------------

*

`timescale  1ps/1fs;

`include "uvm_macros.svh"
`include "package_G10.sv"
`include "intf_Driver_DUT.sv"

`include "../Design_files/new_data_types.sv"
`include "../Design_files/complex_multiplier.sv"
`include "../Design_files/fftw.sv"
`include "../Design_files/DESIGN.sv"


module Top_G10();

	import uvm_pkg::*;

	logic clk,rst;
	intf_Driver_DUT Top_Interface(.clk(clk),.reset(rst));

	initial begin 
		clk = 0;
		rst = 1;
		#1 clk = 1;
		#1;
		rst = 0;
		clk = 0;
		//forever #1 clk = ~clk;
		repeat(1000000) begin #1 clk = ~clk; end
		$display ("Ran Out of Clocks");
		$finish;
	end

	

	initial begin 
		uvm_config_db#(virtual intf_Driver_DUT)::set(null, "*", "INTF_DRV_DUT",Top_Interface );
		run_test("Test_G10");
	end

	initial begin 
		$dumpvars();
		$dumpfile("Waves.vcd");
	end

	 DESIGN_FFT try (		.clk(clk),
						.reset(rst),
						.PushIn(Top_Interface.push_in),
						.FirstData(Top_Interface.First_Data),
						.DinR(Top_Interface.DinR),
						.DinI(Top_Interface.DinI),
						.PushOut(Top_Interface.push_out),
						.Data_Out(Top_Interface.Data_Out)
						);



endmodule : Top_G10
