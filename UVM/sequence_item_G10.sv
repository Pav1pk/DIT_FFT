/* 
-------------------------------------------------------------------------
-> This is a sequence item class
-> The message / packet for passing the information through the blocks, throughout the Flow.
-> This sequence item is used for randomizing the input 48 bits, which is required for generation of 128 points for the FFT/IFFT. 
-> The other data items in the sequence item are used in the driver for controlling the sequential inputs to the Device Under Test
 ----------------------------------------------------------------------- 
 */
class sequence_item_G10 extends  uvm_sequence_item;

	`uvm_object_utils(sequence_item_G10)

	function new (string name = "sequence_item_G10");
		super.new(name);
	endfunction : new
	
	rand bit [47:0] bits;

	bit FirstData;
	bit Pushin;
	bit [16:0] DinR;
	bit [16:0] DinI;

	reg PushOut;
	reg [47:0] DataOut;

	// constraint delay
	
	
endclass : sequence_item_G10
