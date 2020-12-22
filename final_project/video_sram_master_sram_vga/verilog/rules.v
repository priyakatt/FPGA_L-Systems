////////////////////////////////////////////////////////////////////////
// RULES.V
//		Responsible for computing and storing the L-System
// (Priya Kattappurath, Michael Rivera, Caitlin Stanton)
////////////////////////////////////////////////////////////////////////

// Dual Clock RAM
//		Equivalent to instantiating ~8 M10Ks
module dual_clock_ram(q, d, write_address, read_address, we, clk1, clk2);
 	output reg [7:0] q;
 	input [7:0] d;
 	input [12:0] write_address, read_address;
 	input we, clk1, clk2;

 	reg [12:0] read_address_reg;
 	reg [7:0] mem [8191:0];	//8192 memory locations

 	always @ (posedge clk1) begin
 		if (we) mem[write_address] <= d;
 	end
 	always @ (posedge clk2) begin
 		q <= mem[read_address_reg];
 		read_address_reg <= read_address;
 	end
endmodule

// Fixed point signed multiplier
//		Works in 11.21 fixed point
module signed_mult (out, a, b); //11.21 fixed point
	output 	signed  [31:0]	out;
	input 	signed	[31:0] 	a;
	input 	signed	[31:0] 	b;
	// intermediate full bit length
	wire 	signed	[63:0]	mult_out;
	assign mult_out = a * b;
	// select bits for 11.21 fixed point
	assign out = {mult_out[63], mult_out[51:21]}; //11.21 fixed point
endmodule

// Rule module
//		Declares rules for 7 L-Systems: Dragon curve, 2 Sierpinski arrowheads, 2 Koch curves, cross, tessellated triangle
//		(Equivalent to applyRule in lsystem.py)
module rules(clk, reset, lsystem, rule_val, rule_prev, rule_result, rule_done);
	input clk, reset, rule_val;
	input [2:0] lsystem;
	input [7:0] rule_prev; 			//8 bit input, defined by ASCII code
	output [79:0] rule_result; 	//up to 80 bit output
	output [1:0] rule_done;

	reg [7:0] rule_prev_reg;
	reg [1:0] rule_done_reg;
	reg [79:0] rule_result_reg;
	reg [2:0] rule_state_reg;
	
	assign rule_result = rule_result_reg;
	assign rule_done = rule_done_reg;
	
	//ASCII definitions of alphabet
	localparam [7:0] X = 8'b01011000;
	localparam [7:0] Y = 8'b01011001;
	localparam [7:0] plus = 8'd43;						//+
	localparam [7:0] minus = 8'd45;						//-
	localparam [7:0] F = 8'd70;
	localparam [7:0] A = 8'd65;

	//FSM states
	localparam RULE_UPDATE 							= 3'b0;
	localparam DRAGON_TRANSLATE 				= 3'b1;
	localparam TRIANGLE_TRANSLATE				= 3'd2;	
	localparam ARROW_TRANSLATE 					= 3'd3;
	localparam KOCH_TRANSLATE						= 3'd4;
	localparam SNOWFLAKE_TRANSLATE			= 3'd5;
	localparam CROSS_TRANSLATE					= 3'd6;
	localparam TESSELLATE_TRANSLATE			= 3'd7;

	always @ (posedge clk) begin
		//reset state
		if (reset) begin
			rule_result_reg <= 80'b0;
			rule_done_reg <= 2'b0;
			rule_prev_reg <= rule_prev;
			rule_state_reg <= RULE_UPDATE;
		end
		else begin
			case (rule_state_reg)
				//waits for new character to apply rule to
				RULE_UPDATE: begin
					rule_prev_reg <= rule_prev;
					rule_result_reg <= rule_result_reg;
					if (rule_val) begin	//if new character has arrived
						rule_done_reg <= 2'b0;
						//choose which state to transition to based on inputted lsystem
						if (lsystem == 3'b0) begin
							rule_state_reg <= DRAGON_TRANSLATE;
						end
						else if (lsystem == 3'b1) begin 
							rule_state_reg <= TRIANGLE_TRANSLATE;
						end 
						else if (lsystem == 3'd2) begin
							rule_state_reg <= KOCH_TRANSLATE;
						end
						else if (lsystem == 3'd3) begin
							rule_state_reg <= ARROW_TRANSLATE;
						end
						else if (lsystem == 3'd4) begin
							rule_state_reg <= SNOWFLAKE_TRANSLATE;
						end
						else if (lsystem == 3'd5) begin
							rule_state_reg <= CROSS_TRANSLATE;
						end
						else if (lsystem == 3'd6) begin 
							rule_state_reg <= TESSELLATE_TRANSLATE;
						end
						else begin 
							rule_state_reg <= RULE_UPDATE;
						end
					end
					else begin	//stays in this state until a valid character is received
						rule_done_reg <= rule_done_reg;
						rule_state_reg <= RULE_UPDATE;
					end
				end

				//RULE APPLICATION STATES
					//If the inputted character matches a rule, output that string
					//Otherwise output the character
					//Buffered by zeroes to be 10 bytes (80 bits)

				//Dragon curve
				DRAGON_TRANSLATE: begin		
					rule_prev_reg <= rule_prev_reg;
					if (rule_prev_reg == X) begin
						rule_done_reg <= 2'b1;
						rule_result_reg <= {X, plus, Y, F, plus, 40'b0};	//"X+YF+"
					end
					else if (rule_prev_reg == Y) begin
						rule_done_reg <= 2'd2;
						rule_result_reg <= {minus, F, X, minus, Y, 40'b0};	//"-FX-Y"
					end
					else begin
						rule_done_reg <= 2'd3;
						rule_result_reg <= {rule_prev_reg, 72'b0};
					end
					rule_state_reg <= RULE_UPDATE;
				end
				//Sierpsinki arrowhead (1)
				TRIANGLE_TRANSLATE: begin
					rule_prev_reg <= rule_prev_reg;
					if (rule_prev_reg == X) begin
						rule_done_reg <= 2'b1;
						rule_result_reg <= {Y, F, plus, X, F, plus, Y, 24'b0};	//"YF+XF+Y"
					end
					else if (rule_prev_reg == Y) begin
						rule_done_reg <= 2'd2;
						rule_result_reg <= {X, F, minus, Y, F, minus, X, 24'b0};	//"XF-YF-X"
					end
					else begin
						rule_done_reg <= 2'd3;
						rule_result_reg <= {rule_prev_reg, 72'b0};
					end
					rule_state_reg <= RULE_UPDATE;
				end
				//Sierpinski arrowhead (2)
				ARROW_TRANSLATE: begin
					rule_prev_reg <= rule_prev_reg;
					if (rule_prev_reg == A) begin
						rule_done_reg <= 2'b1;
						rule_result_reg <= {plus, F, minus, A, minus, F, plus, 24'b0};	//"+F-A-F+"
					end
					else if (rule_prev_reg == F) begin
						rule_done_reg <= 2'd2;
						rule_result_reg <= {minus, A, plus, F, plus, A, minus, 24'b0};	//"-A+F+A-"
					end
					else begin
						rule_done_reg <= 2'd3;
						rule_result_reg <= {rule_prev_reg, 72'b0};
					end
					rule_state_reg <= RULE_UPDATE;
				end
				//Koch curve
				KOCH_TRANSLATE: begin
					rule_prev_reg <= rule_prev_reg;
					if (rule_prev_reg == F) begin
						rule_done_reg <= 2'b1;
						rule_result_reg <= {F, plus, F, minus, minus, F, plus, F, 16'b0};	//"F+F--F+F"
					end
					else begin
						rule_done_reg <= 2'd3;
						rule_result_reg <= {rule_prev_reg, 72'b0};
					end
					rule_state_reg <= RULE_UPDATE;
				end
				//Koch snowflake
				SNOWFLAKE_TRANSLATE: begin 
					rule_prev_reg <= rule_prev_reg;
					if (rule_prev_reg == F) begin
						rule_done_reg <= 2'b1;
						rule_result_reg <= {F, minus, F, plus, plus, F, minus, F, 16'b0};	//"F-F++F-F"
					end
					else begin
						rule_done_reg <= 2'd3;
						rule_result_reg <= {rule_prev_reg, 72'b0};
					end
					rule_state_reg <= RULE_UPDATE;
				end
				//Cross
				CROSS_TRANSLATE: begin
					rule_prev_reg <= rule_prev_reg;
					if (rule_prev_reg == F) begin
						rule_done_reg <= 2'b1;
						rule_result_reg <= {F, plus, F, F, plus, plus, F, plus, F, 8'b0};	//"F+FF++F+F"
					end
					else begin
						rule_done_reg <= 2'd3;
						rule_result_reg <= {rule_prev_reg, 72'b0};
					end
					rule_state_reg <= RULE_UPDATE;
				end
				//Tessellated triangle
				TESSELLATE_TRANSLATE: begin
					rule_prev_reg <= rule_prev_reg;
					if (rule_prev_reg == F) begin
						rule_done_reg <= 2'b1;
						rule_result_reg <= {F, minus, F, plus, F, 40'b0};	//"F-F+F"
					end
					else begin
						rule_done_reg <= 2'd3;
						rule_result_reg <= {rule_prev_reg, 72'b0};
					end
					rule_state_reg <= RULE_UPDATE;
				end
			endcase
		end
	end	
endmodule

// Create System module
//		Performs given number of iterations on the L-System string
//		Stores strings in memory
//		Sends result of each iteration byte by byte to the top-level
//		(Equivalent to createSystem and processString in lsystem.py)
module create_system(clk, reset, top_rdy, top_graphing, lsystem, iterations, system_input_string, system_output_string, system_val, system_done, iterations_counter); //equivalent to createSystem() in translated_python.c
	input clk, reset, top_rdy;
	input [1:0] top_graphing;
	input [31:0] system_input_string;
	input [2:0] lsystem;
	input [3:0] iterations;
	output [7:0] system_output_string;
	output system_val;
	output system_done;
	output [3:0] iterations_counter;

	//ASCII definitions of alphabet
	localparam [7:0] X = 8'b01011000;
	localparam [7:0] Y = 8'b01011001;
	localparam [7:0] plus = 8'd43;		//+
	localparam [7:0] minus = 8'd45;		//-
	localparam [7:0] F = 8'd70;
	localparam [7:0] A = 8'd65;
	localparam [7:0] open_bracket = 8'd91;	//[
	localparam [7:0] closing_bracket = 8'd93;	//]

	//dual_clock_ram instantiations (M10K memory)
	wire [7:0] a_q;
	wire [7:0] a_d;
	reg[7:0] a_d_reg;
	wire [12:0] a_write_address;
	reg [12:0] a_write_address_reg;
	wire [12:0] a_read_address;
	reg [12:0] a_read_address_reg;
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
	wire [12:0] b_write_address;
	reg [12:0] b_write_address_reg;
	wire [12:0] b_read_address;
	reg [12:0] b_read_address_reg;
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

	//rules module 
	reg rule_val_reg;
	wire [79:0] rule_result;
	reg [79:0] rule_result_reg;
	wire [1:0] rule_done;
	wire rule_val;
	reg [7:0] input_char_reg;
	wire [7:0] input_char;
	
	assign rule_val = rule_val_reg;
	assign input_char = input_char_reg;

	rules rule(
		.clk				(clk),
		.reset			(reset),
		.lsystem			(lsystem),
		.rule_prev		(input_char),
		.rule_result	(rule_result),
		.rule_done		(rule_done),
		.rule_val		(rule_val)
	);		
	
	//FSM states
	localparam RESET_SYSTEM				= 4'd0;
	localparam CLEAR_M10KS				= 4'd1;	
	localparam GET_CHAR						= 4'd2;		
	localparam READ_M10K					= 4'd3;		
	localparam COMPUTE_DRAGON			= 4'd4;
	localparam WRITE_M10K_A				= 4'd5;
	localparam INCREMENT_WRITE_A	= 4'd6;
	localparam WRITE_M10K_B				= 4'd7;
	localparam INCREMENT_WRITE_B	= 4'd8;
	localparam NEXT_BYTE					= 4'd9;
	localparam INCREMENT_ITER			= 4'd10;	
	localparam ZERO_READ					= 4'd11;
	localparam DONE								= 4'd12;
	
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
		//reset state, board startup
		if (reset) begin
			iterations_counter_reg <= 4'b0;
			input_char_reg <= 8'b0;
			a_d_reg <= 8'b0;
			a_write_address_reg <= 13'b0;
			a_read_address_reg <= 13'b0;
			a_we_reg <= 1'b0;
			b_d_reg <= 8'b0;
			b_write_address_reg <= 13'b0;
			b_read_address_reg <= 13'b0;
			b_we_reg <= 1'b0;
			axiom <= system_input_string;
			rule_result_reg <= rule_result;
			read_counter <= 1'b0;
			system_val_reg <= 1'b0;
			system_output_string_reg <= 8'b0;
			system_done_reg <= 1'b0;
			state_reg <= CLEAR_M10KS;
		end
		else begin
			case (state_reg)
				//reset state, new L-System
				RESET_SYSTEM: begin
					if (reset) begin
						iterations_counter_reg <= 4'b0;
						input_char_reg <= 8'b0;
						a_d_reg <= 8'b0;
						a_write_address_reg <= 13'b0;
						a_read_address_reg <= 13'b0;
						a_we_reg <= 1'b0;
						b_d_reg <= 8'b0;
						b_write_address_reg <= 13'b0;
						b_read_address_reg <= 13'b0;
						b_we_reg <= 1'b0;
						axiom <= system_input_string;
						rule_result_reg <= rule_result;
						read_counter <= 1'b0;
						system_val_reg <= 1'b0;
						system_output_string_reg <= 8'b0;
						system_done_reg <= 1'b0;
						state_reg <= CLEAR_M10KS;
					end
					else begin
						state_reg <= RESET_SYSTEM;
					end
				end
				//sets all M10K data to zero
				CLEAR_M10KS: begin 
					a_d_reg <= 8'b0;
					b_d_reg <= 8'b0;
					if (a_write_address_reg < 13'h1FFF) begin
						a_we_reg <= 1'b1;
						a_write_address_reg <= a_write_address_reg + 13'b1;
					end
					if (b_write_address_reg < 13'h1FFF) begin 
						b_we_reg <= 1'b1;
						b_write_address_reg <= b_write_address_reg + 13'b1;
					end
					if (a_write_address_reg == 13'h1FFF && b_write_address_reg == 13'h1FFF) begin 
						a_we_reg <= 1'b0;
						b_we_reg <= 1'b0;
						a_write_address_reg <= 13'b0;
						b_write_address_reg <= 13'b0;
						state_reg <= GET_CHAR;
					end
					else begin 
						state_reg <= CLEAR_M10KS;
					end
				end
				//grabs the next character in the string to process, either from the axiom or M10K memory
				GET_CHAR: begin
					a_d_reg <= 8'b0;
					a_write_address_reg <= a_write_address_reg;
					a_read_address_reg <= a_read_address_reg;
					a_we_reg <= 1'b0;
					b_d_reg <= 8'b0;
					b_write_address_reg <= b_write_address_reg;
					b_read_address_reg <= b_read_address_reg;
					b_we_reg <= 1'b0;
					rule_result_reg <= rule_result;
					read_counter <= 1'b0;
					system_val_reg <= 1'b0;
					system_output_string_reg <= system_output_string_reg;
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
				//Reads from either of the M10Ks depending on the iteration count
						//Requires 3 clock cycles with dual_port_ram
				READ_M10K: begin
					a_d_reg <= 8'b0;
					a_write_address_reg <= a_write_address_reg;
					a_read_address_reg <= a_read_address_reg;
					a_we_reg <= 1'b0;
					b_d_reg <= 8'b0;
					b_write_address_reg <= b_write_address_reg;
					b_read_address_reg <= b_read_address_reg;
					b_we_reg <= 1'b0;
					rule_result_reg <= rule_result;
					read_counter <= read_counter;
					system_val_reg <= 1'b0;
					system_done_reg <= 1'b0;
					if (iterations_counter_reg[0] == 1'b1) begin
						input_char_reg <= a_q;
					end
					else begin
						input_char_reg <= b_q;
					end
						state_reg <= COMPUTE_DRAGON;
						if (iterations_counter_reg[0] == 1'b0) begin
							b_read_address_reg <= b_read_address_reg + 13'b1;
						end 
						else begin
							a_read_address_reg <= a_read_address_reg + 13'b1;
						end
				end
				//Sends character to the rules module to be processed
				COMPUTE_DRAGON: begin
					a_d_reg <= 8'b0;
					a_write_address_reg <= a_write_address_reg;
					a_read_address_reg <= a_read_address_reg;
					a_we_reg <= 1'b0;
					b_d_reg <= 8'b0;
					b_write_address_reg <= b_write_address_reg;
					b_read_address_reg <= b_read_address_reg;
					b_we_reg <= 1'b0;
					rule_result_reg <= rule_result;
					rule_val_reg <= 1'b1;
					read_counter <= 1'b0;
					system_val_reg <= 1'b0;
					system_output_string_reg <= system_output_string_reg;
					system_done_reg <= 1'b0;
					if (rule_done > 2'b0) begin
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
				//Writes to M10K A memory on even iterations
				//Determines if entire result from rules has been written to memory
				//Sends result from rules byte by byte to top level
				WRITE_M10K_A: begin
					a_d_reg <= rule_result_reg[79:72];
					a_write_address_reg <= a_write_address_reg;
					a_read_address_reg <= a_read_address_reg;
					rule_result_reg <= rule_result_reg;
					read_counter <= 1'b0;
					system_done_reg <= 1'b0;
					system_output_string_reg <= rule_result_reg[79:72];
					if (rule_result_reg == 80'b0) begin
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
				//Increments write address for M10K A to write entire result to memory
				INCREMENT_WRITE_A: begin
					system_output_string_reg <= system_output_string_reg;
					a_write_address_reg <= a_write_address_reg + 13'b1;
					a_we_reg <= 1'b0;	
					rule_result_reg <= rule_result_reg << 8;
					read_counter <= 1'b0;
					system_val_reg <= 1'b0;
					system_done_reg <= 1'b0;
					state_reg <= WRITE_M10K_A;
				end
				//Writes to M10K B memory on odd iterations
				//Determines if entire result from rules has been written to memory
				//Sends result from rules byte by byte to top level
				WRITE_M10K_B: begin
					b_d_reg <= rule_result_reg[79:72];
					b_write_address_reg <= b_write_address_reg;
					b_read_address_reg <= b_read_address_reg;
					rule_result_reg <= rule_result_reg;
					read_counter <= 1'b0;
					system_done_reg <= 1'b0;
					system_output_string_reg <= rule_result_reg[79:72];
					if (rule_result_reg == 80'b0) begin
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
				//Increments write address for M10K B to write entire result to memory
				INCREMENT_WRITE_B: begin
					system_output_string_reg <= system_output_string_reg;
					b_write_address_reg <= b_write_address_reg + 13'b1;
					b_we_reg <= 1'b0;	
					rule_result_reg <= rule_result_reg << 8;
					read_counter <= 1'b0;
					system_val_reg <= 1'b0;
					system_done_reg <= 1'b0;
					state_reg <= WRITE_M10K_B;
				end
				//Shifts the axiom to indicate a character has been fully processed and written to memory
				NEXT_BYTE: begin
					axiom <= axiom >> 8;
					read_counter <= 1'b0;
					system_val_reg <= 1'b0;
					system_done_reg <= 1'b0;
					system_output_string_reg <= system_output_string_reg;
					state_reg <= INCREMENT_ITER;
				end
				//Increments the iterations_counter for the L-System
					//This is done:
						// - when there's nothing left of axiom and we're on the zeroth iteration
						// - a zero byte is read from M10K A on an odd iteration
						// - a zero byte is read from M10K B on an even iteration
				INCREMENT_ITER: begin
					read_counter <= 1'b0;
					system_val_reg <= 1'b0;
					system_done_reg <= 1'b0;
					if (system_output_string_reg == 8'b0 && axiom == 32'b0 && top_graphing == 2'd2) begin
						if (	iterations_counter_reg == 4'b0 || 
								 (iterations_counter_reg[0] == 1'b1 && a_q == 8'b0) || 
								 (iterations_counter_reg[0] == 1'b0 && b_q == 8'b0)) begin
							a_write_address_reg <= 13'b0;
							b_write_address_reg <= 13'b0;
							iterations_counter_reg <= iterations_counter_reg + 4'b1;
							state_reg <= ZERO_READ;
						end
						else begin
							state_reg <= GET_CHAR;
						end
					end
					else begin
						state_reg <= GET_CHAR;
					end
				end
				//Zeroes out the read addresses so that they'll start at the top of the M10K in the next iteration
				ZERO_READ: begin
					if (iterations_counter[0] == 1'b0) begin
						a_read_address_reg <= a_read_address_reg;
						b_read_address_reg <= 13'b0;
					end
					else begin
						a_read_address_reg <= 13'b0;
						b_read_address_reg <= b_read_address_reg;
					end
					state_reg <= GET_CHAR;
				end
				//Designated number of iterations has been performed on the L-System
				DONE: begin
					system_done_reg <= 1'b1;
					a_write_address_reg <= 13'b0;
					b_write_address_reg <= 13'b0;
					a_read_address_reg <= 13'b0;
					b_read_address_reg <= 13'b0;
					state_reg <= RESET_SYSTEM;
				end
			endcase
		end
	end	
endmodule