/*
-------------------------------------------------------------------------------------------------------
-> This is an Environemnt, extending uvm_environemnt.

-> This agent builds: 
					i)    a  Score Board
					ii)   an Active Agent Block [Driver + IFFT boxes]
					iii)  a Passive Agent Blockk [Reference FFT Boxes]

-> Connnects :
			i)   The Monitors in the Agents with the scoreboard.

-------------------------------------------------------------------------------------------------------
*/

class Environment_G10 extends  uvm_env;
	`uvm_component_utils (Environment_G10)

	Score_Board_G10 Score_Board_G10_Env;
	Active_agent_G10 Agent_Env;
	Passive_Agent Agent_Passive_Env;

	function new (string name = "Environment_G10",uvm_component parent);
		super.new(name,parent);
	endfunction : new

	function void build_phase (uvm_phase phase);
		super.build_phase(phase);
		Agent_Env = Active_agent_G10::type_id::create("Agent_Env",this);
		Score_Board_G10_Env = Score_Board_G10::type_id::create("Score_Board_G10_Env",this);
		Agent_Passive_Env = Passive_Agent::type_id::create("Passive_Agent",this);
		`uvm_info ("ENVIRONMENT","IN BUILD PHASE",UVM_NONE)
	endfunction : build_phase

	function void connect_phase (uvm_phase phase);
		super.connect_phase(phase);
		`uvm_info("ENVIRONMENT","IN CONNECT PHASE",UVM_NONE);
		// connect the agent's monitor and socreboard
		Agent_Env.Agent_Driver.port_drv_2_fft.connect(Agent_Passive_Env.reference_agent_bit_reversal.port_bit_reversal_from_enc.analysis_export);
		Agent_Env.Agent_monitor_dut_to_scoreboard.port_monitor_tx_to_scoreboard.connect(Score_Board_G10_Env.port_from_DUT_monitor_to_SB.analysis_export);
		Agent_Passive_Env.reference_monitor.port_monitor_rx_to_scoreboard.connect(Score_Board_G10_Env.port_from_ref_monitor_to_SB.analysis_export);
	endfunction : connect_phase

endclass : Environment_G10
