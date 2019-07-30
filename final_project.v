  module test (
     CLOCK_50,	//	On Board 50 MHz
     // Your inputs and outputs here
     KEY,
     SW,
     LEDR,
    // The ports below are for the VGA output.  Do not change.	
    VGA_CLK,	//	VGA Clock
    VGA_HS,	//	VGA H_SYNC
    VGA_VS,	//	VGA V_SYNC
    VGA_BLANK_N,	//	VGA BLANK
    VGA_SYNC_N,	//	VGA SYNC
    VGA_R,   	//	VGA Red[9:0]
    VGA_G,	//	VGA Green[9:0]
    VGA_B,   	//	VGA Blue[9:0]
	 HEX0,
	 HEX1,
	 HEX2,
	 HEX3,
	 HEX4,
	 HEX5
);

    // Declare your inputs and outputs here
    input   CLOCK_50;	//	50 MHz
    input   [7:0]   SW;
    input   [3:0]   KEY; 
    output [9:0]  LEDR ;

    // Do not change the following outputs
    output			VGA_CLK;   	//	VGA Clock
    output			VGA_HS;		//	VGA H_SYNC
    output			VGA_VS;		//	VGA V_SYNC
    output			VGA_BLANK_N;	//	VGA BLANK
    output			VGA_SYNC_N;	//	VGA SYNC
    output	[9:0]	VGA_R;   			//	VGA Red[9:0]
    output	[9:0]	VGA_G;	 		//	VGA Green[9:0]
    output	[9:0]	VGA_B; 	 //	VGA Blue[9:0]
	 
	 output [6:0] HEX0;
	 output [6:0] HEX1;
	 output [6:0] HEX2;
	 output [6:0] HEX3;
	 output [6:0] HEX4;
	 output [6:0] HEX5;
	
	 
    wire resetn;
    assign resetn = KEY[0];
    //wire enable;                 
	
	
    // Create an Instance of a VGA controller - there can be only one!
    // Define the number of colours as well as the initial background
    // image file (.MIF) for the controller.

    vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(color),
			.x(x),
			.y(y),
			.plot(writeEn),
			//Signals for the DAC to drive the monitor. 
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "board.colour.mif";
		
	
    // Put your code here. Your code should produce signals x,y,colour and writeEn
    // for the VGA controller, in addition to any other functionality your design may require.
    wire [3:0] state ;                   // output from cp -> all other modules

    wire [3:0] addr_x, addr_y ;          // addr_x, addr_y from input SW,  datapath->validation & draw_chess
    wire start_draw;                     // if 1, start to draw, datapath->draw_chess
    wire [2:0] chesscolor;               // datapath->draw_chess, & validation

    wire [3:0] done;                    //  draw_chess -> control_path & datapath, when one chess is drawn, done + 1 

    wire [7:0] x;                        //output from Draw_chess-> VGA required
    wire [7:0] y;
    wire writeEn ;                       // draw_chess -> VGA required input
    wire [2:0] color ;                   // output from  draw_chess -> VGA

    wire [3:0] dir1, dir2, dir3, dir4, dir5, dir6, dir7, dir8 ;  //output from Validation -> datapath
    wire [3:0] total ;                                           // Validation -> control_path
    wire [1:0] check_done ;                                      // validation -> control_path & datapath
    wire [3:0] mem_x, mem_y ;                                    //  validation -> ram64
    wire black_win ;                                             // validation -> datapath
    wire rplot ;                                                // flag of read mem , validation -> ram64

    wire [2:0] data;       // value of color read from ram64-> validation, color stored in memory
    wire [7:0] address ;   // select_addr -> ram64
    wire [2:0] colorout ;  // select_addr -> ram64,  color to write to ram
    wire rw_switch ;       // rw_switch = 0, read enable,  1, withe enable

// Instanciate FSM control
    control_path cp(CLOCK_50, resetn, KEY, done, check_done, total, state);

// Instanciate datapath
   data_path dp(CLOCK_50, resetn, SW, state, done, check_done, black_win,
                dir1, dir2, dir3, dir4, dir5, dir6, dir7,dir8,
                addr_x, addr_y, chesscolor, LEDR, start_draw,	 
					 HEX0, HEX1, HEX2, HEX3, HEX4, HEX5);

// Validate chess
    validation vd(CLOCK_50,  resetn, state, addr_x, addr_y, chesscolor, data, 
     dir1,dir2, dir3,dir4,dir5,dir6,dir7,dir8, total, check_done, black_win, 
     mem_x, mem_y, rplot) ;

// Draw chess
   draw_chess dc(CLOCK_50, resetn, state, addr_x, addr_y, chesscolor, start_draw, 
                 x, y, writeEn, color, done) ;

// Read-Write Memory 

select_addr saddr (CLOCK_50, mem_x, mem_y, rplot, addr_x, addr_y, color, writeEn, 
                       address,  rw_switch, colorout) ;

my_ram64 u0 (address,CLOCK_50, colorout, writeEn, rw_switch, data);


endmodule

//==========================================================
module control_path(clock, resetn, KEY, done, check_done, total, state) ;
    input clock;
    input resetn ;
    input [3:0]KEY ;
    input [3:0]done ; 
    input [1:0]check_done ;
    input [3:0] total ;     
    output [3:0] state ;
    
    reg [3:0] presentState ;    
    reg [3:0] nextState, previousState ;
	 assign state = presentState ;

    parameter [3:0] Initial_S = 4'b1111, BlackMove =4'b0001, WhiteMove = 4'b0010, Draw = 4'b0011, Load=4'b0100,  Check=4'b1100, GameOver=4'b1010, Reset_S=4'b0000;

   reg [1:0] wait_for_load ;

    always @(posedge clock)
    begin
        if (resetn == 1'b0)		  
            presentState = Reset_S ;
        else if (nextState != presentState)
            begin
                if (presentState == BlackMove | presentState == WhiteMove)
                   previousState = presentState ;
                presentState = nextState ;
            end
    end

    always @(posedge clock)
    begin: state_table
        case (presentState)
        Reset_S:
          begin
               wait_for_load = 0 ;
	       if(KEY==4'b0111)
                    nextState = Initial_S;
          end
        Initial_S:  
                if (done == 4'b0100)                   // means 4 inital chesses were drawn
                    nextState = BlackMove ;
                else
	            nextState =Initial_S;
        BlackMove: 
            begin
                if (KEY==4'b1101)                           // press KEY[1] to confirm
                    nextState = Load ;
                if (KEY==4'b0001)                           // press KEY[3], game over
                    nextState = GameOver ;
            end
        Load:
           begin
              if (wait_for_load < 3)                   // wait to load  SW input to addr_x, addr_y
                  wait_for_load = wait_for_load + 1 ;
             else 
                  begin
                  nextState = Check ;
                  wait_for_load = 0 ;
                 end
             end
        Check:
            begin
             if (check_done[0] == 1)                 // valid play
                nextState = Draw ;
             else if (check_done[1] == 1)            // invalid play, re-input
                 nextState = previousState ;  
            end
        WhiteMove:
            begin
                if (KEY==4'b1011)                         // press KEY[2] to confirm white chess
                    nextState = Load ;
                if (KEY==4'b0001)                             // press KEY[3] game over
                    nextState = GameOver ;    
           end
       Draw :
          begin
             if (done == total + 1)                  // when drawing completed, return to BlackMove or WhiteMove
                nextState = previousState ^ 4'b0011 ; 
          end 
       GameOver:
             if (done == 4'b1111)                    // when gameover, calculate who wins and draw 16 chess in winner's color
                 nextState = Reset_S ;               // when drawing complete, return to Reset State
      endcase
 end 
endmodule 

module data_path(clock, resetn, SW, state,done, check_done , black_win, 
                 dir1, dir2, dir3, dir4, dir5, dir6, dir7, dir8, 
                 addr_x, addr_y, color, LEDR, plot,HEX0, HEX1, HEX2, HEX3, HEX4, HEX5);

input clock ;
input resetn, black_win ;
input [7:0]SW ;
input [3:0]state ;
input [3:0]done ;
input [1:0]check_done ;
input [3:0] dir1, dir2, dir3, dir4, dir5, dir6, dir7, dir8;

output reg [3:0] addr_x ;
output reg [3:0] addr_y ;
output reg [2:0] color ;
output reg [9:0] LEDR ;
output reg plot;
	 output reg [6:0] HEX0;
	 output reg [6:0] HEX1;
	 output reg [6:0] HEX2;
	 output reg [6:0] HEX3;
	 output reg [6:0] HEX4;
	 output reg [6:0] HEX5;

 parameter [3:0] Initial_S = 4'b1111, BlackMove =4'b0001, WhiteMove = 4'b0010, Draw = 4'b0011, Check=4'b1100 ,
 Reset_S=4'b0000, Load=4'b0100, GameOver=4'b1010 ;

parameter [2:0] BLACK=3'b101 , WHITE= 3'b111;

reg [3:0] xx, yy ;

always @(posedge clock)
begin
case (state)
    Reset_S:
      begin
						HEX0[6:0]=7'b1111111;
						HEX1[6:0]=7'b1111111;
						HEX2[6:0]=7'b1111111;
						HEX3[6:0]=7'b1111111;
						HEX4[6:0]=7'b1111111;
						HEX5[6:0]=7'b1111111;	
        plot <= 0;
        color <=3'b000 ; 
        addr_x <=0 ;
        addr_y <=0 ;
        LEDR[0] <= 1'b0 ;                  // LED 0 turn on
        LEDR[1] <= 1'b0 ;
        LEDR[2] <= 1'b0 ;
        LEDR[3] <= 1'b0;
        LEDR[5] <= 1'b1;
       end	
    Initial_S:
        begin				
            LEDR[0] <= 1'b1 ;                  // LED 0 turn on
            LEDR[1] <= 1'b1 ;   
            LEDR[2] <= 1'b1 ;
            LEDR[3] <= 1'b1;
            //draw chess board and initial black/white chess
            if (done< 4'b0001)    //draw the first Black chess
                begin
                    color <=BLACK ;      
                    addr_x <=3 ;
                    addr_y <=3 ;
          	    plot <=1;
                end
            else if (done< 4'b0010)     // draw the second Black chess
                begin
                    color <=BLACK;  //RED ?
                    addr_x <= 4 ;
                    addr_y <= 4 ;
        	    plot <=1;
               end 
           else if (done < 4'b0011)      // draw the first white chess
               begin
                   color <= WHITE  ;   //WHITE ?
                   addr_x <= 4 ;
                   addr_y <= 3 ;
        	   plot <=1;
              end
          else if (done< 4'b0100)       // draw the second white chess
              begin
                  color <= WHITE ; 
                  addr_x <= 3 ;
                  addr_y <= 4 ;
                  plot <=1;
             end
        else
            begin 
        	color <= 3'b000;
        	addr_x <= 0;
        	addr_y <=0;
        	plot<=0;
           end
       end		       
    BlackMove:
        begin
            LEDR[0] <= 1'b1 ;                  // LED 0 turn on
            LEDR[1] <= 1'b0 ;
            LEDR[2] <= 1'b0 ;
            LEDR[3] <= 1'b0 ;
            color <= BLACK ; 
            plot<=0;
        end
    WhiteMove:
        begin
            LEDR[0] <= 1'b0 ;
            LEDR[1] <= 1'b1 ;               //LED 1 turn on
            LEDR[2] <= 1'b0 ;
            LEDR[3] <= 1'b0 ;
            color <= WHITE ;              //WHITE
            plot<=0;
        end
    Load: 
        begin
            xx <= {1'b0,SW[2:0]} ;      
            yy <= {1'b0,SW[6:4]} ;     
            addr_x <= {1'b0,SW[2:0]} ;
            addr_y <= {1'b0,SW[6:4]}  ;     
            plot <= 0 ;    
            LEDR[0] <= 1'b1 ;
            LEDR[1] <= 1'b1 ;
            LEDR[2] <= 1'b0 ;
            LEDR[3] <= 1'b0 ;				
        end
    Check:
        begin
                LEDR[0] <= 1'b1 ;
                LEDR[1] <= 1'b1 ;
                LEDR[2] <= 1'b1 ;
                LEDR[3] <= 1'b0 ;				 
        end 
    Draw:
      begin
        if (done < 1)    //draw original chess
          begin
            addr_x <= xx ;
            addr_y <= yy ;
            plot <= 1 ;
          end
        else if (done  < dir1 + 1)    // x-dir decrease, y no change
          begin
            addr_x <= xx - done ;
            addr_y <= yy ;
            plot <= 1 ;
          end
        else if (done < dir2 + dir1+1)  // x-direction increase, y no change 
          begin
            addr_x <= xx + done - dir1 ;
            addr_y <= yy ;
            plot <= 1 ;
          end
        else if (done  < dir3 + dir2 + dir1+1)  //y decrease, x no change
          begin
            addr_x <= xx  ;
            addr_y <= yy - done + dir2 + dir1;
            plot <= 1 ;
          end
        else if (done  < dir4 + dir3 + dir2 + dir1+1 )   // y increase, x no change
          begin
            addr_x <= xx ;
            addr_y <= yy + done - dir3 - dir2 - dir1 ;
            plot <= 1 ;
          end
        // x decrease, y decrease
        else if (done  < dir5 + dir4 + dir3 + dir2 + dir1+1 )
          begin
            addr_x <= xx - done + dir4 + dir3 + dir2 + dir1 ;
            addr_y <= yy - done + dir4 + dir3 + dir2 + dir1 ;
            plot <= 1 ;
          end
        // x increase, y increase
        else if (done  < dir6 + dir5 + dir4 + dir3 + dir2 + dir1+1)
          begin
            addr_x <= xx + done - dir5 - dir4 - dir3 - dir2 - dir1 ;
            addr_y <= yy + done - dir5 - dir4 - dir3 - dir2 - dir1 ;
            plot <= 1 ;
          end
        // x decrease, y increase
        else if (done  < dir7 + dir6 + dir5 + dir4 + dir3 + dir2 +dir1+1)
          begin
            addr_x <= xx - done + dir6 + dir5 + dir4 + dir3 + dir2 + dir1 ;
            addr_y <= yy + done - dir6 - dir5 - dir4 - dir3 - dir2 - dir1 ;
            plot <= 1 ;
          end
        // x increase, y decrease
        else if (done  < dir8 + dir7 + dir6 + dir5 + dir4 + dir3 + dir2 + dir1+1)
          begin
            addr_x <= xx + done - dir7 - dir6 - dir5 - dir4 - dir3 - dir2 - dir1 ;
            addr_y <= yy - done + dir7 + dir6 + dir5 + dir4 + dir3 + dir2 + dir1 ;
            plot <= 1 ;
          end
        else 
          begin 
        	color <= 3'b000;
        	addr_x <= 0;
        	addr_y <=0;
        	plot<=0;
          end
      end
    GameOver:
      begin
                LEDR[0] <= 1'b0 ;
                LEDR[1] <= 1'b0 ;
                LEDR[2] <= 1'b0 ;
          if (check_done[0] & check_done[1])
             begin
                if (black_win)       // if black chess = white chess, white win
                  begin
						HEX0[6:0]=7'b1001111;
						HEX1[6:0]=7'b0001100;
						HEX2[6:0]=7'b1111111;
						HEX3[6:0]=7'b0100001;
						HEX4[6:0]=7'b0101011;
						HEX5[6:0]=7'b0000110;				
 
                  end
              else
                begin
                    LEDR[0] <= 1'b0 ;
                    LEDR[1] <= 1'b1 ;
                    LEDR[2] <= 1'b1 ;
                  						
						HEX0[6:0]=7'b0100100;
						HEX1[6:0]=7'b0001100;
						HEX2[6:0]=7'b1111111;
						HEX3[6:0]=7'b0100001;
						HEX4[6:0]=7'b0101011;
						HEX5[6:0]=7'b0000110;				
 
                  
                 
                end
           end
      end         
endcase
end
endmodule


module draw_chess (clock, resetn, state, addr_x, addr_y, colorin,  plot,
                   x, y, writeEn, colorout, draw_done);

    input clock ;
    input resetn ;
    input [3:0]state ;
    input [3:0]addr_x ;
    input [3:0]addr_y ;
    input plot;
    input [2:0]colorin;

    output reg [7:0] x ;
    output reg [7:0] y ;
    output reg writeEn ;
    output reg [2:0]colorout;
    output reg [3:0] draw_done ;
   
    reg [1:0] wait_for_draw ;
    reg [6:0] draw_one_pixel ;
    reg [3:0] cntx, cnty ;
    reg [7:0] result ;



always @ (posedge clock)
begin
    if ( (state == 4'b1010 | state[1:0] == 2'b11) & plot == 1'b1)
        begin

        if (draw_one_pixel < 36)
          begin

           if (wait_for_draw < 3)
               begin
                     writeEn <= 1 ;
                     x <= {4'b0000,addr_x} * 4'b1110  + 2'b11 + cntx ;
                     y <= {4'b0000,addr_y}* 4'b1110 + 2'b11  + cnty;
                    colorout <= colorin ;      
                    wait_for_draw <= wait_for_draw + 1 ; 
               end
          else
              begin
                if (cntx < 5)
                  begin
                    cntx <= cntx + 1 ;
                    cnty <= cnty ;
                  end
                else
                  begin
                    cnty <= cnty + 1 ;
                    cntx <= 0 ;
                  end

                 wait_for_draw <= 0 ;
                 draw_one_pixel <= draw_one_pixel + 1 ;        
             end
          end
       else
           begin
             draw_done <= draw_done + 1 ;
             cntx <= 0 ;
             cnty <= 0 ;
             draw_one_pixel <= 0 ;
             wait_for_draw <= 0 ;
             writeEn <= 0;
          end
      end
    else
       begin
            writeEn <= 0;
            colorout <= colorin;
            wait_for_draw <= 0 ;
            draw_done <= 0 ;
            cntx <= 0 ;
            cnty <= 0 ;
            draw_one_pixel <= 0 ;
      end
end
endmodule

     
//===========================================================================
module validation (clock, resetn, state, addr_x, addr_y, color, data, 
    dir1,dir2, dir3, dir4, dir5, dir6, dir7, dir8, total, check_done, black_win, mem_x, mem_y, rplot) ;
input clock ;
input resetn ;
input [3:0] state ;
input [3:0] addr_x, addr_y ;
input [2:0] color ;
input [2:0] data ;
output reg [3:0] dir1, dir2, dir3, dir4, dir5, dir6, dir7,dir8 ;
output reg [3:0] total ; 
output reg [1:0] check_done ;
output reg rplot, black_win ;
output reg [3:0] mem_x, mem_y ;

parameter [3:0] ORIG=4'b0000, X_DEC=4'b0001, X_INC=4'b0010, Y_DEC=4'b0011, Y_INC=4'b0100,
                XD_YD=4'b0101, XI_YI=4'b0110, XD_YI=4'b0111, XI_YD=4'b1000, DONE=4'b1001 ;
parameter [2:0]  WHITE=3'b111, BLUE=3'b011, BLACK=3'b101, NOCOLOR=3'b000 ;


reg [3:0] direc ;
reg [4:0] skip ;
reg [5:0] count_black = 6'b0;
reg [5:0] count_white = 6'b0;

reg gameover = 1'b0 ;
reg [2:0] vcolor ;

always @ (posedge clock)
begin //always block
  case (state)
    4'b0000:   //Reset_S
      begin 
        direc <= 0 ;
        dir1 <= 0 ;
        dir2 <= 0 ;
        dir3 <= 0 ;
        dir4 <= 0 ;
        dir5 <= 0 ;
        dir6 <= 0 ;
        dir7 <= 0 ;
        dir8 <= 0 ;
        total <= 0 ;
        skip <= 0 ;
        check_done <= 0 ;
        black_win <= 0 ;
      end
    4'b0100:   //Load
      begin
        mem_x <= addr_x ;
        mem_y <= addr_y ;
        rplot <= 1 ;
        check_done <= 0 ;
        skip <= 0 ;
        direc <= 0 ;
        dir1<=0 ;
        dir2<=0 ;
        dir3 <= 0 ;
        dir4<=0 ;
        dir5<=0 ;
        dir6<= 0 ;
        dir7 <= 0 ;
        dir8 <= 0 ;
        total <= 0 ;
      end
    4'b1010: 	 //game over begin
      begin
        if (~gameover)
          begin
            mem_x <= 0 ;
            mem_y <= 0 ;
            rplot <= 1 ;
            gameover <= gameover + 1 ;
          end
        if (skip < 2)
            skip <= skip + 1 ;
        else 
          begin
            skip <= 0 ;
            if (data == BLACK)             // count number of black chess
               count_black <= count_black + 1 ;
            else if (data == WHITE)
               count_white <= count_white + 1 ;
            if (check_done[0] == 1 )
              begin
                if (count_black > count_white)
                   black_win <= 1'b1 ;   //black win
                else
                   black_win <= 1'b0 ;   //white win
               check_done[1] <= 1;
              end
           else if (mem_x < 7 )
            begin
              mem_x <= mem_x + 1 ;
              mem_y <= mem_y ;
              rplot <= 1 ;
            end
          else if (mem_y < 7 )
            begin
              mem_y <= mem_y + 1 ;
              mem_x <= 0 ;
              rplot <= 1 ;
            end
         else if (mem_x == 7 & mem_y == 7)
            begin
              mem_x <= 0 ;
              mem_y <= 0 ;
              rplot <= 1 ;
              check_done[0] <= 1 ;
            end
         end
       end
    4'b1100:         //Check
      begin
        vcolor = color ^ 3'b010 ;
        if (!check_done)
          begin
          if (skip < 2)
            begin
              skip <= skip + 1 ;
              rplot <= 1 ;
            end
          if (skip == 2)
            begin 
              skip <= 0 ;
              case (direc)
              ORIG: 
                begin
                  if (data == BLACK | data == WHITE)        //already exist chess 
                      check_done[1] <= 1 ;                        // error
                  else if (addr_x > 7 | addr_y > 7)         // invalid input value
                      check_done[1] <= 1 ;                        // error
                  else if (addr_x > 0)                      // next direction is XD
                    begin
                      direc <= X_DEC ;
                      mem_x <= addr_x - 1 ;
                      mem_y <= addr_y ;
                      rplot <= 1 ;
                    end
                 else 
                    begin                                     // next direction is XI
                      direc <= X_INC ;
                      mem_x <= addr_x +1 ;
                      mem_y <= addr_y ;
                      rplot <= 1 ;
                    end
                end
              X_DEC:
                begin
                  if (data ==  vcolor & mem_x > 0)            
                    begin
                      mem_x <= mem_x -1 ;
                      mem_y <= mem_y ;
                      rplot <= 1 ;
                    end
                  else if (data == color)
                    begin
                     dir1 = addr_x - mem_x - 1 ;
                     if (addr_x < 7 )
                       begin
                           direc <= X_INC ;
                           mem_x <= addr_x + 1 ;
                           mem_y <= addr_y ;
                           rplot <= 1 ;
                       end
                     else if (addr_y  > 0)
                       begin
                           direc <= Y_DEC ;
                           mem_x <= addr_x ;
                           mem_y <= addr_y - 1 ;
                           rplot <= 1 ;
                       end
                     else 
                       begin
                           direc <= Y_INC ;
                           mem_x <= addr_x ;
                           mem_y <= addr_y + 1 ;
                           rplot <= 1 ;
                       end
                    end
                  else
                    begin
                      dir1 = 0 ;
                      if (addr_x < 7 )
                        begin
                            direc <= X_INC ;
                            mem_x <= addr_x + 1 ;
                            mem_y <= addr_y ;
                            rplot <= 1 ;
                        end
                      else if (addr_y  > 0)
                        begin
                          direc <= Y_DEC ;
                          mem_x <= addr_x ;
                          mem_y <= addr_y - 1 ;
                          rplot <= 1 ;
                        end
                      else 
                        begin
                          direc <= Y_INC ;
                          mem_x <= addr_x ;
                          mem_y <= addr_y + 1 ;
                          rplot <= 1 ;
                        end
                    end
                end
              X_INC:
                begin
                  if (data ==  vcolor  & mem_x < 7)            
                    begin
                       mem_x <= mem_x + 1 ;
                       mem_y <= mem_y ;
                       rplot <= 1 ;
                    end
                  else if (data == color)
                    begin
                      dir2 = mem_x - addr_x - 1 ;
                      if (addr_y  > 0)
                        begin
                          direc <= Y_DEC ;
                          mem_x <= addr_x ;
                          mem_y <= addr_y - 1 ;
                          rplot <= 1 ;
                        end
                      else 
                        begin
                          direc <= Y_INC ;
                          mem_x <= addr_x ;
                          mem_y <= addr_y + 1 ;
                          rplot <= 1 ;
                        end
                    end
                  else 
                    begin
                     dir2 = 0 ;
                      if (addr_y  > 0)
                        begin
                          direc <= Y_DEC ;
                          mem_x <= addr_x ;
                          mem_y <= addr_y - 1 ;
                          rplot <= 1 ;
                        end
                      else 
                        begin
                          direc <= Y_INC ;
                          mem_x <= addr_x ;
                          mem_y <= addr_y + 1 ;
                          rplot <= 1 ;
                        end
                    end
                end
              Y_DEC:
                begin
                  if (data == vcolor  & mem_y > 0)            
                    begin
                       mem_y <= mem_y - 1 ;
                       mem_x <= mem_x ;
                       rplot <= 1 ;
                    end
                  else if (data == color)
                    begin
                      dir3 = addr_y - mem_y - 1 ;
                      if (addr_y < 7 )
                        begin
                           direc <= Y_INC ;
                           mem_y <= addr_y + 1 ;
                           mem_x <= addr_x ;
                           rplot <= 1 ;
                        end
                      else if (addr_x > 0)   // y=7
                        begin
                           direc <= XD_YD ;
                           mem_x <= addr_x - 1;
                           mem_y <= addr_y - 1 ;
                           rplot <= 1 ;
                        end
                      else               // addr_x = 0, addr_y=7
                        begin
                           direc <= XI_YD ;
                           mem_x <= addr_x + 1;
                           mem_y <= addr_y - 1 ;
                           rplot <= 1 ;
                        end
                    end
                  else 
                    begin
                      dir3 = 0 ;
                      if (addr_y < 7 )
                        begin
                           direc <= Y_INC ;
                           mem_y <= addr_y + 1 ;
                           mem_x <= addr_x ;
                           rplot <= 1 ;
                        end
                      else if (addr_x > 0)   // y=7
                        begin
                           direc <= XD_YD ;
                           mem_x <= addr_x - 1;
                           mem_y <= addr_y - 1 ;
                           rplot <= 1 ;
                        end
                      else  // addr_x = 0, addr_y=7
                        begin
                           direc <= XI_YD ;
                           mem_x <= addr_x + 1;
                           mem_y <= addr_y - 1 ;
                           rplot <= 1 ;
                        end
                    end
                end
              Y_INC:
                begin //begin of Y_INC
                  if (data == vcolor  & mem_y > 0)
                    begin
                       mem_x <= mem_x ;
                       mem_y <= mem_y + 1 ;
                       rplot <= 1 ;
                    end
                  else if (data == color)
                    begin 
                      dir4 <= mem_y - addr_y - 1 ;
                      if (addr_y > 0 & addr_x > 0)
                        begin
                           direc <= XD_YD ;
                           mem_x <= addr_x - 1;
                           mem_y <= addr_y - 1 ;
                           rplot <= 1 ;
                        end
                      else if (addr_x < 7 & addr_y < 7)  
                        begin
                           direc <= XI_YI ;
                           mem_x <= addr_x + 1;
                           mem_y <= addr_y + 1 ;
                           rplot <= 1 ;
                        end
                      else if (addr_y < 7 & addr_x > 0)
                        begin
                           direc <= XD_YI;
                           mem_x <= addr_x - 1;
                           mem_y <= addr_y + 1 ;
                           rplot <= 1 ;
                       end
                      else
                        begin
                          direc <= XI_YD ;
                          mem_x <= addr_x + 1 ;
                          mem_y <= addr_y - 1 ;
                          rplot <= 1 ;
                        end						  
                    end
                  else 
                    begin 
                      dir4 = 0 ;
                      if (addr_y > 0 & addr_x > 0)
                        begin
                           direc <= XD_YD ;
                           mem_x <= addr_x - 1;
                           mem_y <= addr_y - 1 ;
                           rplot <= 1 ;
                        end
                      else if (addr_x < 7 & addr_y < 7)
                        begin
                           direc <= XI_YI ;
                           mem_x <= addr_x + 1;
                           mem_y <= addr_y + 1 ;
                           rplot <= 1 ;
                        end
                      else if (addr_y < 7 & addr_x > 0)
                        begin
                           direc <= XD_YI ;
                           mem_x <= addr_x - 1;
                           mem_y <= addr_y + 1 ;
                           rplot <= 1 ;
                        end
                      else
                        begin
                           direc <= XI_YD ;
                           mem_x <= addr_x + 1 ;
                           mem_y <= addr_y - 1 ;
                           rplot <= 1 ;
                        end
                    end
                end //end of Y_INC
              XD_YD:
                begin
                  if (data == vcolor & mem_y > 0 & mem_x > 0)        
                    begin
                        mem_y <= mem_y - 1 ;
                        mem_x <= mem_x - 1 ;
                        rplot <= 1 ;
                    end
                  else if (data == color)
                    begin
                      dir5 = addr_y - mem_y - 1 ;
                      if (addr_x < 7 & addr_y < 7)
                        begin
                           direc <= XI_YI ;
                           mem_x <= addr_x + 1;
                           mem_y <= addr_y + 1 ;
                           rplot <= 1 ;
                        end
                      else if (addr_x > 0 & addr_y < 7)
                        begin
                           direc <= XD_YI ;
                           mem_x <= addr_x - 1;
                           mem_y <= addr_y + 1 ;
                           rplot <= 1 ;
                        end
                      else
                        begin
                           direc <= XI_YD ;
                           mem_x <= addr_x + 1;
                           mem_y <= addr_y - 1 ;
                           rplot <= 1 ;
                        end
                    end
                  else 
                    begin
                      dir5 = 0 ;
                      if (addr_x < 7 & addr_y < 7)
                        begin
                           direc <= XI_YI ;
                           mem_x <= addr_x + 1;
                           mem_y <= addr_y + 1 ;
                           rplot <= 1 ;
                        end
                      else if (addr_x > 0 & addr_y < 7)
                        begin
                           direc <= XD_YI ;
                           mem_x <= addr_x - 1;
                           mem_y <= addr_y + 1 ;
                           rplot <= 1 ;
                        end
                      else 
                        begin
                           direc <= XI_YD ;
                           mem_x <= addr_x + 1;
                           mem_y <= addr_y - 1 ;
                           rplot <= 1 ;
                        end
                    end
                end
              XI_YI:
                begin
                  if (data == vcolor  & mem_y < 7 & mem_x < 7)  
                    begin
                     mem_y <= mem_y + 1 ;
                     mem_x <= mem_x + 1 ;
                     rplot <= 1 ;
                    end
                  else if (data == color)
                    begin
                      dir6 = mem_x - addr_x - 1 ;
                      if (addr_x > 0 & addr_y < 7)
                        begin
                           direc <= XD_YI ;
                           mem_x <= addr_x - 1;
                           mem_y <= addr_y + 1 ;
                           rplot <= 1 ;
                        end
                      else if (addr_x < 7 & addr_y > 0)
                        begin
                           direc <= XI_YD;
                           mem_x <= addr_x + 1;
                           mem_y <= addr_y - 1 ;
                           rplot <= 1 ;
                         end
                      else
                         direc <= DONE ;    
                    end
                  else 
                    begin
                      dir6 <= 0 ;
                      if (addr_x > 0 & addr_y < 7)
                        begin
                           direc <= XD_YI ;
                           mem_x <= addr_x - 1;
                           mem_y <= addr_y + 1 ;
                           rplot <= 1 ;
                        end
                      else if (addr_x < 7 & addr_y > 0)
                        begin
                           direc <= XI_YD;
                           mem_x <= addr_x + 1;
                           mem_y <= addr_y - 1 ;
                           rplot <= 1 ;
                        end
                      else
                         direc <= DONE ;    
                    end
                end
              XD_YI:
                begin
                  if (data == vcolor  & mem_y < 7 & mem_x > 0)      
                    begin
                       mem_y <= mem_y + 1 ;
                       mem_x <= mem_x - 1 ;
                       rplot <= 1 ;
                    end
                  else if (data == color)
                    begin
                      dir7 <= addr_x - mem_x - 1 ;
                      if (addr_x < 7 & addr_y > 0)
                        begin
                           direc <= XI_YD ;
                           mem_x <= addr_x + 1;
                           mem_y <= addr_y - 1 ;
                           rplot <= 1 ;
                        end
                      else
                         direc <= DONE ;
                    end
                  else 
                    begin
                      dir7 = 0 ;
                      if (addr_x < 7 & addr_y > 0)
                        begin
                          direc <= XI_YD ;
                          mem_x <= addr_x + 1;
                          mem_y <= addr_y - 1 ;
                          rplot <= 1 ;
                        end
                      else
                         direc <= DONE ;
                    end                 
                end
              XI_YD: 
                begin
                  if (data == vcolor  & mem_y > 0 & mem_x < 7) 
                     begin
                       mem_y <= mem_y - 1 ;
                       mem_x <= mem_x + 1 ;
                       rplot <= 1 ;
                     end
                  else if (data == color)
                    begin
                       dir8 <= addr_y - mem_y - 1 ;
                       direc <= DONE ;
                    end
                  else 
                    begin
                       dir8 <= 0 ;
                       direc <= DONE ;
                    end
                end
              DONE: 
                begin
                  total = dir1 + dir2 + dir3 + dir4 + dir5 + dir6 + dir7 + dir8 ;
                  if (total > 0)
                    begin
                      check_done[0] <= 1 ;
                      check_done[1] <= 0 ;
                    end	
                else
                  begin
                     check_done[0] <= 0;
                    check_done[1] <= 1 ;
                  end
                end
              endcase   //end of the inner case
          end
        end  // end of if (check_done)
      end //end of 4'b1100	
    4'b0001:
      begin
        check_done <= 0 ;
        skip <= 0 ;
        total <= 0 ;
      end
    4'b0010:
      begin
        check_done <= 0 ;
        skip <= 0 ;
        total <= 0 ;
      end
  endcase
end //end of always block

endmodule

module select_addr(clock, rx, ry, rplot, wx, wy, color, wplot, 
                   address, plot, colorout) ;
    input clock ;
    input [3:0] rx, ry, wx, wy ;
    input rplot, wplot ;
    input [2:0] color ;
    output reg plot ;
    output reg [2:0] colorout ; 
    output reg [7:0] address ;

always @(posedge clock)
  begin
    if (wplot) 
      begin
        address <= {wx, wy} ;
        plot <= 1 ;
        colorout <= color ;
      end
    else
      begin
        address <= {rx, ry} ;
        plot <= 0 ;
        colorout <= 3'b000 ;
      end
  end

endmodule
    


module  my_ram64 (address,clock, color, writeEn, rw_switch, data) ;
input [7:0]address ;
input clock ;
input [2:0] color ;
input writeEn, rw_switch  ;
output reg [2:0] data  ;

reg [2:0] c00, c01, c02, c03, c04, c05, c06, c07 ;
reg [2:0] c10, c11, c12, c13, c14, c15, c16, c17 ;
reg [2:0] c20, c21, c22, c23, c24, c25, c26, c27 ;
reg [2:0] c30, c31, c32, c33, c34, c35, c36, c37 ;
reg [2:0] c40, c41, c42, c43, c44, c45, c46, c47 ;
reg [2:0] c50, c51, c52, c53, c54, c55, c56, c57 ;
reg [2:0] c60, c61, c62, c63, c64, c65, c66, c67 ;
reg [2:0] c70, c71, c72, c73, c74, c75, c76, c77 ;


always @ (posedge clock)
begin
    if (writeEn == 1 & rw_switch)
      begin
         case(address)
         8'h00:
            c00 <= color ;
         8'h01:
            c01 <= color ;
         8'h02:
            c02 <= color ;
         8'h03:
            c03 <= color ;
         8'h04:
            c04 <= color ;
         8'h05:
            c05 <= color ;
         8'h06:
            c06 <= color ;
         8'h07:
            c07 <= color ;
         8'h10:
            c10 <= color ;
         8'h11:
            c11 <= color ;
         8'h12:
            c12 <= color ;
         8'h13:
            c13 <= color ;
         8'h14:
            c14 <= color ;
         8'h15:
            c15 <= color ;
         8'h16:
            c16 <= color ;
         8'h17:
            c17 <= color ;
         8'h20:
            c20 <= color ;
         8'h21:
            c21 <= color ;
         8'h22:
            c22 <= color ;
         8'h23:
            c23 <= color ;
         8'h24:
            c24 <= color ;
         8'h25:
            c25 <= color ;
         8'h26:
            c26 <= color ;
         8'h27:
            c27 <= color ;
         8'h30:
            c30<=color ;
         8'h31:
            c31<=color ;
         8'h32:
            c32<=color ;
         8'h33:
            c33<=color ;
         8'h34:
            c34<=color ;
         8'h35:
            c35<=color ;
         8'h36:
            c36<=color ;
         8'h37:
            c37<=color ;
         8'h40:
            c40<=color ;
         8'h41:
            c41<=color ;
         8'h42:
            c42<=color ;
         8'h43:
            c43<=color ;
         8'h44:
            c44 <= color ;
        8'h45:
            c45 <=color ;
         8'h46:
             c46<= color ;
         8'h47:
             c47 <= color ;
         8'h50:
            c50<=color ;
         8'h51:
            c51<=color ;
         8'h52:
            c52<=color ;
         8'h53:
            c53<=color ;
         8'h54:
            c54 <= color ;
        8'h55:
            c55 <=color ;
         8'h56:
             c56<= color ;
         8'h57:
             c57 <= color ;
         8'h60:
            c60<=color ;
         8'h61:
            c61<=color ;
         8'h62:
            c62<=color ;
         8'h63:
            c63<=color ;
         8'h64:
            c64 <= color ;
        8'h65:
            c65 <=color ;
         8'h66:
             c66<= color ;
         8'h67:
             c67 <= color ;
        8'h70:
            c70<=color ;
         8'h71:
            c71<=color ;
         8'h72:
            c72<=color ;
         8'h73:
            c73<=color ;
         8'h74:
            c74 <= color ;
        8'h75:
            c75 <=color ;
         8'h76:
             c76<= color ;
         8'h77:
             c77 <= color ;
        endcase
     end
   else 
     begin
       case(address)
       8'h00:
           data <= c00 ;
       8'h01:
           data <= c01 ;
       8'h02:
           data <= c02 ;
       8'h03:
           data <= c03 ;
       8'h04:
           data <= c04 ;
       8'h05:
           data <= c05 ;
       8'h06:
           data <= c06 ;
       8'h07:
           data <= c07 ;
       8'h10:
           data <= c10 ;
       8'h11:
           data <= c11 ;
       8'h12:
           data <= c12 ;
       8'h13:
           data <= c13 ;
       8'h14:
           data <= c14 ;
       8'h15:
           data <= c15 ;
       8'h16:
           data <= c16 ;
       8'h17:
           data <= c17 ;
       8'h20:
           data <= c20 ;
       8'h21:
           data <= c21 ;
       8'h22:
           data <= c22 ;
       8'h23:
           data <= c23 ;
       8'h24:
           data <= c24 ;
       8'h25:
           data <= c25 ;
       8'h26:
           data <= c26 ;
       8'h27:
           data <= c27 ;
       8'h30:
         data <=c30 ;
       8'h31:
         data <=c31 ;
       8'h32:
         data <=c32 ;
       8'h33:
         data <=c33 ;
       8'h34:
         data <=c34 ;
       8'h35:
         data <=c35 ;
       8'h36:
         data <=c36 ;
       8'h37:
         data <=c37 ;
      8'h40:
         data <=c40 ;
       8'h41:
         data <=c41 ;
      8'h42:
         data <=c42 ;
       8'h43:
         data <=c43 ;
      8'h44:
         data <=c44 ;
       8'h45:
         data <=c45 ;
      8'h46:
         data <=c46 ;
       8'h47:
         data <=c47 ;
       8'h50:
           data <= c50 ;
       8'h51:
           data <= c51 ;
       8'h52:
           data <= c52 ;
       8'h53:
           data <= c53 ;
       8'h54:
           data <= c54 ;
       8'h55:
           data <= c55 ;
       8'h56:
           data <= c56 ;
       8'h57:
           data <= c57 ;
       8'h60:
           data <= c60 ;
       8'h61:
           data <= c61 ;
       8'h62:
           data <= c62 ;
       8'h63:
           data <= c63 ;
       8'h64:
           data <= c64 ;
       8'h65:
           data <= c65 ;
       8'h66:
           data <= c66 ;
       8'h67:
           data <= c67 ;
       8'h70:
           data <= c70 ;
       8'h71:
           data <= c71 ;
       8'h72:
           data <= c72 ;
       8'h73:
           data <= c73 ;
       8'h74:
           data <= c74 ;
       8'h75:
           data <= c75 ;
       8'h76:
           data <= c76 ;
       8'h77:
           data <= c77 ;
      default:
         data <= 0 ;
      endcase

    end
end
endmodule


//----------------------------------------VGA-----------------------------------------------

/* VGA Adapter
 * ----------------
 *
 * This is an implementation of a VGA Adapter. The adapter uses VGA mode signalling to initiate
 * a 640x480 resolution mode on a computer monitor, with a refresh rate of approximately 60Hz.
 * It is designed for easy use in an early digital logic design course to facilitate student
 * projects on the Altera DE2 Educational board.
 *
 * This implementation of the VGA adapter can display images of varying colour depth at a resolution of
 * 320x240 or 160x120 superpixels. The concept of superpixels is introduced to reduce the amount of on-chip
 * memory used by the adapter. The following table shows the number of bits of on-chip memory used by
 * the adapter in various resolutions and colour depths.
 * 
 * -------------------------------------------------------------------------------------------------------------------------------
 * Resolution | Mono    | 8 colours | 64 colours | 512 colours | 4096 colours | 32768 colours | 262144 colours | 2097152 colours |
 * -------------------------------------------------------------------------------------------------------------------------------
 * 160x120    |   19200 |     57600 |     115200 |      172800 |       230400 |        288000 |         345600 |          403200 |
 * 320x240    |   78600 |    230400 | ############## Does not fit ############################################################## |
 * -------------------------------------------------------------------------------------------------------------------------------
 *
 * By default the adapter works at the resolution of 320x240 with 8 colours. To set the adapter in any of
 * the other modes, the adapter must be instantiated with specific parameters. These parameters are:
 * - RESOLUTION - a string that should be either "320x240" or "160x120".
 * - MONOCHROME - a string that should be "TRUE" if you only want black and white colours, and "FALSE"
 *                otherwise.
 * - BITS_PER_COLOUR_CHANNEL  - an integer specifying how many bits are available to describe each colour
 *                          (R,G,B). A default value of 1 indicates that 1 bit will be used for red
 *                          channel, 1 for green channel and 1 for blue channel. This allows 8 colours
 *                          to be used.
 * 
 * In addition to the above parameters, a BACKGROUND_IMAGE parameter can be specified. The parameter
 * refers to a memory initilization file (MIF) which contains the initial contents of video memory.
 * By specifying the initial contents of the memory we can force the adapter to initially display an
 * image of our choice. Please note that the image described by the BACKGROUND_IMAGE file will only
 * be valid right after your program the DE2 board. If your circuit draws a single pixel on the screen,
 * the video memory will be altered and screen contents will be changed. In order to restore the background
 * image your circuti will have to redraw the background image pixel by pixel, or you will have to
 * reprogram the DE2 board, thus allowing the video memory to be rewritten.
 *
 * To use the module connect the vga_adapter to your circuit. Your circuit should produce a value for
 * inputs X, Y and plot. When plot is high, at the next positive edge of the input clock the vga_adapter
 * will change the contents of the video memory for the pixel at location (X,Y). At the next redraw
 * cycle the VGA controller will update the contants of the screen by reading the video memory and copying
 * it over to the screen. Since the monitor screen has no memory, the VGA controller has to copy the
 * contents of the video memory to the screen once every 60th of a second to keep the image stable. Thus,
 * the video memory should not be used for other purposes as it may interfere with the operation of the
 * VGA Adapter.
 *
 * As a final note, ensure that the following conditions are met when using this module:
 * 1. You are implementing the the VGA Adapter on the Altera DE2 board. Using another board may change
 *    the amount of memory you can use, the clock generation mechanism, as well as pin assignments required
 *    to properly drive the VGA digital-to-analog converter.
 * 2. Outputs VGA_* should exist in your top level design. They should be assigned pin locations on the
 *    Altera DE2 board as specified by the DE2_pin_assignments.csv file.
 * 3. The input clock must have a frequency of 50 MHz with a 50% duty cycle. On the Altera DE2 board
 *    PIN_N2 is the source for the 50MHz clock.
 *
 * During compilation with Quartus II you may receive the following warnings:
 * - Warning: Variable or input pin "clocken1" is defined but never used
 * - Warning: Pin "VGA_SYNC" stuck at VCC
 * - Warning: Found xx output pins without output pin load capacitance assignment
 * These warnings can be ignored. The first warning is generated, because the software generated
 * memory module contains an input called "clocken1" and it does not drive logic. The second warning
 * indicates that the VGA_SYNC signal is always high. This is intentional. The final warning is
 * generated for the purposes of power analysis. It will persist unless the output pins are assigned
 * output capacitance. Leaving the capacitance values at 0 pf did not affect the operation of the module.
 *
 * If you see any other warnings relating to the vga_adapter, be sure to examine them carefully. They may
 * cause your circuit to malfunction.
 *
 * NOTES/REVISIONS:
 * July 10, 2007 - Modified the original version of the VGA Adapter written by Sam Vafaee in 2006. The module
 *		   now supports 2 different resolutions as well as uses half the memory compared to prior
 *		   implementation. Also, all settings for the module can be specified from the point
 *		   of instantiation, rather than by modifying the source code. (Tomasz S. Czajkowski)
 */

module vga_adapter(
			resetn,
			clock,
			colour,
			x, y, plot,
			/* Signals for the DAC to drive the monitor. */
			VGA_R,
			VGA_G,
			VGA_B,
			VGA_HS,
			VGA_VS,
			VGA_BLANK,
			VGA_SYNC,
			VGA_CLK);
 
	parameter BITS_PER_COLOUR_CHANNEL = 1;
	/* The number of bits per colour channel used to represent the colour of each pixel. A value
	 * of 1 means that Red, Green and Blue colour channels will use 1 bit each to represent the intensity
	 * of the respective colour channel. For BITS_PER_COLOUR_CHANNEL=1, the adapter can display 8 colours.
	 * In general, the adapter is able to use 2^(3*BITS_PER_COLOUR_CHANNEL ) colours. The number of colours is
	 * limited by the screen resolution and the amount of on-chip memory available on the target device.
	 */	
	
	parameter MONOCHROME = "FALSE";
	/* Set this parameter to "TRUE" if you only wish to use black and white colours. Doing so will reduce
	 * the amount of memory you will use by a factor of 3. */
	
	parameter RESOLUTION = "320x240";
	/* Set this parameter to "160x120" or "320x240". It will cause the VGA adapter to draw each dot on
	 * the screen by using a block of 4x4 pixels ("160x120" resolution) or 2x2 pixels ("320x240" resolution).
	 * It effectively reduces the screen resolution to an integer fraction of 640x480. It was necessary
	 * to reduce the resolution for the Video Memory to fit within the on-chip memory limits.
	 */
	
	parameter BACKGROUND_IMAGE = "background.colour.mif";
	/* The initial screen displayed when the circuit is first programmed onto the DE2 board can be
	 * defined useing an MIF file. The file contains the initial colour for each pixel on the screen
	 * and is placed in the Video Memory (VideoMemory module) upon programming. Note that resetting the
	 * VGA Adapter will not cause the Video Memory to revert to the specified image. */


	/*****************************************************************************/
	/* Declare inputs and outputs.                                               */
	/*****************************************************************************/
	input resetn;
	input clock;
	
	/* The colour input can be either 1 bit or 3*BITS_PER_COLOUR_CHANNEL bits wide, depending on
	 * the setting of the MONOCHROME parameter.
	 */
	input [((MONOCHROME == "TRUE") ? (0) : (BITS_PER_COLOUR_CHANNEL*3-1)):0] colour;
	
	/* Specify the number of bits required to represent an (X,Y) coordinate on the screen for
	 * a given resolution.
	 */
	input [((RESOLUTION == "320x240") ? (8) : (7)):0] x; 
	input [((RESOLUTION == "320x240") ? (7) : (6)):0] y;
	
	/* When plot is high then at the next positive edge of the clock the pixel at (x,y) will change to
	 * a new colour, defined by the value of the colour input.
	 */
	input plot;
	
	/* These outputs drive the VGA display. The VGA_CLK is also used to clock the FSM responsible for
	 * controlling the data transferred to the DAC driving the monitor. */
	output [9:0] VGA_R;
	output [9:0] VGA_G;
	output [9:0] VGA_B;
	output VGA_HS;
	output VGA_VS;
	output VGA_BLANK;
	output VGA_SYNC;
	output VGA_CLK;

	/*****************************************************************************/
	/* Declare local signals here.                                               */
	/*****************************************************************************/
	
	wire valid_160x120;
	wire valid_320x240;
	/* Set to 1 if the specified coordinates are in a valid range for a given resolution.*/
	
	wire writeEn;
	/* This is a local signal that allows the Video Memory contents to be changed.
	 * It depends on the screen resolution, the values of X and Y inputs, as well as 
	 * the state of the plot signal.
	 */
	
	wire [((MONOCHROME == "TRUE") ? (0) : (BITS_PER_COLOUR_CHANNEL*3-1)):0] to_ctrl_colour;
	/* Pixel colour read by the VGA controller */
	
	wire [((RESOLUTION == "320x240") ? (16) : (14)):0] user_to_video_memory_addr;
	/* This bus specifies the address in memory the user must write
	 * data to in order for the pixel intended to appear at location (X,Y) to be displayed
	 * at the correct location on the screen.
	 */
	
	wire [((RESOLUTION == "320x240") ? (16) : (14)):0] controller_to_video_memory_addr;
	/* This bus specifies the address in memory the vga controller must read data from
	 * in order to determine the colour of a pixel located at coordinate (X,Y) of the screen.
	 */
	
	wire clock_25;
	/* 25MHz clock generated by dividing the input clock frequency by 2. */
	
	wire vcc, gnd;
	
	/*****************************************************************************/
	/* Instances of modules for the VGA adapter.                                 */
	/*****************************************************************************/	
	assign vcc = 1'b1;
	assign gnd = 1'b0;
	
	vga_address_translator user_input_translator(
					.x(x), .y(y), .mem_address(user_to_video_memory_addr) );
		defparam user_input_translator.RESOLUTION = RESOLUTION;
	/* Convert user coordinates into a memory address. */

	assign valid_160x120 = (({1'b0, x} >= 0) & ({1'b0, x} < 160) & ({1'b0, y} >= 0) & ({1'b0, y} < 120)) & (RESOLUTION == "160x120");
	assign valid_320x240 = (({1'b0, x} >= 0) & ({1'b0, x} < 320) & ({1'b0, y} >= 0) & ({1'b0, y} < 240)) & (RESOLUTION == "320x240");
	assign writeEn = (plot) & (valid_160x120 | valid_320x240);
	/* Allow the user to plot a pixel if and only if the (X,Y) coordinates supplied are in a valid range. */
	
	/* Create video memory. */
	altsyncram	VideoMemory (
				.wren_a (writeEn),
				.wren_b (gnd),
				.clock0 (clock), // write clock
				.clock1 (clock_25), // read clock
				.clocken0 (vcc), // write enable clock
				.clocken1 (vcc), // read enable clock				
				.address_a (user_to_video_memory_addr),
				.address_b (controller_to_video_memory_addr),
				.data_a (colour), // data in
				.q_b (to_ctrl_colour)	// data out
				);
	defparam
		VideoMemory.WIDTH_A = ((MONOCHROME == "FALSE") ? (BITS_PER_COLOUR_CHANNEL*3) : 1),
		VideoMemory.WIDTH_B = ((MONOCHROME == "FALSE") ? (BITS_PER_COLOUR_CHANNEL*3) : 1),
		VideoMemory.INTENDED_DEVICE_FAMILY = "Cyclone II",
		VideoMemory.OPERATION_MODE = "DUAL_PORT",
		VideoMemory.WIDTHAD_A = ((RESOLUTION == "320x240") ? (17) : (15)),
		VideoMemory.NUMWORDS_A = ((RESOLUTION == "320x240") ? (76800) : (19200)),
		VideoMemory.WIDTHAD_B = ((RESOLUTION == "320x240") ? (17) : (15)),
		VideoMemory.NUMWORDS_B = ((RESOLUTION == "320x240") ? (76800) : (19200)),
		VideoMemory.OUTDATA_REG_B = "CLOCK1",
		VideoMemory.ADDRESS_REG_B = "CLOCK1",
		VideoMemory.CLOCK_ENABLE_INPUT_A = "BYPASS",
		VideoMemory.CLOCK_ENABLE_INPUT_B = "BYPASS",
		VideoMemory.CLOCK_ENABLE_OUTPUT_B = "BYPASS",
		VideoMemory.POWER_UP_UNINITIALIZED = "FALSE",
		VideoMemory.INIT_FILE = BACKGROUND_IMAGE;
		
	vga_pll mypll(clock, clock_25);
	/* This module generates a clock with half the frequency of the input clock.
	 * For the VGA adapter to operate correctly the clock signal 'clock' must be
	 * a 50MHz clock. The derived clock, which will then operate at 25MHz, is
	 * required to set the monitor into the 640x480@60Hz display mode (also known as
	 * the VGA mode).
	 */
	
	vga_controller controller(
			.vga_clock(clock_25),
			.resetn(resetn),
			.pixel_colour(to_ctrl_colour),
			.memory_address(controller_to_video_memory_addr), 
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK),
			.VGA_SYNC(VGA_SYNC),
			.VGA_CLK(VGA_CLK)				
		);
		defparam controller.BITS_PER_COLOUR_CHANNEL  = BITS_PER_COLOUR_CHANNEL ;
		defparam controller.MONOCHROME = MONOCHROME;
		defparam controller.RESOLUTION = RESOLUTION;

endmodule
	
	
/* This module implements the VGA controller. It assumes a 25MHz clock is supplied as input.
 *
 * General approach:
 * Go through each line of the screen and read the colour each pixel on that line should have from
 * the Video memory. To do that for each (x,y) pixel on the screen convert (x,y) coordinate to
 * a memory_address at which the pixel colour is stored in Video memory. Once the pixel colour is
 * read from video memory its brightness is first increased before it is forwarded to the VGA DAC.
 */
module vga_controller(	vga_clock, resetn, pixel_colour, memory_address, 
		VGA_R, VGA_G, VGA_B,
		VGA_HS, VGA_VS, VGA_BLANK,
		VGA_SYNC, VGA_CLK);
	
	/* Screen resolution and colour depth parameters. */
	
	parameter BITS_PER_COLOUR_CHANNEL = 1;
	/* The number of bits per colour channel used to represent the colour of each pixel. A value
	 * of 1 means that Red, Green and Blue colour channels will use 1 bit each to represent the intensity
	 * of the respective colour channel. For BITS_PER_COLOUR_CHANNEL=1, the adapter can display 8 colours.
	 * In general, the adapter is able to use 2^(3*BITS_PER_COLOUR_CHANNEL) colours. The number of colours is
	 * limited by the screen resolution and the amount of on-chip memory available on the target device.
	 */	
	
	parameter MONOCHROME = "FALSE";
	/* Set this parameter to "TRUE" if you only wish to use black and white colours. Doing so will reduce
	 * the amount of memory you will use by a factor of 3. */
	
	parameter RESOLUTION = "320x240";
	/* Set this parameter to "160x120" or "320x240". It will cause the VGA adapter to draw each dot on
	 * the screen by using a block of 4x4 pixels ("160x120" resolution) or 2x2 pixels ("320x240" resolution).
	 * It effectively reduces the screen resolution to an integer fraction of 640x480. It was necessary
	 * to reduce the resolution for the Video Memory to fit within the on-chip memory limits.
	 */
	
	//--- Timing parameters.
	/* Recall that the VGA specification requires a few more rows and columns are drawn
	 * when refreshing the screen than are actually present on the screen. This is necessary to
	 * generate the vertical and the horizontal syncronization signals. If you wish to use a
	 * display mode other than 640x480 you will need to modify the parameters below as well
	 * as change the frequency of the clock driving the monitor (VGA_CLK).
	 */
	parameter C_VERT_NUM_PIXELS  = 10'd480;
	parameter C_VERT_SYNC_START  = 10'd493;
	parameter C_VERT_SYNC_END    = 10'd494; //(C_VERT_SYNC_START + 2 - 1); 
	parameter C_VERT_TOTAL_COUNT = 10'd525;

	parameter C_HORZ_NUM_PIXELS  = 10'd640;
	parameter C_HORZ_SYNC_START  = 10'd659;
	parameter C_HORZ_SYNC_END    = 10'd754; //(C_HORZ_SYNC_START + 96 - 1); 
	parameter C_HORZ_TOTAL_COUNT = 10'd800;	
		
	/*****************************************************************************/
	/* Declare inputs and outputs.                                               */
	/*****************************************************************************/
	
	input vga_clock, resetn;
	input [((MONOCHROME == "TRUE") ? (0) : (BITS_PER_COLOUR_CHANNEL*3-1)):0] pixel_colour;
	output [((RESOLUTION == "320x240") ? (16) : (14)):0] memory_address;
	output reg [9:0] VGA_R;
	output reg [9:0] VGA_G;
	output reg [9:0] VGA_B;
	output reg VGA_HS;
	output reg VGA_VS;
	output reg VGA_BLANK;
	output VGA_SYNC, VGA_CLK;
	
	/*****************************************************************************/
	/* Local Signals.                                                            */
	/*****************************************************************************/
	
	reg VGA_HS1;
	reg VGA_VS1;
	reg VGA_BLANK1; 
	reg [9:0] xCounter, yCounter;
	wire xCounter_clear;
	wire yCounter_clear;
	wire vcc;
	
	reg [((RESOLUTION == "320x240") ? (8) : (7)):0] x; 
	reg [((RESOLUTION == "320x240") ? (7) : (6)):0] y;	
	/* Inputs to the converter. */
	
	/*****************************************************************************/
	/* Controller implementation.                                                */
	/*****************************************************************************/

	assign vcc =1'b1;
	
	/* A counter to scan through a horizontal line. */
	always @(posedge vga_clock or negedge resetn)
	begin
		if (!resetn)
			xCounter <= 10'd0;
		else if (xCounter_clear)
			xCounter <= 10'd0;
		else
		begin
			xCounter <= xCounter + 1'b1;
		end
	end
	assign xCounter_clear = (xCounter == (C_HORZ_TOTAL_COUNT-1));

	/* A counter to scan vertically, indicating the row currently being drawn. */
	always @(posedge vga_clock or negedge resetn)
	begin
		if (!resetn)
			yCounter <= 10'd0;
		else if (xCounter_clear && yCounter_clear)
			yCounter <= 10'd0;
		else if (xCounter_clear)		//Increment when x counter resets
			yCounter <= yCounter + 1'b1;
	end
	assign yCounter_clear = (yCounter == (C_VERT_TOTAL_COUNT-1)); 
	
	/* Convert the xCounter/yCounter location from screen pixels (640x480) to our
	 * local dots (320x240 or 160x120). Here we effectively divide x/y coordinate by 2 or 4,
	 * depending on the resolution. */
	always @(*)
	begin
		if (RESOLUTION == "320x240")
		begin
			x = xCounter[9:1];
			y = yCounter[8:1];
		end
		else
		begin
			x = xCounter[9:2];
			y = yCounter[8:2];
		end
	end
	
	/* Change the (x,y) coordinate into a memory address. */
	vga_address_translator controller_translator(
					.x(x), .y(y), .mem_address(memory_address) );
		defparam controller_translator.RESOLUTION = RESOLUTION;


	/* Generate the vertical and horizontal synchronization pulses. */
	always @(posedge vga_clock)
	begin
		//- Sync Generator (ACTIVE LOW)
		VGA_HS1 <= ~((xCounter >= C_HORZ_SYNC_START) && (xCounter <= C_HORZ_SYNC_END));
		VGA_VS1 <= ~((yCounter >= C_VERT_SYNC_START) && (yCounter <= C_VERT_SYNC_END));
		
		//- Current X and Y is valid pixel range
		VGA_BLANK1 <= ((xCounter < C_HORZ_NUM_PIXELS) && (yCounter < C_VERT_NUM_PIXELS));	
	
		//- Add 1 cycle delay
		VGA_HS <= VGA_HS1;
		VGA_VS <= VGA_VS1;
		VGA_BLANK <= VGA_BLANK1;	
	end
	
	/* VGA sync should be 1 at all times. */
	assign VGA_SYNC_N= vcc;
	
	/* Generate the VGA clock signal. */
	assign VGA_CLK = vga_clock;
	
	/* Brighten the colour output. */
	// The colour input is first processed to brighten the image a little. Setting the top
	// bits to correspond to the R,G,B colour makes the image a bit dull. To brighten the image,
	// each bit of the colour is replicated through the 10 DAC colour input bits. For example,
	// when BITS_PER_COLOUR_CHANNEL is 2 and the red component is set to 2'b10, then the
	// VGA_R input to the DAC will be set to 10'b1010101010.
	
	integer index;
	integer sub_index;
	
	always @(pixel_colour)
	begin		
		VGA_R <= 'b0;
		VGA_G <= 'b0;
		VGA_B <= 'b0;
		if (MONOCHROME == "FALSE")
		begin
			for (index = 10-BITS_PER_COLOUR_CHANNEL; index >= 0; index = index - BITS_PER_COLOUR_CHANNEL)
			begin
				for (sub_index = BITS_PER_COLOUR_CHANNEL - 1; sub_index >= 0; sub_index = sub_index - 1)
				begin
					VGA_R[sub_index+index] <= pixel_colour[sub_index + BITS_PER_COLOUR_CHANNEL*2];
					VGA_G[sub_index+index] <= pixel_colour[sub_index + BITS_PER_COLOUR_CHANNEL];
					VGA_B[sub_index+index] <= pixel_colour[sub_index];
				end
			end	
		end
		else
		begin
			for (index = 0; index < 10; index = index + 1)
			begin
				VGA_R[index] <= pixel_colour[0:0];
				VGA_G[index] <= pixel_colour[0:0];
				VGA_B[index] <= pixel_colour[0:0];
			end	
		end
	end

endmodule


/* This module converts a user specified coordinates into a memory address.
 * The output of the module depends on the resolution set by the user.
 */
module vga_address_translator(x, y, mem_address);

	parameter RESOLUTION = "320x240";
	/* Set this parameter to "160x120" or "320x240". It will cause the VGA adapter to draw each dot on
	 * the screen by using a block of 4x4 pixels ("160x120" resolution) or 2x2 pixels ("320x240" resolution).
	 * It effectively reduces the screen resolution to an integer fraction of 640x480. It was necessary
	 * to reduce the resolution for the Video Memory to fit within the on-chip memory limits.
	 */

	input [((RESOLUTION == "320x240") ? (8) : (7)):0] x; 
	input [((RESOLUTION == "320x240") ? (7) : (6)):0] y;	
	output reg [((RESOLUTION == "320x240") ? (16) : (14)):0] mem_address;
	
	/* The basic formula is address = y*WIDTH + x;
	 * For 320x240 resolution we can write 320 as (256 + 64). Memory address becomes
	 * (y*256) + (y*64) + x;
	 * This simplifies multiplication a simple shift and add operation.
	 * A leading 0 bit is added to each operand to ensure that they are treated as unsigned
	 * inputs. By default the use a '+' operator will generate a signed adder.
	 * Similarly, for 160x120 resolution we write 160 as 128+32.
	 */
	wire [16:0] res_320x240 = ({1'b0, y, 8'd0} + {1'b0, y, 6'd0} + {1'b0, x});
	wire [15:0] res_160x120 = ({1'b0, y, 7'd0} + {1'b0, y, 5'd0} + {1'b0, x});
	
	always @(*)
	begin
		if (RESOLUTION == "320x240")
			mem_address = res_320x240;
		else
			mem_address = res_160x120[14:0];
	end
endmodule


// megafunction wizard: %ALTPLL%
// GENERATION: STANDARD
// VERSION: WM1.0
// MODULE: altpll 

// ============================================================
// File Name: VgaPll.v
// Megafunction Name(s):
// 			altpll
// ============================================================
// ************************************************************
// THIS IS A WIZARD-GENERATED FILE. DO NOT EDIT THIS FILE!
//
// 5.0 Build 168 06/22/2005 SP 1 SJ Full Version
// ************************************************************


//Copyright (C) 1991-2005 Altera Corporation
//Your use of Altera Corporation's design tools, logic functions 
//and other software and tools, and its AMPP partner logic       
//functions, and any output files any of the foregoing           
//(including device programming or simulation files), and any    
//associated documentation or information are expressly subject  
//to the terms and conditions of the Altera Program License      
//Subscription Agreement, Altera MegaCore Function License       
//Agreement, or other applicable license agreement, including,   
//without limitation, that your use is for the sole purpose of   
//programming logic devices manufactured by Altera and sold by   
//Altera or its authorized distributors.  Please refer to the    
//applicable agreement for further details.


// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module vga_pll (
	clock_in,
	clock_out);

	input	  clock_in;
	output	  clock_out;

	wire [5:0] clock_output_bus;
	wire [1:0] clock_input_bus;
	wire gnd;
	
	assign gnd = 1'b0;
	assign clock_input_bus = { gnd, clock_in }; 

	altpll	altpll_component (
				.inclk (clock_input_bus),
				.clk (clock_output_bus)
				);
	defparam
		altpll_component.operation_mode = "NORMAL",
		altpll_component.intended_device_family = "Cyclone II",
		altpll_component.lpm_type = "altpll",
		altpll_component.pll_type = "FAST",
		/* Specify the input clock to be a 50MHz clock. A 50 MHz clock is present
		 * on PIN_N2 on the DE2 board. We need to specify the input clock frequency
		 * in order to set up the PLL correctly. To do this we must put the input clock
		 * period measured in picoseconds in the inclk0_input_frequency parameter.
		 * 1/(20000 ps) = 0.5 * 10^(5) Hz = 50 * 10^(6) Hz = 50 MHz. */
		altpll_component.inclk0_input_frequency = 20000,
		altpll_component.primary_clock = "INCLK0",
		/* Specify output clock parameters. The output clock should have a
		 * frequency of 25 MHz, with 50% duty cycle. */
		altpll_component.compensate_clock = "CLK0",
		altpll_component.clk0_phase_shift = "0",
		altpll_component.clk0_divide_by = 2,
		altpll_component.clk0_multiply_by = 1,		
		altpll_component.clk0_duty_cycle = 50;
		
	assign clock_out = clock_output_bus[0];

endmodule

// ============================================================
// CNX file retrieval info
// ============================================================
// Retrieval info: PRIVATE: MIRROR_CLK0 STRING "0"
// Retrieval info: PRIVATE: PHASE_SHIFT_UNIT0 STRING "deg"
// Retrieval info: PRIVATE: OUTPUT_FREQ_UNIT0 STRING "MHz"
// Retrieval info: PRIVATE: INCLK1_FREQ_UNIT_COMBO STRING "MHz"
// Retrieval info: PRIVATE: SPREAD_USE STRING "0"
// Retrieval info: PRIVATE: SPREAD_FEATURE_ENABLED STRING "0"
// Retrieval info: PRIVATE: GLOCKED_COUNTER_EDIT_CHANGED STRING "1"
// Retrieval info: PRIVATE: GLOCK_COUNTER_EDIT NUMERIC "1048575"
// Retrieval info: PRIVATE: SRC_SYNCH_COMP_RADIO STRING "0"
// Retrieval info: PRIVATE: DUTY_CYCLE0 STRING "50.00000000"
// Retrieval info: PRIVATE: PHASE_SHIFT0 STRING "0.00000000"
// Retrieval info: PRIVATE: MULT_FACTOR0 NUMERIC "1"
// Retrieval info: PRIVATE: OUTPUT_FREQ_MODE0 STRING "1"
// Retrieval info: PRIVATE: SPREAD_PERCENT STRING "0.500"
// Retrieval info: PRIVATE: LOCKED_OUTPUT_CHECK STRING "0"
// Retrieval info: PRIVATE: PLL_ARESET_CHECK STRING "0"
// Retrieval info: PRIVATE: STICKY_CLK0 STRING "1"
// Retrieval info: PRIVATE: BANDWIDTH STRING "1.000"
// Retrieval info: PRIVATE: BANDWIDTH_USE_CUSTOM STRING "0"
// Retrieval info: PRIVATE: DEVICE_SPEED_GRADE STRING "Any"
// Retrieval info: PRIVATE: SPREAD_FREQ STRING "50.000"
// Retrieval info: PRIVATE: BANDWIDTH_FEATURE_ENABLED STRING "0"
// Retrieval info: PRIVATE: LONG_SCAN_RADIO STRING "1"
// Retrieval info: PRIVATE: PLL_ENHPLL_CHECK NUMERIC "0"
// Retrieval info: PRIVATE: LVDS_MODE_DATA_RATE_DIRTY NUMERIC "0"
// Retrieval info: PRIVATE: USE_CLK0 STRING "1"
// Retrieval info: PRIVATE: INCLK1_FREQ_EDIT_CHANGED STRING "1"
// Retrieval info: PRIVATE: SCAN_FEATURE_ENABLED STRING "0"
// Retrieval info: PRIVATE: ZERO_DELAY_RADIO STRING "0"
// Retrieval info: PRIVATE: PLL_PFDENA_CHECK STRING "0"
// Retrieval info: PRIVATE: CREATE_CLKBAD_CHECK STRING "0"
// Retrieval info: PRIVATE: INCLK1_FREQ_EDIT STRING "50.000"
// Retrieval info: PRIVATE: CUR_DEDICATED_CLK STRING "c0"
// Retrieval info: PRIVATE: PLL_FASTPLL_CHECK NUMERIC "0"
// Retrieval info: PRIVATE: ACTIVECLK_CHECK STRING "0"
// Retrieval info: PRIVATE: BANDWIDTH_FREQ_UNIT STRING "MHz"
// Retrieval info: PRIVATE: INCLK0_FREQ_UNIT_COMBO STRING "MHz"
// Retrieval info: PRIVATE: GLOCKED_MODE_CHECK STRING "0"
// Retrieval info: PRIVATE: NORMAL_MODE_RADIO STRING "1"
// Retrieval info: PRIVATE: CUR_FBIN_CLK STRING "e0"
// Retrieval info: PRIVATE: DIV_FACTOR0 NUMERIC "1"
// Retrieval info: PRIVATE: INCLK1_FREQ_UNIT_CHANGED STRING "1"
// Retrieval info: PRIVATE: HAS_MANUAL_SWITCHOVER STRING "1"
// Retrieval info: PRIVATE: EXT_FEEDBACK_RADIO STRING "0"
// Retrieval info: PRIVATE: PLL_AUTOPLL_CHECK NUMERIC "1"
// Retrieval info: PRIVATE: CLKLOSS_CHECK STRING "0"
// Retrieval info: PRIVATE: BANDWIDTH_USE_AUTO STRING "1"
// Retrieval info: PRIVATE: SHORT_SCAN_RADIO STRING "0"
// Retrieval info: PRIVATE: LVDS_MODE_DATA_RATE STRING "Not Available"
// Retrieval info: PRIVATE: CLKSWITCH_CHECK STRING "1"
// Retrieval info: PRIVATE: SPREAD_FREQ_UNIT STRING "KHz"
// Retrieval info: PRIVATE: PLL_ENA_CHECK STRING "0"
// Retrieval info: PRIVATE: INCLK0_FREQ_EDIT STRING "50.000"
// Retrieval info: PRIVATE: CNX_NO_COMPENSATE_RADIO STRING "0"
// Retrieval info: PRIVATE: INT_FEEDBACK__MODE_RADIO STRING "1"
// Retrieval info: PRIVATE: OUTPUT_FREQ0 STRING "25.000"
// Retrieval info: PRIVATE: PRIMARY_CLK_COMBO STRING "inclk0"
// Retrieval info: PRIVATE: CREATE_INCLK1_CHECK STRING "0"
// Retrieval info: PRIVATE: SACN_INPUTS_CHECK STRING "0"
// Retrieval info: PRIVATE: DEV_FAMILY STRING "Cyclone II"
// Retrieval info: PRIVATE: SWITCHOVER_COUNT_EDIT NUMERIC "1"
// Retrieval info: PRIVATE: SWITCHOVER_FEATURE_ENABLED STRING "1"
// Retrieval info: PRIVATE: BANDWIDTH_PRESET STRING "Low"
// Retrieval info: PRIVATE: GLOCKED_FEATURE_ENABLED STRING "1"
// Retrieval info: PRIVATE: USE_CLKENA0 STRING "0"
// Retrieval info: PRIVATE: LVDS_PHASE_SHIFT_UNIT0 STRING "deg"
// Retrieval info: PRIVATE: CLKBAD_SWITCHOVER_CHECK STRING "0"
// Retrieval info: PRIVATE: BANDWIDTH_USE_PRESET STRING "0"
// Retrieval info: PRIVATE: PLL_LVDS_PLL_CHECK NUMERIC "0"
// Retrieval info: LIBRARY: altera_mf altera_mf.altera_mf_components.all
// Retrieval info: CONSTANT: CLK0_DUTY_CYCLE NUMERIC "50"
// Retrieval info: CONSTANT: LPM_TYPE STRING "altpll"
// Retrieval info: CONSTANT: CLK0_MULTIPLY_BY NUMERIC "1"
// Retrieval info: CONSTANT: INCLK0_INPUT_FREQUENCY NUMERIC "20000"
// Retrieval info: CONSTANT: CLK0_DIVIDE_BY NUMERIC "2"
// Retrieval info: CONSTANT: PLL_TYPE STRING "FAST"
// Retrieval info: CONSTANT: INTENDED_DEVICE_FAMILY STRING "Cyclone II"
// Retrieval info: CONSTANT: OPERATION_MODE STRING "NORMAL"
// Retrieval info: CONSTANT: COMPENSATE_CLOCK STRING "CLK0"
// Retrieval info: CONSTANT: CLK0_PHASE_SHIFT STRING "0"
// Retrieval info: USED_PORT: c0 0 0 0 0 OUTPUT VCC "c0"
// Retrieval info: USED_PORT: @clk 0 0 6 0 OUTPUT VCC "@clk[5..0]"
// Retrieval info: USED_PORT: inclk0 0 0 0 0 INPUT GND "inclk0"
// Retrieval info: USED_PORT: @extclk 0 0 4 0 OUTPUT VCC "@extclk[3..0]"
// Retrieval info: CONNECT: @inclk 0 0 1 0 inclk0 0 0 0 0
// Retrieval info: CONNECT: c0 0 0 0 0 @clk 0 0 1 0
// Retrieval info: CONNECT: @inclk 0 0 1 1 GND 0 0 0 0
// Retrieval info: GEN_FILE: TYPE_NORMAL VgaPll.v TRUE FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL VgaPll.inc FALSE FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL VgaPll.cmp FALSE FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL VgaPll.bsf FALSE FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL VgaPll_inst.v FALSE FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL VgaPll_bb.v FALSE FALSE




