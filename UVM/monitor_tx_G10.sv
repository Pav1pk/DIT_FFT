/*
------------------------------------------------------------------------------------------------------------------------------------
-> This is a monitor , monitoring the "DUT" for sending the Dut's output to the scoreboard, synchronously.

-> It has two ports:
			i)  tlm_anlaysis_fifo port for collecting the 48 bits from the DUT (virtual Interface).
			ii) analysis Port for sending the 48 bits to the scoreboard..

-> It has a virtual interface, connecting the global conifg interface for monitoring the interface port signals.

-> The monitor collects the output from the DUT (in the Interface).

-> Whenver it sees a reset signal, it sends zero signal to the scoreboard.

-> Whenever the monitor sees a pushout signal from the dut, the 48 bit element is sent/written it to the scoreboard.
------------------------------------------------------------------------------------------------------------------------------------
*/
class monitor_dut_to_scoreboard extends  uvm_monitor;

	virtual intf_Driver_DUT intf_DUT_Monitor;

	reg [47:0] data_d;

	`uvm_component_utils (monitor_dut_to_scoreboard)

	uvm_analysis_port #(bit_data_48) port_monitor_tx_to_scoreboard;

	function new (string name = "monitor_dut_to_scoreboard",uvm_component parent);
		super.new(name,parent);
	endfunction : new

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		`uvm_info("DUT Output MONITOR","IN BUILD PHASE",UVM_NONE)
		//port_monitor_tx_from_dut = new("port_monitor_tx_from_dut",this);
		port_monitor_tx_to_scoreboard = new("port_monitor_tx_to_scoreboard",this);
	endfunction : build_phase

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		`uvm_info("DUT Output MONITOR","IN CONNECT PHASE",UVM_NONE)
		if(!uvm_config_db#(virtual intf_Driver_DUT)::get(null, "*", "INTF_DRV_DUT",intf_DUT_Monitor))
			`uvm_fatal(get_full_name(),"No virtual INterface found intf_drv_DUT");
	endfunction : connect_phase

	/*virtual task drive (input logic [47:0] Input_data);
	bit_data_48 tempp;
	tempp = '{Input_data};
	$display("Input Received: %h  %b @ %t",Input_data,tempp.bit_data,$realtime);
		@(posedge intf_DUT_Monitor.clk) begin 
			$display("\n \n Push Out: %b @ %t",intf_DUT_Monitor.push_out,$realtime);
			if(intf_DUT_Monitor.push_out ==1) port_monitor_tx_to_scoreboard.write(tempp);
		end
	endtask: drive*/

	task run_phase(uvm_phase phase);
	super.run_phase(phase);
		`uvm_info("DUT Output MONITOR","RUN PHASE",UVM_NONE)
		forever begin
			@(posedge intf_DUT_Monitor.clk) begin 
				if(intf_DUT_Monitor.reset == 1) data_d = 0;
				else begin 
					if(intf_DUT_Monitor.push_out == 1)begin
						data_d = intf_DUT_Monitor.Data_Out;
						port_monitor_tx_to_scoreboard.write('{data_d});
					end
					else data_d = 0;
				end
			//`uvm_info ("MONITOR_DUT",$sformatf("Data:: Input: %h Push_out: %d, Output:: %h",intf_DUT_Monitor.Data_Out,intf_DUT_Monitor.push_out,data),UVM_LOW)
			end
			//drive (intf_DUT_Monitor.Data_Out);

		end
	endtask : run_phase

	
endclass : monitor_dut_to_scoreboard
