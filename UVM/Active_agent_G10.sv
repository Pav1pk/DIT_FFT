/*
-------------------------------------------------------------------------------------------------------
-> This is an agent, precisely an Active agent, extending uvm_agent.

-> This agent builds: 
					i)     a sequencer box.
					ii)    a Agent_Driver box.
					iii)   a Agent_Encoder for ifft Design box.
					iv)    a Agent_bit reversal box.
					v)    a Agent_IFFT Design box.
					vi)     a Agent_real_to_fixed point converted box.
					vii)    a Agent_monitor_DUT box for monitoring DUT
-> Connnects :
          				i) Driver and Sequencer
          				ii)    Driver and encoder
					   iii)   encoder and bit reversal
						iV)    bit reversal and ifft
				       V)     ifft and driver
				      vi)    driver and real_to_fixed
				      Vii)   real_to_fixed and driver
		
-------------------------------------------------------------------------------------------------------
*/
class Active_agent_G10 extends  uvm_agent;
	`uvm_component_utils (Active_agent_G10)

	driver_G10 Agent_Driver;
	sequencer_G10 Agent_Sequencer;
	encoder_G10 Agent_Encoder;
	bit_reversal_G10 Agent_bit_reversal;
	ifft_design_G10 Agent_ifft;
	Real_to_Fixed Agent_real_2_fixed_pt;
	monitor_dut_to_scoreboard Agent_monitor_dut_to_scoreboard;

	function new (string name = "Active_agent_G10",uvm_component parent = null);
		super.new(name,parent);
	endfunction : new

	function void build_phase (uvm_phase phase);
		super.build_phase(phase);

		Agent_Driver = driver_G10::type_id::create("Agent_Driver",this);
		Agent_Sequencer = sequencer_G10::type_id::create("Agent_Sequencer",this);
		Agent_Encoder = encoder_G10::type_id::create("Agent_Encoder",this);
		Agent_bit_reversal = bit_reversal_G10::type_id::create("Agent_bit_reversal",this);
		Agent_ifft = ifft_design_G10::type_id::create("Agent_ifft",this);
		Agent_real_2_fixed_pt = Real_to_Fixed::type_id::create("Agent_real_2_fixed_pt",this);
		Agent_monitor_dut_to_scoreboard = monitor_dut_to_scoreboard::type_id::create("Agent_monitor_dut_to_scoreboard",this);
		`uvm_info ("ACTIVE AGENT","IN BUILD PHASE",UVM_NONE)
	endfunction : build_phase

	function void connect_phase (uvm_phase phase);
		super.connect_phase(phase);
		Agent_Driver.seq_item_port.connect(Agent_Sequencer.seq_item_export);
		Agent_Driver.port_drv_2_enc.connect(Agent_Encoder.port_enc_from_drv.analysis_export);
		Agent_Encoder.port_enc_2_bit_reversal.connect(Agent_bit_reversal.port_bit_reversal_from_enc.analysis_export);
		Agent_bit_reversal.port_bit_reversal_2_ifft.connect(Agent_ifft.port_ifft_from_bit_reversal.analysis_export);
		Agent_ifft.port_ifft_2_drv.connect(Agent_Driver.port_drv_from_ifft.analysis_export);
		Agent_Driver.port_drv_2_fixed_point_conv.connect(Agent_real_2_fixed_pt.port_Conv_from_Drv.analysis_export);
		Agent_real_2_fixed_pt.port_Conv_2_Drv.connect(Agent_Driver.port_drv_from_Fixed_point_conv.analysis_export);
		
		`uvm_info ("ACTIVE AGENT","IN CONNECT PHASE",UVM_NONE)
	endfunction : connect_phase

endclass : Active_agent_G10
