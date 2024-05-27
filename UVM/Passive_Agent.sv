/*
-------------------------------------------------------------------------------------------------------
-> This is an agent, precisely passive agent, extending uvm_agent.

-> This agent builds: 
					i)    a Bit reversal block for reference fft Design
					ii)   a Reference FFT Design.
					iii)  a Reference FFT Design's Decoder.
					iv)   a reference monitor

-> Connnects :
			i)   reference bit reversal and reference fft design.
			ii)  reference fft Design and reference Decoder.
			iii) reference Decoder and reference monitor.

-------------------------------------------------------------------------------------------------------
*/
class Passive_Agent extends  uvm_agent;
	`uvm_component_utils(Passive_Agent)

	bit_reversal_G10 reference_agent_bit_reversal;
	fft_design_g10 reference_fft_design;
	decoder_G10 reference_fft_decoder;
	monitor_reference_to_scoreboard reference_monitor;
	//monitor_reference_to_scoreboard reference_monitor;

	function new(string name = "Passive_Agent",uvm_component parent);
		super.new(name,parent);
	endfunction : new

	function void build_phase (uvm_phase phase);
		`uvm_info("REFERENCE MODEL AGENT","IN BUILD PHASE",UVM_NONE)
		super.build_phase(phase);
		reference_agent_bit_reversal = bit_reversal_G10::type_id::create("reference_agent_bit_reversal",this);
		reference_fft_design = fft_design_g10::type_id::create("reference_fft_design",this);
		reference_fft_decoder = decoder_G10::type_id::create("reference_fft_decoder",this);
		reference_monitor = monitor_reference_to_scoreboard::type_id::create("reference_monitor",this);
	endfunction: build_phase

	function void connect_phase (uvm_phase phase);
		super.connect_phase(phase);
		`uvm_info("REFERENCE MODEL AGENT","IN CONNECT PHASE",UVM_NONE)
	reference_agent_bit_reversal.port_bit_reversal_2_ifft.connect(reference_fft_design.port_fft_from_bit_reversal.analysis_export);
		reference_fft_design.port_fft_2_dec.connect(reference_fft_decoder.port_fft_2_dec.analysis_export);
		reference_fft_decoder.port_fft_dec_to_monitor.connect(reference_monitor.port_monitor_rx_from_decoder.analysis_export);
	endfunction : connect_phase

endclass : Passive_Agent
