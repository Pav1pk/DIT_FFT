/*
----------------------------------------------------------------------------------------
-> This is a sequence class, used for generating random sequences
-> It contains a sequence item in the name of "msg".
-> This sequence uses the sequence item message and reuse it and randomly generates 48 bits which are passed to the driver.
-> Initial 5 sequence stimulus are applied and next 50,000 sequence are randmonly generated.
-----------------------------------------------------------------------------------------
*/

class sequence_G10 extends  uvm_sequence #(sequence_item_G10);
	`uvm_object_utils (sequence_G10)

 sequence_item_G10 msg;
 int count =6;
 	function new (string name = "sequence_G10");
 		super.new(name);
 	endfunction : new


 	task body();
	msg = sequence_item_G10::type_id::create("msg");

	#2;
	start_item (msg);
		msg.randomize() with {bits == 48'hE234_5678_F19B;};
		`uvm_info ("progress",$sformatf("(Starting Sequence 1) :: Input bits : %0h",msg.bits),UVM_MEDIUM)
	finish_item (msg);


	#2;

	start_item (msg);
		msg.randomize() with {bits == 48'h0000_1001_0000;};
		`uvm_info ("progress",$sformatf("(Starting Sequence 2) :: Input bits : %h",msg.bits),UVM_MEDIUM)
	finish_item (msg);

	#2;

	start_item (msg);
		msg.randomize() with {bits == 48'h5555_5555_5555;};
		`uvm_info ("progress",$sformatf("(Starting Sequence 3) :: Input bits : %h",msg.bits),UVM_MEDIUM)
	finish_item (msg);

  	#2;

	start_item (msg);
		msg.randomize() with {bits == 48'hAAAA_AAAA_AAAA;};
		`uvm_info ("progress",$sformatf("(Starting Sequence 4) :: Input bits : %h",msg.bits),UVM_MEDIUM)
	finish_item (msg);

	#2;


	start_item (msg);
		msg.randomize() with {bits == 48'hFFFF_FFFF_FFFF;};
		`uvm_info ("progress",$sformatf("(Starting Sequence 5) :: Input bits : %h",msg.bits),UVM_MEDIUM)
	finish_item (msg);

	repeat (500) begin
	#2;
	  start_item(msg);
		msg.randomize();
		`uvm_info ("progress",$sformatf("(Starting Sequence %0d) :: Input bits : %h",count,msg.bits),UVM_MEDIUM)
	  finish_item(msg);
	  count +=1;
	end

 	endtask : body


endclass : sequence_G10
