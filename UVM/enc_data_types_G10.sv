typedef struct {
		real real_part;
		real imaginary_part;
	}point;

typedef struct { 
			point DATA [128]; 
		}points_128;

typedef struct {
	int real_value;
	int imaginary_value;
}fixed_decimal_point;

typedef struct {
	fixed_decimal_point decimal_point[128];
}decimal_points_128;

typedef struct packed 
	{
		bit [45:23] real_bits;
		bit [22:0] imaginary_bits;
	}fixed_point;

	// 2_15 data representation

typedef struct 
{
	fixed_point value [128];
}DUT_Input;

typedef struct
{
	reg [47:0] bit_data;
}bit_data_48;