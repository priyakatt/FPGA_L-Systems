module dual_clock_ram(q, d, write_address, read_address, we, clk1, clk2);
 	output reg [7:0] q;
 	input [7:0] d;
 	input [6:0] write_address, read_address;
 	input we, clk1, clk2;

 	reg [6:0] read_address_reg;
 	reg [7:0] mem [127:0];

 	always @ (posedge clk1) begin
 		if (we) mem[write_address] <= d;
 	end
 	always @ (posedge clk2) begin
 		q <= mem[read_address_reg];
 		read_address_reg <= read_address;
 	end
endmodule


module rules(clk, reset, rule_val, rule_prev, rule_result, rule_done);		//equivalent to applyRule
	input clk, reset, rule_val;
	input [7:0] rule_prev; //8 bit input, ascii defined
	output [79:0] rule_result; //up to 80 bit output
	output [1:0] rule_done;

	reg [7:0] rule_prev_reg;
	reg [1:0] rule_done_reg;
	reg [79:0] rule_result_reg;
	reg [7:0] rule_state_reg;
	
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
			endcase
		end
	end	

endmodule


module create_system(clk, reset, lsystem, top_rdy, top_graphing, iterations, system_input_string, system_output_string, system_val, system_done, iterations_counter); //equivalent to createSystem() in translated_python.c
	input clk, reset, top_rdy;
	input [1:0] top_graphing, lsystem;
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

	reg [7:0] input_char_reg;
	wire [7:0] input_char;
	assign input_char = input_char_reg;

	reg dragon_val_reg;
	wire [39:0] dragon_result;
	reg [39:0] dragon_result_reg;
	wire [1:0] dragon_done;
	wire dragon_val;
	assign dragon_val = dragon_val_reg;

	dragon dragon_rule(
		.clk		(clk),
		.reset		(reset),
		.dragon_prev	(input_char),
		.dragon_result	(dragon_result),
		.dragon_done	(dragon_done),
		.dragon_val	(dragon_val)
	);	
	
	localparam RESET_SYSTEM			= 4'd0;	 	
	localparam GET_CHAR				= 4'd1;		//grab byte from axiom if count_iter == 0, otherwise read from M10K address; increment count_iter if axiom == 0 or start/end address of M10K are equal
	localparam READ_M10K				= 4'd2;		//takes 3 cycles to read value from M10K
	localparam INCREMENT_READ		= 4'd3;		//buffer state for reading M10K
	localparam COMPUTE_DRAGON		= 4'd4;		//send one byte to dragon and stays in here until dragon_done is set
	localparam WRITE_M10K_A			= 4'd5;		//write to M10K with dragon_result
	localparam INCREMENT_WRITE_A	= 4'd6;
	localparam WRITE_M10K_B			= 4'd7;		//write to M10K with dragon_result
	localparam INCREMENT_WRITE_B	= 4'd8;
	localparam NEXT_BYTE				= 4'd9;		//shift axiom if count_iter == 0, otherwise move to next address in M10K
	localparam INCREMENT_ITER		= 4'd10;	
	localparam ZERO_READ				= 4'd11;
	localparam DONE					= 4'd12;
	
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
			system_output_string_reg <= 8'b0;
			system_done_reg <= 1'b0;
			state_reg <= GET_CHAR;
		end
		else begin
			case (state_reg)
				RESET_SYSTEM: begin
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
						system_output_string_reg <= 8'b0;
						system_done_reg <= 1'b0;
						state_reg <= GET_CHAR;
					end
					else begin
						state_reg <= RESET_SYSTEM;
					end
				end
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
				READ_M10K: begin
					a_d_reg <= 8'b0;
					a_write_address_reg <= a_write_address_reg;
					a_read_address_reg <= a_read_address_reg;
					a_we_reg <= 1'b0;
					b_d_reg <= 8'b0;
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
					system_output_string_reg <= system_output_string_reg;
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
					dragon_result_reg <= {dragon_result_reg[31:0],8'b0};//dragon_result_reg << 8;
					read_counter <= 1'b0;
					system_val_reg <= 1'b0;
					system_done_reg <= 1'b0;
					state_reg <= WRITE_M10K_A;
				end
				WRITE_M10K_B: begin
					b_d_reg <= dragon_result_reg[39:32];
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
					dragon_result_reg <= {dragon_result_reg[31:0],8'b0};//dragon_result_reg << 8;
					read_counter <= 1'b0;
					system_val_reg <= 1'b0;
					system_done_reg <= 1'b0;
					state_reg <= WRITE_M10K_B;
				end
				NEXT_BYTE: begin
					axiom <= {8'b0,axiom[31:8]};//axiom >> 8;
					read_counter <= 1'b0;
					system_val_reg <= 1'b0;
					system_done_reg <= 1'b0;
					system_output_string_reg <= system_output_string_reg;
					state_reg <= INCREMENT_ITER;
				end
				INCREMENT_ITER: begin
					read_counter <= 1'b0;
					system_val_reg <= 1'b0;
					system_done_reg <= 1'b0;
					if (system_output_string_reg == 8'b0 && axiom == 32'b0 && top_graphing == 2'd2) begin //check if a_q_ref, b_q_ref has reached a value of 0, indicating it's at the bottom of the M10K
						if (iterations_counter_reg == 4'b0 || (iterations_counter_reg[0] == 1'b1 && a_q == 8'b0) || (iterations_counter_reg[0] == 1'b0 && b_q == 8'b0)) begin
							a_write_address_reg <= 10'b0;
							b_write_address_reg <= 10'b0;
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
					state_reg <= RESET_SYSTEM;
				end
			endcase
		end
	end	

endmodule