module SET ( clk , rst, en, central, radius, busy, valid, candidate );

input clk, rst;
input en;
input [15:0] central;
input [7:0] radius;
output busy;
output valid;
output reg [3:0] candidate;

//============= Parameter =============
parameter Prep = 2'd0, DataIn = 2'd1, Cal = 2'd2;
integer i, j;

//======== Reg/Wire Declaration =======
reg [1:0] state, nxt_state;
reg [2:0] cnt, nxt_cnt;
reg [11:0] cir, nxt_cir, y_cir, x_cir;
reg [9:0] sqr [0:9];
reg [9:0] nxt_sqr [0:9];
reg [9:0] nnxt_sqr [0:9];
reg [9:0] same [0:9];
reg [4:0] final[0:9];
reg [4:0] nxt_final[0:9];
reg [3:0] nxt_candidate;
reg [3:0] x, y, r, nxt_r;
reg [3:0] min [0:9][0:9];
reg [3:0] max [0:9][0:9];
reg [3:0] nxt_min [0:9][0:9];
reg [3:0] nxt_max [0:9][0:9];

//======= Finite State Machine ========
always@(*)begin
	case(state)
		Prep:   begin
			nxt_state = (en)? DataIn : Prep;	
			end
		DataIn: begin
			nxt_state = (cnt == 3'd3)? Cal : DataIn;
			end
		Cal:    begin
			nxt_state = (cnt == 3'd5)? Prep : Cal;
			end
		default: nxt_state = Prep;
	endcase
end

always@(posedge clk or posedge rst)begin
	if(rst)begin
		state <= Prep;
	end
	else begin
		state <= nxt_state;
	end
end

//============= Sequential =============
always@(posedge clk or posedge rst)begin
	if(rst)begin
		cnt <= 3'b0;
		x_cir <= 12'b0;
		y_cir <= 12'b0;
		candidate <= 4'b0;
		for( i=0 ; i<10 ; i=i+1)begin
			final[i] <= 4'b0;
		end
	end
	else begin
		cnt <= nxt_cnt;
		x_cir <= {central[15:8], radius[7:4]};
		y_cir <= {central[7:0], radius[3:0]};
		candidate <= nxt_candidate;
		for( i=0 ; i<10 ; i=i+1)begin
			final[i] <= nxt_final[i];
		end
	end
end

always@(posedge clk or posedge rst)begin
	if(rst)begin
		cir <= 12'b0;
		nxt_cir <= 12'b0;
	end
	else if	(cnt == 3'b0)begin
		nxt_cir <= x_cir;
		cir <= y_cir;
	end
	else begin
		nxt_cir <= 12'b0;
		cir <= nxt_cir;
	end
end

always@(posedge clk or posedge rst)begin
	if(rst)begin
		for( i=0 ; i<10 ; i=i+1)begin
			sqr[i] <= 10'b0;
			nxt_sqr[i] <= 10'b0;
		end
	end
	else begin
		for( i=0 ; i<10 ; i=i+1)begin
			nxt_sqr[i] <= nnxt_sqr[i];
			sqr[i] <= nxt_sqr[i];
		end
	end
end

always@(posedge clk or posedge rst)begin  // max and min delay
	if(rst)begin
		r <= 4'b0;
		for( i=0 ; i<10 ; i=i+1)begin
			for( j=0 ; j<10 ; j=j+1)begin
				max[i][j] <= 4'b0;
				min[i][j] <= 4'b0;
			end
		end
	end
	else begin
		r <= nxt_r;
		for( i=0 ; i<10 ; i=i+1)begin
			for( j=0 ; j<10 ; j=j+1)begin
				max[i][j] <= nxt_max[i][j];
				min[i][j] <= nxt_min[i][j];
			end
		end
	end
end

//============ Combinational ===========
assign busy = (state == DataIn)? 1'b1 : 1'b0;
assign valid = (state == Prep)? 1'b1 : 1'b0;

always @(*)begin
	if(state == Prep)begin
		nxt_cnt = 3'b0;
	end
	else begin
		nxt_cnt = cnt +1'b1;
	end
end


always@(*)begin		//choose max and min, decide sqr
	if(state == DataIn)begin
		nxt_r = cir[3:0];
		for( i=0 ; i<10 ; i=i+1 )begin
			for( j=0 ; j<10 ; j=j+1 )begin
				x = ( i > cir[11:8] )? (i-cir[11:8]) : (cir[11:8]-i);
				y = ( j > cir[7:4] )? (j-cir[7:4]) : (cir[7:4]-j);
				if( x > y )begin
					nxt_max[i][j] = x;
					nxt_min[i][j] = y;
				end
				else begin
					nxt_max[i][j] = y;
					nxt_min[i][j] = x;
				end
//saparate
//				nnxt_sqr[i][j] =( (max[i][j]*61 + min[i][j]*25) < r[3:0] << 6)? 1'b1 : 1'b0;
			end
		end
	end
	else begin
		x = 4'b0;
		y = 4'b0;
		nxt_r = 4'b0;
		for( i=0 ; i<10 ; i=i+1)begin
//			nnxt_sqr[i] = 10'b0;
			for( j=0 ; j<10 ; j=j+1 )begin
				nxt_max[i][j] = 4'b0;
				nxt_min[i][j] = 4'b0;
			end
		end
	end	
end

always@(*)begin
	if(state == DataIn)begin
		for( i=0 ; i<10 ; i=i+1 )begin
			for( j=0 ; j<10 ; j=j+1 )begin
				nnxt_sqr[i][j] =( (max[i][j]*61 + min[i][j]*25) < r[3:0] << 6)? 1'b1 : 1'b0;
			end
		end
	end
	else begin
		for( i=0 ; i<10 ; i=i+1)begin
			nnxt_sqr[i] = 10'b0;
		end
	end
end	


always@(*)begin		//add up the sum of 1
	if(state == Cal)begin	
		for( i=0 ; i<10 ; i=i+1)begin
			for( j=0 ; j<10 ; j=j+1)begin
				same[i][j] = (sqr[i][j] & nxt_sqr[i][j]);
			end
			nxt_final[i] = same[i][0] + same[i][1] + same[i][2] + same[i][3] + same[i][4] + same[i][5] + same[i][6] + same[i][7] + same[i][8] + same[i][9];          
		end
//		nxt_candidate = final[0]+final[1]+final[2]+final[3]+final[4]+final[5]+final[6]+final[7]+final[8]+final[9];
	end
	else begin
		for( i=0 ; i<10 ; i=i+1)begin
			for( j=0 ; j<10 ; j=j+1)begin
				same[i][j] = 1'b0;
			end
			nxt_final[i] = 4'b0;
		end
//		nxt_candidate = 4'b0;
	end
end

always@(*)begin
	if(state == Cal)begin	
		nxt_candidate = final[0]+final[1]+final[2]+final[3]+final[4]+final[5]+final[6]+final[7]+final[8]+final[9];
	end
	else begin
		nxt_candidate = 4'b0;
	end
end
		

endmodule
