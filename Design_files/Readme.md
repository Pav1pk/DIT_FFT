=>  This is a Design Directory consisting of "DESIGN.sv," "complex_multiplier.sv", "fftw.sv", "new_data_types.sv"

In this directory: 
new_data_types.sv: declaration of all the data types used in the design for accessing the 128 points easily

fftw.sv: the twiddle factors required for all the levels 

complex_multiplier.sv: The complex multiplier which takes 2 complex points, 1 twiddle factor (complex) and gives two output points (complex)

DESIGN.sv: The Design for the FFT. 

// ------------------------------------------------------------------------------------------------------------------- //

**new_data_types.sv** <br/> It consists of all the data type declaration for smooth data transfer and easy debugging <br/> "fixed_point" for holding data of each point in 8-15 format. <br/> "fixed_128_point" for holding the 128 fixed_point together. 

**complex_multiplier.sv** <br/> It is the modified complex multiplier used for supporting this design; the complex multiplier takes 2 input points, 1 twiddle factor, and produces 2 output points.<br/> The input points, twiddle factor, and output points are all complex. <br/> The module multiplies the twiddle factor with one input point, and the resulting complex number is added and subtracted with another input point to produce two output points, respectively.

**fftw.sv** <br/> It is the twiddle factor function, consisting of all 64 twiddle factors used in this 128 point fft, and accessed them using their indexes respectively. 

// -------------------------------------------------------------------------------------------------------------------------- //

**DESIGN.sv** <br/> i) This is the design for doing the FFT operation
<br/> ii)  The design receives each point sequentially.
<br/> iii) The design consists of three state machines: collect_states, fft_states, and decoder_states.
<br/> iV)  The above state machines operates individually, upon their respective constraints.




