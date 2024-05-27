class bit_reversal_G10 extends  uvm_scoreboard;
	`uvm_component_utils (bit_reversal_G10)

	points_128 msg_bit_reversal_from_enc;
	points_128 msg_bit_reversal_2_ifft;

	points_128 data_output;

	static int ix = 0;
	uvm_tlm_analysis_fifo #(points_128) port_bit_reversal_from_enc;

	uvm_analysis_port #(points_128) port_bit_reversal_2_ifft;

	function new (string name = "bit_reversal_G10",uvm_component parent);
		super.new(name,parent);
	endfunction : new

	function void build_phase (uvm_phase phase);

		super.build_phase(phase);
		port_bit_reversal_from_enc = new("port_bit_reversal_from_enc",this);
		port_bit_reversal_2_ifft = new ("port_bit_reversal_2_ifft",this);
		`uvm_info("BIT REVERSAL","IN BUILD PHASE",UVM_NONE)

	endfunction : build_phase

	virtual task bit_reversal (input point data_input[128],output points_128 data_output);
	
		    bit [6:0] wx = 0;
			bit [6:0] rx = 0;
				//$display("\n\n IN BIT REVERSAL Task:: \n\n");
				for (ix=0;ix<128;ix++) begin
					wx = ix;
					rx = {wx[0],wx[1],wx[2],wx[3],wx[4],wx[5],wx[6]};
					data_output.DATA[ix].real_part = data_input[rx].real_part;
					data_output.DATA[ix].imaginary_part = data_input[rx].imaginary_part;
					//`uvm_info("BIT Reversal :::",$sformatf(" \n\t\t Destination Index: %0b  %0d Destination data: real: %f, imag:%f , Source Index: %0b  %0d, Source data: real: %f, imag:%f \n",ix,ix,data_output.DATA[ix].real_part,data_output.DATA[ix].imaginary_part,rx,rx,data_input[rx].real_part,data_input[rx].imaginary_part),UVM_LOW)
				end	
			
	endtask : bit_reversal

	virtual task run_phase(uvm_phase phase);
		super.run_phase(phase);
		`uvm_info ("BIT REVERSAL","IN RUN PHASE",UVM_NONE)
		forever begin 
		 port_bit_reversal_from_enc.get(msg_bit_reversal_from_enc);
				bit_reversal(msg_bit_reversal_from_enc.DATA,msg_bit_reversal_2_ifft);
		 port_bit_reversal_2_ifft.write(msg_bit_reversal_2_ifft);
		end
		
	endtask : run_phase

endclass : bit_reversal_G10
