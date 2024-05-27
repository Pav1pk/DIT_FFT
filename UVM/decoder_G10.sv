/*
--------------------------------------------------------------------------------------------
-> It is decoder box, which extends "uvm_scoreboard".

-> This box conists fot two ports , 
                i)  The tlm analysis fifo for receiving the sequence item message from the FFT Box.
                ii)  The analysis port for sending 48 bits decoder output to the reference monitor.

-> This decoder receives the 128 frequency bins and decodes them and slice into corresponding 48 bits.

-> This decoder first calculate the max magnitude by comparing the frequency of bin 55 and bin 57.

-> According to the max values, three decision points are calculated.

->  The magnitude is maintained in square values, rather than sqaure roooting them'

-> Each frequency bins magintude is computed, and compared with the decision points and corresponding 2 bits are stored.

-> 24 bins are computed and 48 bits are generated.

-> These 48 bits are passed to the reference monitor.
-----------------------------------------------------------------------------------------------
*/

class decoder_G10 extends  uvm_scoreboard;
	`uvm_component_utils (decoder_G10)

	points_128 msg_dec_from_fft;
	sequence_item_G10 msg_dec_to_monitor;
	reg [47:0] decoder_output;

	uvm_tlm_analysis_fifo #(points_128) port_fft_2_dec;
	uvm_analysis_port #(bit_data_48) port_fft_dec_to_monitor;

	function new(string name ="decoder_G10",uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase (uvm_phase phase);
		`uvm_info("DECODER","BUILD PHASE",UVM_NONE)
		super.build_phase(phase);
		port_fft_2_dec = new("port_fft_2_dec",this);
		port_fft_dec_to_monitor = new("port_fft_dec_to_monitor",this);
		msg_dec_to_monitor = sequence_item_G10::type_id::create("msg_dec_to_monitor",this);
	endfunction : build_phase

	task complex_magnitude (input point input_point,output real magnitude);// returns squared magnitude
		magnitude = input_point.real_part*input_point.real_part + input_point.imaginary_part*input_point.imaginary_part;
	endtask : complex_magnitude
	

	task decoder (input point dec_in[128],output reg [47:0] dec_out);
		real bin_55,bin_57;
		real max_bin_value;
		real absolute,percentage;
		bit [1:0]freq_bins[64] ;
		real dec_points_1,dec_points_2,dec_points_3;
		int index;

		reg [5:0] ptr1,ptr2;

		complex_magnitude(dec_in[55],bin_55);
		complex_magnitude(dec_in[57],bin_57);

		if (bin_55 >= bin_57) max_bin_value = bin_55; 
		else max_bin_value = bin_57;

		//$display("max_bin::: %f",max_bin_value);

		for (int ix=0;ix<64;ix++) begin 

			complex_magnitude(dec_in[ix],absolute);
			complex_magnitude('{0.166*max_bin_value,0.00},dec_points_1); //squaring the points
			complex_magnitude('{0.499*max_bin_value,0.00},dec_points_2);
			complex_magnitude('{0.75*max_bin_value,0.00},dec_points_3);

			percentage = absolute/max_bin_value;
			//$display("absoluteL",absolute);
			// comparing both square values; no sqrt is taken; points are squard and percentage is in squared/squared
			if 		(percentage < dec_points_1) freq_bins[ix] = 2'b00;
			else if (percentage >= dec_points_1 & percentage < dec_points_2)  freq_bins[ix] = 2'b01;
			else if (percentage >=dec_points_2 & percentage < dec_points_3) freq_bins[ix] = 2'b10;
			else 	freq_bins [ix] = 2'b11;
			//$display("Index: %0d Input: re: %f  im: %f Percentage: %f freq_bins:%b",ix,dec_in[ix].real_part,dec_in[ix].imaginary_part,percentage,freq_bins[ix]);
		end

		for (int rx=4;rx<52;rx=rx+2) begin 
			index = (rx/2);
			ptr2 = 2*(index- 2)+1;
			ptr1 = 2*(index -2);
			{dec_out[ptr2],dec_out[ptr1]} = freq_bins[rx];
		end
	endtask : decoder

	virtual task run_phase (uvm_phase phase);
		super.run_phase(phase);
		`uvm_info("DECODER","IN RUN PHASE",UVM_NONE)
		forever begin
		port_fft_2_dec.get(msg_dec_from_fft);
			decoder (msg_dec_from_fft.DATA,decoder_output);
			//`uvm_info("DECODER OUTPUT::",$sformatf("Output Bits: BITS : %0b   HEX :: %h \n ",decoder_output,decoder_output),UVM_LOW)
		port_fft_dec_to_monitor.write('{decoder_output});
	end
	endtask: run_phase


endclass : decoder_G10
