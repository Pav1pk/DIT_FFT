module complex_multiplier (
		
		input fixed_point [1:0] input_data,
		input fixed_point twiddle_factor,
		output fixed_point [1:0] output_data
	
	);

	fixed_point multiplication;
	reg [22:0] twiddle_real,twiddle_imag;
	reg [45:0] m1,m2;
	always @(*) begin
	// complex multiplication
	m1 = ((twiddle_factor.real_bits*input_data[1].real_bits)>>15) - ((twiddle_factor.imaginary_bits*input_data[1].imaginary_bits)>>15);
	m2	= ((twiddle_factor.imaginary_bits*input_data[1].real_bits)>>15) + ((twiddle_factor.real_bits*input_data[1].imaginary_bits)>>15);

	twiddle_real = twiddle_factor.real_bits;
	twiddle_imag = twiddle_factor.imaginary_bits;

	multiplication.real_bits 		        = m1[22:0];
	multiplication.imaginary_bits           = m2[22:0];

	// butterfly

	output_data[0].real_bits 	  = input_data[0].real_bits 	 + multiplication.real_bits;
	output_data[0].imaginary_bits     = input_data[0].imaginary_bits + multiplication.imaginary_bits;
	output_data[1].real_bits 	  = input_data[0].real_bits 	 - multiplication.real_bits;
	output_data[1].imaginary_bits     = input_data[0].imaginary_bits - multiplication.imaginary_bits;

	end

endmodule : complex_multiplier
