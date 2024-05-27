/*
----------------------------------------------------------------------------
-> This a sequencer class for connecting the sequence object with the Driver.
-> Used as a connection between sequence and driver, for handling the handshake signals and passing the msg.
-----------------------------------------------------------------------------
*/

class sequencer_G10 extends  uvm_sequencer #(sequence_item_G10);
 
 `uvm_component_utils (sequencer_G10)

  function new (string name = "sequencer_G10",uvm_component parent = null);
  	super.new(name,parent);
  endfunction : new

  function void build_phase (uvm_phase phase);
  	`uvm_info("SEQUENCER","IN BUILD PHASE",UVM_NONE)
  	super.build_phase(phase);
  endfunction : build_phase

	
endclass : sequencer_G10
