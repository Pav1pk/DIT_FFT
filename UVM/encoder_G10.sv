/*
--------------------------------------------------------------------------------------------
-> It is an encoder box, which extends "uvm_scoreboard".
-> This box conists fot two ports , 
                i)  The tlm analysis fifo for receiving the sequence item message from the driver.
                ii)  The analysis port for sending 128 floating point frequency bins to the bit reversal block.

-> This encoder receives the 48 bits and encodes them into corresponding 128 frequency bins, which is of the datatype: "points_128".
-> These 128 frequency bins are passed to the bit reversal box.
-----------------------------------------------------------------------------------------------
*/

class encoder_G10 extends uvm_scoreboard;
    `uvm_component_utils (encoder_G10)

    sequence_item_G10 msg_drv_2_enc;
    bit [47:0] message;
    points_128 msg_enc_2_bit_reversal;
    point enc_out;

    logic [1:0] enc_switch = 2'b00;
    logic [1:0] slicing_bits = 2'b11;

    uvm_tlm_analysis_fifo #(sequence_item_G10) port_enc_from_drv; // port to receive data from the driver of the 48 bits

    uvm_analysis_port #(points_128) port_enc_2_bit_reversal; // port for sending the encoded data to the port_enc_2_bit_reversal

    function new (string name ="encoder_G10",uvm_component parent = null);
        super.new (name,parent);
    endfunction: new

    function void build_phase (uvm_phase phase);

        super.build_phase (phase);
        msg_drv_2_enc = sequence_item_G10::type_id::create("msg_drv_2_enc",this);
        //msg_enc_2_bit_reversal = sequence_item_G10::type_id::create("msg_enc_2_bit_reversal",this);
        //enc_out = point::type_id::create("enc_out",this);
        port_enc_from_drv = new("port_enc_from_drv",this);
        port_enc_2_bit_reversal = new ("port_enc_2_bit_reversal",this);

        `uvm_info("ENCODER","IN BUILD PHASE",UVM_NONE)
    endfunction: build_phase

    task encoder (input sequence_item_G10 msg, output point enc_out[128]);
            int freq_bin = 0;
            message = msg.bits;
    		while (freq_bin < 64) begin 
                //`uvm_info("Encoder Input---:::",$sformatf("Input Data: hex : %h  Binary: %b",message,message),UVM_LOW)
    			if (freq_bin <= 2)begin 
    				enc_out[freq_bin].real_part = 0.000;
                    enc_out[freq_bin].imaginary_part = 0.000;
    			end

    			else if (freq_bin >=4 && freq_bin < 52)begin // 4 to 50 :: 24 bins
    				enc_switch =  message[1:0] & slicing_bits;
    				case (enc_switch)
    					2'b00 : begin 
    								enc_out[freq_bin].real_part = 0.000;
    								enc_out[freq_bin].imaginary_part = 0.000;
    							end
    					2'b01: begin 
    						   		enc_out[freq_bin].real_part = 0.333;
    						   		enc_out[freq_bin].imaginary_part = 0.000;
    						   end
    				    2'b10: begin 
    				    			enc_out[freq_bin].real_part = 0.666;
    						   		enc_out[freq_bin].imaginary_part = 0.000;
    				    	   end
    				    2'b11: begin 
    				    			enc_out[freq_bin].real_part = 1.000;
    						   		enc_out[freq_bin].imaginary_part = 0.000;
    				    	   end
    				    default :begin 
    								enc_out[freq_bin].real_part = 0.000;
    								enc_out[freq_bin].imaginary_part = 0.000;
    							end		
    				endcase
                message = message >> 2;
    			end

    			else begin 
    				enc_out [freq_bin].real_part = 0.00;
    				enc_out[freq_bin].imaginary_part = 0.00;
    			end
    			enc_out[128 - freq_bin] = enc_out[freq_bin];
                // `uvm_info("Encoder Output:: --",$sformatf("Encoded Data [%0d]: real: %f imag: %f  \n",freq_bin,enc_out[freq_bin].real_part,enc_out[freq_bin].imaginary_part),UVM_LOW)
    			freq_bin = freq_bin + 2;
    		end
            enc_out[55].real_part = 1.00;
            enc_out[55].imaginary_part = 0.00;
            enc_out[128 - 55].real_part = 1.00;
            enc_out[128 - 55].imaginary_part = 0.00;
    endtask : encoder

    virtual task run_phase (uvm_phase phase);
        super.run_phase(phase);
        `uvm_info ("ENCODER","IN RUN PHASE",UVM_NONE)
    	// get the input 
    	// drive to encoder task
    	// send it to IFFt
    	forever begin 
    		port_enc_from_drv.get(msg_drv_2_enc);
    		 //`uvm_info("get",msg_drv_2_enc,UVM_MEDIUM)
             //`uvm_info("IN ENCODER's RUN PHASE:",$sformatf("\n Encoder's Input: %h",msg_drv_2_enc.bits),UVM_LOW)
                encoder (msg_drv_2_enc,msg_enc_2_bit_reversal.DATA);
    		 //`uvm_info("get",msg_enc_2_bit_reversal,UVM_MEDIUM)
            //$display("\n \n THE 128 POINTS: \n \n ");
            //for (int i=0;i<128;i++) `uvm_info("ENCODER's Output:",$sformatf("Encoder's Output [%0d]: real: %f imaginary: %f \n",i,msg_enc_2_bit_reversal.DATA[i].real_part,msg_enc_2_bit_reversal.DATA[i].imaginary_part),UVM_LOW)
            port_enc_2_bit_reversal.write(msg_enc_2_bit_reversal);
    	end
    endtask: run_phase



endclass : encoder_G10

