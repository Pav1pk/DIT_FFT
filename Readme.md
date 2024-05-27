***************************  Read Me for Design  *******************

=>  This is a Design Directory consisting of "DESIGN.sv", "complex_multiplier.sv", "fftw.sv", "new_data_types.sv"

 /// ------------------------------------------------         Specifications  --------------------------------------------- //

 => It is a 128 point FFT for supporting OFDM Communications.
 => A 128 point FFT takes 7 levels of Butterfly Operation.

 => Constraints: Only 4 complex multiplers are allowed. (Hardware Constraint)

 => A complex multiplier, does a complex multiplication between two complex points and produce resulting real part and complex part
 => Complex points multiplication : (a1 + jb1) * (a2 +j b2) = (a1.a2 - b1.b2) + j (a1.b2 + a2.b1), has two addition/subtraction and 4 multipliers.

 => The multiplication/summations should be carried in 8.15 through the FFT for enough range at the end.
 => In a traditional 128-bit radix 2 DIT FFT, There are 7 levels, each requiring 64 complex multiplies and 128 complex adds. This would require 64*7 complex multipliers (Each complex multiply requires 4 
  multiplies and two adds/subtracts) The project fft design is limited to 4 complex multipliers (total). The 
  number of clocks required for the FFT is 64*7/4 or 112 clocks.

 // ------------------------------------- Hardware Constraints Info ----------------------------------------------------- //

 => Only 4 complex multipliers are allowed, meaning @ one clock edge -> max 4 complex multiplication can be done.
 => That means we can handle 8 complex points (2 complex points -> one complex multiplier) at one clock edge.

 => At each level: 64 complex multiplications must be performed, so for each level the design takes 16 clocks.
 => For 7 levels it takes 16*7 = 112 clocks for completing butterfly operation.

// --------------------------------------------------------------------------------------------------------------------- //

This repository consists of:

i) Design_Files  ii) Synthesis
iii) UVM
iV) Specifications.pdf

**a) Design Files :** 
       i)   It consists of all the files required for a working design.
       ii)  Check the Design's readme for functionality.
**b) Synthesis**: 
       i)   It consists of a synthesis script used for the design synthesis.
       ii)  Have the synthesis's power, timing, and area reports.
**c) UVM :**
       i) It consists of the UVM components required for the functional verification of the design.
       ii) Have the results in the results.txt for observation and analysis.
       iii) Check the readme file in that dir for more information.
**d) Specifications.pdf:** Have the specifications of the 128 Point DIT FFT.



*********************************************************************************************************************************
