class Real_to_Fixed extends uvm_scoreboard;
	`uvm_component_utils (Real_to_Fixed)

	uvm_tlm_analysis_fifo #(points_128) port_Conv_from_Drv;
	uvm_analysis_port #(DUT_Input) port_Conv_2_Drv;

	points_128 msg_to_Conv_from_Drv;
	decimal_points_128 conv_2_complement;
	DUT_Input msg_Conv_2_Drv;

	function new (string name = "Real_to_Fixed",uvm_component parent);
		super.new(name,parent);	
	endfunction : new

	function void build_phase (uvm_phase phase);
		super.build_phase(phase);
		`uvm_info ("Real_to_Fixed","In Build Phase",UVM_NONE)
		 port_Conv_from_Drv = new("port_Conv_from_Drv",this);
		 port_Conv_2_Drv=new("port_Conv_2_Drv",this);
	endfunction : build_phase

	task real_2_fixed_point (input points_128 input_points,output decimal_points_128 fixed_decimal_points); 	
		for (int ix=0;ix<128;ix++) begin 
			fixed_decimal_points.decimal_point[ix].real_value = (input_points.DATA[ix].real_part)*(1<<15); //2_15 format
			fixed_decimal_points.decimal_point[ix].imaginary_value = (input_points.DATA[ix].imaginary_part)*(1<<15);
			//`uvm_info("Real points to fixed point:",$sformatf(" \n \t Index: %0d Input: real: %f imag: %f Output: real: %0d  real: %0d",ix,input_points.DATA[ix].real_part,input_points.DATA[ix].imaginary_part,fixed_decimal_points.decimal_point[ix].real_value,fixed_decimal_points.decimal_point[ix].imaginary_value),UVM_LOW)
		end
	endtask : real_2_fixed_point

	task fixed_decimal_2_binary(input decimal_points_128 input_decimals,output DUT_Input fixed_binary_points); // converting 2's complement
		for (int ix=0;ix<128;ix++)begin 
			//`uvm_info("Entered fixed_decimal_2_binary",$sformatf("input data: real: %d  imag: %d",input_decimals.decimal_point[ix].real_value,input_decimals.decimal_point[ix].imaginary_value),UVM_LOW)
			if(input_decimals.decimal_point[ix].real_value <0)begin 
				input_decimals.decimal_point[ix].real_value = input_decimals.decimal_point[ix].real_value *-1; // to get the magnitude
				fixed_binary_points.value[ix].real_bits[45] = 1; // set the msb = 1
				fixed_binary_points.value[ix].real_bits[44:23] = input_decimals.decimal_point[ix].real_value; // decimal magnitude to binary
				fixed_binary_points.value[ix].real_bits[44:23] = ~fixed_binary_points.value[ix].real_bits[44:23] + 1; // 2's complement
				end
			else begin 
				fixed_binary_points.value[ix].real_bits[45:23] = input_decimals.decimal_point[ix].real_value;
			end

			if(input_decimals.decimal_point[ix].imaginary_value <0)begin 
				input_decimals.decimal_point[ix].imaginary_value = input_decimals.decimal_point[ix].imaginary_value *-1;
				fixed_binary_points.value[ix].imaginary_bits[22] = 1;
				fixed_binary_points.value[ix].imaginary_bits[21:0] = input_decimals.decimal_point[ix].imaginary_value;
				fixed_binary_points.value[ix].imaginary_bits[21:0] = ~fixed_binary_points.value[ix].imaginary_bits[21:0] + 1;
				end
			else begin 
				fixed_binary_points.value[ix].imaginary_bits[22:0] = input_decimals.decimal_point[ix].imaginary_value;
			end
			//`uvm_info("Exiting fixed_decimal_2_binary",$sformatf("input:output: real: %b imag:%b\n",fixed_binary_points.value[ix].real_bits,fixed_binary_points.value[ix].imaginary_bits),UVM_LOW)
		end
	endtask:fixed_decimal_2_binary

	virtual task run_phase (uvm_phase phase);
		super.run_phase(phase);
		`uvm_info("Real_to_Fixed","IN Run Phase",UVM_NONE)
		forever begin 
			port_Conv_from_Drv.get(msg_to_Conv_from_Drv);
				real_2_fixed_point(msg_to_Conv_from_Drv,conv_2_complement); // converts points real values into decimal values
				fixed_decimal_2_binary(conv_2_complement,msg_Conv_2_Drv); // converts decimal to binary
			port_Conv_2_Drv.write(msg_Conv_2_Drv);
		end
	endtask : run_phase

endclass : Real_to_Fixed
