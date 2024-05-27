class Score_Board_G10 extends  uvm_scoreboard;
	`uvm_component_utils (Score_Board_G10)
	uvm_cmdline_processor c1;
	string cmd_line;

	bit_data_48 data1[$];
	bit_data_48 data2[$];
	bit_data_48 data_1,data_1_1;
	bit_data_48 data_2,data_2_2;

	int max_quit_count = 10;
	int error_count = 0;
	int sequence_count = 0;
	reg temp;

	uvm_tlm_analysis_fifo #(bit_data_48) port_from_ref_monitor_to_SB;
	uvm_tlm_analysis_fifo #(bit_data_48) port_from_DUT_monitor_to_SB;

	function new (string name="Score_Board_G10",uvm_component parent);
		super.new(name,parent);
	endfunction : new

	function void build_phase (uvm_phase phase);
		super.build_phase(phase);
		`uvm_info("Score Board","BUILD Phase",UVM_NONE)
		port_from_ref_monitor_to_SB = new("port_from_ref_monitor_to_SB",this);
		port_from_DUT_monitor_to_SB = new("port_from_DUT_monitor_to_SB",this);
		//max_quit_count = $sscanf("UVM_MAX_QUIT_COUNT %d", max_quit_count);
	endfunction : build_phase

	function void write_DUT (bit_data_48 pkt);
		data1.push_back(pkt);
	endfunction : write_DUT

	function void write_FFT (bit_data_48 pkt);
	 	data2.push_back(pkt);
	 endfunction :  write_FFT

	task run_phase (uvm_phase phase);
		super.run_phase(phase);

		`uvm_info("Score Board","IN Run Phase",UVM_NONE)
		c1 = uvm_cmdline_processor::get_inst();
		cmd_line = "";
		c1.get_arg_value("+UVM_MAX_QUIT_COUNT=",cmd_line);
		temp=$sscanf(cmd_line,"%d",max_quit_count);
		/*if (!$sscanf("UVM_MAX_QUIT_COUNT=%d", max_quit_count)) begin
			`uvm_warning(get_type_name(), "Failed to retrieve UVM_MAX_QUIT_COUNT from command line. Using default value.");
			max_quit_count = 10; // Default value if not specified via command line
		end*/

		forever begin
		port_from_DUT_monitor_to_SB.get(data_1_1);
		port_from_ref_monitor_to_SB.get(data_2_2);
		write_DUT(data_1_1);
		write_FFT(data_2_2);
		//$display("\n");
		//`uvm_info ("ScoreBoard","Checking @ Pushout == 1",UVM_NONE)
		//`uvm_info("ScoreBoardddd",$sformatf("Size of the Queue::: %d   %d",data1.size(),data2.size()),UVM_NONE)
		wait (data1.size() != 0 && data2.size() != 0)begin
			sequence_count+=1;
			data_1 = data1.pop_front();
			data_2 = data2.pop_front();
			//`uvm_info("ScoreBoardddd",$sformatf("Data::: DUT'S Output:: %h   FFT_Model_Output:: %h ",data_1.bit_data,data_2.bit_data),UVM_NONE)
			if(data_1.bit_data != data_2.bit_data) begin
			`uvm_error ("Output Bits Mismatch",$sformatf("Expected Data : %h  but Received : %h\n",data_2.bit_data,data_1.bit_data))
			error_count += 1;
			end
			else `uvm_info ("passed",$sformatf("Data Matched for the [Sequence (%0d) = %h]--->(Proceeding to next) \n",sequence_count,data_2.bit_data),UVM_NONE)
		end
		if (error_count >= max_quit_count)begin
			uvm_report_info ("ScoreBoard bit Check Error",$sformatf(" \n Quit Count Reached \n Max Errors Count Reached :: (%0d) of %0d",error_count,max_quit_count),UVM_NONE);
			`uvm_fatal ("ScoreBoard Missmatch Limit Exceeded","Stopping the simulation")
		end

		end
    endtask : run_phase

endclass : Score_Board_G10
