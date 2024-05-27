=>  This is a Design Directory consisting of "DESIGN.sv," "complex_multiplier.sv", "fftw.sv", "new_data_types.sv"

In this directory: 
new_data_types.sv: declaration of all the data types used in the design for accessing the 128 points easily

fftw.sv: the twiddle factors required for all the levels 

complex_multiplier.sv: The complex multiplier which takes 2 complex points, 1 twiddle factor (complex) and gives two output points (complex)

DESIGN.sv: The Design for the FFT. 

// ------------------------------------------------------------------------------------------------------------------- //

**new_data_types.sv** <br/> It consists of all the data type declaration for smooth data transfer and easy debugging <br/> "fixed_point" for holding data of each point in 8-15 format. <br/> "fixed_128_point" for holding the 128 fixed_point together. 

**complex_multiplier.sv** <br/> It is the modified complex multiplier used for supporting this design, The complex multiplier takes 2 input points, 1 twiddle factor and produced 2 output points.<br/> the input points, twiddle factor, and output points are all complex. <br/> The module multiplies the twiddle factor with one input point and resulting complex number is added and subtracted with other input point to produce two output points respectively.

