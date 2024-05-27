typedef struct packed {
	reg signed [45:23] real_bits;
	reg signed [22:0] imaginary_bits;
}fixed_point;

typedef struct packed {
	fixed_point [127:0] fixed_point_data;
}fixed_128_point;


