/* 
-> Package which includes all the files, for building in "top_down_ format"
*/

package package_G10;
import uvm_pkg::*;

	`include "sequence_item_G10.sv"
	`include "enc_data_types_G10.sv"
	`include "sequence_G10.sv"
	`include "sequencer_G10.sv"
	`include "encoder_G10.sv"
	`include "bit_reversal_G10.sv"
	`include "ifft_design_G10.sv"
	`include "Real_to_Fixed.sv"

	`include "driver_G10.sv"
	`include "monitor_tx_G10.sv"
	`include "monitor_rx.sv"

	`include "fft_design_g10.sv"
	`include "decoder_G10.sv"

	// still more needs to agents, environment, need to add a FFT ref design for comparision
	// add top modules as well
	`include "Score_Board_G10.sv"
	`include "Active_agent_G10.sv"
	`include "Passive_Agent.sv"
	`include "Environment_G10.sv"
	`include "Test_G10.sv"

endpackage
