=>  This is a Design Directory consisting of "DESIGN.sv," "complex_multiplier.sv", "fftw.sv", "new_data_types.sv"

In this directory: 
new_data_types.sv: declaration of all the data types used in the design for accessing the 128 points easily

fftw.sv: the twiddle factors required for all the levels 

complex_multiplier.sv: The complex multiplier which takes 2 complex points, 1 twiddle factor (complex) and gives two output points (complex)

DESIGN.sv: The Design for the FFT. 

// ------------------------------------------------------------------------------------------------------------------- //

**new_data_types.sv** <br/> It consists of all the data type declarations for smooth data transfer and easy debugging <br/> "fixed_point" for holding data of each point in 8-15 format. <br/> "fixed_128_point" for holding the 128 fixed_point together. 

**complex_multiplier.sv** <br/> It is the modified complex multiplier used for supporting this design; the complex multiplier takes 2 input points, 1 twiddle factor, and produces 2 output points.<br/> The input points, twiddle factor, and output points are all complex. <br/> The module multiplies the twiddle factor with one input point, and the resulting complex number is added and subtracted with another input point to produce two output points, respectively.

**fftw.sv** <br/> It is the twiddle factor function, consisting of all 64 twiddle factors used in this 128 point fft, and accessed them using their indexes respectively. 

// -------------------------------------------------------------------------------------------------------------------------- //

**DESIGN.sv** <br/> i) This is the design for doing the FFT operation
<br/> ii)  The design receives each point sequentially.
<br/> iii) The design consists of three state machines: collect_states, fft_states, and decoder_states.
<br/> iV)  The above state machines operate individually, upon their respective constraints.
<br/>    a) collect_states: It has two states in it, First is an IDLE state, and the other is SAMPLING (It keeps on collecting data @ each clock edge with sign extension, and once it reaches 128 points, it reverses the data and sends it to the "fft_states" state machine's register. 
<br/>    b) fft_states: It Consists of 9 states, one for IDLE, 7 states == 7 levels, and one for output to the decoder.
<br/>              functionality: Once the fft receives the 128 points from the collect states, it does the butterfly computation, and for completing one level it takes 16 clocks (until k =16), and at each clock (k) it process/computes 8 points (4 complex multiplication).





