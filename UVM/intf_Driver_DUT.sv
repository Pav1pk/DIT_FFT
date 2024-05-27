// Interface for connecting the DUT and the Environment Virtually..
interface intf_Driver_DUT (input clk,input reset);

	logic push_in;
	logic First_Data;
	logic [16:0] DinR;
	logic [16:0] DinI;

	logic push_out;
	logic [47:0] Data_Out;

	/*modport DUT (input clk, 
				input reset, 
				input push_in, 
				input DinR, 
				input DinI, 
				output push_out, 
				output Data_Out
				);*/
	
endinterface : intf_Driver_DUT
