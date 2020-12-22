`timescale 1ns/1ns
module dual_clock_ram(q, d, write_address, read_address, we, clk1, clk2);
 	output reg [7:0] q;
 	input [7:0] d;
 	input [9:0] write_address, read_address;
 	input we, clk1, clk2;

 	reg [9:0] read_address_reg;
 	reg [7:0] mem [1023:0];

 	always @ (posedge clk1) begin
 		if (we) mem[write_address] <= d;
 	end
 	always @ (posedge clk2) begin
 		q <= mem[read_address_reg];
 		read_address_reg <= read_address;
 	end
endmodule


//rules for dragon curve
module dragon(clk, reset, dragon_val, dragon_prev, dragon_result, dragon_done);		//equivalent to applyRule_DragonCurve
	input clk, reset, dragon_val;
	input [7:0] dragon_prev; //8 bit input, ascii defined
	output [39:0] dragon_result; //40 bit output
	output [1:0] dragon_done;

	reg [7:0] dragon_prev_reg;
	reg [1:0] dragon_done_reg;
	reg [39:0] dragon_result_reg;
	reg [7:0] dragon_state_reg;
	
	assign dragon_result = dragon_result_reg;
	assign dragon_done = dragon_done_reg;
	
	//ascii definitions
	localparam [7:0] X = 8'b01011000;
	localparam [7:0] Y = 8'b01011001;
	localparam [7:0] plus = 8'd43;		//+
	localparam [7:0] minus = 8'd45;		//-
	localparam [7:0] F = 8'd70;
	localparam [7:0] open_bracket = 8'd91;	//[
	localparam [7:0] closing_bracket = 8'd93;	//]

	//state reg
	localparam DRAGON_UPDATE = 8'b0;
	localparam DRAGON_TRANSLATE = 8'b1;
	localparam DRAGON_DONE = 8'd2;

	always @ (posedge clk) begin
		if (reset) begin
			dragon_result_reg <= 40'b0;
			dragon_done_reg <= 2'b0;
			dragon_prev_reg <= dragon_prev;
			dragon_state_reg <= DRAGON_UPDATE;
		end
		else begin
			case (dragon_state_reg)
				DRAGON_UPDATE: begin
					dragon_prev_reg <= dragon_prev;
					//dragon_state_reg <= DRAGON_TRANSLATE;
					dragon_result_reg <= dragon_result_reg;
					if (dragon_val) begin
						dragon_done_reg <= 2'b0;
						dragon_state_reg <= DRAGON_TRANSLATE;
					end
					else begin
						dragon_done_reg <= dragon_done_reg;
						dragon_state_reg <= DRAGON_UPDATE;
					end
				end
				DRAGON_TRANSLATE: begin
					dragon_prev_reg <= dragon_prev_reg;
					if (dragon_prev_reg == X) begin
						dragon_done_reg <= 2'b1;
						dragon_result_reg <= {X, plus, Y, F, plus};	//"X+YF+"
					end
					else if (dragon_prev_reg == Y) begin
						dragon_done_reg <= 2'd2;
						dragon_result_reg <= {minus, F, X, minus, Y};	//"-FX-Y"
					end
					else begin
						dragon_done_reg <= 2'd3;
						dragon_result_reg <= {dragon_prev_reg,32'b0};
					end
					dragon_state_reg <= DRAGON_UPDATE;
				end
				//DRAGON_DONE: begin
					//dragon_result_reg <= dragon_result_reg;
					//dragon_prev_reg <= dragon_prev_reg;
					//dragon_state_reg <= DRAGON_UPDATE;
				//end
			endcase
		end
	end	

endmodule

module create_system(clk, reset, top_rdy, iterations, system_input_string, system_output_string, system_val, system_done, iterations_counter); //equivalent to createSystem() in translated_python.c
	input clk, reset, top_rdy;
	input [31:0] system_input_string;
	input [3:0] iterations;
	output [7:0] system_output_string;
	output system_val;
	output system_done;
	output [3:0] iterations_counter;

	localparam [7:0] X = 8'b01011000;
	localparam [7:0] Y = 8'b01011001;
	localparam [7:0] plus = 8'd43;		//+
	localparam [7:0] minus = 8'd45;		//-
	localparam [7:0] F = 8'd70;
	localparam [7:0] open_bracket = 8'd91;	//[
	localparam [7:0] closing_bracket = 8'd93;	//]

	wire [7:0] a_q;
	wire [7:0] a_d;
	reg[7:0] a_d_reg;
	wire [9:0] a_write_address;
	reg [9:0] a_write_address_reg;
	wire [9:0] a_read_address;
	reg [9:0] a_read_address_reg;
	wire a_we;
	reg a_we_reg;

	assign a_d = a_d_reg;
	assign a_write_address = a_write_address_reg;
	assign a_read_address = a_read_address_reg;
	assign a_we = a_we_reg;

	dual_clock_ram a(
		.q		(a_q), 
		.d		(a_d), 
		.write_address	(a_write_address), 
		.read_address	(a_read_address), 
		.we		(a_we), 
		.clk1		(clk), 
		.clk2		(clk)
	);

	wire [7:0] b_q;
	wire [7:0] b_d;
	reg[7:0] b_d_reg;
	wire [9:0] b_write_address;
	reg [9:0] b_write_address_reg;
	wire [9:0] b_read_address;
	reg [9:0] b_read_address_reg;
	wire b_we;
	reg b_we_reg;

	assign b_d = b_d_reg;
	assign b_write_address = b_write_address_reg;
	assign b_read_address = b_read_address_reg;
	assign b_we = b_we_reg;

	dual_clock_ram b(
		.q		(b_q), 
		.d		(b_d), 
		.write_address	(b_write_address), 
		.read_address	(b_read_address), 
		.we		(b_we), 
		.clk1		(clk), 
		.clk2		(clk)
	);

	reg dragon_val_reg;
	wire [39:0] dragon_result;
	reg [39:0] dragon_result_reg;
	wire [1:0] dragon_done;
	wire dragon_val;
	reg [7:0] input_char_reg;
	wire [7:0] input_char;
	
	assign dragon_val = dragon_val_reg;
	assign input_char = input_char_reg;

	dragon rule(
		.clk		(clk),
		.reset		(reset),
		.dragon_prev	(input_char),
		.dragon_result	(dragon_result),
		.dragon_done	(dragon_done),
		.dragon_val	(dragon_val)
	);		
	
	localparam RESET_SYSTEM		= 4'd0;	 	
	localparam GET_CHAR		= 4'd1;		//grab byte from axiom if count_iter == 0, otherwise read from M10K address; increment count_iter if axiom == 0 or start/end address of M10K are equal
	localparam READ_M10K		= 4'd2;		//takes 3 cycles to read value from M10K
	localparam INCREMENT_READ	= 4'd3;		//buffer state for reading M10K
	localparam COMPUTE_DRAGON	= 4'd4;		//send one byte to dragon and stays in here until dragon_done is set
	localparam WRITE_M10K_A		= 4'd5;		//write to M10K with dragon_result
	localparam INCREMENT_WRITE_A	= 4'd6;
	localparam WRITE_M10K_B		= 4'd7;		//write to M10K with dragon_result
	localparam INCREMENT_WRITE_B	= 4'd8;
	localparam NEXT_BYTE		= 4'd9;		//shift axiom if count_iter == 0, otherwise move to next address in M10K
	localparam INCREMENT_ITER	= 4'd10;	
	localparam ZERO_READ		= 4'd11;
	localparam DONE			= 4'd12;
	
	reg [3:0] state_reg;
	reg [7:0] system_output_string_reg;
	reg [7:0] output_counter;
	reg [3:0] iterations_counter_reg;
	reg system_val_reg;
	reg system_done_reg;
	reg [31:0] axiom;
	reg [1:0] read_counter;

	assign system_output_string = system_output_string_reg;
	assign system_val = system_val_reg;
	assign system_done = system_done_reg;
	assign iterations_counter = iterations_counter_reg;

	always @ (posedge clk) begin
		if (reset) begin
			iterations_counter_reg <= 4'b0;
			input_char_reg <= 8'b0;
			a_d_reg <= 8'b0;
			a_write_address_reg <= 10'b0;
			a_read_address_reg <= 10'b0;
			a_we_reg <= 1'b0;
			b_d_reg <= 8'b0;
			b_write_address_reg <= 10'b0;
			b_read_address_reg <= 10'b0;
			b_we_reg <= 1'b0;
			axiom <= system_input_string;
			dragon_result_reg <= dragon_result;
			read_counter <= 1'b0;
			system_val_reg <= 1'b0;
			system_done_reg <= 1'b0;
			state_reg <= GET_CHAR;
		end
		else begin
			case (state_reg)
				//RESET_SYSTEM: begin
				//end
				GET_CHAR: begin
					a_d_reg <= 8'b0;
					a_write_address_reg <= a_write_address_reg;
					a_read_address_reg <= a_read_address_reg;
					a_we_reg <= 1'b0;
					b_d_reg <= 8'b0;
					b_write_address_reg <= b_write_address_reg;
					b_read_address_reg <= b_read_address_reg;
					b_we_reg <= 1'b0;
					dragon_result_reg <= dragon_result;
					read_counter <= 1'b0;
					system_val_reg <= 1'b0;
					system_done_reg <= 1'b0;
					if (top_rdy == 1'b0) begin
						state_reg <= GET_CHAR;
					end
					else begin
						if (iterations_counter_reg == 4'b0) begin
							input_char_reg <= axiom[7:0];
							state_reg <= COMPUTE_DRAGON;
						end
						else if (iterations_counter_reg < iterations) begin
							state_reg <= READ_M10K;
						end
						else begin
							state_reg <= DONE;
						end	
					end
				end
				READ_M10K: begin
					a_d_reg <= a_d_reg;
					a_write_address_reg <= a_write_address_reg;
					a_read_address_reg <= a_read_address_reg;
					a_we_reg <= 1'b0;
					b_d_reg <= b_d_reg;
					b_write_address_reg <= b_write_address_reg;
					b_read_address_reg <= b_read_address_reg;
					b_we_reg <= 1'b0;
					dragon_result_reg <= dragon_result;
					read_counter <= read_counter;
					system_val_reg <= 1'b0;
					system_done_reg <= 1'b0;
					if (iterations_counter_reg[0] == 1'b1) begin
						input_char_reg <= a_q;
					end
					else begin
						input_char_reg <= b_q;
					end
					//if (read_counter == 2'd2) begin
						state_reg <= COMPUTE_DRAGON;
						if (iterations_counter_reg[0] == 1'b0) begin
							b_read_address_reg <= b_read_address_reg + 10'b1;
						end 
						else begin
							a_read_address_reg <= a_read_address_reg + 10'b1;
						end
					//end
					//else begin
						//state_reg <= INCREMENT_READ;
					//end
				end
				INCREMENT_READ: begin
					system_val_reg <= 1'b0;
					read_counter <= read_counter + 1'b1;
					state_reg <= READ_M10K;
				end
				COMPUTE_DRAGON: begin
					a_d_reg <= 8'b0;
					a_write_address_reg <= a_write_address_reg;
					a_read_address_reg <= a_read_address_reg;
					a_we_reg <= 1'b0;
					b_d_reg <= 8'b0;
					b_write_address_reg <= b_write_address_reg;
					b_read_address_reg <= b_read_address_reg;
					b_we_reg <= 1'b0;
					dragon_result_reg <= dragon_result;
					dragon_val_reg <= 1'b1;
					read_counter <= 1'b0;
					system_val_reg <= 1'b0;
					system_done_reg <= 1'b0;
					if (dragon_done > 2'b0) begin
						if (iterations_counter_reg[0] == 1'b0) begin
							state_reg <= WRITE_M10K_A;
						end
						else begin
							state_reg <= WRITE_M10K_B;
						end
					end
					else begin
						state_reg <= COMPUTE_DRAGON;
					end
				end
				WRITE_M10K_A: begin
					a_d_reg <= dragon_result_reg[39:32];
					a_write_address_reg <= a_write_address_reg;
					a_read_address_reg <= a_read_address_reg;
					dragon_result_reg <= dragon_result_reg;
					read_counter <= 1'b0;
					system_done_reg <= 1'b0;
					system_output_string_reg <= dragon_result_reg[39:32];
					if (dragon_result_reg == 40'b0) begin
						a_we_reg <= 1'b0;
						system_val_reg <= 1'b0;
						state_reg <= NEXT_BYTE;
					end
					else begin
						a_we_reg <= 1'b1;	
						if (top_rdy == 1'b1) begin
							system_val_reg <= 1'b1;
							state_reg <= INCREMENT_WRITE_A;
						end
						else begin
							system_val_reg <= 1'b0;
							state_reg <= WRITE_M10K_A;
						end
					end
				end
				INCREMENT_WRITE_A: begin
					system_output_string_reg <= system_output_string_reg;
					a_write_address_reg <= a_write_address_reg + 10'b1;
					a_we_reg <= 1'b0;	
					dragon_result_reg <= dragon_result_reg << 8;
					read_counter <= 1'b0;
					system_val_reg <= 1'b0;
					system_done_reg <= 1'b0;
					state_reg <= WRITE_M10K_A;
				end
				WRITE_M10K_B: begin
					b_d_reg <= dragon_result[39:32];
					b_write_address_reg <= b_write_address_reg;
					b_read_address_reg <= b_read_address_reg;
					dragon_result_reg <= dragon_result_reg;
					read_counter <= 1'b0;
					system_done_reg <= 1'b0;
					system_output_string_reg <= dragon_result_reg[39:32];
					if (dragon_result_reg == 40'b0) begin
						b_we_reg <= 1'b0;
						system_val_reg <= 1'b0;
						state_reg <= NEXT_BYTE;
					end
					else begin
						b_we_reg <= 1'b1;	
						if (top_rdy == 1'b1) begin
							system_val_reg <= 1'b1;
							state_reg <= INCREMENT_WRITE_B;
						end
						else begin
							system_val_reg <= 1'b0;
							state_reg <= WRITE_M10K_B;
						end
					end
				end
				INCREMENT_WRITE_B: begin
					system_output_string_reg <= system_output_string_reg;
					b_write_address_reg <= b_write_address_reg + 10'b1;
					b_we_reg <= 1'b0;	
					dragon_result_reg <= dragon_result_reg << 8;
					read_counter <= 1'b0;
					system_val_reg <= 1'b0;
					system_done_reg <= 1'b0;
					state_reg <= WRITE_M10K_B;
				end
				NEXT_BYTE: begin
					axiom <= axiom >> 8;
					read_counter <= 1'b0;
					system_val_reg <= 1'b0;
					system_done_reg <= 1'b0;
					system_output_string_reg <= system_output_string_reg;
					//system_output_string_reg <= 8'b0; //DON'T KEEP THIS IN QUARTUS
					state_reg <= INCREMENT_ITER;
				end
				INCREMENT_ITER: begin
					read_counter <= 1'b0;
					system_val_reg <= 1'b0;
					system_done_reg <= 1'b0;
					if (system_output_string_reg == 8'b0 && axiom == 32'b0) begin //check if a_q_ref, b_q_ref has reached a value of 0, indicating it's at the bottom of the M10K
						a_write_address_reg <= 10'b0;
						b_write_address_reg <= 10'b0;
						iterations_counter_reg <= iterations_counter_reg + 4'b1;
						state_reg <= ZERO_READ;
					end
					state_reg <= GET_CHAR;
				end
				ZERO_READ: begin
					if (iterations_counter[0] == 1'b0) begin
						a_read_address_reg <= a_read_address_reg;
						b_read_address_reg <= 10'b0;
					end
					else begin
						a_read_address_reg <= 10'b0;
						b_read_address_reg <= b_read_address_reg;
					end
					state_reg <= GET_CHAR;
				end
				DONE: begin
					system_done_reg <= 1'b1;
				end
			endcase
		end
	end	

endmodule

module testbench();
	localparam [7:0] X = 8'b01011000;
	localparam [7:0] Y = 8'b01011001;
	localparam [7:0] plus = 8'd43;		//+
	localparam [7:0] minus = 8'd45;		//-
	localparam [7:0] F = 8'd70;
	localparam [7:0] open_bracket = 8'd91;	//[
	localparam [7:0] closing_bracket = 8'd93;	//]
	reg clk_50, clk_25, reset;
	
	reg [31:0] index;
	wire signed [15:0]  testbench_out;
	
	//Initialize clocks and index
	initial begin
		clk_50 = 1'b0;
		clk_25 = 1'b0;
		index  = 32'd0;
		//testbench_out = 15'd0 ;
	end
	
	//Toggle the clocks
	always begin
		#10
		clk_50  = !clk_50;
	end
	
	always begin
		#20
		clk_25  = !clk_25;
	end
	
	//Intialize and drive signals
	initial begin
		reset  = 1'b0;
		#10 
		reset  = 1'b1;
		#30
		reset  = 1'b0;
	end
	
	//Increment index
	always @ (posedge clk_50) begin
		index  <= index + 32'd1;
	end
	
	// Controls for VGA memory
	//=======================================================
	wire [31:0] vga_out_base_address = 32'h0000_0000 ;  // vga base addr
	reg [7:0] vga_sram_writedata ;
	reg [31:0] vga_sram_address; 
	reg vga_sram_write ;
	wire vga_sram_clken = 1'b1;
	wire vga_sram_chipselect = 1'b1;

	//=======================================================
	// pixel address is
	reg [9:0] vga_x_cood, vga_y_cood ;
	reg [7:0] pixel_color ;

	//=======================================================
	// L SYSTEM MODULE
	//=======================================================

	wire [7:0] system_output_string;
	wire system_done;
	reg [7:0] system_output_string_reg;
	reg [7:0] top_char_reg;
	wire top_done;
	reg top_done_reg;
	assign top_done = top_done_reg;
	wire top_rdy;
	reg top_rdy_reg;
	assign top_rdy = top_rdy_reg;
	wire system_val;

	// PIO port connections for graphing
	wire [7:0] top_char;	//plots 1 byte at a time
	assign top_char = top_char_reg;
	wire graphing;
	assign graphing = system_done && (!top_done);
	wire [31:0] axiom;
	wire [3:0] iterations;
	wire [3:0] iterations_counter;

	create_system system(
		.clk							(clk_50), 
		.reset						(reset), 
		.top_rdy						(top_rdy),
		.iterations					(4'd2), 
		.system_input_string		({Y,X,Y,F}), 
		.system_output_string	(system_output_string), 
		.system_val					(system_val),
		.system_done				(system_done),
		.iterations_counter		(iterations_counter)
	);

	//wait for l_system to be created
	//grab a byte of system_output_string into top_char
	//shift system_output_string
	//graph the byte (HPS)
	//continue this until system_output_string = 0 (fully shifted, all bytes grabbed)
	//done

	localparam TOP_RESET 	= 4'd0;
	localparam TOP_WAIT 		= 4'd1;	//wait for l_system to be created, then decides whether to go to GRAPH or DONE
	localparam TOP_SETUP 	= 4'd2;	//grab a byte of system_output_string into top_char
	localparam TOP_TARGET	= 4'd3;	//calculate angle and target x/y values
	localparam TOP_GRAPH		= 4'd4;	//graph on the VGA until the desired target x/y is reached
	localparam TOP_SHIFT 	= 4'd5;	//shift system_output_string << 8
	localparam TOP_DONE 		= 4'd6;	//we did it

	reg [3:0] top_state_reg;
	reg [9:0] x_reg = 10'd300;
	reg [9:0] y_reg = 10'd300;
	reg [9:0] targetx_reg;
	reg [9:0] targety_reg;
	reg [9:0] angle_reg;

	wire [6:0] length = 7'd100;

	always @ (posedge clk_50) begin
		if (reset) begin
			system_output_string_reg <= 8'b0;
			top_done_reg <= 1'b0;
			top_rdy_reg <= 1'b0;
			vga_sram_write <= 1'b0;
			vga_sram_address <= vga_out_base_address;
			vga_sram_writedata <= 8'h00;
			x_reg <= x_reg;
			y_reg <= y_reg;
			targetx_reg <= x_reg;
			targety_reg <= y_reg;
			angle_reg <= 10'b0;
			top_state_reg <= TOP_RESET;
		end
		else begin
			case (top_state_reg)
				TOP_RESET: begin
					system_output_string_reg <= 8'b0;
					top_state_reg <= TOP_WAIT;
					top_rdy_reg <= 1'b0;
					top_done_reg <= 1'b0;
					vga_sram_write <= 1'b0;
					vga_sram_address <= vga_out_base_address;
					vga_sram_writedata <= 8'h00;
					x_reg <= x_reg;
					y_reg <= y_reg;
					targetx_reg <= targetx_reg;
					targety_reg <= targety_reg;
					angle_reg <= 10'b0;
				end
				TOP_WAIT: begin
					top_done_reg <= 1'b0;
					vga_sram_write <= 1'b0;
					vga_sram_address <= vga_out_base_address;
					vga_sram_writedata <= 8'h00;
					x_reg <= x_reg;
					y_reg <= y_reg;
					targetx_reg <= x_reg;
					targety_reg <= y_reg;
					angle_reg <= angle_reg;
					if (system_done) begin
						top_state_reg <= TOP_DONE;
						top_rdy_reg <= 1'b0;
					end
					else begin
						if (system_val == 1'b0) begin
							top_rdy_reg <= 1'b1;
							top_state_reg <= TOP_WAIT;
						end
						else begin
							top_rdy_reg <= 1'b0;
							system_output_string_reg <= system_output_string;
							top_state_reg <= TOP_SETUP;
						end
					end
				end
				TOP_SETUP: begin
					top_rdy_reg <= 1'b0;
					top_done_reg <= 1'b0;
					vga_sram_write <= 1'b0;
					vga_sram_address <= vga_out_base_address;
					vga_sram_writedata <= 8'h00;
					x_reg <= x_reg;
					y_reg <= y_reg;
					targetx_reg <= targetx_reg;
					targety_reg <= targety_reg;
					angle_reg <= angle_reg;
					top_char_reg <= system_output_string_reg;
					system_output_string_reg <= system_output_string_reg;
					top_state_reg <= TOP_TARGET;
				end
				TOP_TARGET: begin
					top_rdy_reg <= 1'b0;
					top_state_reg <= TOP_GRAPH;
					vga_sram_write <= 1'b0;
					vga_sram_address <= vga_out_base_address;
					vga_sram_writedata <= 8'h00;
					x_reg <= x_reg;
					y_reg <= y_reg;
					if (iterations_counter == iterations - 4'b1) begin 
						case(top_char_reg)
							F: begin
								if (angle_reg == 10'd0) begin
									targetx_reg <= x_reg;
									targety_reg <= y_reg - length;
									angle_reg <= angle_reg;
								end 
								else if (angle_reg == 10'd90) begin 
									targetx_reg <= x_reg + length;
									targety_reg <= y_reg;
									angle_reg <= angle_reg;
								end
								else if (angle_reg == 10'd180) begin
									targetx_reg <= x_reg;
									targety_reg <= y_reg + length;
									angle_reg <= angle_reg;
								end
								else if (angle_reg == 10'd270) begin
									targetx_reg <= x_reg - length;
									targety_reg <= y_reg;
									angle_reg <= angle_reg;
								end
							end
							plus: begin 
								if (angle_reg == 10'd270) begin
									targetx_reg <= targetx_reg;
									targety_reg <= targety_reg;
									angle_reg <= 10'd0;
								end
								else begin
									targetx_reg <= targetx_reg;
									targety_reg <= targety_reg;
									angle_reg <= angle_reg + 10'd90;
								end
							end
							minus: begin
								if (angle_reg == 10'd0) begin
									targetx_reg <= targetx_reg;
									targety_reg <= targety_reg;
									angle_reg <= 10'd270;
								end
								else begin 
									targetx_reg <= targetx_reg;
									targety_reg <= targety_reg;
									angle_reg <= angle_reg - 10'd90;
								end
							end
						endcase 
					end
					else begin
						targetx_reg <= targetx_reg;
						targety_reg <= targety_reg;
						angle_reg <= angle_reg;
					end
				end
				TOP_GRAPH: begin
					top_rdy_reg <= 1'b0;
					targetx_reg <= targetx_reg;
					targety_reg <= targety_reg;
					angle_reg <= angle_reg;
					
					if (iterations_counter == iterations - 4'b1) begin
						vga_sram_write <= 1'b1;
					end 
					else begin
						vga_sram_write <= 1'b0;
					end
					vga_sram_address <= vga_out_base_address + {22'b0, x_reg} + ({22'b0,y_reg}*640) ; // compute address
					vga_sram_writedata <= 8'hbd; // data
					
					// iterate through all x,y until target is reached
					if (x_reg < targetx_reg) begin
						x_reg <= x_reg + 10'd1 ;
					end
					else if (x_reg > targetx_reg) begin
						x_reg <= x_reg - 10'd1 ;
					end
					else begin
						x_reg <= x_reg;
					end
					if (y_reg < targety_reg) begin
						y_reg <= y_reg + 10'd1 ;
					end
					else if (y_reg > targety_reg) begin
						y_reg <= y_reg - 10'd1 ;
					end
					else begin
						y_reg <= y_reg;	
					end
					
					if (x_reg == targetx_reg && y_reg == targety_reg) begin 
						top_state_reg <= TOP_SHIFT;
					end 
					else begin
						top_state_reg <= TOP_GRAPH;
					end
				end
				TOP_SHIFT: begin
					top_rdy_reg <= 1'b0;
					top_done_reg <= 1'b0;
					vga_sram_write <= 1'b0;
					vga_sram_address <= vga_out_base_address;
					vga_sram_writedata <= 8'h00;
					x_reg <= x_reg;
					y_reg <= y_reg;
					targetx_reg <= targetx_reg;
					targety_reg <= targety_reg;
					angle_reg <= angle_reg;
					system_output_string_reg <= system_output_string_reg;
					top_state_reg <= TOP_WAIT;
				end
				TOP_DONE: begin
					top_rdy_reg <= 1'b0;
					top_done_reg <= 1'b1;
					vga_sram_write <= 1'b0;
					vga_sram_address <= vga_out_base_address;
					vga_sram_writedata <= 8'h00;
					x_reg <= x_reg;
					y_reg <= y_reg;
					targetx_reg <= targetx_reg;
					targety_reg <= targety_reg;
					angle_reg <= angle_reg;
					//MAYBE GO TO TOP_RESET
				end
				default: begin
					system_output_string_reg <= system_output_string;
					top_state_reg <= TOP_WAIT;
					top_rdy_reg <= 1'b0;
					top_done_reg <= 1'b0;
					vga_sram_write <= 1'b0;
					vga_sram_address <= vga_out_base_address;
					vga_sram_writedata <= 8'h00;
					x_reg <= x_reg;
					y_reg <= y_reg;
					targetx_reg <= targetx_reg;
					targety_reg <= targety_reg;
					angle_reg <= angle_reg;
				end
			endcase
		end	
	end

	/*
	wire [39:0] dragon_result;
	wire dragon_done;
	dragon test(
		.clk			(clk_50), 
		.reset			(reset), 
		.dragon_prev		(X), 
		.dragon_result		(dragon_result), 
		.dragon_done		(dragon_done)
	);

	wire process_done;
	wire [79:0] process_output_string;
	process_string process(
		.clk			(clk_50), 
		.reset			(reset), 
		.process_input_string	({X,Y}), 
		.l_system		(1'b0), 
		.process_done		(process_done), 
		.process_output_string	(process_output_string)
	);
	*/

endmodule
	


