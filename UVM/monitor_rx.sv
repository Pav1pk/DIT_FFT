class monitor_reference_to_scoreboard extends  uvm_monitor;
	virtual intf_Driver_DUT intf_FFT_to_DUT_Monitor;

	`uvm_component_utils (monitor_reference_to_scoreboard)

	bit_data_48 output_data,input_data;
	bit_data_48 temp_data;

	uvm_tlm_analysis_fifo #(bit_data_48) port_monitor_rx_from_decoder;
	uvm_analysis_port #(bit_data_48) port_monitor_rx_to_scoreboard;

	function new (string name = "monitor_reference_to_scoreboard",uvm_component parent);
		super.new(name,parent);
	endfunction : new

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		`uvm_info("Reference MONITOR","IN BUILD PHASE",UVM_NONE)
		port_monitor_rx_from_decoder = new("port_monitor_rx_from_decoder",this);
		port_monitor_rx_to_scoreboard = new("port_monitor_rx_to_scoreboard",this);
	endfunction : build_phase

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		`uvm_info("Reference MONITOR","IN CONNECT PHASE",UVM_NONE)
		if(!uvm_config_db#(virtual intf_Driver_DUT)::get(null, "*", "INTF_DRV_DUT",intf_FFT_to_DUT_Monitor))
			`uvm_fatal(get_full_name(),"No virtual INterface found intf_drv_DUT");
	endfunction : connect_phase

	task run_phase (uvm_phase phase);
		//bit_data_48 temp;
		super.run_phase(phase);
		`uvm_info("Reference MONITOR","In Run Phase",UVM_NONE)
		forever begin
					port_monitor_rx_from_decoder.get(input_data);
				// $display("\n\n Inputter : %h @ %t",input_data.bit_data, $realtime);
		  		 //@ (posedge intf_FFT_to_DUT_Monitor.clk) begin 
		  		// if (intf_FFT_to_DUT_Monitor.reset == 1) output_data.bit_data = 0;
		  		 //else begin 
		  		 //	if(intf_FFT_to_DUT_Monitor.First_Data ==1) temp = input_data;
		  		 //	if(intf_FFT_to_DUT_Monitor.push_out == 1)begin 
				//	output_data = temp;
				//	end
				//	else output_data.bit_data = 0;
		  		 //end
				@(posedge intf_FFT_to_DUT_Monitor.First_Data) port_monitor_rx_to_scoreboard.write(input_data);
				//`uvm_info ("MONITOR_FFT",$sformatf("Data:: Input: %h Push_out: %d, Output:: %h",input_data.bit_data,intf_FFT_to_DUT_Monitor.push_out,output_data.bit_data),UVM_LOW)
				//end
			end
	endtask: run_phase

	
endclass : monitor_reference_to_scoreboard
