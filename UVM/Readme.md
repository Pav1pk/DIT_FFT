// ------------------------------------------- This is a Read Me text File --------------------------------------------- //

-> This is a readme file for designing and verifying IFFT and FFT for OFDM communications in UVM.
-> Documentation is provided for each box used in the code itself..

-> For Verifiying the DUT - FFT Design, initially we are randomly generating the encoded bits which can generate 128 frequency bins for the IFFT.

-> First most randmofly geenrating 128 freq_bins/points and verifying them is not feasible as in the communication system, a little bit packet energy loss is expected, if we generate 128 points and exactly match 128 points at output results in erros mostly.

-> To avoid these misconception and other issues, the communication is dealt in the enery ranges/percentage of the energy of the bins.
-> So initially to generate 128 points randomly, based on the energy levels, we are generating 48 bits randoms encoded bits using the sequencer component.

-> The sequence item handles the message, and holds rand 48 bits. The sequencer upon request from the driver pushes the random sequences to the driver, each sequence sends 48 bits randomly to the driver.
-> The driver then sends these 48 bits to the encoder - box, where the conversion of 48 bits to 128 points/ freq_bins based on the energy levels occur.
-> Each freq bin consists of real_part and Imaginary_part.
-> After Encoding the 128 points it is passed to bit reversal for reversing the indexes according to the size of 128 i.e 7 bits here,,,
-> After Bit reversal it is sent to IFFT box, where the butterfly computation for 128 points in 7 levels are done and produces the time domain bins in its output (128 bins).
-> These 128 time domain bins are converted to binary values in 8_15 format and sent to the driver.
-> The driver places these 128 points in time-domain, binary_represented into virtual interface sequentially for 128 clocks.
-> The VIF is connected to the DUT and DUT gets these and process them.
-> Concurrently the IFFT 128 points output in time domain and sent to the reference model.
-> In the reference model, it takes the 128 points from IFFT and bit reverse them and do the butterfly computation and give back the 128 frequency bins.
-> These frequency bins are sent to a decoder which, according to the energy levels of bins 4 to 50 (even bins, count = 24) mapped comparing with the max energy in bin 55/ bin 57 and 48 bits are generated accordingly.
-> Theoretically these 48 bits should match with the randomly generated bits in the sequence.

--------------------------------------------------------------------------------------------------------------------------------

For DUT's verification::
-> The 48 bits from the DUT is captured whenever dut monitor watches a pushout.
-> The reference decoder is stored in scoreboard.
-> once the monitor dut sends 48 bits , scoreboard matches this 48 bits and popping out the first element in the QUEUE in the socreboard of the reference decode output.

-----------------------------------------------------------------------------------------------------------------------------------------
