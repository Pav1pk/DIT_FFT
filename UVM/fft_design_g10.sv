/*
------------------------------------------------------------------------------------------------------------------------------------------
-> This is an FFT block acts as a "reference Model", which extends uvm_scoreboard for computing the butterfly operation.

-> It has two ports:
			i)   tlm anlaysis fifo port for collecting the 128 points from the Bit Reversal.
			ii)  analysis port for sending the 7 stage butterfly 128 floating frequency bins output to the Decoder. 

-> User defined Data types: point, points_128 , check these in the included files. for their definition

-> This block consists of task "fft_model", which takes 128 flaoting point frequency bins as input and output.

-> There is a function "fft_twiddle", which gives the twiddle factor according to the level and k, by : index = k<<(6-Level), which
is used in the butterfly computation.

-> There are three other function for performing complex multiplication, addition, subtraction, these takes two frequency bins points and give
two frequency bins poins ad outputs after mathematical operation.

-> The while loop, iterates all the 128 points in a single level, and the outer for loop runs for 7 times covering each level.

-> The inner for loop iterates over each set, by calling certain points at certain level and certain spread (k).

-> Then the output  sent to the Decoder Block.
-------------------------------------------------------------------------------------------------------------------------------------------
*/


class fft_design_g10 extends uvm_scoreboard;
	`uvm_component_utils (fft_design_g10)

	points_128 msg_bit_reversal_2_fft;
	points_128 msg_fft_2_dec;

	uvm_tlm_analysis_fifo #(points_128) port_fft_from_bit_reversal;
	uvm_analysis_port #(points_128) port_fft_2_dec;

	function new (string name = "fft_design_G10",uvm_component parent);
		super.new(name,parent);
	endfunction: new

	function void build_phase (uvm_phase phase);
		super.build_phase(phase);
		`uvm_info ("FFT MODE::  Reference Model","IN BUILD PHASE",UVM_NONE)
		port_fft_from_bit_reversal = new("port_fft_from_bit_reversal",this);
		port_fft_2_dec = new("port_fft_2_dec",this);
	endfunction: build_phase

// fft_twiddle for 128 points:
// 128/2 = 64 points
	virtual function point fft_twiddle (input reg [5:0] index_bits);
		point real_imaginary;
		case(index_bits)
			    0 : real_imaginary='{1.0, 0.0};
			    1 : real_imaginary='{0.9987954562051724, -0.049067674327418015};
			    2 : real_imaginary='{0.9951847266721969, -0.0980171403295606};
			    3 : real_imaginary='{0.989176509964781, -0.14673047445536175};
			    4 : real_imaginary='{0.9807852804032304, -0.19509032201612825};
			    5 : real_imaginary='{0.970031253194544, -0.24298017990326387};
			    6 : real_imaginary='{0.9569403357322088, -0.29028467725446233};
			    7 : real_imaginary='{0.9415440651830208, -0.33688985339222005};
			    8 : real_imaginary='{0.9238795325112867, -0.3826834323650898};
			    9 : real_imaginary='{0.9039892931234433, -0.4275550934302821};
			    10 : real_imaginary='{0.881921264348355, -0.47139673682599764};
			    11 : real_imaginary='{0.8577286100002721, -0.5141027441932217};
			    12 : real_imaginary='{0.8314696123025452, -0.5555702330196022};
			    13 : real_imaginary='{0.8032075314806449, -0.5956993044924334};
			    14 : real_imaginary='{0.773010453362737, -0.6343932841636455};
			    15 : real_imaginary='{0.7409511253549591, -0.6715589548470183};
			    16 : real_imaginary='{0.7071067811865476, -0.7071067811865475};
			    17 : real_imaginary='{0.6715589548470183, -0.7409511253549591};
			    18 : real_imaginary='{0.6343932841636455, -0.773010453362737};
			    19 : real_imaginary='{0.5956993044924335, -0.8032075314806448};
			    20 : real_imaginary='{0.5555702330196023, -0.8314696123025452};
			    21 : real_imaginary='{0.5141027441932217, -0.8577286100002721};
			    22 : real_imaginary='{0.4713967368259978, -0.8819212643483549};
			    23 : real_imaginary='{0.4275550934302822, -0.9039892931234433};
			    24 : real_imaginary='{0.38268343236508984, -0.9238795325112867};
			    25 : real_imaginary='{0.33688985339222005, -0.9415440651830208};
			    26 : real_imaginary='{0.29028467725446233, -0.9569403357322089};
			    27 : real_imaginary='{0.24298017990326398, -0.970031253194544};
			    28 : real_imaginary='{0.19509032201612833, -0.9807852804032304};
			    29 : real_imaginary='{0.14673047445536175, -0.989176509964781};
			    30 : real_imaginary='{0.09801714032956077, -0.9951847266721968};
			    31 : real_imaginary='{0.049067674327418126, -0.9987954562051724};
			    32 : real_imaginary='{6.123233995736766e-17, -1.0};
			    33 : real_imaginary='{-0.04906767432741801, -0.9987954562051724};
			    34 : real_imaginary='{-0.09801714032956065, -0.9951847266721969};
			    35 : real_imaginary='{-0.14673047445536164, -0.989176509964781};
			    36 : real_imaginary='{-0.1950903220161282, -0.9807852804032304};
			    37 : real_imaginary='{-0.24298017990326387, -0.970031253194544};
			    38 : real_imaginary='{-0.29028467725446216, -0.9569403357322089};
			    39 : real_imaginary='{-0.33688985339221994, -0.9415440651830208};
			    40 : real_imaginary='{-0.3826834323650897, -0.9238795325112867};
			    41 : real_imaginary='{-0.42755509343028186, -0.9039892931234434};
			    42 : real_imaginary='{-0.4713967368259977, -0.881921264348355};
			    43 : real_imaginary='{-0.5141027441932217, -0.8577286100002721};
			    44 : real_imaginary='{-0.555570233019602, -0.8314696123025455};
			    45 : real_imaginary='{-0.5956993044924334, -0.8032075314806449};
			    46 : real_imaginary='{-0.6343932841636454, -0.7730104533627371};
			    47 : real_imaginary='{-0.6715589548470184, -0.740951125354959};
			    48 : real_imaginary='{-0.7071067811865475, -0.7071067811865476};
			    49 : real_imaginary='{-0.7409511253549589, -0.6715589548470186};
			    50 : real_imaginary='{-0.773010453362737, -0.6343932841636455};
			    51 : real_imaginary='{-0.8032075314806448, -0.5956993044924335};
			    52 : real_imaginary='{-0.8314696123025453, -0.5555702330196022};
			    53 : real_imaginary='{-0.857728610000272, -0.5141027441932218};
			    54 : real_imaginary='{-0.8819212643483549, -0.47139673682599786};
			    55 : real_imaginary='{-0.9039892931234433, -0.42755509343028203};
			    56 : real_imaginary='{-0.9238795325112867, -0.3826834323650899};
			    57 : real_imaginary='{-0.9415440651830207, -0.33688985339222033};
			    58 : real_imaginary='{-0.9569403357322088, -0.2902846772544624};
			    59 : real_imaginary='{-0.970031253194544, -0.24298017990326407};
			    60 : real_imaginary='{-0.9807852804032304, -0.1950903220161286};
			    61 : real_imaginary='{-0.989176509964781, -0.1467304744553618};
			    62 : real_imaginary='{-0.9951847266721968, -0.09801714032956083};
			    63 : real_imaginary='{-0.9987954562051724, -0.049067674327417966};
  			endcase
		return real_imaginary;
	endfunction: fft_twiddle


	//complex multiplication:
	virtual function point complex_multiplication (input point x,y);
		point z;
		z.real_part = x.real_part * y.real_part - x.imaginary_part*y.imaginary_part;
		z.imaginary_part = x.real_part*y.imaginary_part + x.imaginary_part*y.real_part;
		return z;
	endfunction : complex_multiplication

	virtual function point complex_addition (input point x,y);
		point z;
		z.real_part = x.real_part + y.real_part;
		z.imaginary_part = x.imaginary_part + y.imaginary_part;
		return z;
	endfunction: complex_addition

	virtual function point complex_subtraction (input point x,y);
		point z;
		z.real_part = x.real_part - y.real_part;
		z.imaginary_part = x.imaginary_part - y.imaginary_part;
		return z;
	endfunction: complex_subtraction


	virtual task fft_model(input points_128 fft_input,output points_128 fft_model_o_p);
		int spread = 2;
		reg [2:0] level;
		int ix = 0;
		reg [5:0] index;
		int ptr1,ptr2;
		point index_vals,temp; 
		point val1,val2;
		
		// butterfly computation::
		fft_model_o_p.DATA = fft_input.DATA;
		for (level = 0;level < 7; level++) begin
			int point_count = 0;
			//$display(" \n \n AT LEVEL: %d \n \n ",level);
			while (point_count < 128) begin 
				for (int ix = point_count; ix < (point_count + (spread/2)); ix++) begin 
					index = (ix % spread)*(128/spread);
					ptr1 = ix;
					ptr2 = ix + (spread/2);
					index_vals = fft_twiddle(index);
					// complex numbers multiplication next..
					// need to add a function which does the multiplication
					// as stated by the professor.

					temp = complex_multiplication(fft_model_o_p.DATA[ptr2],index_vals);
					val1 = complex_addition(fft_model_o_p.DATA[ptr1],temp);
					val2 = complex_subtraction (fft_model_o_p.DATA[ptr1],temp);

					//$display("\n\n Twiddle Factor: real: %f  imag: %f  index: %0d, count: %0d",index_vals.real_part,index_vals.imaginary_part,index,point_count);
					//$display("temp:  real: %f  imag:%f, val1: real : %f  imag:%f, val2 : real:%f  imag:%f",temp.real_part,temp.imaginary_part,val1.real_part,val1.imaginary_part,val2.real_part,val2.imaginary_part);

					fft_model_o_p.DATA[ptr1] = val1;
					fft_model_o_p.DATA[ptr2] = val2;
				end
			point_count = point_count + spread;
			end
		  spread = spread*2;
	   end

  endtask : fft_model

	virtual task run_phase (uvm_phase phase);
	//`uvm_info ("FFT MODE::  Reference Model","IN RUN PHASE",UVM_NONE)
		super.run_phase(phase);
		forever begin
			port_fft_from_bit_reversal.get(msg_bit_reversal_2_fft);
			fft_model(msg_bit_reversal_2_fft,msg_fft_2_dec);
			port_fft_2_dec.write(msg_fft_2_dec);
			//$display("\n\n DISPLAYING THE FFT INPUTS AND OUTPUTS");
			//for (int j=0;j<128;j++) begin
				//$display("\n Index: %0d",j);
				//`uvm_info ("FFT INPUT::::",$sformatf(" Received Input : real: %f  imaginary: %f",msg_bit_reversal_2_fft.DATA[j].real_part,msg_bit_reversal_2_fft.DATA[j].imaginary_part),UVM_LOW)
				//`uvm_info ("FFT OUTPUT:::",$sformatf(" Output: real: %f, imaginary: %f \n\n",msg_fft_2_dec.DATA[j].real_part,msg_fft_2_dec.DATA[j].imaginary_part),UVM_LOW)
			//end
		end
	endtask : run_phase


endclass : fft_design_g10
