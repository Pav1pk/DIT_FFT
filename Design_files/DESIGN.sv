`include "new_data_types.sv"
`include "complex_multipliers.sv"
`include "fftw.sv"

module DESIGN_FFT (
	input wire 			clk,
	input wire 			reset,
	input wire 			PushIn,
	input wire 			FirstData,
	input wire 			[16:0]   DinR,
	input wire 			[16:0]   DinI,

	output reg 			PushOut,
	output reg [47:0]  Data_Out	
	);



// Output Registers :: ------------------------------------------->
reg        PushOut_d;
reg [47:0] Data_Out_d;

// Decoder Registers :::->
// ----------------------------------------------------------------
reg signed [23:0] max,max_d;
reg signed [23:0] Decision_Point1,Decision_Point2,Decision_Point3;
reg signed [45:0] d1,d2,d3;
reg signed [23:0] bin_55,bin_57;
reg signed [23:0] bin_i;

reg signed [23:0] p1 = 24'b00000_0000_001_0101_0101_0101; // 0.166
reg signed [23:0] p2 = 24'b000000000_011_1111_1101_1111; // 0.498...
reg signed [23:0] p3 = 24'b000000000_110_0000_0000_0000; // 0.75

reg [1:0] temp;
reg [47:0] temp_d,temp_d_q;
int index,ptr1,ptr2;


/// ----------- Decoder Registers Done -------------------------------


// I should have three state machines...... one for SAMPLING, one for FFT, one for DECODER

// -----------------------xx--------- FFT STATE MACHINES ------------------------------xxxxx---

typedef enum logic {IDLEA,SAMPLING} collect_states;
typedef enum logic [3:0] {IDLEB,LVL_0,LVL_1,LVL_2,LVL_3,LVL_4,LVL_5,LVL_6,OUTPUT_STATE} fft_states;
typedef enum logic [1:0] {IDLEC,MAX,EVAL,OUTPUT} decoder_states;

// -----------------------x-----------------------x--------------------------x---------------x

// BIT REVERSAL FUNCTION....

function fixed_128_point bit_reverse (input fixed_128_point input_data_br);
		
		fixed_128_point output_data_br = 0;
		
		bit [6:0] wx = 0;
		bit [6:0] rx = 0;

		for (int ix = 0; ix<128; ix++) begin
			wx = ix;
			rx = {wx[0],wx[1],wx[2],wx[3],wx[4],wx[5],wx[6]};
			output_data_br.fixed_point_data[ix] = input_data_br.fixed_point_data[rx]; 
		end
		return output_data_br;
endfunction : bit_reverse 

// ---------------------------------------x------------------------------------------------------

// Absolute Square........ function

function reg signed [23:0] abs_square (input fixed_point input_data);
	 reg signed [23:0] output_data = 0;
	 reg signed [45:0] m1 = 0;
	 reg signed [45:0] m2 = 0;
	 m1  = ((input_data.real_bits*input_data.real_bits)>>15);
	 m2  = ((input_data.imaginary_bits*input_data.imaginary_bits)>>15);
	 output_data = m1[22:0] + m2[22:0];
	 //$display(" Input: real::  %d   imag:: %d    Output: %d",input_data.real_bits,input_data.imaginary_bits,output_data);
	 return output_data;
endfunction : abs_square

// -------------------------------------x----------------------x-------------------x-----------------

// State Machines & its Regsiters:

collect_states current_collect_state,next_collect_state;
fft_states current_fft_state,next_fft_state;
decoder_states current_dec_state,next_dec_state;

reg [3:0] k,k_d;
reg [2:0] level,level_d;
reg [7:0] sm_count,sm_count_d;
reg [7:0] collect_state_counter,collect_state_counter_d;

// -----------------------------------x------------------------------x-----------------------x-----------

// get the sequential data
fixed_128_point parallel_data,parallel_data_d;

// reversing the received data
fixed_128_point reverse_data;

// output and input datas at each level
fixed_128_point level_input,level_input_d;

// decoder input
fixed_128_point decoder_input_d,decoder_input;


// Complex Multiplers :: --------------------x-------------------------x-------------------------------------x - //

// i) Complex Multiplier Takes two input and one twiddle factor in a single clock and produce two outputs
//  according to the butterfly Computration.....................

// 4 complex multipliers input and output
fixed_point [1:0] input_data_c1_d,output_data_c1_d;
fixed_point [1:0] input_data_c2_d,output_data_c2_d;
fixed_point [1:0] input_data_c3_d,output_data_c3_d;
fixed_point [1:0] input_data_c4_d,output_data_c4_d;

fixed_point [1:0] input_data_c1,output_data_c1;
fixed_point [1:0] input_data_c2,output_data_c2;
fixed_point [1:0] input_data_c3,output_data_c3;
fixed_point [1:0] input_data_c4,output_data_c4;

fixed_point twiddle_factor_c1_d,twiddle_factor_c2_d,twiddle_factor_c3_d,twiddle_factor_c4_d;
fixed_point twiddle_factor_c1,twiddle_factor_c2,twiddle_factor_c3,twiddle_factor_c4;

complex_multiplier C1 (   .input_data     (input_data_c1_d),
   						  .twiddle_factor (twiddle_factor_c1_d),
   						  .output_data    (output_data_c1_d)
   						  );

complex_multiplier C2 (.input_data     (input_data_c2_d),
   						  .twiddle_factor (twiddle_factor_c2_d),
   						  .output_data    (output_data_c2_d)
   						  );

complex_multiplier C3 (.input_data     (input_data_c3_d),
   						  .twiddle_factor (twiddle_factor_c3_d),
   						  .output_data    (output_data_c3_d)
   						  );

complex_multiplier C4 (.input_data     (input_data_c4_d),
   						  .twiddle_factor (twiddle_factor_c4_d),
   						  .output_data    (output_data_c4_d )
   						  );

// ---------------x-x-x-x- 4 Complex Multipliers Done -------x----x-x-x-x-x------------------------------- //



always @ (posedge clk or posedge reset) begin 

	if (reset) begin 

		current_dec_state 		<= IDLEC;
		current_fft_state 		<= IDLEB;
		current_collect_state   <= IDLEA;
		PushOut 				<= 0;
		Data_Out 				<= 0;
		collect_state_counter   <= 0;
		parallel_data           <= 0;
		k 						<= 0;
		sm_count                <= 0;
		level_input 			<= 0;
		decoder_input           <= 0;
		max 					<= 0;
		level 					<= 0;
		temp_d_q                <= 0;

		input_data_c1          <=  0;
		input_data_c2          <=  0;
		input_data_c3          <=  0;
		input_data_c4          <=  0;

		twiddle_factor_c1      <=   0;
		twiddle_factor_c2      <=   0;
		twiddle_factor_c3      <=   0;
		twiddle_factor_c4      <=   0;

		output_data_c1         <=   0;
		output_data_c2         <=   0;
		output_data_c3         <=   0;
		output_data_c4         <=   0;

	end

	else begin 

		current_dec_state  		<= next_dec_state;
		current_fft_state  		<= next_fft_state;
		current_collect_state   <= next_collect_state;
		PushOut 				<= PushOut_d;
		Data_Out                <= Data_Out_d;
		collect_state_counter   <= collect_state_counter_d;
		parallel_data           <= parallel_data_d;
		k                       <= k_d;
		sm_count                <= sm_count_d;
		level_input             <= level_input_d;
		decoder_input           <= decoder_input_d;
		max 					<= max_d;
		level 					<= level_d;
		temp_d_q                <= temp_d;

		input_data_c1          <=  input_data_c1_d;
		input_data_c2          <=  input_data_c2_d;
		input_data_c3          <=  input_data_c3_d;
		input_data_c4          <=  input_data_c4_d;

		twiddle_factor_c1      <=   twiddle_factor_c1_d;
		twiddle_factor_c2      <=   twiddle_factor_c2_d;
		twiddle_factor_c3      <=   twiddle_factor_c3_d;
		twiddle_factor_c4      <=   twiddle_factor_c4_d;

		output_data_c1         <=   output_data_c1_d;
		output_data_c2         <=   output_data_c2_d;
		output_data_c3         <=   output_data_c3_d;
		output_data_c4         <=   output_data_c4_d;
	end

end

always @(*) begin 
 	sm_count_d   = sm_count;
 	decoder_input_d = decoder_input;
 	k_d = k;
 	parallel_data_d = parallel_data;
 	level_input_d = level_input;
 	max_d = max;
 	level_d =level;
 	collect_state_counter_d = collect_state_counter;
 	next_fft_state = current_fft_state;
 	next_collect_state = current_collect_state;
 	next_dec_state = current_dec_state;
 	Data_Out_d = Data_Out;
 	PushOut_d = PushOut;
 	temp_d   = temp_d_q;

	input_data_c1_d          =  input_data_c1;
	input_data_c2_d        	 =  input_data_c2;
	input_data_c3_d          =  input_data_c3;
	input_data_c4_d          =  input_data_c4;

	twiddle_factor_c1_d      =   twiddle_factor_c1;
	twiddle_factor_c2_d      =   twiddle_factor_c2;
	twiddle_factor_c3_d      =   twiddle_factor_c3;
	twiddle_factor_c4_d      =   twiddle_factor_c4;

 	// Collect State FSM:::=>

	case (current_collect_state) // collect state

		IDLEA: begin
			if (reset) begin 
				next_collect_state = IDLEA;
				collect_state_counter_d = 0;
				parallel_data_d = 0;
				reverse_data = 0;
			end
			
			else 
				begin 
					if (PushIn) begin 
						if (FirstData) begin 
								if (DinR[16] == 1) parallel_data_d.fixed_point_data[0].real_bits =      {6'b1111_11,DinR}; 
								else parallel_data_d.fixed_point_data[0].real_bits = {6'b000000,DinR};
								if (DinI[16] == 1) parallel_data_d.fixed_point_data[0].imaginary_bits = $signed({6'b1111_11,DinI}); 
								else parallel_data_d.fixed_point_data[0].imaginary_bits = {6'b000000,DinI};
						end
						collect_state_counter_d = collect_state_counter + 1;
						next_collect_state = SAMPLING;
					end 
					else begin 
						next_collect_state = IDLEA;
						collect_state_counter_d = 0;
					end
			end
		end

		SAMPLING : begin 
			if (reset) begin 
				next_collect_state = IDLEA;
			end
			else if (PushIn) begin 
				if (collect_state_counter < 128) begin 
					next_collect_state = SAMPLING;

					if (~DinR[16]) parallel_data_d.fixed_point_data[collect_state_counter].real_bits = {6'b00_0000,DinR};

					else parallel_data_d.fixed_point_data[collect_state_counter].real_bits = {6'b11_1111,DinR};

				    if (DinI[16] == 1) parallel_data_d.fixed_point_data[collect_state_counter].imaginary_bits = {6'b1111_11,DinI};
				    else parallel_data_d.fixed_point_data[collect_state_counter].imaginary_bits = {6'b00_0000,DinI};
					collect_state_counter_d = collect_state_counter + 1;
				end
			end

			if (collect_state_counter == 128) begin 
				next_collect_state = IDLEA;
				reverse_data = bit_reverse(parallel_data_d);
				next_fft_state = LVL_0;
				level_input_d = reverse_data;
				collect_state_counter_d = 0;
			end

		end

	
	endcase // current_collect_state

/// FFFT DESIGN FSM :::

	case (current_fft_state)
		IDLEB : begin 
			if (reset) begin next_fft_state = IDLEB; end
			input_data_c1_d = 0;
			input_data_c2_d = 0;
			input_data_c3_d = 0;
			input_data_c4_d = 0;
			twiddle_factor_c1_d = 0;
			twiddle_factor_c2_d = 0;
			twiddle_factor_c3_d = 0;
			twiddle_factor_c4_d = 0;
		end

		LVL_0 : begin  // 2points ..this loop ran for 16 clocks... each clock = 4 sets
			if (reset) begin next_fft_state = IDLEB; end

			else begin 
				if (sm_count < 128) begin 

					   	twiddle_factor_c1_d  = fftwiddle (0);
   						twiddle_factor_c2_d  = fftwiddle (0);
   						twiddle_factor_c3_d  = fftwiddle (0);
   						twiddle_factor_c4_d  = fftwiddle (0);

   						case (k)

   								0: begin 
					   						input_data_c1_d = level_input.fixed_point_data[1:0];
					   						input_data_c2_d = level_input.fixed_point_data[3:2];
					   						input_data_c3_d = level_input.fixed_point_data[5:4];
					   						input_data_c4_d = level_input.fixed_point_data[7:6];


											level_input_d.fixed_point_data [1:0] = output_data_c1_d;
					   						level_input_d.fixed_point_data [3:2] = output_data_c2_d;
					   						level_input_d.fixed_point_data [5:4] = output_data_c3_d;
					   						level_input_d.fixed_point_data [7:6] = output_data_c4_d;
					 
					 						sm_count_d = sm_count+ 8;
					 						k_d = k + 1;
			 					 end

			   					1: begin 
					   						input_data_c1_d = level_input.fixed_point_data[8+1:8];
					   						input_data_c2_d = level_input.fixed_point_data[8+3:8+2];
					   						input_data_c3_d = level_input.fixed_point_data[8+5:8+4];
					   						input_data_c4_d = level_input.fixed_point_data[8+7:8+6];

					                        level_input_d.fixed_point_data [8+1:8]   = output_data_c1_d;
					   						level_input_d.fixed_point_data [8+3:8+2] = output_data_c2_d;
					   						level_input_d.fixed_point_data [8+5:8+4] = output_data_c3_d;
					   						level_input_d.fixed_point_data [8+7:8+6] = output_data_c4_d;
					 
					 						sm_count_d = sm_count + 8;
					 						k_d = k + 1;
			 					 end


			   					2: begin 
					   						input_data_c1_d = level_input.fixed_point_data[16+1:16];
					   						input_data_c2_d = level_input.fixed_point_data[16+3:16+2];
					   						input_data_c3_d = level_input.fixed_point_data[16+5:16+4];
					   						input_data_c4_d = level_input.fixed_point_data[16+7:16+6];

					                        level_input_d.fixed_point_data [16+1:16]   = output_data_c1_d;
					   						level_input_d.fixed_point_data [16+3:16+2] = output_data_c2_d;
					   						level_input_d.fixed_point_data [16+5:16+4] = output_data_c3_d;
					   						level_input_d.fixed_point_data [16+7:16+6] = output_data_c4_d;
					 
					 						sm_count_d = sm_count + 8;
					 						k_d = k + 1;
			 					 end


			   					3: begin 
					   						input_data_c1_d = level_input.fixed_point_data[24+1:24];
					   						input_data_c2_d = level_input.fixed_point_data[24+3:24+2];
					   						input_data_c3_d = level_input.fixed_point_data[24+5:24+4];
					   						input_data_c4_d = level_input.fixed_point_data[24+7:24+6];

					                        level_input_d.fixed_point_data [24+1:24]   = output_data_c1_d;
					   						level_input_d.fixed_point_data [24+3:24+2] = output_data_c2_d;
					   						level_input_d.fixed_point_data [24+5:24+4] = output_data_c3_d;
					   						level_input_d.fixed_point_data [24+7:24+6] = output_data_c4_d;
					 
					 						sm_count_d = sm_count + 8;
					 						k_d = k + 1;
			 					 end


			   					4: begin 
					   						input_data_c1_d = level_input.fixed_point_data[32+1:32];
					   						input_data_c2_d = level_input.fixed_point_data[32+3:32+2];
					   						input_data_c3_d = level_input.fixed_point_data[32+5:32+4];
					   						input_data_c4_d = level_input.fixed_point_data[32+7:32+6];

					                        level_input_d.fixed_point_data [32+1:32]   = output_data_c1_d;
					   						level_input_d.fixed_point_data [32+3:32+2] = output_data_c2_d;
					   						level_input_d.fixed_point_data [32+5:32+4] = output_data_c3_d;
					   						level_input_d.fixed_point_data [32+7:32+6] = output_data_c4_d;
					 
					 						sm_count_d = sm_count + 8;
					 						k_d = k + 1;
			 					 end


			   					5: begin 
					   						input_data_c1_d = level_input.fixed_point_data[40+1:40];
					   						input_data_c2_d = level_input.fixed_point_data[40+3:40+2];
					   						input_data_c3_d = level_input.fixed_point_data[40+5:40+4];
					   						input_data_c4_d = level_input.fixed_point_data[40+7:40+6];

					                        level_input_d.fixed_point_data [40+1:40]   = output_data_c1_d;
					   						level_input_d.fixed_point_data [40+3:40+2] = output_data_c2_d;
					   						level_input_d.fixed_point_data [40+5:40+4] = output_data_c3_d;
					   						level_input_d.fixed_point_data [40+7:40+6] = output_data_c4_d;
					 
					 						sm_count_d = sm_count + 8;
					 						k_d = k + 1;
			 					 end


			   					6: begin 
					   						input_data_c1_d = level_input.fixed_point_data[48+1:48];
					   						input_data_c2_d = level_input.fixed_point_data[48+3:48+2];
					   						input_data_c3_d = level_input.fixed_point_data[48+5:48+4];
					   						input_data_c4_d = level_input.fixed_point_data[48+7:48+6];

					                        level_input_d.fixed_point_data [48+1:48]   = output_data_c1_d;
					   						level_input_d.fixed_point_data [48+3:48+2] = output_data_c2_d;
					   						level_input_d.fixed_point_data [48+5:48+4] = output_data_c3_d;
					   						level_input_d.fixed_point_data [48+7:48+6] = output_data_c4_d;
					 
					 						sm_count_d = sm_count + 8;
					 						k_d = k + 1;
			 					 end


			   					7: begin 
					   						input_data_c1_d = level_input.fixed_point_data[56+1:56];
					   						input_data_c2_d = level_input.fixed_point_data[56+3:56+2];
					   						input_data_c3_d = level_input.fixed_point_data[56+5:56+4];
					   						input_data_c4_d = level_input.fixed_point_data[56+7:56+6];

					                        level_input_d.fixed_point_data [56+1:56]   = output_data_c1_d;
					   						level_input_d.fixed_point_data [56+3:56+2] = output_data_c2_d;
					   						level_input_d.fixed_point_data [56+5:56+4] = output_data_c3_d;
					   						level_input_d.fixed_point_data [56+7:56+6] = output_data_c4_d;
					 
					 						sm_count_d = sm_count + 8;
					 						k_d = k + 1;
			 					 end


			   					8: begin 
					   						input_data_c1_d = level_input.fixed_point_data[64+1:64];
					   						input_data_c2_d = level_input.fixed_point_data[64+3:64+2];
					   						input_data_c3_d = level_input.fixed_point_data[64+5:64+4];
					   						input_data_c4_d = level_input.fixed_point_data[64+7:64+6];

					                        level_input_d.fixed_point_data [64+1:64]   = output_data_c1_d;
					   						level_input_d.fixed_point_data [64+3:64+2] = output_data_c2_d;
					   						level_input_d.fixed_point_data [64+5:64+4] = output_data_c3_d;
					   						level_input_d.fixed_point_data [64+7:64+6] = output_data_c4_d;
					 
					 						sm_count_d = sm_count + 8;
					 						k_d = k + 1;
			 					 end


			   					9: begin 
					   						input_data_c1_d = level_input.fixed_point_data[72+1:72];
					   						input_data_c2_d = level_input.fixed_point_data[72+3:72+2];
					   						input_data_c3_d = level_input.fixed_point_data[72+5:72+4];
					   						input_data_c4_d = level_input.fixed_point_data[72+7:72+6];

					                        level_input_d.fixed_point_data [72+1:72]   = output_data_c1_d;
					   						level_input_d.fixed_point_data [72+3:72+2] = output_data_c2_d;
					   						level_input_d.fixed_point_data [72+5:72+4] = output_data_c3_d;
					   						level_input_d.fixed_point_data [72+7:72+6] = output_data_c4_d;
					 
					 						sm_count_d = sm_count + 8;
					 						k_d = k + 1;
			 					 end


			   					10: begin 
					   						input_data_c1_d = level_input.fixed_point_data[80+1:80];
					   						input_data_c2_d = level_input.fixed_point_data[80+3:80+2];
					   						input_data_c3_d = level_input.fixed_point_data[80+5:80+4];
					   						input_data_c4_d = level_input.fixed_point_data[80+7:80+6];

					                        level_input_d.fixed_point_data [80+1:80]   = output_data_c1_d;
					   						level_input_d.fixed_point_data [80+3:80+2] = output_data_c2_d;
					   						level_input_d.fixed_point_data [80+5:80+4] = output_data_c3_d;
					   						level_input_d.fixed_point_data [80+7:80+6] = output_data_c4_d;
					 
					 						sm_count_d = sm_count + 8;
					 						k_d = k + 1;
			 					 end


			   					11:begin 
					   						input_data_c1_d = level_input.fixed_point_data[88+1:88];
					   						input_data_c2_d = level_input.fixed_point_data[88+3:88+2];
					   						input_data_c3_d = level_input.fixed_point_data[88+5:88+4];
					   						input_data_c4_d = level_input.fixed_point_data[88+7:88+6];

					                        level_input_d.fixed_point_data [88+1:88]   = output_data_c1_d;
					   						level_input_d.fixed_point_data [88+3:88+2] = output_data_c2_d;
					   						level_input_d.fixed_point_data [88+5:88+4] = output_data_c3_d;
					   						level_input_d.fixed_point_data [88+7:88+6] = output_data_c4_d;
					 
					 						sm_count_d = sm_count + 8;
					 						k_d = k + 1;
			 					 end

			   					12: begin 
					   						input_data_c1_d = level_input.fixed_point_data[96+1:96];
					   						input_data_c2_d = level_input.fixed_point_data[96+3:96+2];
					   						input_data_c3_d = level_input.fixed_point_data[96+5:96+4];
					   						input_data_c4_d = level_input.fixed_point_data[96+7:96+6];

					                        level_input_d.fixed_point_data [96+1:96]   = output_data_c1_d;
					   						level_input_d.fixed_point_data [96+3:96+2] = output_data_c2_d;
					   						level_input_d.fixed_point_data [96+5:96+4] = output_data_c3_d;
					   						level_input_d.fixed_point_data [96+7:96+6] = output_data_c4_d;
					 
					 						sm_count_d = sm_count + 8;
					 						k_d = k + 1;
			 					 end


			   					13: begin 
					   						input_data_c1_d = level_input.fixed_point_data[104+1:104];
					   						input_data_c2_d = level_input.fixed_point_data[104+3:104+2];
					   						input_data_c3_d = level_input.fixed_point_data[104+5:104+4];
					   						input_data_c4_d = level_input.fixed_point_data[104+7:104+6];

					                        level_input_d.fixed_point_data [104+1:104]   = output_data_c1_d;
					   						level_input_d.fixed_point_data [104+3:104+2] = output_data_c2_d;
					   						level_input_d.fixed_point_data [104+5:104+4] = output_data_c3_d;
					   						level_input_d.fixed_point_data [104+7:104+6] = output_data_c4_d;
					 
					 						sm_count_d = sm_count + 8;
					 						k_d = k + 1;
			 					 end


			   					14: begin 
					   						input_data_c1_d = level_input.fixed_point_data[112+1:112];
					   						input_data_c2_d = level_input.fixed_point_data[112+3:112+2];
					   						input_data_c3_d = level_input.fixed_point_data[112+5:112+4];
					   						input_data_c4_d = level_input.fixed_point_data[112+7:112+6];

					                        level_input_d.fixed_point_data [112+1:112]   = output_data_c1_d;
					   						level_input_d.fixed_point_data [112+3:112+2] = output_data_c2_d;
					   						level_input_d.fixed_point_data [112+5:112+4] = output_data_c3_d;
					   						level_input_d.fixed_point_data [112+7:112+6] = output_data_c4_d;
					 
					 						sm_count_d = sm_count + 8;
					 						k_d = k + 1;
			 					 end


			   					15: begin 
					   						input_data_c1_d = level_input.fixed_point_data[120+1:120];
					   						input_data_c2_d = level_input.fixed_point_data[120+3:120+2];
					   						input_data_c3_d = level_input.fixed_point_data[120+5:120+4];
					   						input_data_c4_d = level_input.fixed_point_data[120+7:120+6];

					                        level_input_d.fixed_point_data [120+1:120]   = output_data_c1_d;
					   						level_input_d.fixed_point_data [120+3:120+2] = output_data_c2_d;
					   						level_input_d.fixed_point_data [120+5:120+4] = output_data_c3_d;
					   						level_input_d.fixed_point_data [120+7:120+6] = output_data_c4_d;
					 
					 						sm_count_d = sm_count + 8;
					 						k_d = k + 1;
			 					 end

 					   endcase

 					next_fft_state = LVL_0;
				end

				if (sm_count == 128) begin 
					next_fft_state = LVL_1;
					k_d = 0;
					sm_count_d = 0;
					level_d = 1;
				end
			end
		
		end

	    LVL_1 : begin // 4 points FFT, 16 clocks, each clock = 2 sets
	    	 if (reset) next_fft_state = IDLEB;
	    	 else begin

			    	 twiddle_factor_c1_d = fftwiddle(0);
			   		 twiddle_factor_c2_d = fftwiddle(32);
			  		 twiddle_factor_c3_d = fftwiddle(0);
			   		 twiddle_factor_c4_d = fftwiddle(32);

			   		 if (sm_count < 128) begin 

			   		 				   		 	case (k)

	   		   				0: begin 

		   		   				input_data_c1_d = {level_input.fixed_point_data[0+2],level_input.fixed_point_data[0]};
		   		   				input_data_c2_d = {level_input.fixed_point_data[0+3],level_input.fixed_point_data[0+1]};
		   		   				input_data_c3_d = {level_input.fixed_point_data[0+6],level_input.fixed_point_data[0+4]};
		   		   				input_data_c4_d = {level_input.fixed_point_data[0+7],level_input.fixed_point_data[0+5]};

		   		   				
		   		   				{level_input_d.fixed_point_data[0+2],level_input_d.fixed_point_data[0]}  = output_data_c1_d;
		   		   				{level_input_d.fixed_point_data[0+3],level_input_d.fixed_point_data[0+1]} = output_data_c2_d;
		   		   				{level_input_d.fixed_point_data[0+6],level_input_d.fixed_point_data[0+4]} = output_data_c3_d;
		   		   				{level_input_d.fixed_point_data[0+7],level_input_d.fixed_point_data[0+5]}  = output_data_c4_d;

			   		   			sm_count_d = sm_count + 8;
			   		   			k_d = k + 1;
			   		   	 	 end


			   		   	   1: begin 

		   		   				input_data_c1_d = {level_input.fixed_point_data[8+2],level_input.fixed_point_data[8]};
		   		   				input_data_c2_d = {level_input.fixed_point_data[8+3],level_input.fixed_point_data[8+1]};
		   		   				input_data_c3_d = {level_input.fixed_point_data[8+6],level_input.fixed_point_data[8+4]};
		   		   				input_data_c4_d = {level_input.fixed_point_data[8+7],level_input.fixed_point_data[8+5]};

		   		   				
		   		   				{level_input_d.fixed_point_data[8+2],level_input_d.fixed_point_data[8]} 	= output_data_c1_d;
		   		   				{level_input_d.fixed_point_data[8+3],level_input_d.fixed_point_data[8+1]} = output_data_c2_d;
		   		   				{level_input_d.fixed_point_data[8+6],level_input_d.fixed_point_data[8+4]} = output_data_c3_d;
		   		   				{level_input_d.fixed_point_data[8+7],level_input_d.fixed_point_data[8+5]}  = output_data_c4_d;

			   		   			sm_count_d = sm_count + 8;
			   		   			k_d = k + 1;
			   		   	 	 end

							
							2: begin

		   		   				input_data_c1_d = {level_input.fixed_point_data[16+2],level_input.fixed_point_data[16]};
		   		   				input_data_c2_d = {level_input.fixed_point_data[16+3],level_input.fixed_point_data[16+1]};
		   		   				input_data_c3_d = {level_input.fixed_point_data[16+6],level_input.fixed_point_data[16+4]};
		   		   				input_data_c4_d = {level_input.fixed_point_data[16+7],level_input.fixed_point_data[16+5]};

		   		   				
		   		   				{level_input_d.fixed_point_data[16+2],level_input_d.fixed_point_data[16]} 	= output_data_c1_d;
		   		   				{level_input_d.fixed_point_data[16+3],level_input_d.fixed_point_data[16+1]} = output_data_c2_d;
		   		   				{level_input_d.fixed_point_data[16+6],level_input_d.fixed_point_data[16+4]} = output_data_c3_d;
		   		   				{level_input_d.fixed_point_data[16+7],level_input_d.fixed_point_data[16+5]}  = output_data_c4_d;

			   		   			sm_count_d = sm_count + 8;
			   		   			k_d = k + 1;
			   		   	 	 end


			   		   	   3: begin 

		   		   				input_data_c1_d = {level_input.fixed_point_data[24+2],level_input.fixed_point_data[24]};
		   		   				input_data_c2_d = {level_input.fixed_point_data[24+3],level_input.fixed_point_data[24+1]};
		   		   				input_data_c3_d = {level_input.fixed_point_data[24+6],level_input.fixed_point_data[24+4]};
		   		   				input_data_c4_d = {level_input.fixed_point_data[24+7],level_input.fixed_point_data[24+5]};

		   		   				
		   		   				{level_input_d.fixed_point_data[24+2],level_input_d.fixed_point_data[24]} 	= output_data_c1_d;
		   		   				{level_input_d.fixed_point_data[24+3],level_input_d.fixed_point_data[24+1]} = output_data_c2_d;
		   		   				{level_input_d.fixed_point_data[24+6],level_input_d.fixed_point_data[24+4]} = output_data_c3_d;
		   		   				{level_input_d.fixed_point_data[24+7],level_input_d.fixed_point_data[24+5]}  = output_data_c4_d;

			   		   			sm_count_d = sm_count + 8;
			   		   			k_d = k + 1;
			   		   	 	 end


	   		   				4: begin 

		   		   				input_data_c1_d = {level_input.fixed_point_data[32+2],level_input.fixed_point_data[32]};
		   		   				input_data_c2_d = {level_input.fixed_point_data[32+3],level_input.fixed_point_data[32+1]};
		   		   				input_data_c3_d = {level_input.fixed_point_data[32+6],level_input.fixed_point_data[32+4]};
		   		   				input_data_c4_d = {level_input.fixed_point_data[32+7],level_input.fixed_point_data[32+5]};

		   		   				
		   		   				{level_input_d.fixed_point_data[32+2],level_input_d.fixed_point_data[32]} 	= output_data_c1_d;
		   		   				{level_input_d.fixed_point_data[32+3],level_input_d.fixed_point_data[32+1]} = output_data_c2_d;
		   		   				{level_input_d.fixed_point_data[32+6],level_input_d.fixed_point_data[32+4]} = output_data_c3_d;
		   		   				{level_input_d.fixed_point_data[32+7],level_input_d.fixed_point_data[32+5]}  = output_data_c4_d;
			   		   			
			   		   			sm_count_d = sm_count + 8;
			   		   			
			   		   			k_d = k + 1;
			   		   	 	 end


			   		   	   5: begin 

		   		   				input_data_c1_d = {level_input.fixed_point_data[40+2],level_input.fixed_point_data[40]};
		   		   				input_data_c2_d = {level_input.fixed_point_data[40+3],level_input.fixed_point_data[40+1]};
		   		   				input_data_c3_d = {level_input.fixed_point_data[40+6],level_input.fixed_point_data[40+4]};
		   		   				input_data_c4_d = {level_input.fixed_point_data[40+7],level_input.fixed_point_data[40+5]};

		   		   				
		   		   				{level_input_d.fixed_point_data[40+2],level_input_d.fixed_point_data[40]} 	= output_data_c1_d;
		   		   				{level_input_d.fixed_point_data[40+3],level_input_d.fixed_point_data[40+1]} = output_data_c2_d;
		   		   				{level_input_d.fixed_point_data[40+6],level_input_d.fixed_point_data[40+4]} = output_data_c3_d;
		   		   				{level_input_d.fixed_point_data[40+7],level_input_d.fixed_point_data[40+5]}  = output_data_c4_d;

			   		   			sm_count_d = sm_count + 8;
			   		   			k_d = k + 1;
			   		   	 	 end

							
							6: begin 

		   		   				input_data_c1_d = {level_input.fixed_point_data[48+2],level_input.fixed_point_data[48]};
		   		   				input_data_c2_d = {level_input.fixed_point_data[48+3],level_input.fixed_point_data[48+1]};
		   		   				input_data_c3_d = {level_input.fixed_point_data[48+6],level_input.fixed_point_data[48+4]};
		   		   				input_data_c4_d = {level_input.fixed_point_data[48+7],level_input.fixed_point_data[48+5]};

		   		   				
		   		   				{level_input_d.fixed_point_data[48+2],level_input_d.fixed_point_data[48]} 	= output_data_c1_d;
		   		   				{level_input_d.fixed_point_data[48+3],level_input_d.fixed_point_data[48+1]} = output_data_c2_d;
		   		   				{level_input_d.fixed_point_data[48+6],level_input_d.fixed_point_data[48+4]} = output_data_c3_d;
		   		   				{level_input_d.fixed_point_data[48+7],level_input_d.fixed_point_data[48+5]}  = output_data_c4_d;
			   		   			sm_count_d = sm_count + 8;
			   		   			k_d = k + 1;
			   		   	 	 end


			   		   	   7: begin 

		   		   				input_data_c1_d = {level_input.fixed_point_data[56+2],level_input.fixed_point_data[56]};
		   		   				input_data_c2_d = {level_input.fixed_point_data[56+3],level_input.fixed_point_data[56+1]};
		   		   				input_data_c3_d = {level_input.fixed_point_data[56+6],level_input.fixed_point_data[56+4]};
		   		   				input_data_c4_d = {level_input.fixed_point_data[56+7],level_input.fixed_point_data[56+5]};

		   		   				
		   		   				{level_input_d.fixed_point_data[56+2],level_input_d.fixed_point_data[56]} 	= output_data_c1_d;
		   		   				{level_input_d.fixed_point_data[56+3],level_input_d.fixed_point_data[56+1]} = output_data_c2_d;
		   		   				{level_input_d.fixed_point_data[56+6],level_input_d.fixed_point_data[56+4]} = output_data_c3_d;
		   		   				{level_input_d.fixed_point_data[56+7],level_input_d.fixed_point_data[56+5]}  = output_data_c4_d;

			   		   			sm_count_d = sm_count + 8;
			   		   			k_d = k + 1;
			   		   	 	 end

			   		   	 	8: begin 
		   		   				input_data_c1_d = {level_input.fixed_point_data[64+2],level_input.fixed_point_data[64]};
		   		   				input_data_c2_d = {level_input.fixed_point_data[64+3],level_input.fixed_point_data[64+1]};
		   		   				input_data_c3_d = {level_input.fixed_point_data[64+6],level_input.fixed_point_data[64+4]};
		   		   				input_data_c4_d = {level_input.fixed_point_data[64+7],level_input.fixed_point_data[64+5]};

		   		   				
		   		   				{level_input_d.fixed_point_data[64+2],level_input_d.fixed_point_data[64]} 	= output_data_c1_d;
		   		   				{level_input_d.fixed_point_data[64+3],level_input_d.fixed_point_data[64+1]} = output_data_c2_d;
		   		   				{level_input_d.fixed_point_data[64+6],level_input_d.fixed_point_data[64+4]} = output_data_c3_d;
		   		   				{level_input_d.fixed_point_data[64+7],level_input_d.fixed_point_data[64+5]}  = output_data_c4_d;

			   		   			sm_count_d = sm_count + 8;
			   		   			k_d = k + 1;
			   		   	 	 end


			   		   	   9: begin 
		   		   				input_data_c1_d = {level_input.fixed_point_data[72+2],level_input.fixed_point_data[72]};
		   		   				input_data_c2_d = {level_input.fixed_point_data[72+3],level_input.fixed_point_data[72+1]};
		   		   				input_data_c3_d = {level_input.fixed_point_data[72+6],level_input.fixed_point_data[72+4]};
		   		   				input_data_c4_d = {level_input.fixed_point_data[72+7],level_input.fixed_point_data[72+5]};

		   		   				
		   		   				{level_input_d.fixed_point_data[72+2],level_input_d.fixed_point_data[72]} 	= output_data_c1_d;
		   		   				{level_input_d.fixed_point_data[72+3],level_input_d.fixed_point_data[72+1]} = output_data_c2_d;
		   		   				{level_input_d.fixed_point_data[72+6],level_input_d.fixed_point_data[72+4]} = output_data_c3_d;
		   		   				{level_input_d.fixed_point_data[72+7],level_input_d.fixed_point_data[72+5]}  = output_data_c4_d;

			   		   			sm_count_d = sm_count + 8;
			   		   			k_d = k + 1;
			   		   	 	 end

							
							10: begin 

		   		   				input_data_c1_d = {level_input.fixed_point_data[80+2],level_input.fixed_point_data[80]};
		   		   				input_data_c2_d = {level_input.fixed_point_data[80+3],level_input.fixed_point_data[80+1]};
		   		   				input_data_c3_d = {level_input.fixed_point_data[80+6],level_input.fixed_point_data[80+4]};
		   		   				input_data_c4_d = {level_input.fixed_point_data[80+7],level_input.fixed_point_data[80+5]};

		   		   				
		   		   				{level_input_d.fixed_point_data[80+2],level_input_d.fixed_point_data[80]} 	= output_data_c1_d;
		   		   				{level_input_d.fixed_point_data[80+3],level_input_d.fixed_point_data[80+1]} = output_data_c2_d;
		   		   				{level_input_d.fixed_point_data[80+6],level_input_d.fixed_point_data[80+4]} = output_data_c3_d;
		   		   				{level_input_d.fixed_point_data[80+7],level_input_d.fixed_point_data[80+5]}  = output_data_c4_d;

			   		   			sm_count_d = sm_count + 8;
			   		   			k_d = k + 1;
			   		   	 	 end


			   		   	   11: begin 

		   		   				input_data_c1_d = {level_input.fixed_point_data[88+2],level_input.fixed_point_data[88]};
		   		   				input_data_c2_d = {level_input.fixed_point_data[88+3],level_input.fixed_point_data[88+1]};
		   		   				input_data_c3_d = {level_input.fixed_point_data[88+6],level_input.fixed_point_data[88+4]};
		   		   				input_data_c4_d = {level_input.fixed_point_data[88+7],level_input.fixed_point_data[88+5]};

		   		   				
		   		   				{level_input_d.fixed_point_data[88+2],level_input_d.fixed_point_data[88]} 	= output_data_c1_d;
		   		   				{level_input_d.fixed_point_data[88+3],level_input_d.fixed_point_data[88+1]} = output_data_c2_d;
		   		   				{level_input_d.fixed_point_data[88+6],level_input_d.fixed_point_data[88+4]} = output_data_c3_d;
		   		   				{level_input_d.fixed_point_data[88+7],level_input_d.fixed_point_data[88+5]}  = output_data_c4_d;

			   		   			sm_count_d = sm_count + 8;
			   		   			k_d = k + 1;
			   		   	 	 end

			   		   	 
	   		   				12: begin 

		   		   				input_data_c1_d = {level_input.fixed_point_data[96+2],level_input.fixed_point_data[96]};
		   		   				input_data_c2_d = {level_input.fixed_point_data[96+3],level_input.fixed_point_data[96+1]};
		   		   				input_data_c3_d = {level_input.fixed_point_data[96+6],level_input.fixed_point_data[96+4]};
		   		   				input_data_c4_d = {level_input.fixed_point_data[96+7],level_input.fixed_point_data[96+5]};

		   		   				
		   		   				{level_input_d.fixed_point_data[96+2],level_input_d.fixed_point_data[96]} 	= output_data_c1_d;
		   		   				{level_input_d.fixed_point_data[96+3],level_input_d.fixed_point_data[96+1]} = output_data_c2_d;
		   		   				{level_input_d.fixed_point_data[96+6],level_input_d.fixed_point_data[96+4]} = output_data_c3_d;
		   		   				{level_input_d.fixed_point_data[96+7],level_input_d.fixed_point_data[96+5]}  = output_data_c4_d;

			   		   			sm_count_d = sm_count + 8;
			   		   			k_d = k + 1;
			   		   	 	 end


			   		   	   13: begin 

		   		   				input_data_c1_d = {level_input.fixed_point_data[104+2],level_input.fixed_point_data[104]};
		   		   				input_data_c2_d = {level_input.fixed_point_data[104+3],level_input.fixed_point_data[104+1]};
		   		   				input_data_c3_d = {level_input.fixed_point_data[104+6],level_input.fixed_point_data[104+4]};
		   		   				input_data_c4_d = {level_input.fixed_point_data[104+7],level_input.fixed_point_data[104+5]};

		   		   				
		   		   				{level_input_d.fixed_point_data[104+2],level_input_d.fixed_point_data[104]} 	= output_data_c1_d;
		   		   				{level_input_d.fixed_point_data[104+3],level_input_d.fixed_point_data[104+1]} = output_data_c2_d;
		   		   				{level_input_d.fixed_point_data[104+6],level_input_d.fixed_point_data[104+4]} = output_data_c3_d;
		   		   				{level_input_d.fixed_point_data[104+7],level_input_d.fixed_point_data[104+5]}  = output_data_c4_d;

			   		   			sm_count_d = sm_count + 8;
			   		   			k_d = k + 1;
			   		   	 	 end

							
							14: begin

		   		   				input_data_c1_d = {level_input.fixed_point_data[112+2],level_input.fixed_point_data[112]};
		   		   				input_data_c2_d = {level_input.fixed_point_data[112+3],level_input.fixed_point_data[112+1]};
		   		   				input_data_c3_d = {level_input.fixed_point_data[112+6],level_input.fixed_point_data[112+4]};
		   		   				input_data_c4_d = {level_input.fixed_point_data[112+7],level_input.fixed_point_data[112+5]};

		   		   				
		   		   				{level_input_d.fixed_point_data[112+2],level_input_d.fixed_point_data[112]} 	= output_data_c1_d;
		   		   				{level_input_d.fixed_point_data[112+3],level_input_d.fixed_point_data[112+1]} = output_data_c2_d;
		   		   				{level_input_d.fixed_point_data[112+6],level_input_d.fixed_point_data[112+4]} = output_data_c3_d;
		   		   				{level_input_d.fixed_point_data[112+7],level_input_d.fixed_point_data[112+5]}  = output_data_c4_d;

			   		   			sm_count_d = sm_count + 8;
			   		   			k_d = k + 1;
			   		   	 	 end


			   		   	   15: begin 
			   		   	   	
		   		   				input_data_c1_d = {level_input.fixed_point_data[120+2],level_input.fixed_point_data[120]};
		   		   				input_data_c2_d = {level_input.fixed_point_data[120+3],level_input.fixed_point_data[120+1]};
		   		   				input_data_c3_d = {level_input.fixed_point_data[120+6],level_input.fixed_point_data[120+4]};
		   		   				input_data_c4_d = {level_input.fixed_point_data[120+7],level_input.fixed_point_data[120+5]};

		   		   				
		   		   				{level_input_d.fixed_point_data[120+2],level_input_d.fixed_point_data[120]} 	= output_data_c1_d;
		   		   				{level_input_d.fixed_point_data[120+3],level_input_d.fixed_point_data[120+1]} = output_data_c2_d;
		   		   				{level_input_d.fixed_point_data[120+6],level_input_d.fixed_point_data[120+4]} = output_data_c3_d;
		   		   				{level_input_d.fixed_point_data[120+7],level_input_d.fixed_point_data[120+5]}  = output_data_c4_d;

			   		   			sm_count_d = sm_count + 8;
			   		   			k_d = 0;
			   		   	 	 end 			
	   		   		  endcase
	   		   		  next_fft_state = LVL_1;
		   		    end

		   		    if (sm_count == 128) begin 
						next_fft_state = LVL_2;
						k_d = 0;
						sm_count_d = 0;
						level_d = 2;
				end
	    	 end

	    end

	    LVL_2 : begin // 8 point fft, 16 clks, with each clock of 1 set

	    		if (reset) next_fft_state = IDLEB;
	    		else begin

				    	 twiddle_factor_c1_d = fftwiddle(0);
				   		 twiddle_factor_c2_d = fftwiddle(16);
				  		 twiddle_factor_c3_d = fftwiddle(32);
				   		 twiddle_factor_c4_d = fftwiddle(48);

			   		 if (sm_count < 128) begin 

					    case (k)

			   		 		0: begin 
			   		   				input_data_c1_d = {level_input.fixed_point_data[0+4],level_input.fixed_point_data[0]};
			   		   				input_data_c2_d = {level_input.fixed_point_data[0+5],level_input.fixed_point_data[0+1]};
			   		   				input_data_c3_d = {level_input.fixed_point_data[0+6],level_input.fixed_point_data[0+2]};
			   		   				input_data_c4_d = {level_input.fixed_point_data[0+7],level_input.fixed_point_data[0+3]};

			   		   				
			   		   				{level_input_d.fixed_point_data[0+4],level_input_d.fixed_point_data[0]} = output_data_c1_d;
			   		   				{level_input_d.fixed_point_data[0+5],level_input_d.fixed_point_data[0+1]} = output_data_c2_d;
			   		   				{level_input_d.fixed_point_data[0+6],level_input_d.fixed_point_data[0+2]} = output_data_c3_d;
			   		   				{level_input_d.fixed_point_data[0+7],level_input_d.fixed_point_data[0+3]}  = output_data_c4_d;

			   		   				sm_count_d = sm_count + 8;
			   		   				k_d = k + 1;
			   		   		 end

	   		   				1: begin 

			   		   				input_data_c1_d = {level_input.fixed_point_data[8+4],level_input.fixed_point_data[8]};
			   		   				input_data_c2_d = {level_input.fixed_point_data[8+5],level_input.fixed_point_data[8+1]};
			   		   				input_data_c3_d = {level_input.fixed_point_data[8+6],level_input.fixed_point_data[8+2]};
			   		   				input_data_c4_d = {level_input.fixed_point_data[8+7],level_input.fixed_point_data[8+3]};

			   		   				
			   		   				{level_input_d.fixed_point_data[8+4],level_input_d.fixed_point_data[8]} = output_data_c1_d;
			   		   				{level_input_d.fixed_point_data[8+5],level_input_d.fixed_point_data[8+1]} = output_data_c2_d;
			   		   				{level_input_d.fixed_point_data[8+6],level_input_d.fixed_point_data[8+2]} = output_data_c3_d;
			   		   				{level_input_d.fixed_point_data[8+7],level_input_d.fixed_point_data[8+3]}  = output_data_c4_d;

			   		   				sm_count_d = sm_count + 8;
			   		   				k_d = k + 1;
			   		   		 end


			   		   	   2: begin 

			   		   				input_data_c1_d = {level_input.fixed_point_data[16+4],level_input.fixed_point_data[16]};
			   		   				input_data_c2_d = {level_input.fixed_point_data[16+5],level_input.fixed_point_data[16+1]};
			   		   				input_data_c3_d = {level_input.fixed_point_data[16+6],level_input.fixed_point_data[16+2]};
			   		   				input_data_c4_d = {level_input.fixed_point_data[16+7],level_input.fixed_point_data[16+3]};

			   		   				
			   		   				{level_input_d.fixed_point_data[16+4],level_input_d.fixed_point_data[16]} = output_data_c1_d;
			   		   				{level_input_d.fixed_point_data[16+5],level_input_d.fixed_point_data[16+1]} = output_data_c2_d;
			   		   				{level_input_d.fixed_point_data[16+6],level_input_d.fixed_point_data[16+2]} = output_data_c3_d;
			   		   				{level_input_d.fixed_point_data[16+7],level_input_d.fixed_point_data[16+3]}  = output_data_c4_d;

			   		   				sm_count_d = sm_count + 8;
			   		   				k_d = k + 1;
			   		   		 end


			   		   	  3: begin 

			   		   				input_data_c1_d = {level_input.fixed_point_data[24+4],level_input.fixed_point_data[24]};
			   		   				input_data_c2_d = {level_input.fixed_point_data[24+5],level_input.fixed_point_data[24+1]};
			   		   				input_data_c3_d = {level_input.fixed_point_data[24+6],level_input.fixed_point_data[24+2]};
			   		   				input_data_c4_d = {level_input.fixed_point_data[24+7],level_input.fixed_point_data[24+3]};

			   		   				
			   		   				{level_input_d.fixed_point_data[24+4],level_input_d.fixed_point_data[24]} = output_data_c1_d;
			   		   				{level_input_d.fixed_point_data[24+5],level_input_d.fixed_point_data[24+1]} = output_data_c2_d;
			   		   				{level_input_d.fixed_point_data[24+6],level_input_d.fixed_point_data[24+2]} = output_data_c3_d;
			   		   				{level_input_d.fixed_point_data[24+7],level_input_d.fixed_point_data[24+3]}  = output_data_c4_d;

			   		   				sm_count_d = sm_count + 8;
			   		   				k_d = k + 1;
			   		   		 end


			   		    	4: begin 

			   		   				input_data_c1_d = {level_input.fixed_point_data[32+4],level_input.fixed_point_data[32]};
			   		   				input_data_c2_d = {level_input.fixed_point_data[32+5],level_input.fixed_point_data[32+1]};
			   		   				input_data_c3_d = {level_input.fixed_point_data[32+6],level_input.fixed_point_data[32+2]};
			   		   				input_data_c4_d = {level_input.fixed_point_data[32+7],level_input.fixed_point_data[32+3]};

			   		   				
			   		   				{level_input_d.fixed_point_data[32+4],level_input_d.fixed_point_data[32]} = output_data_c1_d;
			   		   				{level_input_d.fixed_point_data[32+5],level_input_d.fixed_point_data[32+1]} = output_data_c2_d;
			   		   				{level_input_d.fixed_point_data[32+6],level_input_d.fixed_point_data[32+2]} = output_data_c3_d;
			   		   				{level_input_d.fixed_point_data[32+7],level_input_d.fixed_point_data[32+3]}  = output_data_c4_d;

			   		   				sm_count_d = sm_count + 8;
			   		   				k_d = k + 1;
			   		   		 end

			   		    	5: begin 

			   		   				input_data_c1_d = {level_input.fixed_point_data[40+4],level_input.fixed_point_data[40]};
			   		   				input_data_c2_d = {level_input.fixed_point_data[40+5],level_input.fixed_point_data[40+1]};
			   		   				input_data_c3_d = {level_input.fixed_point_data[40+6],level_input.fixed_point_data[40+2]};
			   		   				input_data_c4_d = {level_input.fixed_point_data[40+7],level_input.fixed_point_data[40+3]};

			   		   				
			   		   				{level_input_d.fixed_point_data[40+4],level_input_d.fixed_point_data[40]} = output_data_c1_d;
			   		   				{level_input_d.fixed_point_data[40+5],level_input_d.fixed_point_data[40+1]} = output_data_c2_d;
			   		   				{level_input_d.fixed_point_data[40+6],level_input_d.fixed_point_data[40+2]} = output_data_c3_d;
			   		   				{level_input_d.fixed_point_data[40+7],level_input_d.fixed_point_data[40+3]}  = output_data_c4_d;

			   		   				sm_count_d = sm_count + 8;
			   		   				k_d = k + 1;
			   		   		 end

			   		  	 	6: begin 

			   		   				input_data_c1_d = {level_input.fixed_point_data[48+4],level_input.fixed_point_data[48]};
			   		   				input_data_c2_d = {level_input.fixed_point_data[48+5],level_input.fixed_point_data[48+1]};
			   		   				input_data_c3_d = {level_input.fixed_point_data[48+6],level_input.fixed_point_data[48+2]};
			   		   				input_data_c4_d = {level_input.fixed_point_data[48+7],level_input.fixed_point_data[48+3]};

			   		   				
			   		   				{level_input_d.fixed_point_data[48+4],level_input_d.fixed_point_data[48]} = output_data_c1_d;
			   		   				{level_input_d.fixed_point_data[48+5],level_input_d.fixed_point_data[48+1]} = output_data_c2_d;
			   		   				{level_input_d.fixed_point_data[48+6],level_input_d.fixed_point_data[48+2]} = output_data_c3_d;
			   		   				{level_input_d.fixed_point_data[48+7],level_input_d.fixed_point_data[48+3]}  = output_data_c4_d;

			   		   				sm_count_d = sm_count + 8;
			   		   				k_d = k + 1;
			   		   		 end

			   		   	   7: begin 

			   		   				input_data_c1_d = {level_input.fixed_point_data[56+4],level_input.fixed_point_data[56]};
			   		   				input_data_c2_d = {level_input.fixed_point_data[56+5],level_input.fixed_point_data[56+1]};
			   		   				input_data_c3_d = {level_input.fixed_point_data[56+6],level_input.fixed_point_data[56+2]};
			   		   				input_data_c4_d = {level_input.fixed_point_data[56+7],level_input.fixed_point_data[56+3]};

			   		   				
			   		   				{level_input_d.fixed_point_data[56+4],level_input_d.fixed_point_data[56]} = output_data_c1_d;
			   		   				{level_input_d.fixed_point_data[56+5],level_input_d.fixed_point_data[56+1]} = output_data_c2_d;
			   		   				{level_input_d.fixed_point_data[56+6],level_input_d.fixed_point_data[56+2]} = output_data_c3_d;
			   		   				{level_input_d.fixed_point_data[56+7],level_input_d.fixed_point_data[56+3]}  = output_data_c4_d;

			   		   				sm_count_d = sm_count + 8;
			   		   				k_d = k + 1;
			   		   		 end

			   		   	  8: begin 

			   		   				input_data_c1_d = {level_input.fixed_point_data[64+4],level_input.fixed_point_data[64]};
			   		   				input_data_c2_d = {level_input.fixed_point_data[64+5],level_input.fixed_point_data[64+1]};
			   		   				input_data_c3_d = {level_input.fixed_point_data[64+6],level_input.fixed_point_data[64+2]};
			   		   				input_data_c4_d = {level_input.fixed_point_data[64+7],level_input.fixed_point_data[64+3]};

			   		   				
			   		   				{level_input_d.fixed_point_data[64+4],level_input_d.fixed_point_data[64]} = output_data_c1_d;
			   		   				{level_input_d.fixed_point_data[64+5],level_input_d.fixed_point_data[64+1]} = output_data_c2_d;
			   		   				{level_input_d.fixed_point_data[64+6],level_input_d.fixed_point_data[64+2]} = output_data_c3_d;
			   		   				{level_input_d.fixed_point_data[64+7],level_input_d.fixed_point_data[64+3]}  = output_data_c4_d;

			   		   				sm_count_d = sm_count + 8;
			   		   				k_d = k + 1;
			   		   		 end

			   		   	  9: begin 

			   		   				input_data_c1_d = {level_input.fixed_point_data[72+4],level_input.fixed_point_data[72]};
			   		   				input_data_c2_d = {level_input.fixed_point_data[72+5],level_input.fixed_point_data[72+1]};
			   		   				input_data_c3_d = {level_input.fixed_point_data[72+6],level_input.fixed_point_data[72+2]};
			   		   				input_data_c4_d = {level_input.fixed_point_data[72+7],level_input.fixed_point_data[72+3]};

			   		   				
			   		   				{level_input_d.fixed_point_data[72+4],level_input_d.fixed_point_data[72]} = output_data_c1_d;
			   		   				{level_input_d.fixed_point_data[72+5],level_input_d.fixed_point_data[72+1]} = output_data_c2_d;
			   		   				{level_input_d.fixed_point_data[72+6],level_input_d.fixed_point_data[72+2]} = output_data_c3_d;
			   		   				{level_input_d.fixed_point_data[72+7],level_input_d.fixed_point_data[72+3]}  = output_data_c4_d;

			   		   				sm_count_d = sm_count + 8;
			   		   				k_d = k + 1;
			   		   		 end

			   		   	   10: begin 

			   		   				input_data_c1_d = {level_input.fixed_point_data[80+4],level_input.fixed_point_data[80]};
			   		   				input_data_c2_d = {level_input.fixed_point_data[80+5],level_input.fixed_point_data[80+1]};
			   		   				input_data_c3_d = {level_input.fixed_point_data[80+6],level_input.fixed_point_data[80+2]};
			   		   				input_data_c4_d = {level_input.fixed_point_data[80+7],level_input.fixed_point_data[80+3]};

			   		   				
			   		   				{level_input_d.fixed_point_data[80+4],level_input_d.fixed_point_data[80]} = output_data_c1_d;
			   		   				{level_input_d.fixed_point_data[80+5],level_input_d.fixed_point_data[80+1]} = output_data_c2_d;
			   		   				{level_input_d.fixed_point_data[80+6],level_input_d.fixed_point_data[80+2]} = output_data_c3_d;
			   		   				{level_input_d.fixed_point_data[80+7],level_input_d.fixed_point_data[80+3]}  = output_data_c4_d;

			   		   				sm_count_d = sm_count + 8;
			   		   				k_d = k + 1;
			   		   		 end

			   		   	   11: begin 
			   		   							   		   				
			   		   				input_data_c1_d = {level_input.fixed_point_data[88+4],level_input.fixed_point_data[88]};
			   		   				input_data_c2_d = {level_input.fixed_point_data[88+5],level_input.fixed_point_data[88+1]};
			   		   				input_data_c3_d = {level_input.fixed_point_data[88+6],level_input.fixed_point_data[88+2]};
			   		   				input_data_c4_d = {level_input.fixed_point_data[88+7],level_input.fixed_point_data[88+3]};

			   		   				
			   		   				{level_input_d.fixed_point_data[88+4],level_input_d.fixed_point_data[88]} = output_data_c1_d;
			   		   				{level_input_d.fixed_point_data[88+5],level_input_d.fixed_point_data[88+1]} = output_data_c2_d;
			   		   				{level_input_d.fixed_point_data[88+6],level_input_d.fixed_point_data[88+2]} = output_data_c3_d;
			   		   				{level_input_d.fixed_point_data[88+7],level_input_d.fixed_point_data[88+3]}  = output_data_c4_d;
			   		   				sm_count_d = sm_count + 8;
			   		   				k_d = k + 1;
			   		   		 end

			   		   		12: begin 

			   		   				input_data_c1_d = {level_input.fixed_point_data[96+4],level_input.fixed_point_data[96]};
			   		   				input_data_c2_d = {level_input.fixed_point_data[96+5],level_input.fixed_point_data[96+1]};
			   		   				input_data_c3_d = {level_input.fixed_point_data[96+6],level_input.fixed_point_data[96+2]};
			   		   				input_data_c4_d = {level_input.fixed_point_data[96+7],level_input.fixed_point_data[96+3]};

			   		   				
			   		   				{level_input_d.fixed_point_data[96+4],level_input_d.fixed_point_data[96]} = output_data_c1_d;
			   		   				{level_input_d.fixed_point_data[96+5],level_input_d.fixed_point_data[96+1]} = output_data_c2_d;
			   		   				{level_input_d.fixed_point_data[96+6],level_input_d.fixed_point_data[96+2]} = output_data_c3_d;
			   		   				{level_input_d.fixed_point_data[96+7],level_input_d.fixed_point_data[96+3]}  = output_data_c4_d;

			   		   				sm_count_d = sm_count + 8;
			   		   				k_d = k + 1;
			   		   		 end

			   		   	    13: begin

			   		   				input_data_c1_d = {level_input.fixed_point_data[104+4],level_input.fixed_point_data[104]};
			   		   				input_data_c2_d = {level_input.fixed_point_data[104+5],level_input.fixed_point_data[104+1]};
			   		   				input_data_c3_d = {level_input.fixed_point_data[104+6],level_input.fixed_point_data[104+2]};
			   		   				input_data_c4_d = {level_input.fixed_point_data[104+7],level_input.fixed_point_data[104+3]};

			   		   				
			   		   				{level_input_d.fixed_point_data[104+4],level_input_d.fixed_point_data[104]} = output_data_c1_d;
			   		   				{level_input_d.fixed_point_data[104+5],level_input_d.fixed_point_data[104+1]} = output_data_c2_d;
			   		   				{level_input_d.fixed_point_data[104+6],level_input_d.fixed_point_data[104+2]} = output_data_c3_d;
			   		   				{level_input_d.fixed_point_data[104+7],level_input_d.fixed_point_data[104+3]}  = output_data_c4_d;

			   		   				sm_count_d = sm_count + 8;
			   		   				k_d = k + 1;
			   		   		 end

			   		   		14: begin 

			   		   				input_data_c1_d = {level_input.fixed_point_data[112+4],level_input.fixed_point_data[112]};
			   		   				input_data_c2_d = {level_input.fixed_point_data[112+5],level_input.fixed_point_data[112+1]};
			   		   				input_data_c3_d = {level_input.fixed_point_data[112+6],level_input.fixed_point_data[112+2]};
			   		   				input_data_c4_d = {level_input.fixed_point_data[112+7],level_input.fixed_point_data[112+3]};

			   		   				
			   		   				{level_input_d.fixed_point_data[112+4],level_input_d.fixed_point_data[112]} = output_data_c1_d;
			   		   				{level_input_d.fixed_point_data[112+5],level_input_d.fixed_point_data[112+1]} = output_data_c2_d;
			   		   				{level_input_d.fixed_point_data[112+6],level_input_d.fixed_point_data[112+2]} = output_data_c3_d;
			   		   				{level_input_d.fixed_point_data[112+7],level_input_d.fixed_point_data[112+3]}  = output_data_c4_d;
			   		   				sm_count_d = sm_count + 8;
			   		   				k_d = k + 1;
			   		   		 end

			   		   		15: begin 

			   		   				input_data_c1_d = {level_input.fixed_point_data[120+4],level_input.fixed_point_data[120]};
			   		   				input_data_c2_d = {level_input.fixed_point_data[120+5],level_input.fixed_point_data[120+1]};
			   		   				input_data_c3_d = {level_input.fixed_point_data[120+6],level_input.fixed_point_data[120+2]};
			   		   				input_data_c4_d = {level_input.fixed_point_data[120+7],level_input.fixed_point_data[120+3]};

			   		   				
			   		   				{level_input_d.fixed_point_data[120+4],level_input_d.fixed_point_data[120]} = output_data_c1_d;
			   		   				{level_input_d.fixed_point_data[120+5],level_input_d.fixed_point_data[120+1]} = output_data_c2_d;
			   		   				{level_input_d.fixed_point_data[120+6],level_input_d.fixed_point_data[120+2]} = output_data_c3_d;
			   		   				{level_input_d.fixed_point_data[120+7],level_input_d.fixed_point_data[120+3]}  = output_data_c4_d;

			   		   				sm_count_d = sm_count + 8;
			   		   				k_d = 0;
			   		   		 end 
	   		   		  endcase
	   		   		  next_fft_state = LVL_2; 
		   		    end

		   		    if (sm_count == 128) begin 
					next_fft_state = LVL_3;
					sm_count_d = 0;
					level_d = 3;
					end

	    	 end

	    end

	   
	   	LVL_3 : begin // 16 points takes 2 clk cycles for one set

		    		if (reset) begin next_fft_state = IDLEB; end

		    			if (sm_count < 128) begin 

		   		   		 	case (k)

		   		   		 		0: begin 

		   		   		 				twiddle_factor_c1_d  = fftwiddle (0);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (8);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (16);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (24);

							   		   	input_data_c1_d = {level_input.fixed_point_data[0+8],level_input.fixed_point_data[0]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[0+9],level_input.fixed_point_data[0+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[0+10],level_input.fixed_point_data[0+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[0+11],level_input.fixed_point_data[0+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[0+8],level_input_d.fixed_point_data[0]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[0+9],level_input_d.fixed_point_data[0+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[0+10],level_input_d.fixed_point_data[0+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[0+11],level_input_d.fixed_point_data[0+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
		   		   		 			end

		   		   		 		1: begin 

		   		   		 				twiddle_factor_c1_d  = fftwiddle (32);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (40);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (48);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (56);


					   		   		   	input_data_c1_d = {level_input.fixed_point_data[4+8],level_input.fixed_point_data[4]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[4+9],level_input.fixed_point_data[4+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[4+10],level_input.fixed_point_data[4+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[4+11],level_input.fixed_point_data[4+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[4+8],level_input_d.fixed_point_data[4]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[4+9],level_input_d.fixed_point_data[4+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[4+10],level_input_d.fixed_point_data[4+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[4+11],level_input_d.fixed_point_data[4+3]} = output_data_c4_d;
						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;

		   		   		 			end
		   		   		 			
		   		   		 		2: begin 

		   		   		 				twiddle_factor_c1_d  = fftwiddle (0);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (8);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (16);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (24);

							   		   	input_data_c1_d = {level_input.fixed_point_data[16+8],level_input.fixed_point_data[16]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[16+9],level_input.fixed_point_data[16+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[16+10],level_input.fixed_point_data[16+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[16+11],level_input.fixed_point_data[16+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[16+8],level_input_d.fixed_point_data[16]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[16+9],level_input_d.fixed_point_data[16+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[16+10],level_input_d.fixed_point_data[16+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[16+11],level_input_d.fixed_point_data[16+3]} = output_data_c4_d;
						   		   		
						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
		   		   		 			end

		   		   		 		3: begin 

		   		   		 				twiddle_factor_c1_d  = fftwiddle (32);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (40);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (48);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (56);


					   		   		 	input_data_c1_d = {level_input.fixed_point_data[20+8],level_input.fixed_point_data[20]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[20+9],level_input.fixed_point_data[20+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[20+10],level_input.fixed_point_data[20+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[20+11],level_input.fixed_point_data[20+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[20+8],level_input_d.fixed_point_data[20]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[20+9],level_input_d.fixed_point_data[20+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[20+10],level_input_d.fixed_point_data[20+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[20+11],level_input_d.fixed_point_data[20+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;

		   		   		 			end

		   		   		 		 4: begin 

		   		   		 				twiddle_factor_c1_d  = fftwiddle (0);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (8);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (16);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (24);

							   		   	input_data_c1_d = {level_input.fixed_point_data[32+8],level_input.fixed_point_data[32]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[32+9],level_input.fixed_point_data[32+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[32+10],level_input.fixed_point_data[32+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[32+11],level_input.fixed_point_data[32+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[32+8],level_input_d.fixed_point_data[32]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[32+9],level_input_d.fixed_point_data[32+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[32+10],level_input_d.fixed_point_data[32+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[32+11],level_input_d.fixed_point_data[32+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
		   		   		 			end

		   		   		 		5: begin 

		   		   		 				twiddle_factor_c1_d  = fftwiddle (32);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (40);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (48);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (56);


							   		   	input_data_c1_d = {level_input.fixed_point_data[36+8],level_input.fixed_point_data[36]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[36+9],level_input.fixed_point_data[36+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[36+10],level_input.fixed_point_data[36+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[36+11],level_input.fixed_point_data[36+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[36+8],level_input_d.fixed_point_data[36]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[36+9],level_input_d.fixed_point_data[36+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[36+10],level_input_d.fixed_point_data[36+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[36+11],level_input_d.fixed_point_data[36+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;

		   		   		 			end

		   		   		 		6: begin 

		   		   		 				twiddle_factor_c1_d  = fftwiddle (0);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (8);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (16);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (24);

							   		   	input_data_c1_d = {level_input.fixed_point_data[48+8],level_input.fixed_point_data[48]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[48+9],level_input.fixed_point_data[48+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[48+10],level_input.fixed_point_data[48+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[48+11],level_input.fixed_point_data[48+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[48+8],level_input_d.fixed_point_data[48]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[48+9],level_input_d.fixed_point_data[48+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[48+10],level_input_d.fixed_point_data[48+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[48+11],level_input_d.fixed_point_data[48+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k +1;
		   		   		 			end

		   		   		 		7: begin 

		   		   		 				twiddle_factor_c1_d  = fftwiddle (32);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (40);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (48);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (56);


							   		   	input_data_c1_d = {level_input.fixed_point_data[52+8],level_input.fixed_point_data[52]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[52+9],level_input.fixed_point_data[52+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[52+10],level_input.fixed_point_data[52+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[52+11],level_input.fixed_point_data[52+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[52+8],level_input_d.fixed_point_data[52]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[52+9],level_input_d.fixed_point_data[52+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[52+10],level_input_d.fixed_point_data[52+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[52+11],level_input_d.fixed_point_data[52+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;

		   		   		 			end
		   		   		 			
		   		   		 		8: begin 

		   		   		 				twiddle_factor_c1_d  = fftwiddle (0);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (8);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (16);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (24);

							   		   	input_data_c1_d = {level_input.fixed_point_data[64+8],level_input.fixed_point_data[64]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[64+9],level_input.fixed_point_data[64+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[64+10],level_input.fixed_point_data[64+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[64+11],level_input.fixed_point_data[64+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[64+8],level_input_d.fixed_point_data[64]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[64+9],level_input_d.fixed_point_data[64+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[64+10],level_input_d.fixed_point_data[64+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[64+11],level_input_d.fixed_point_data[64+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
		   		   		 			end

		   		   		 	   9: begin 

		   		   		 				twiddle_factor_c1_d  = fftwiddle (32);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (40);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (48);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (56);


							   		   	input_data_c1_d = {level_input.fixed_point_data[68+8],level_input.fixed_point_data[68]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[68+9],level_input.fixed_point_data[68+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[68+10],level_input.fixed_point_data[68+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[68+11],level_input.fixed_point_data[68+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[68+8],level_input_d.fixed_point_data[68]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[68+9],level_input_d.fixed_point_data[68+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[68+10],level_input_d.fixed_point_data[68+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[68+11],level_input_d.fixed_point_data[68+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;

		   		   		 			end

		   		   		 		10: begin 

		   		   		 				twiddle_factor_c1_d  = fftwiddle (0);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (8);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (16);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (24);

							   		   	input_data_c1_d = {level_input.fixed_point_data[80+8],level_input.fixed_point_data[80]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[80+9],level_input.fixed_point_data[80+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[80+10],level_input.fixed_point_data[80+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[80+11],level_input.fixed_point_data[80+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[80+8],level_input_d.fixed_point_data[80]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[80+9],level_input_d.fixed_point_data[80+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[80+10],level_input_d.fixed_point_data[80+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[80+11],level_input_d.fixed_point_data[80+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
		   		   		 			end

		   		   		 		
		   		   		 		11: begin 

		   		   		 				twiddle_factor_c1_d  = fftwiddle (32);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (40);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (48);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (56);


							   		   	input_data_c1_d = {level_input.fixed_point_data[84+8],level_input.fixed_point_data[84]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[84+9],level_input.fixed_point_data[84+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[84+10],level_input.fixed_point_data[84+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[84+11],level_input.fixed_point_data[84+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[84+8],level_input_d.fixed_point_data[84]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[84+9],level_input_d.fixed_point_data[84+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[84+10],level_input_d.fixed_point_data[84+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[84+11],level_input_d.fixed_point_data[84+3]} = output_data_c4_d;
						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;

		   		   		 			end


		   		   		 		12: begin 

		   		   		 				twiddle_factor_c1_d  = fftwiddle (0);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (8);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (16);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (24);
							   		   	input_data_c1_d = {level_input.fixed_point_data[96+8],level_input.fixed_point_data[96]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[96+9],level_input.fixed_point_data[96+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[96+10],level_input.fixed_point_data[96+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[96+11],level_input.fixed_point_data[96+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[96+8],level_input_d.fixed_point_data[96]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[96+9],level_input_d.fixed_point_data[96+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[96+10],level_input_d.fixed_point_data[96+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[96+11],level_input_d.fixed_point_data[96+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
		   		   		 			end

		   		   		 		
		   		   		 		13: begin 

		   		   		 				twiddle_factor_c1_d  = fftwiddle (32);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (40);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (48);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (56);


							   		   	input_data_c1_d = {level_input.fixed_point_data[100+8],level_input.fixed_point_data[100]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[100+9],level_input.fixed_point_data[100+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[100+10],level_input.fixed_point_data[100+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[100+11],level_input.fixed_point_data[100+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[100+8],level_input_d.fixed_point_data[100]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[100+9],level_input_d.fixed_point_data[100+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[100+10],level_input_d.fixed_point_data[100+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[100+11],level_input_d.fixed_point_data[100+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;

		   		   		 			end

		   		   		 			
		   		   		 	    14: begin 

		   		   		 				twiddle_factor_c1_d  = fftwiddle (0);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (8);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (16);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (24);

							   		   	input_data_c1_d = {level_input.fixed_point_data[112+8],level_input.fixed_point_data[112]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[112+9],level_input.fixed_point_data[112+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[112+10],level_input.fixed_point_data[112+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[112+11],level_input.fixed_point_data[112+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[112+8],level_input_d.fixed_point_data[112]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[112+9],level_input_d.fixed_point_data[112+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[112+10],level_input_d.fixed_point_data[112+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[112+11],level_input_d.fixed_point_data[112+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
		   		   		 			end

		   		   		 		15: begin 

		   		   		 				twiddle_factor_c1_d  = fftwiddle (32);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (40);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (48);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (56);


					   		   		 	input_data_c1_d = {level_input.fixed_point_data[116+8],level_input.fixed_point_data[116]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[116+9],level_input.fixed_point_data[116+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[116+10],level_input.fixed_point_data[116+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[116+11],level_input.fixed_point_data[116+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[116+8],level_input_d.fixed_point_data[116]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[116+9],level_input_d.fixed_point_data[116+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[116+10],level_input_d.fixed_point_data[116+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[116+11],level_input_d.fixed_point_data[116+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;

		   		   		 			end
		   		   		 	endcase
		   		   		 	next_fft_state = LVL_3;
		   		   	end 

		   		   	if (sm_count == 128) begin 
	   		     	
	   		     	level_d = 4;
	   		     	k_d = 0;
	   		     	next_fft_state = LVL_4;
	   		     	sm_count_d = 0;
	   		     	end

		end // LVL _3


        LVL_4 : begin // 32 points, takes 4 clk cycles... for one set

		   		if (reset) next_fft_state = IDLEB; 

		   		if (sm_count < 128) begin 

							case (k) 

		   						0: begin 	
		   									twiddle_factor_c1_d  = fftwiddle (0);
						   		   		 	twiddle_factor_c2_d  = fftwiddle (4);
						   		   		 	twiddle_factor_c3_d  = fftwiddle (8);
						   		   		 	twiddle_factor_c4_d  = fftwiddle (12);

						   		   		 	input_data_c1_d = {level_input.fixed_point_data[0+16],level_input.fixed_point_data[0]};
							   		   		input_data_c2_d = {level_input.fixed_point_data[0+17],level_input.fixed_point_data[0+1]};
							   		   		input_data_c3_d = {level_input.fixed_point_data[0+18],level_input.fixed_point_data[0+2]};
							   		   		input_data_c4_d = {level_input.fixed_point_data[0+19],level_input.fixed_point_data[0+3]};

							   		   				
							   		   		{level_input_d.fixed_point_data[0+16],level_input_d.fixed_point_data[0]} = output_data_c1_d;
							   		   		{level_input_d.fixed_point_data[0+17],level_input_d.fixed_point_data[0+1]} = output_data_c2_d;
							   		   		{level_input_d.fixed_point_data[0+18],level_input_d.fixed_point_data[0+2]} = output_data_c3_d;
							   		   		{level_input_d.fixed_point_data[0+19],level_input_d.fixed_point_data[0+3]} = output_data_c4_d;

							   		   		sm_count_d = sm_count + 8;
							   		   		k_d = k + 1;
							   		
							   		end

							    1: begin 

							    			twiddle_factor_c1_d  = fftwiddle (16);
						   		   		 	twiddle_factor_c2_d  = fftwiddle (20);
						   		   		 	twiddle_factor_c3_d  = fftwiddle (24);
						   		   		 	twiddle_factor_c4_d  = fftwiddle (28);

						   		   		 	input_data_c1_d = {level_input.fixed_point_data[4+16],level_input.fixed_point_data[4]};
							   		   		input_data_c2_d = {level_input.fixed_point_data[4+17],level_input.fixed_point_data[4+1]};
							   		   		input_data_c3_d = {level_input.fixed_point_data[4+18],level_input.fixed_point_data[4+2]};
							   		   		input_data_c4_d = {level_input.fixed_point_data[4+19],level_input.fixed_point_data[4+3]};

							   		   				
							   		   		{level_input_d.fixed_point_data[4+16],level_input_d.fixed_point_data[4]} 	= output_data_c1_d;
							   		   		{level_input_d.fixed_point_data[4+17],level_input_d.fixed_point_data[4+1]} = output_data_c2_d;
							   		   		{level_input_d.fixed_point_data[4+18],level_input_d.fixed_point_data[4+2]} = output_data_c3_d;
							   		   		{level_input_d.fixed_point_data[4+19],level_input_d.fixed_point_data[4+3]} = output_data_c4_d;

							   		   		sm_count_d = sm_count + 8;
							   		   		k_d = k +1;
							   
							   	    end

							    2: begin 

							    			twiddle_factor_c1_d  = fftwiddle (32);
						   		   		 	twiddle_factor_c2_d  = fftwiddle (36);
						   		   		 	twiddle_factor_c3_d  = fftwiddle (40);
						   		   		 	twiddle_factor_c4_d  = fftwiddle (44);

						   		   		 	input_data_c1_d = {level_input.fixed_point_data[8+16],level_input.fixed_point_data[8]};
							   		   		input_data_c2_d = {level_input.fixed_point_data[8+17],level_input.fixed_point_data[8+1]};
							   		   		input_data_c3_d = {level_input.fixed_point_data[8+18],level_input.fixed_point_data[8+2]};
							   		   		input_data_c4_d = {level_input.fixed_point_data[8+19],level_input.fixed_point_data[8+3]};

							   		   				
							   		   		{level_input_d.fixed_point_data[8+16],level_input_d.fixed_point_data[8]} 	= output_data_c1_d;
							   		   		{level_input_d.fixed_point_data[8+17],level_input_d.fixed_point_data[8+1]} = output_data_c2_d;
							   		   		{level_input_d.fixed_point_data[8+18],level_input_d.fixed_point_data[8+2]} = output_data_c3_d;
							   		   		{level_input_d.fixed_point_data[8+19],level_input_d.fixed_point_data[8+3]} = output_data_c4_d;

							   		   		sm_count_d = sm_count + 8;
							   		   		k_d = k + 1;
							    
							        end


							     3: begin 

							    			twiddle_factor_c1_d  = fftwiddle (48);
						   		   		 	twiddle_factor_c2_d  = fftwiddle (52);
						   		   		 	twiddle_factor_c3_d  = fftwiddle (56);
						   		   		 	twiddle_factor_c4_d  = fftwiddle (60);

						   		   		 	input_data_c1_d = {level_input.fixed_point_data[12+16],level_input.fixed_point_data[12]};
							   		   		input_data_c2_d = {level_input.fixed_point_data[12+17],level_input.fixed_point_data[12+1]};
							   		   		input_data_c3_d = {level_input.fixed_point_data[12+18],level_input.fixed_point_data[12+2]};
							   		   		input_data_c4_d = {level_input.fixed_point_data[12+19],level_input.fixed_point_data[12+3]};

							   		   				
							   		   		{level_input_d.fixed_point_data[12+16],level_input_d.fixed_point_data[12]} 	= output_data_c1_d;
							   		   		{level_input_d.fixed_point_data[12+17],level_input_d.fixed_point_data[12+1]} = output_data_c2_d;
							   		   		{level_input_d.fixed_point_data[12+18],level_input_d.fixed_point_data[12+2]} = output_data_c3_d;
							   		   		{level_input_d.fixed_point_data[12+19],level_input_d.fixed_point_data[12+3]} = output_data_c4_d;

							   		   		sm_count_d = sm_count + 8;
							   		   		k_d = k + 1;
							  
							       end

							   	4: begin 	
		   									twiddle_factor_c1_d  = fftwiddle (0);
						   		   		 	twiddle_factor_c2_d  = fftwiddle (4);
						   		   		 	twiddle_factor_c3_d  = fftwiddle (8);
						   		   		 	twiddle_factor_c4_d  = fftwiddle (12);

						   		   		 	input_data_c1_d = {level_input.fixed_point_data[32+16],level_input.fixed_point_data[32]};
							   		   		input_data_c2_d = {level_input.fixed_point_data[32+17],level_input.fixed_point_data[32+1]};
							   		   		input_data_c3_d = {level_input.fixed_point_data[32+18],level_input.fixed_point_data[32+2]};
							   		   		input_data_c4_d = {level_input.fixed_point_data[32+19],level_input.fixed_point_data[32+3]};

							   		   				
							   		   		{level_input_d.fixed_point_data[32+16],level_input_d.fixed_point_data[32]} = output_data_c1_d;
							   		   		{level_input_d.fixed_point_data[32+17],level_input_d.fixed_point_data[32+1]} = output_data_c2_d;
							   		   		{level_input_d.fixed_point_data[32+18],level_input_d.fixed_point_data[32+2]} = output_data_c3_d;
							   		   		{level_input_d.fixed_point_data[32+19],level_input_d.fixed_point_data[32+3]} = output_data_c4_d;

							   		   		sm_count_d = sm_count + 8;
							   		   		k_d = k + 1;
							   		
							   		end

							    5: begin 

							    			twiddle_factor_c1_d  = fftwiddle (16);
						   		   		 	twiddle_factor_c2_d  = fftwiddle (20);
						   		   		 	twiddle_factor_c3_d  = fftwiddle (24);
						   		   		 	twiddle_factor_c4_d  = fftwiddle (28);

						   		   		 	input_data_c1_d = {level_input.fixed_point_data[36+16],level_input.fixed_point_data[36]};
							   		   		input_data_c2_d = {level_input.fixed_point_data[36+17],level_input.fixed_point_data[36+1]};
							   		   		input_data_c3_d = {level_input.fixed_point_data[36+18],level_input.fixed_point_data[36+2]};
							   		   		input_data_c4_d = {level_input.fixed_point_data[36+19],level_input.fixed_point_data[36+3]};

							   		   				
							   		   		{level_input_d.fixed_point_data[36+16],level_input_d.fixed_point_data[36]} 	= output_data_c1_d;
							   		   		{level_input_d.fixed_point_data[36+17],level_input_d.fixed_point_data[36+1]} = output_data_c2_d;
							   		   		{level_input_d.fixed_point_data[36+18],level_input_d.fixed_point_data[36+2]} = output_data_c3_d;
							   		   		{level_input_d.fixed_point_data[36+19],level_input_d.fixed_point_data[36+3]} = output_data_c4_d;

							   		   		sm_count_d = sm_count + 8;
							   		   		k_d = k +1;
							   
							   	    end

							    6: begin 

							    			twiddle_factor_c1_d  = fftwiddle (32);
						   		   		 	twiddle_factor_c2_d  = fftwiddle (36);
						   		   		 	twiddle_factor_c3_d  = fftwiddle (40);
						   		   		 	twiddle_factor_c4_d  = fftwiddle (44);

						   		   		 	input_data_c1_d = {level_input.fixed_point_data[40+16],level_input.fixed_point_data[40]};
							   		   		input_data_c2_d = {level_input.fixed_point_data[40+17],level_input.fixed_point_data[40+1]};
							   		   		input_data_c3_d = {level_input.fixed_point_data[40+18],level_input.fixed_point_data[40+2]};
							   		   		input_data_c4_d = {level_input.fixed_point_data[40+19],level_input.fixed_point_data[40+3]};

							   		   				
							   		   		{level_input_d.fixed_point_data[40+16],level_input_d.fixed_point_data[40]} 	= output_data_c1_d;
							   		   		{level_input_d.fixed_point_data[40+17],level_input_d.fixed_point_data[40+1]} = output_data_c2_d;
							   		   		{level_input_d.fixed_point_data[40+18],level_input_d.fixed_point_data[40+2]} = output_data_c3_d;
							   		   		{level_input_d.fixed_point_data[40+19],level_input_d.fixed_point_data[40+3]} = output_data_c4_d;

							   		   		sm_count_d = sm_count + 8;
							   		   		k_d = k + 1;
							    
							        end


							     7: begin 

							    			twiddle_factor_c1_d  = fftwiddle (48);
						   		   		 	twiddle_factor_c2_d  = fftwiddle (52);
						   		   		 	twiddle_factor_c3_d  = fftwiddle (56);
						   		   		 	twiddle_factor_c4_d  = fftwiddle (60);

						   		   		 	input_data_c1_d = {level_input.fixed_point_data[44+16],level_input.fixed_point_data[44]};
							   		   		input_data_c2_d = {level_input.fixed_point_data[44+17],level_input.fixed_point_data[44+1]};
							   		   		input_data_c3_d = {level_input.fixed_point_data[44+18],level_input.fixed_point_data[44+2]};
							   		   		input_data_c4_d = {level_input.fixed_point_data[44+19],level_input.fixed_point_data[44+3]};

							   		   				
							   		   		{level_input_d.fixed_point_data[44+16],level_input_d.fixed_point_data[44]} 	= output_data_c1_d;
							   		   		{level_input_d.fixed_point_data[44+17],level_input_d.fixed_point_data[44+1]} = output_data_c2_d;
							   		   		{level_input_d.fixed_point_data[44+18],level_input_d.fixed_point_data[44+2]} = output_data_c3_d;
							   		   		{level_input_d.fixed_point_data[44+19],level_input_d.fixed_point_data[44+3]} = output_data_c4_d;

							   		   		sm_count_d = sm_count + 8;
							   		   		k_d = k + 1;
							  
							       end

							      8: begin 	
		   									twiddle_factor_c1_d  = fftwiddle (0);
						   		   		 	twiddle_factor_c2_d  = fftwiddle (4);
						   		   		 	twiddle_factor_c3_d  = fftwiddle (8);
						   		   		 	twiddle_factor_c4_d  = fftwiddle (12);

						   		   		 	input_data_c1_d = {level_input.fixed_point_data[64+16],level_input.fixed_point_data[64]};
							   		   		input_data_c2_d = {level_input.fixed_point_data[64+17],level_input.fixed_point_data[64+1]};
							   		   		input_data_c3_d = {level_input.fixed_point_data[64+18],level_input.fixed_point_data[64+2]};
							   		   		input_data_c4_d = {level_input.fixed_point_data[64+19],level_input.fixed_point_data[64+3]};

							   		   				
							   		   		{level_input_d.fixed_point_data[64+16],level_input_d.fixed_point_data[64]} 	= output_data_c1_d;
							   		   		{level_input_d.fixed_point_data[64+17],level_input_d.fixed_point_data[64+1]} = output_data_c2_d;
							   		   		{level_input_d.fixed_point_data[64+18],level_input_d.fixed_point_data[64+2]} = output_data_c3_d;
							   		   		{level_input_d.fixed_point_data[64+19],level_input_d.fixed_point_data[64+3]} = output_data_c4_d;

							   		   		sm_count_d = sm_count + 8;
							   		   		k_d = k + 1;
							   		
							   		end

							    9: begin 

							    			twiddle_factor_c1_d  = fftwiddle (16);
						   		   		 	twiddle_factor_c2_d  = fftwiddle (20);
						   		   		 	twiddle_factor_c3_d  = fftwiddle (24);
						   		   		 	twiddle_factor_c4_d  = fftwiddle (28);

						   		   		 	input_data_c1_d = {level_input.fixed_point_data[68+16],level_input.fixed_point_data[68]};
							   		   		input_data_c2_d = {level_input.fixed_point_data[68+17],level_input.fixed_point_data[68+1]};
							   		   		input_data_c3_d = {level_input.fixed_point_data[68+18],level_input.fixed_point_data[68+2]};
							   		   		input_data_c4_d = {level_input.fixed_point_data[68+19],level_input.fixed_point_data[68+3]};


							   		   		{level_input_d.fixed_point_data[68+16],level_input_d.fixed_point_data[68]} 	= output_data_c1_d;
							   		   		{level_input_d.fixed_point_data[68+17],level_input_d.fixed_point_data[68+1]} = output_data_c2_d;
							   		   		{level_input_d.fixed_point_data[68+18],level_input_d.fixed_point_data[68+2]} = output_data_c3_d;
							   		   		{level_input_d.fixed_point_data[68+19],level_input_d.fixed_point_data[68+3]} = output_data_c4_d;

							   		   		sm_count_d = sm_count + 8;
							   		   		k_d = k +1;
							   
							   	    end

							    10: begin 

							    			twiddle_factor_c1_d  = fftwiddle (32);
						   		   		 	twiddle_factor_c2_d  = fftwiddle (36);
						   		   		 	twiddle_factor_c3_d  = fftwiddle (40);
						   		   		 	twiddle_factor_c4_d  = fftwiddle (44);

						   		   		 	input_data_c1_d = {level_input.fixed_point_data[72+16],level_input.fixed_point_data[72]};
							   		   		input_data_c2_d = {level_input.fixed_point_data[72+17],level_input.fixed_point_data[72+1]};
							   		   		input_data_c3_d = {level_input.fixed_point_data[72+18],level_input.fixed_point_data[72+2]};
							   		   		input_data_c4_d = {level_input.fixed_point_data[72+19],level_input.fixed_point_data[72+3]};

							   		   				
							   		   		{level_input_d.fixed_point_data[72+16],level_input_d.fixed_point_data[72]} 	= output_data_c1_d;
							   		   		{level_input_d.fixed_point_data[72+17],level_input_d.fixed_point_data[72+1]} = output_data_c2_d;
							   		   		{level_input_d.fixed_point_data[72+18],level_input_d.fixed_point_data[72+2]} = output_data_c3_d;
							   		   		{level_input_d.fixed_point_data[72+19],level_input_d.fixed_point_data[72+3]} = output_data_c4_d;

							   		   		sm_count_d = sm_count + 8;
							   		   		k_d = k + 1;
							    
							        end


							     11: begin 

							    			twiddle_factor_c1_d  = fftwiddle (48);
						   		   		 	twiddle_factor_c2_d  = fftwiddle (52);
						   		   		 	twiddle_factor_c3_d  = fftwiddle (56);
						   		   		 	twiddle_factor_c4_d  = fftwiddle (60);

						   		   		 	input_data_c1_d = {level_input.fixed_point_data[76+16],level_input.fixed_point_data[76]};
							   		   		input_data_c2_d = {level_input.fixed_point_data[76+17],level_input.fixed_point_data[76+1]};
							   		   		input_data_c3_d = {level_input.fixed_point_data[76+18],level_input.fixed_point_data[76+2]};
							   		   		input_data_c4_d = {level_input.fixed_point_data[76+19],level_input.fixed_point_data[76+3]};

							   		   				
							   		   		{level_input_d.fixed_point_data[76+16],level_input_d.fixed_point_data[76]} 	= output_data_c1_d;
							   		   		{level_input_d.fixed_point_data[76+17],level_input_d.fixed_point_data[76+1]} = output_data_c2_d;
							   		   		{level_input_d.fixed_point_data[76+18],level_input_d.fixed_point_data[76+2]} = output_data_c3_d;
							   		   		{level_input_d.fixed_point_data[76+19],level_input_d.fixed_point_data[76+3]} = output_data_c4_d;

							   		   		sm_count_d = sm_count + 8;
							   		   		k_d = k + 1;
							  
							       end

							      12: begin 	
		   									twiddle_factor_c1_d  = fftwiddle (0);
						   		   		 	twiddle_factor_c2_d  = fftwiddle (4);
						   		   		 	twiddle_factor_c3_d  = fftwiddle (8);
						   		   		 	twiddle_factor_c4_d  = fftwiddle (12);

						   		   		 	input_data_c1_d = {level_input.fixed_point_data[96+16],level_input.fixed_point_data[96]};
							   		   		input_data_c2_d = {level_input.fixed_point_data[96+17],level_input.fixed_point_data[96+1]};
							   		   		input_data_c3_d = {level_input.fixed_point_data[96+18],level_input.fixed_point_data[96+2]};
							   		   		input_data_c4_d = {level_input.fixed_point_data[96+19],level_input.fixed_point_data[96+3]};

							   		   				
							   		   		{level_input_d.fixed_point_data[96+16],level_input_d.fixed_point_data[96]} 	= output_data_c1_d;
							   		   		{level_input_d.fixed_point_data[96+17],level_input_d.fixed_point_data[96+1]} = output_data_c2_d;
							   		   		{level_input_d.fixed_point_data[96+18],level_input_d.fixed_point_data[96+2]} = output_data_c3_d;
							   		   		{level_input_d.fixed_point_data[96+19],level_input_d.fixed_point_data[96+3]} = output_data_c4_d;
							   		   		
							   		   		sm_count_d = sm_count + 8;
							   		   		k_d = k + 1;
							   		
							   		end

							    13: begin 

							    			twiddle_factor_c1_d  = fftwiddle (16);
						   		   		 	twiddle_factor_c2_d  = fftwiddle (20);
						   		   		 	twiddle_factor_c3_d  = fftwiddle (24);
						   		   		 	twiddle_factor_c4_d  = fftwiddle (28);

						   		   		 	input_data_c1_d = {level_input.fixed_point_data[100+16],level_input.fixed_point_data[100]};
							   		   		input_data_c2_d = {level_input.fixed_point_data[100+17],level_input.fixed_point_data[100+1]};
							   		   		input_data_c3_d = {level_input.fixed_point_data[100+18],level_input.fixed_point_data[100+2]};
							   		   		input_data_c4_d = {level_input.fixed_point_data[100+19],level_input.fixed_point_data[100+3]};

							   		   				
							   		   		{level_input_d.fixed_point_data[100+16],level_input_d.fixed_point_data[100]} 	= output_data_c1_d;
							   		   		{level_input_d.fixed_point_data[100+17],level_input_d.fixed_point_data[100+1]} = output_data_c2_d;
							   		   		{level_input_d.fixed_point_data[100+18],level_input_d.fixed_point_data[100+2]} = output_data_c3_d;
							   		   		{level_input_d.fixed_point_data[100+19],level_input_d.fixed_point_data[100+3]} = output_data_c4_d;

							   		   		sm_count_d = sm_count + 8;
							   		   		k_d = k +1;
							   
							   	    end

							    14: begin 

							    			twiddle_factor_c1_d  = fftwiddle (32);
						   		   		 	twiddle_factor_c2_d  = fftwiddle (36);
						   		   		 	twiddle_factor_c3_d  = fftwiddle (40);
						   		   		 	twiddle_factor_c4_d  = fftwiddle (44);

						   		   		 	input_data_c1_d = {level_input.fixed_point_data[104+16],level_input.fixed_point_data[104]};
							   		   		input_data_c2_d = {level_input.fixed_point_data[104+17],level_input.fixed_point_data[104+1]};
							   		   		input_data_c3_d = {level_input.fixed_point_data[104+18],level_input.fixed_point_data[104+2]};
							   		   		input_data_c4_d = {level_input.fixed_point_data[104+19],level_input.fixed_point_data[104+3]};

							   		   				
							   		   		{level_input_d.fixed_point_data[104+16],level_input_d.fixed_point_data[104]} 	= output_data_c1_d;
							   		   		{level_input_d.fixed_point_data[104+17],level_input_d.fixed_point_data[104+1]} = output_data_c2_d;
							   		   		{level_input_d.fixed_point_data[104+18],level_input_d.fixed_point_data[104+2]} = output_data_c3_d;
							   		   		{level_input_d.fixed_point_data[104+19],level_input_d.fixed_point_data[104+3]} = output_data_c4_d;

							   		   		sm_count_d = sm_count + 8;
							   		   		k_d = k + 1;
							    
							        end


							     15: begin 

							    			twiddle_factor_c1_d  = fftwiddle (48);
						   		   		 	twiddle_factor_c2_d  = fftwiddle (52);
						   		   		 	twiddle_factor_c3_d  = fftwiddle (56);
						   		   		 	twiddle_factor_c4_d  = fftwiddle (60);

						   		   		 	input_data_c1_d = {level_input.fixed_point_data[108+16],level_input.fixed_point_data[108]};
							   		   		input_data_c2_d = {level_input.fixed_point_data[108+17],level_input.fixed_point_data[108+1]};
							   		   		input_data_c3_d = {level_input.fixed_point_data[108+18],level_input.fixed_point_data[108+2]};
							   		   		input_data_c4_d = {level_input.fixed_point_data[108+19],level_input.fixed_point_data[108+3]};

							   		   				
							   		   		{level_input_d.fixed_point_data[108+16],level_input_d.fixed_point_data[108]} 	= output_data_c1_d;
							   		   		{level_input_d.fixed_point_data[108+17],level_input_d.fixed_point_data[108+1]} = output_data_c2_d;
							   		   		{level_input_d.fixed_point_data[108+18],level_input_d.fixed_point_data[108+2]} = output_data_c3_d;
							   		   		{level_input_d.fixed_point_data[108+19],level_input_d.fixed_point_data[108+3]} = output_data_c4_d;

							   		   		sm_count_d = sm_count + 8;
							   		   		k_d = k + 1;
							  
							       end

		   				endcase

		   			next_fft_state = LVL_4;
		   		end

		   		if (sm_count == 128) begin 
	   		       	level_d = 5;
	   		       	k_d = 0;
	   		     	next_fft_state = LVL_5;
	   		     	sm_count_d = 0;
	   		    end
		
		end // LVL_4

		LVL_5 : begin // 64 points, takes 8 clk cycles...for one set

		   		if (reset) next_fft_state = IDLEB; 

		   		else if (sm_count < 128) begin 

		   				case (k) 

		   							0 : begin 

				   						twiddle_factor_c1_d  = fftwiddle (0);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (2);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (4);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (6);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[0+32],level_input.fixed_point_data[0]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[0+33],level_input.fixed_point_data[0+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[0+34],level_input.fixed_point_data[0+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[0+35],level_input.fixed_point_data[0+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[0+32],level_input_d.fixed_point_data[0]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[0+33],level_input_d.fixed_point_data[0+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[0+34],level_input_d.fixed_point_data[0+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[0+35],level_input_d.fixed_point_data[0+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
						   		   	end

						   		   	1 : begin 

				   						twiddle_factor_c1_d  = fftwiddle (8);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (10);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (12);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (14);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[4+32],level_input.fixed_point_data[4]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[4+33],level_input.fixed_point_data[4+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[4+34],level_input.fixed_point_data[4+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[4+35],level_input.fixed_point_data[4+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[4+32],level_input_d.fixed_point_data[4]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[4+33],level_input_d.fixed_point_data[4+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[4+34],level_input_d.fixed_point_data[4+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[4+35],level_input_d.fixed_point_data[4+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
						   		   	end

						   		   	2 : begin 

				   						twiddle_factor_c1_d  = fftwiddle (16);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (18);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (20);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (22);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[8+32],level_input.fixed_point_data[8]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[8+33],level_input.fixed_point_data[8+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[8+34],level_input.fixed_point_data[8+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[8+35],level_input.fixed_point_data[8+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[8+32],level_input_d.fixed_point_data[8]} = output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[8+33],level_input_d.fixed_point_data[8+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[8+34],level_input_d.fixed_point_data[8+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[8+35],level_input_d.fixed_point_data[8+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
						   		   	end


						   		   	3 : begin 

				   						twiddle_factor_c1_d  = fftwiddle (24);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (26);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (28);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (30);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[12+32],level_input.fixed_point_data[12]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[12+33],level_input.fixed_point_data[12+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[12+34],level_input.fixed_point_data[12+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[12+35],level_input.fixed_point_data[12+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[12+32],level_input_d.fixed_point_data[12]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[12+33],level_input_d.fixed_point_data[12+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[12+34],level_input_d.fixed_point_data[12+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[12+35],level_input_d.fixed_point_data[12+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
						   		   	end

						   		   	4 : begin 

				   						twiddle_factor_c1_d  = fftwiddle (32);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (34);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (36);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (38);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[16+32],level_input.fixed_point_data[16]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[16+33],level_input.fixed_point_data[16+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[16+34],level_input.fixed_point_data[16+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[16+35],level_input.fixed_point_data[16+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[16+32],level_input_d.fixed_point_data[16]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[16+33],level_input_d.fixed_point_data[16+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[16+34],level_input_d.fixed_point_data[16+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[16+35],level_input_d.fixed_point_data[16+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
						   		   	end

						   		   	5: begin 

				   						twiddle_factor_c1_d  = fftwiddle (40);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (42);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (44);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (46);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[20+32],level_input.fixed_point_data[20]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[20+33],level_input.fixed_point_data[20+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[20+34],level_input.fixed_point_data[20+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[20+35],level_input.fixed_point_data[20+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[20+32],level_input_d.fixed_point_data[20]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[20+33],level_input_d.fixed_point_data[20+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[20+34],level_input_d.fixed_point_data[20+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[20+35],level_input_d.fixed_point_data[20+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
						   		   	end


						   		   	6: begin 

				   						twiddle_factor_c1_d  = fftwiddle (48);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (50);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (52);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (54);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[24+32],level_input.fixed_point_data[24]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[24+33],level_input.fixed_point_data[24+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[24+34],level_input.fixed_point_data[24+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[24+35],level_input.fixed_point_data[24+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[24+32],level_input_d.fixed_point_data[24]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[24+33],level_input_d.fixed_point_data[24+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[24+34],level_input_d.fixed_point_data[24+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[24+35],level_input_d.fixed_point_data[24+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
						   		   	end

						   		   	7: begin 

				   						twiddle_factor_c1_d  = fftwiddle (56);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (58);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (60);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (62);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[28+32],level_input.fixed_point_data[28]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[28+33],level_input.fixed_point_data[28+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[28+34],level_input.fixed_point_data[28+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[28+35],level_input.fixed_point_data[28+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[28+32],level_input_d.fixed_point_data[28]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[28+33],level_input_d.fixed_point_data[28+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[28+34],level_input_d.fixed_point_data[28+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[28+35],level_input_d.fixed_point_data[28+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k+1;
						   		   	end	


						   		   8: begin 

				   						twiddle_factor_c1_d  = fftwiddle (0);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (2);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (4);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (6);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[64+32],level_input.fixed_point_data[64]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[64+33],level_input.fixed_point_data[64+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[64+34],level_input.fixed_point_data[64+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[64+35],level_input.fixed_point_data[64+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[64+32],level_input_d.fixed_point_data[64]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[64+33],level_input_d.fixed_point_data[64+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[64+34],level_input_d.fixed_point_data[64+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[64+35],level_input_d.fixed_point_data[64+3]} = output_data_c4_d;
						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k+1;
						   		   	end 

						   		 9: begin 

				   						twiddle_factor_c1_d  = fftwiddle (8);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (10);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (12);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (14);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[68+32],level_input.fixed_point_data[68]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[68+33],level_input.fixed_point_data[68+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[68+34],level_input.fixed_point_data[68+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[68+35],level_input.fixed_point_data[68+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[68+32],level_input_d.fixed_point_data[68]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[68+33],level_input_d.fixed_point_data[68+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[68+34],level_input_d.fixed_point_data[68+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[68+35],level_input_d.fixed_point_data[68+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k+1;
						   		   	end


						   		   10 : begin 

				   						twiddle_factor_c1_d  = fftwiddle (16);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (18);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (20);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (22);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[72+32],level_input.fixed_point_data[72]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[72+33],level_input.fixed_point_data[72+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[72+34],level_input.fixed_point_data[72+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[72+35],level_input.fixed_point_data[72+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[72+32],level_input_d.fixed_point_data[72]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[72+33],level_input_d.fixed_point_data[72+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[72+34],level_input_d.fixed_point_data[72+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[72+35],level_input_d.fixed_point_data[72+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k+1;
						   		   	end


						   		   11 : begin 

				   						twiddle_factor_c1_d  = fftwiddle (24);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (26);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (28);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (30);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[76+32],level_input.fixed_point_data[76]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[76+33],level_input.fixed_point_data[76+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[76+34],level_input.fixed_point_data[76+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[76+35],level_input.fixed_point_data[76+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[76+32],level_input_d.fixed_point_data[76]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[76+33],level_input_d.fixed_point_data[76+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[76+34],level_input_d.fixed_point_data[76+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[76+35],level_input_d.fixed_point_data[76+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k+1;
						   		   	end

						   		   12 : begin 

				   						twiddle_factor_c1_d  = fftwiddle (32);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (34);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (36);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (38);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[80+32],level_input.fixed_point_data[80]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[80+33],level_input.fixed_point_data[80+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[80+34],level_input.fixed_point_data[80+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[80+35],level_input.fixed_point_data[80+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[80+32],level_input_d.fixed_point_data[80]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[80+33],level_input_d.fixed_point_data[80+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[80+34],level_input_d.fixed_point_data[80+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[80+35],level_input_d.fixed_point_data[80+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k+1;
						   		   	end 


						   		   13 : begin 

				   						twiddle_factor_c1_d  = fftwiddle (40);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (42);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (44);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (46);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[84+32],level_input.fixed_point_data[84]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[84+33],level_input.fixed_point_data[84+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[84+34],level_input.fixed_point_data[84+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[84+35],level_input.fixed_point_data[84+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[84+32],level_input_d.fixed_point_data[84]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[84+33],level_input_d.fixed_point_data[84+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[84+34],level_input_d.fixed_point_data[84+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[84+35],level_input_d.fixed_point_data[84+3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k+1;
						   		   	end 


						   		   14 : begin 

				   						twiddle_factor_c1_d  = fftwiddle (48);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (50);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (52);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (54);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[88+32],level_input.fixed_point_data[88]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[88+33],level_input.fixed_point_data[88+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[88+34],level_input.fixed_point_data[88+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[88+35],level_input.fixed_point_data[88+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[88+32],level_input_d.fixed_point_data[88]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[88+33],level_input_d.fixed_point_data[88+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[88+34],level_input_d.fixed_point_data[88+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[88+35],level_input_d.fixed_point_data[88+3]} = output_data_c4_d;


						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k+1;
						   		   	end 


						   		   15 : begin 

				   						twiddle_factor_c1_d  = fftwiddle (56);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (58);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (60);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (62);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[92+32],level_input.fixed_point_data[92]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[92+33],level_input.fixed_point_data[92+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[92+34],level_input.fixed_point_data[92+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[92+35],level_input.fixed_point_data[92+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[92+32],level_input_d.fixed_point_data[92]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[92+33],level_input_d.fixed_point_data[92+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[92+34],level_input_d.fixed_point_data[92+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[92+35],level_input_d.fixed_point_data[92+3]} = output_data_c4_d;


						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = 0;
						   		   	end 
		   				endcase

		   			next_fft_state = LVL_5;
		   		end

		   		if (sm_count == 128) begin 
	   		     	
	   		     	level_d = 6;
	   		     	k_d = 0;
	   		     	next_fft_state = LVL_6;
	   		     	sm_count_d = 0;
	   		    end

		end // LV_5

		LVL_6 : begin // 128 points, takes 16 clk cycles... for one set

		   		if (reset) next_fft_state = IDLEB; 

		   		if (sm_count < 128) begin 

		   				case (k) 

		   							0 : begin 

				   						twiddle_factor_c1_d  = fftwiddle (0);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (1);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (2);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (3);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[64],level_input.fixed_point_data[0]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[65],level_input.fixed_point_data[1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[66],level_input.fixed_point_data[2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[67],level_input.fixed_point_data[3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[64],level_input_d.fixed_point_data[0]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[65],level_input_d.fixed_point_data[1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[66],level_input_d.fixed_point_data[2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[67],level_input_d.fixed_point_data[3]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
						   		   	end

						   		   	1 : begin 

				   						twiddle_factor_c1_d  = fftwiddle (4);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (5);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (6);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (7);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[68],level_input.fixed_point_data[4]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[69],level_input.fixed_point_data[5]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[70],level_input.fixed_point_data[6]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[71],level_input.fixed_point_data[7]};

						   		   				
						   		   		{level_input_d.fixed_point_data[68],level_input_d.fixed_point_data[4]} = output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[69],level_input_d.fixed_point_data[5]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[70],level_input_d.fixed_point_data[6]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[71],level_input_d.fixed_point_data[7]} = output_data_c4_d;


						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
						   		   	end

						   		   	2 : begin 

				   						twiddle_factor_c1_d  = fftwiddle (8);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (9);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (10);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (11);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[72],level_input.fixed_point_data[8]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[73],level_input.fixed_point_data[9]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[74],level_input.fixed_point_data[10]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[75],level_input.fixed_point_data[11]};

						   		   				
						   		   		{level_input_d.fixed_point_data[72],level_input_d.fixed_point_data[8]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[73],level_input_d.fixed_point_data[9]}  = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[74],level_input_d.fixed_point_data[10]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[75],level_input_d.fixed_point_data[11]} = output_data_c4_d;


						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
						   		   	end


						   		   	3 : begin 

				   						twiddle_factor_c1_d  = fftwiddle (12);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (13);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (14);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (15);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[76],level_input.fixed_point_data[12]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[77],level_input.fixed_point_data[13]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[78],level_input.fixed_point_data[14]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[79],level_input.fixed_point_data[15]};

						   		   				
						   		   		{level_input_d.fixed_point_data[76],level_input_d.fixed_point_data[12]} = output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[77],level_input_d.fixed_point_data[13]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[78],level_input_d.fixed_point_data[14]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[79],level_input_d.fixed_point_data[15]} = output_data_c4_d;

						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
						   		   	end

						   		   	4 : begin 

				   						twiddle_factor_c1_d  = fftwiddle (16);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (17);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (18);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (19);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[80],level_input.fixed_point_data[16]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[81],level_input.fixed_point_data[17]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[82],level_input.fixed_point_data[18]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[83],level_input.fixed_point_data[19]};

						   		   				
						   		   		{level_input_d.fixed_point_data[80],level_input_d.fixed_point_data[16]} = output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[81],level_input_d.fixed_point_data[17]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[82],level_input_d.fixed_point_data[18]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[83],level_input_d.fixed_point_data[19]} = output_data_c4_d;


						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
						   		   	end

						   		   	5: begin 

				   						twiddle_factor_c1_d  = fftwiddle (20);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (21);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (22);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (23);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[20+64],level_input.fixed_point_data[20]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[20+65],level_input.fixed_point_data[20+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[20+66],level_input.fixed_point_data[20+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[20+67],level_input.fixed_point_data[20+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[20+64],level_input_d.fixed_point_data[20]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[20+65],level_input_d.fixed_point_data[20+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[20+66],level_input_d.fixed_point_data[20+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[20+67],level_input_d.fixed_point_data[20+3]} = output_data_c4_d;


						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
						   		   	end


						   		   	6: begin 

				   						twiddle_factor_c1_d  = fftwiddle (24);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (25);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (26);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (27);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[24+64],level_input.fixed_point_data[24]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[24+65],level_input.fixed_point_data[24+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[24+66],level_input.fixed_point_data[24+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[24+67],level_input.fixed_point_data[24+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[24+64],level_input_d.fixed_point_data[24]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[24+65],level_input_d.fixed_point_data[24+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[24+66],level_input_d.fixed_point_data[24+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[24+67],level_input_d.fixed_point_data[24+3]} = output_data_c4_d;


						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
						   		   	end

						   		   	7: begin 

				   						twiddle_factor_c1_d  = fftwiddle (28);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (29);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (30);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (31);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[28+64],level_input.fixed_point_data[28]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[28+65],level_input.fixed_point_data[28+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[28+66],level_input.fixed_point_data[28+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[28+67],level_input.fixed_point_data[28+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[28+64],level_input_d.fixed_point_data[28]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[28+65],level_input_d.fixed_point_data[28+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[28+66],level_input_d.fixed_point_data[28+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[28+67],level_input_d.fixed_point_data[28+3]} = output_data_c4_d;


						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
						   		   	end

						   		   	8: begin 

				   						twiddle_factor_c1_d  = fftwiddle (32);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (33);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (34);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (35);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[32+64],level_input.fixed_point_data[32]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[32+65],level_input.fixed_point_data[32+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[32+66],level_input.fixed_point_data[32+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[32+67],level_input.fixed_point_data[32+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[32+64],level_input_d.fixed_point_data[32]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[32+65],level_input_d.fixed_point_data[32+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[32+66],level_input_d.fixed_point_data[32+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[32+67],level_input_d.fixed_point_data[32+3]} = output_data_c4_d;


						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
						   		   	end 


						   		   9: begin 

				   						twiddle_factor_c1_d  = fftwiddle (36);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (37);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (38);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (39);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[36+64],level_input.fixed_point_data[36]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[36+65],level_input.fixed_point_data[36+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[36+66],level_input.fixed_point_data[36+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[36+67],level_input.fixed_point_data[36+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[36+64],level_input_d.fixed_point_data[36]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[36+65],level_input_d.fixed_point_data[36+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[36+66],level_input_d.fixed_point_data[36+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[36+67],level_input_d.fixed_point_data[36+3]} = output_data_c4_d;


						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
						   		   	end

						   		   	10: begin 

				   						twiddle_factor_c1_d  = fftwiddle (40);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (41);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (42);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (43);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[40+64],level_input.fixed_point_data[40]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[40+65],level_input.fixed_point_data[40+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[40+66],level_input.fixed_point_data[40+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[40+67],level_input.fixed_point_data[40+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[40+64],level_input_d.fixed_point_data[40]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[40+65],level_input_d.fixed_point_data[40+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[40+66],level_input_d.fixed_point_data[40+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[40+67],level_input_d.fixed_point_data[40+3]} = output_data_c4_d;


						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
						   		   	end


						   		  	11: begin 

				   						twiddle_factor_c1_d  = fftwiddle (44);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (45);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (46);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (47);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[44+64],level_input.fixed_point_data[44]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[44+65],level_input.fixed_point_data[44+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[44+66],level_input.fixed_point_data[44+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[44+67],level_input.fixed_point_data[44+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[44+64],level_input_d.fixed_point_data[44]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[44+65],level_input_d.fixed_point_data[44+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[44+66],level_input_d.fixed_point_data[44+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[44+67],level_input_d.fixed_point_data[44+3]} = output_data_c4_d;


						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
						   		   	end

						   		    12: begin 

				   						twiddle_factor_c1_d  = fftwiddle (48);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (49);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (50);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (51);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[48+64],level_input.fixed_point_data[48]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[48+65],level_input.fixed_point_data[48+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[48+66],level_input.fixed_point_data[48+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[48+67],level_input.fixed_point_data[48+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[48+64],level_input_d.fixed_point_data[48]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[48+65],level_input_d.fixed_point_data[48+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[48+66],level_input_d.fixed_point_data[48+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[48+67],level_input_d.fixed_point_data[48+3]} = output_data_c4_d;


						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
						   		   	end

						   		   13: begin 

				   						twiddle_factor_c1_d  = fftwiddle (52);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (53);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (54);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (55);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[52+64],level_input.fixed_point_data[52]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[52+65],level_input.fixed_point_data[52+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[52+66],level_input.fixed_point_data[52+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[52+67],level_input.fixed_point_data[52+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[52+64],level_input_d.fixed_point_data[52]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[52+65],level_input_d.fixed_point_data[52+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[52+66],level_input_d.fixed_point_data[52+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[52+67],level_input_d.fixed_point_data[52+3]} = output_data_c4_d;


						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
						   		   	end

						   		   14: begin 

				   						twiddle_factor_c1_d  = fftwiddle (56);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (57);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (58);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (59);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[56+64],level_input.fixed_point_data[56]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[56+65],level_input.fixed_point_data[56+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[56+66],level_input.fixed_point_data[56+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[56+67],level_input.fixed_point_data[56+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[56+64],level_input_d.fixed_point_data[56]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[56+65],level_input_d.fixed_point_data[56+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[56+66],level_input_d.fixed_point_data[56+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[56+67],level_input_d.fixed_point_data[56+3]} = output_data_c4_d;


						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = k + 1;
						   		   	end

						   		   	15: begin 

				   						twiddle_factor_c1_d  = fftwiddle (60);
					   		   		 	twiddle_factor_c2_d  = fftwiddle (61);
					   		   		 	twiddle_factor_c3_d  = fftwiddle (62);
					   		   		 	twiddle_factor_c4_d  = fftwiddle (63);

					   		   		 	input_data_c1_d = {level_input.fixed_point_data[60+64],level_input.fixed_point_data[60]};
						   		   		input_data_c2_d = {level_input.fixed_point_data[60+65],level_input.fixed_point_data[60+1]};
						   		   		input_data_c3_d = {level_input.fixed_point_data[60+66],level_input.fixed_point_data[60+2]};
						   		   		input_data_c4_d = {level_input.fixed_point_data[60+67],level_input.fixed_point_data[60+3]};

						   		   				
						   		   		{level_input_d.fixed_point_data[60+64],level_input_d.fixed_point_data[60]} 	= output_data_c1_d;
						   		   		{level_input_d.fixed_point_data[60+65],level_input_d.fixed_point_data[60+1]} = output_data_c2_d;
						   		   		{level_input_d.fixed_point_data[60+66],level_input_d.fixed_point_data[60+2]} = output_data_c3_d;
						   		   		{level_input_d.fixed_point_data[60+67],level_input_d.fixed_point_data[60+3]} = output_data_c4_d;


						   		   		sm_count_d = sm_count + 8;
						   		   		k_d = 0;
						   		   	end
		   				endcase

		   			next_fft_state = LVL_6;
		   		end

		   		if (sm_count == 128) begin 
	   		     	
	   		     	level_d = 7;
	   		     	k_d = 0;
	   		     	next_fft_state = OUTPUT_STATE;
	   		     	sm_count_d = 0;
	   		    end

		end // LV_6

		OUTPUT_STATE : begin 
				level_d = 0;
				next_fft_state = IDLEB;
				next_dec_state = MAX;
				decoder_input_d = level_input_d;
				//$display ("decoder_input: %h",decoder_input_d.fixed_point_data);

		end // output to the decoder // FFT STATE

	endcase // current_fft_state


// --------------- Decoder FSM =>-

	case (current_dec_state)

		IDLEC : begin 

			if (reset) begin next_dec_state = IDLEC; end
			Data_Out_d = 0;
			PushOut_d = 0;
			Decision_Point1 = 0;
			Decision_Point2 = 0;
			Decision_Point3 = 0;
			index = 0;
			ptr2 = 0;
			ptr1 = 0;
			temp = 0;
			temp_d = 0;
			d1 = 0;
			d2 = 0;
			d3 = 0;
			bin_55 = 0;
			bin_57 = 0;
			bin_i =  0;
		end

		MAX : begin 	
			if (reset) begin next_dec_state = IDLEC; end
			
			else begin
					decoder_input_d = level_input;
 					bin_55 = abs_square(decoder_input_d.fixed_point_data[55]);
 					//$display ("55: %d",bin_55);
 					bin_57 = abs_square(decoder_input_d.fixed_point_data[57]);
 					//$display ("57: %d",bin_57);
 					if (bin_55 > bin_57) max_d = bin_55;
 					else max_d = bin_57;
 					next_dec_state = EVAL;
			end

		end

		EVAL : begin 
			if (reset) begin next_dec_state = IDLEC; end

			else begin 
				 d1 = (p1*max) >> 15;
				 d2 = (p2*max) >> 15;
				 d3 = (p3*max) >> 15;
				 Decision_Point1 = abs_square('{d1[22:0],23'h0});
				 Decision_Point2 = abs_square('{d2[22:0],23'h0});
				 Decision_Point3 = abs_square('{d3[22:0],23'h0});
				 //$display("full scale: %h",max);
				 //$display ("Decision Points : 1: %h  2 : %h 3: %h",Decision_Point1,Decision_Point2,Decision_Point3);
				 for (int ix=4;ix<52;ix+=2) begin
				 	bin_i= abs_square(decoder_input_d.fixed_point_data[ix]);

				 	if 		(bin_i < Decision_Point1) temp = 2'b00;
				 	else if ((bin_i >= Decision_Point1) && (bin_i < Decision_Point2)) temp = 2'b01;
				 	else if ((bin_i >= Decision_Point2) && (bin_i < Decision_Point3)) temp = 2'b10;
				 	else temp = 2'b11;
                   
    			 	index = ix/2;
				 	ptr2 = 2*(index-2)+1;
				 	ptr1 = 2*(index-2);
					{temp_d[ptr2],temp_d[ptr1]} = temp;
				 end
				next_dec_state = OUTPUT;

			end

		end

		OUTPUT : begin 
			if (reset) begin next_dec_state = IDLEC; end
			else begin 
				PushOut_d = 1;
				Data_Out_d = temp_d;
				next_dec_state = IDLEC;
			end
		end

	endcase // current_dec_state


end
/*
initial begin
  $dumpfile("Test.vcd");
  $dumpvars(9,ofdmdec);
end
*/


endmodule : DESIGN_FFT