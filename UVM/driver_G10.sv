class driver_G10 extends  uvm_driver #(sequence_item_G10);
`uvm_component_utils (driver_G10)

sequence_item_G10 message_g10;
virtual intf_Driver_DUT intf_Driver_to_DUT;
int count = 0;

points_128 IFFT_OUTPUT;
DUT_Input Conv_Output;

uvm_analysis_port #(sequence_item_G10) port_drv_2_enc;
uvm_tlm_analysis_fifo #(points_128) port_drv_from_ifft;
uvm_analysis_port #(points_128) port_drv_2_fixed_point_conv;
uvm_tlm_analysis_fifo #(DUT_Input) port_drv_from_Fixed_point_conv;
uvm_analysis_port #(points_128) port_drv_2_fft;

function new (string name = "driver_G10",uvm_component parent);
	super.new(name,parent);
endfunction : new

function void build_phase(uvm_phase phase);
	super.build_phase(phase);
	`uvm_info ("DRIVER","IN BUILD PHASE",UVM_NONE)
	message_g10 = sequence_item_G10::type_id::create("message_g10",this);
	port_drv_2_enc = new("port_drv_2_enc",this);
	port_drv_from_ifft = new("port_drv_from_ifft",this);
	port_drv_2_fixed_point_conv = new("port_drv_2_fixed_point_conv",this);
	port_drv_from_Fixed_point_conv = new("port_drv_from_Fixed_point_conv",this);
	port_drv_2_fft = new("port_drv_2_fft",this);
endfunction : build_phase

function void connect_phase (uvm_phase phase);
	`uvm_info("DRIVER","IN CONNECT PHASE",UVM_NONE)
	super.connect_phase(phase);
	if(!uvm_config_db#(virtual intf_Driver_DUT)::get(null, "*", "INTF_DRV_DUT",intf_Driver_to_DUT ))
		`uvm_fatal(get_full_name(),"No virtual INterface found intf_drv_DUT");
endfunction : connect_phase

virtual task drive_point(input DUT_Input conv_Output);
	count = 0;
		while (count < 129) begin
			@(negedge intf_Driver_to_DUT.clk)begin

					if(intf_Driver_to_DUT.reset) begin
						intf_Driver_to_DUT.push_in 		<= 0;
						intf_Driver_to_DUT.First_Data 	<= 0;
						intf_Driver_to_DUT.DinR         <= 0;
						intf_Driver_to_DUT.DinI         <= 0;
					end

				else begin 
						if(count == 0) begin 
							intf_Driver_to_DUT.push_in     <= 1;
							intf_Driver_to_DUT.First_Data  <= 1;
							intf_Driver_to_DUT.DinR        <= conv_Output.value[count].real_bits;
							intf_Driver_to_DUT.DinI        <= conv_Output.value[count].imaginary_bits;
						end 

						else if(count < 128) begin 
							intf_Driver_to_DUT.push_in     <= 1;
							intf_Driver_to_DUT.First_Data  <= 0;
							intf_Driver_to_DUT.DinR        <= conv_Output.value[count].real_bits;
							intf_Driver_to_DUT.DinI        <= conv_Output.value[count].imaginary_bits;
						end

						else if (count == 128) begin 
							intf_Driver_to_DUT.First_Data  <= 0;
							intf_Driver_to_DUT.DinR        <= conv_Output.value[count].real_bits;
							intf_Driver_to_DUT.DinI        <= conv_Output.value[count].imaginary_bits;
							intf_Driver_to_DUT.push_in     <= 0;
						end
			//$display("Driver to Dut  [%0d] @ time:: %t  DinR :: hex:: %h  bits:: %b",count,$realtime,intf_Driver_to_DUT.DinR,intf_Driver_to_DUT.DinR);
				end
			end
			count <= count + 1;
		end
		count <= 0;
endtask: drive_point

virtual task run_phase (uvm_phase phase);
	`uvm_info("DRIVER","IN RUN PHASE",UVM_NONE)
	super.run_phase(phase);
	  forever begin
	      seq_item_port.get_next_item(message_g10); // get the rand bits from sequencer
		//`uvm_info("INPUT BITS:::",$sformatf(" input data: %h  bits: %b",message_g10.bits,message_g10.bits),UVM_LOW)
	      		port_drv_2_enc.write(message_g10); // write the message into the encoder
	      		port_drv_from_ifft.get(IFFT_OUTPUT); // get the outrput from the IFFT
	      		port_drv_2_fixed_point_conv.write(IFFT_OUTPUT); // send the IFFT Output for Fixed Point COnversion
	      		port_drv_from_Fixed_point_conv.get(Conv_Output); // get the Connverted 128 points and drive it to the VIF
	      		port_drv_2_fft.write(IFFT_OUTPUT); // send the IFFT Output to the FFT Input
	      //	for (int ix=0;ix<128;ix++) begin
			//`uvm_info("Driver to DUT MESAGE:::::: ->>>", $sformatf("\n \t  INDEX: %0d ::: IFFT Output: real: %f imag:%f, fixed Point: real: %b  imag: %b \n",ix,IFFT_OUTPUT.DATA[ix].real_part,IFFT_OUTPUT.DATA[ix].imaginary_part,Conv_Output.value[ix].real_bits,Conv_Output.value[ix].imaginary_bits),UVM_LOW)
	      	//end
	      	drive_point(Conv_Output);
		//@(negedge intf_Driver_to_DUT.push_out) seq_item_port.item_done();
		seq_item_port.item_done();

		end //----------- forever
endtask : run_phase
	
endclass : driver_G10
