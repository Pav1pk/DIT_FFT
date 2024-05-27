// ---------------------------------------------------------------------------

/*
-> This is Test Component extending uvm_test, for testing the dut by starting the sequence.
-> This Test Box contatins an Environment and a sequence block(s) in it.
*/

//-------------------------------------------------------------------------------
class Test_G10 extends  uvm_test;
	`uvm_component_utils (Test_G10)

	Environment_G10 TEST_ENVIRONMENT;
	sequence_G10 TEST_SEQUENCE;

	function new (string name = "Test_G10",uvm_component parent);
			super.new(name,parent);
	endfunction : new

	function void build_phase (uvm_phase phase);
		`uvm_info("TEST","BUILD PHASE",UVM_NONE)
		super.build_phase(phase);
		TEST_ENVIRONMENT = Environment_G10::type_id::create("TEST_ENVIRONMENT",this);
		TEST_SEQUENCE = sequence_G10::type_id::create("TEST_SEQUENCE",this);
	endfunction: build_phase

	function void connect_phase (uvm_phase phase);
		`uvm_info("TEST","IN CONNECT PHASE",UVM_NONE)
	endfunction : connect_phase

	virtual task run_phase (uvm_phase phase);
		uvm_top.print_topology();
		super.run_phase(phase);
		`uvm_info ("TEST","IN RUN PHASE",UVM_NONE)
		phase.raise_objection(this);
		TEST_SEQUENCE.start(this.TEST_ENVIRONMENT.Agent_Env.Agent_Sequencer);
		phase.drop_objection(this);

	endtask : run_phase

endclass : Test_G10
