\`timescale 1ns/1ps

//==============================================================================  
// pe\_baseline  
//  
// 3-Stage Pipelined Signed MAC Processing Element  
//  
// Stage 1 : Input Capture  
// Stage 2 : Signed Multiply  
// Stage 3 : Accumulate  
//  
// INT8 × INT8 \-\> INT16  
// INT16 \-\> INT32 Sign Extension  
// INT32 Accumulation  
//  
// Target:  
//   \- Cadence Genus  
//   \- Xcelium  
//   \- Synopsys DC  
//  
//==============================================================================

module pe\_baseline  
(  
	//----------------------------------------------------------------------  
	// Clock / Reset  
	//----------------------------------------------------------------------  
	input  logic           	clk,  
	input  logic           	rst\_n,

	//----------------------------------------------------------------------  
	// Input Interface  
	//----------------------------------------------------------------------  
	input  logic           	valid\_in,

	input  logic signed \[7:0\]  act\_in,  
	input  logic signed \[7:0\]  weight\_in,

	input  logic signed \[31:0\] psum\_in,

	//----------------------------------------------------------------------  
	// Output Interface  
	//----------------------------------------------------------------------  
	output logic           	valid\_out,

	output logic signed \[7:0\]  act\_out,  
	output logic signed \[7:0\]  weight\_out,

	output logic signed \[31:0\] psum\_out  
);

	//==========================================================================  
	// Stage 1 Registers  
	//==========================================================================

	logic           	s1\_valid;  
	logic signed \[7:0\]  s1\_act;  
	logic signed \[7:0\]  s1\_weight;  
	logic signed \[31:0\] s1\_psum;

	always\_ff @(posedge clk or negedge rst\_n)  
	begin  
    	if(\!rst\_n)  
    	begin  
        	s1\_valid  \<= 1'b0;  
        	s1\_act	\<= '0;  
        	s1\_weight \<= '0;  
        	s1\_psum   \<= '0;  
    	end  
    	else  
    	begin  
        	s1\_valid  \<= valid\_in;  
        	s1\_act	\<= act\_in;  
        	s1\_weight \<= weight\_in;  
        	s1\_psum   \<= psum\_in;  
    	end  
	end

	//==========================================================================  
	// Stage 2 Registers  
	//==========================================================================

	logic           	s2\_valid;  
	logic signed \[7:0\]  s2\_act;  
	logic signed \[7:0\]  s2\_weight;

	logic signed \[15:0\] s2\_prod;  
	logic signed \[31:0\] s2\_psum;

	always\_ff @(posedge clk or negedge rst\_n)  
	begin  
    	if(\!rst\_n)  
    	begin  
        	s2\_valid  \<= 1'b0;  
        	s2\_act	\<= '0;  
        	s2\_weight \<= '0;  
        	s2\_prod   \<= '0;  
        	s2\_psum   \<= '0;  
    	end  
    	else  
    	begin  
        	s2\_valid  \<= s1\_valid;  
        	s2\_act	\<= s1\_act;  
        	s2\_weight \<= s1\_weight;

        	// Signed Multiplier  
        	s2\_prod   \<= s1\_act \* s1\_weight;

        	s2\_psum   \<= s1\_psum;  
    	end  
	end

	//==========================================================================  
	// Explicit Sign Extension  
	//==========================================================================

	logic signed \[31:0\] s2\_prod\_ext;

	always\_comb  
	begin  
    	s2\_prod\_ext \= {{16{s2\_prod\[15\]}}, s2\_prod};  
	end

	//==========================================================================  
	// Stage 3 Registers  
	//==========================================================================

	always\_ff @(posedge clk or negedge rst\_n)  
	begin  
    	if(\!rst\_n)  
    	begin  
        	valid\_out  \<= 1'b0;

        	act\_out	\<= '0;  
        	weight\_out \<= '0;

        	psum\_out   \<= '0;  
    	end  
    	else  
    	begin  
        	valid\_out  \<= s2\_valid;

        	act\_out	\<= s2\_act;  
        	weight\_out \<= s2\_weight;

        	// Final Accumulation  
        	psum\_out   \<= s2\_psum \+ s2\_prod\_ext;  
    	end  
	end

endmodule

//============================================================  
// Systolic 16x16 Baseline — Weight-Stationary Array  
//============================================================  
// Architecture:  
//   16x16 grid of pe\_baseline instances (256 PEs)  
//   Weight-Stationary dataflow:  
// 	\- Weights (B) are stationary in PEs  
// 	\- Activations (A) flow horizontally  
// 	\- Partial Sums (C) flow and accumulate vertically  
//============================================================

\`include "hsa\_params.svh"

module systolic16x16\_baseline  
(  
	input  logic                             	clk,  
	input  logic                             	rst\_n,

	//------------------------------------------------------  
	// Weight Loading Interface  
	//------------------------------------------------------  
	input  logic                             	load\_weight,  
	input  logic \[3:0\]                       	weight\_row\_sel,  
	input  logic signed \[DATA\_WIDTH-1:0\]     	weight\_in  \[0:ARRAY\_SIZE-1\],

	//------------------------------------------------------  
	// Compute Interface  
	//------------------------------------------------------  
	input  logic                             	start,  
	input  logic signed \[DATA\_WIDTH-1:0\]     	act\_in 	\[0:ARRAY\_SIZE-1\],

	//------------------------------------------------------  
	// Output Interface  
	//------------------------------------------------------  
	output logic                             	done,  
	output logic signed \[ACC\_WIDTH-1:0\]      	result 	\[0:ARRAY\_SIZE-1\]\[0:ARRAY\_SIZE-1\]  
);

	//----------------------------------------------------------  
	// 1\. Weight Memory  
	//----------------------------------------------------------  
	logic signed \[DATA\_WIDTH-1:0\] weight\_mem \[0:ARRAY\_SIZE-1\]\[0:ARRAY\_SIZE-1\];

	always\_ff @(posedge clk or negedge rst\_n) begin  
    	if (\!rst\_n) begin  
        	for (int r \= 0; r \< ARRAY\_SIZE; r++)  
            	for (int c \= 0; c \< ARRAY\_SIZE; c++)  
                	weight\_mem\[r\]\[c\] \<= '0;  
    	end else if (load\_weight) begin  
        	for (int c \= 0; c \< ARRAY\_SIZE; c++)  
            	weight\_mem\[weight\_row\_sel\]\[c\] \<= weight\_in\[c\];  
    	end  
	end

	//----------------------------------------------------------  
	// 2\. FSM (Expanded window to let wavefront flush)  
	//----------------------------------------------------------  
	typedef enum logic \[1:0\] {  
    	S\_IDLE	\= 2'b00,  
    	S\_COMPUTE \= 2'b01,  
    	S\_DONE	\= 2'b10  
	} state\_t;

	state\_t state, state\_next;  
	logic \[7:0\] cycle\_cnt;

	// 150 cycles guarantees all skews and 3-cycle PEs flush completely  
	localparam TOTAL\_COMPUTE\_CYCLES \= 150;

	always\_ff @(posedge clk or negedge rst\_n) begin  
    	if (\!rst\_n) begin  
        	state 	\<= S\_IDLE;  
        	cycle\_cnt \<= '0;  
    	end else begin  
        	state \<= state\_next;  
        	if (state \== S\_COMPUTE)  
            	cycle\_cnt \<= cycle\_cnt \+ 1'b1;  
        	else  
            	cycle\_cnt \<= '0;  
    	end  
	end

	always\_comb begin  
    	state\_next \= state;  
    	case (state)  
        	S\_IDLE:	if (start) state\_next \= S\_COMPUTE;  
        	S\_COMPUTE: if (cycle\_cnt \== TOTAL\_COMPUTE\_CYCLES \- 1\) state\_next \= S\_DONE;  
        	S\_DONE:	state\_next \= S\_IDLE;  
        	default:   state\_next \= S\_IDLE;  
    	endcase  
	end

	assign done \= (state \== S\_DONE);

	//----------------------------------------------------------  
	// 3\. Activation Capture (Captures exactly 16 rows of A)  
	//----------------------------------------------------------  
	logic signed \[DATA\_WIDTH-1:0\] act\_captured \[0:ARRAY\_SIZE-1\];  
	logic                     	act\_captured\_valid;

	always\_ff @(posedge clk or negedge rst\_n) begin  
    	if (\!rst\_n) begin  
        	for (int k \= 0; k \< ARRAY\_SIZE; k++) act\_captured\[k\] \<= '0;  
        	act\_captured\_valid \<= 1'b0;  
    	end else if ((state \== S\_IDLE && start) || (state \== S\_COMPUTE && cycle\_cnt \< ARRAY\_SIZE \- 1)) begin  
        	for (int k \= 0; k \< ARRAY\_SIZE; k++) act\_captured\[k\] \<= act\_in\[k\];  
        	act\_captured\_valid \<= 1'b1;  
    	end else begin  
        	for (int k \= 0; k \< ARRAY\_SIZE; k++) act\_captured\[k\] \<= '0;  
        	act\_captured\_valid \<= 1'b0;  
    	end  
	end

	//----------------------------------------------------------  
	// 4\. Input Row Skewing (3 cycles per PE row)  
	//----------------------------------------------------------  
	logic signed \[DATA\_WIDTH-1:0\] row\_act   \[0:ARRAY\_SIZE-1\];  
	logic                     	row\_valid \[0:ARRAY\_SIZE-1\];

	assign row\_act\[0\]   \= act\_captured\[0\];  
	assign row\_valid\[0\] \= act\_captured\_valid;

	genvar gr;  
	generate  
    	for (gr \= 1; gr \< ARRAY\_SIZE; gr \= gr \+ 1\) begin : gen\_row\_skew  
        	localparam DELAY \= PIPE\_STAGES \* gr; // 3 cycles per row

        	logic signed \[DATA\_WIDTH-1:0\] sr\_data  \[0:DELAY-1\];  
        	logic                     	sr\_valid \[0:DELAY-1\];

        	always\_ff @(posedge clk or negedge rst\_n) begin  
            	if (\!rst\_n) begin  
                	sr\_data\[0\]  \<= '0;  
                	sr\_valid\[0\] \<= 1'b0;  
            	end else begin  
                	sr\_data\[0\]  \<= act\_captured\[gr\];  
                	sr\_valid\[0\] \<= act\_captured\_valid;  
            	end  
        	end

        	for (genvar s \= 1; s \< DELAY; s \= s \+ 1\) begin : gen\_sr\_stage  
            	always\_ff @(posedge clk or negedge rst\_n) begin  
                	if (\!rst\_n) begin  
                    	sr\_data\[s\]  \<= '0;  
                    	sr\_valid\[s\] \<= 1'b0;  
                	end else begin  
                    	sr\_data\[s\]  \<= sr\_data\[s-1\];  
                    	sr\_valid\[s\] \<= sr\_valid\[s-1\];  
                	end  
            	end  
        	end

        	assign row\_act\[gr\]   \= sr\_data\[DELAY-1\];  
        	assign row\_valid\[gr\] \= sr\_valid\[DELAY-1\];  
    	end  
	endgenerate

	//----------------------------------------------------------  
	// 5\. PE Array Connectivity (Valid flows HORIZONTALLY)  
	//----------------------------------------------------------  
	logic signed \[DATA\_WIDTH-1:0\] act\_wire   \[0:ARRAY\_SIZE-1\]\[0:ARRAY\_SIZE\];  
	logic                     	valid\_wire \[0:ARRAY\_SIZE-1\]\[0:ARRAY\_SIZE\];  
	logic signed \[ACC\_WIDTH-1:0\]  psum\_wire  \[0:ARRAY\_SIZE\]\[0:ARRAY\_SIZE-1\];  
	logic signed \[DATA\_WIDTH-1:0\] weight\_out\_unused \[0:ARRAY\_SIZE-1\]\[0:ARRAY\_SIZE-1\];

	// Connect skewed inputs to the left side of the array  
	generate  
    	for (gr \= 0; gr \< ARRAY\_SIZE; gr \= gr \+ 1\) begin : gen\_left\_bound  
        	assign act\_wire\[gr\]\[0\]   \= row\_act\[gr\];  
        	assign valid\_wire\[gr\]\[0\] \= row\_valid\[gr\];  
    	end  
	endgenerate

	// Connect 0 to the top of the partial sum vertical chains  
	genvar gcol;  
	generate  
    	for (gcol \= 0; gcol \< ARRAY\_SIZE; gcol \= gcol \+ 1\) begin : gen\_top\_bound  
        	assign psum\_wire\[0\]\[gcol\] \= '0;  
    	end  
	endgenerate

	generate  
    	for (gr \= 0; gr \< ARRAY\_SIZE; gr \= gr \+ 1\) begin : gen\_pe\_row  
        	for (gcol \= 0; gcol \< ARRAY\_SIZE; gcol \= gcol \+ 1\) begin : gen\_pe\_col  
            	pe\_baseline u\_pe (  
                	.clk    	(clk),  
                	.rst\_n  	(rst\_n),  
                	// Horizontal flow: valid and act travel together  
                	.valid\_in   (valid\_wire\[gr\]\[gcol\]),  
                	.act\_in 	(act\_wire\[gr\]\[gcol\]),  
                	.valid\_out  (valid\_wire\[gr\]\[gcol+1\]),  
                	.act\_out	(act\_wire\[gr\]\[gcol+1\]),  
               	   
                	// Static weight  
                	.weight\_in  (weight\_mem\[gr\]\[gcol\]),  
                	.weight\_out (weight\_out\_unused\[gr\]\[gcol\]),  
               	   
                	// Vertical flow: psums accumulate downwards  
                	.psum\_in	(psum\_wire\[gr\]\[gcol\]),  
                	.psum\_out   (psum\_wire\[gr+1\]\[gcol\])  
            	);  
        	end  
    	end  
	endgenerate

	//----------------------------------------------------------  
	// 6\. Result Capture (Using Bottom Row's Horizontal Valid)  
	//----------------------------------------------------------  
	logic \[4:0\] result\_row\_cnt \[0:ARRAY\_SIZE-1\];

	generate  
    	for (gcol \= 0; gcol \< ARRAY\_SIZE; gcol \= gcol \+ 1\) begin : gen\_result\_capture  
        	always\_ff @(posedge clk or negedge rst\_n) begin  
            	if (\!rst\_n) begin  
                	result\_row\_cnt\[gcol\] \<= '0;  
                	for (int r \= 0; r \< ARRAY\_SIZE; r++)  
                    	result\[r\]\[gcol\] \<= '0;  
            	end else if (state \== S\_IDLE && start) begin  
                	result\_row\_cnt\[gcol\] \<= '0;  
            	end  
            	// When valid\_out of PE\[15\]\[gcol\] is high, psum\_out is complete  
            	else if (valid\_wire\[ARRAY\_SIZE-1\]\[gcol+1\] && result\_row\_cnt\[gcol\] \< ARRAY\_SIZE) begin  
                	result\[result\_row\_cnt\[gcol\]\]\[gcol\] \<= psum\_wire\[ARRAY\_SIZE\]\[gcol\];  
                	result\_row\_cnt\[gcol\] \<= result\_row\_cnt\[gcol\] \+ 1'b1;  
            	end  
        	end  
    	end  
	endgenerate

endmodule

\-     	\-  
\#\#\>M:Misc                         	176  
\#\#\>----------------------------------------------------------------------------------------  
\#\#\>Total Elapsed                  	211  
\#\#\>========================================================================================

\+-----------+-------------------------+-----+----------------------+---------------------------+  
|   Host	|     	Machine     	| CPU | Physical Memory (MB) | Peak Physical Memory (MB) |  
\+-----------+-------------------------+-----+----------------------+---------------------------+  
| localhost | vlsilab14.srmist.edu.in |  1  |    	1680.1    	|      	2448.2       	|  
\+-----------+-------------------------+-----+----------------------+---------------------------+

\+---------------+----------------------+---------------------------+  
|	Server 	| Physical Memory (MB) | Peak Physical Memory (MB) |  
\+---------------+----------------------+---------------------------+  
| localhost\_1\_0 |    	315.0     	|      	1000.0       	|  
\+---------------+----------------------+---------------------------+

Info	: Done mapping. \[SYNTH-5\]  
    	: Done mapping 'systolic16x16\_baseline'.  
  	flow.cputime  flow.realtime  timing.setup.tns  timing.setup.wns  snapshot  
UM:\*                                                               	syn\_map  
@file(genus\_b16.tcl) 54: syn\_opt 	\-effort high  
Info	: Incrementally optimizing. \[SYNTH-7\]  
    	: Incrementally optimizing 'systolic16x16\_baseline' using 'high' effort.  
PBS\_Incr\_Opt-Start \- Elapsed\_Time 0, CPU\_Time 0.0  
stamp 'PBS\_Incr\_Opt-Start' being created for table 'pbs\_debug'

  Total Time (Wall) |  Stage Time (Wall)  |   % (Wall)   |	Date \- Time 	|  Memory   | Stage  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:00:16(00:00:13) |  00:00:00(00:00:00) |   0.0(  0.0) |   15:29:36 (Jun19) |  774.4 MB | PBS\_Generic-Start  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:29(00:06:19) |  00:06:13(00:06:06) |  61.8( 61.8) |   15:35:42 (Jun19) |   1.54 GB | PBS\_Generic\_Opt-Post  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:31(00:06:21) |  00:00:02(00:00:02) |   0.3(  0.3) |   15:35:44 (Jun19) |   1.54 GB | PBS\_Generic-Postgen HBO Optimizations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:36(00:06:26) |  00:00:05(00:00:05) |   0.8(  0.8) |   15:35:49 (Jun19) |   1.50 GB | PBS\_TechMap-Start  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:38(00:06:28) |  00:00:02(00:00:02) |   0.3(  0.3) |   15:35:51 (Jun19) |   1.50 GB | PBS\_TechMap-Premap HBO Optimizations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:09:30(00:09:16) |  00:02:52(00:02:48) |  28.4( 28.4) |   15:38:39 (Jun19) |   1.72 GB | PBS\_Techmap-Global Mapping  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:09:59(00:09:45) |  00:00:28(00:00:29) |   4.7(  4.9) |   15:39:08 (Jun19) |   1.69 GB | PBS\_TechMap-Datapath Postmap Operations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:02(00:09:47) |  00:00:03(00:00:02) |   0.5(  0.3) |   15:39:10 (Jun19) |   1.69 GB | PBS\_TechMap-Postmap HBO Optimizations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:08(00:09:53) |  00:00:06(00:00:06) |   1.0(  1.0) |   15:39:16 (Jun19) |   1.68 GB | PBS\_TechMap-Postmap Clock Gating  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:11(00:09:55) |  00:00:03(00:00:02) |   0.5(  0.3) |   15:39:18 (Jun19) |   1.68 GB | PBS\_TechMap-Postmap Cleanup  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:11(00:09:56) |  00:00:00(00:00:01) |   0.0(  0.2) |   15:39:19 (Jun19) |   1.68 GB | PBS\_Techmap-Post\_MBCI  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:20(00:10:05) |  00:00:09(00:00:09) |   1.5(  1.5) |   15:39:28 (Jun19) |   1.68 GB | PBS\_Incr\_Opt-Start  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
Number of threads: 8 \* 1   (id: pbs\_debug, time\_info v1.57)  
Info: (\*N\*) indicates data that was populated from previously saved time\_info database  
Info: CPU time includes time of parent \+ longest thread  
Info	: The given (sub)design is already uniquified. \[TUI-296\]  
    	: design:systolic16x16\_baseline.  
    	: Try running the 'edit\_netlist uniquify' command on the parent hierarchy of this (sub)design, if there exists any.  
PBS\_Incr\_Opt-Uniquify\_Netlist \- Elapsed\_Time 1, CPU\_Time 1.0  
stamp 'PBS\_Incr\_Opt-Uniquify\_Netlist' being created for table 'pbs\_debug'

  Total Time (Wall) |  Stage Time (Wall)  |   % (Wall)   |	Date \- Time 	|  Memory   | Stage  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:00:16(00:00:13) |  00:00:00(00:00:00) |   0.0(  0.0) |   15:29:36 (Jun19) |  774.4 MB | PBS\_Generic-Start  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:29(00:06:19) |  00:06:13(00:06:06) |  61.7( 61.7) |   15:35:42 (Jun19) |   1.54 GB | PBS\_Generic\_Opt-Post  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:31(00:06:21) |  00:00:02(00:00:02) |   0.3(  0.3) |   15:35:44 (Jun19) |   1.54 GB | PBS\_Generic-Postgen HBO Optimizations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:36(00:06:26) |  00:00:05(00:00:05) |   0.8(  0.8) |   15:35:49 (Jun19) |   1.50 GB | PBS\_TechMap-Start  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:38(00:06:28) |  00:00:02(00:00:02) |   0.3(  0.3) |   15:35:51 (Jun19) |   1.50 GB | PBS\_TechMap-Premap HBO Optimizations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:09:30(00:09:16) |  00:02:52(00:02:48) |  28.4( 28.3) |   15:38:39 (Jun19) |   1.72 GB | PBS\_Techmap-Global Mapping  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:09:59(00:09:45) |  00:00:28(00:00:29) |   4.7(  4.9) |   15:39:08 (Jun19) |   1.69 GB | PBS\_TechMap-Datapath Postmap Operations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:02(00:09:47) |  00:00:03(00:00:02) |   0.5(  0.3) |   15:39:10 (Jun19) |   1.69 GB | PBS\_TechMap-Postmap HBO Optimizations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:08(00:09:53) |  00:00:06(00:00:06) |   1.0(  1.0) |   15:39:16 (Jun19) |   1.68 GB | PBS\_TechMap-Postmap Clock Gating  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:11(00:09:55) |  00:00:03(00:00:02) |   0.5(  0.3) |   15:39:18 (Jun19) |   1.68 GB | PBS\_TechMap-Postmap Cleanup  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:11(00:09:56) |  00:00:00(00:00:01) |   0.0(  0.2) |   15:39:19 (Jun19) |   1.68 GB | PBS\_Techmap-Post\_MBCI  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:20(00:10:05) |  00:00:09(00:00:09) |   1.5(  1.5) |   15:39:28 (Jun19) |   1.68 GB | PBS\_Incr\_Opt-Start  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:21(00:10:06) |  00:00:01(00:00:01) |   0.2(  0.2) |   15:39:29 (Jun19) |   1.68 GB | PBS\_Incr\_Opt-Uniquify\_Netlist  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
Number of threads: 8 \* 1   (id: pbs\_debug, time\_info v1.57)  
Info: (\*N\*) indicates data that was populated from previously saved time\_info database  
Info: CPU time includes time of parent \+ longest thread  
 Uniquify netlist ...  
 Swap or remap avoided cells ...  
                               	Group     
                              	Tot Wrst 	Total DRC Total  
                       	Total  Weighted  	Neg   	Max  
Operation               	Area   Slacks  	Slack  	Cap  
 init\_iopt                 	0    	0     	0     	0  
\-------------------------------------------------------------------------------  
 hi\_fo\_buf                 	0    	0     	0     	0

       	Trick 	Calls 	Accepts   Attempts	Time(secs)  
\-----------------------------------------------------------  
   	hi\_fo\_buf    	18  (   	18 /   	18 )  0.60

 

                               	Group     
                              	Tot Wrst 	Total DRC Total  
                       	Total  Weighted  	Neg   	Max  
Operation               	Area   Slacks  	Slack  	Cap  
 init\_delay                	0    	0     	0     	0

       	Trick 	Calls 	Accepts   Attempts	Time(secs)  
\-----------------------------------------------------------

 init\_tns                  	0    	0     	0     	0

       	Trick 	Calls 	Accepts   Attempts	Time(secs)  
\-----------------------------------------------------------

INIT\_CLEAN\_UP \- Elapsed\_Time 3, CPU\_Time 4.259613999999942  
stamp 'INIT\_CLEAN\_UP' being created for table 'pbs\_debug'

  Total Time (Wall) |  Stage Time (Wall)  |   % (Wall)   |	Date \- Time 	|  Memory   | Stage  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:00:16(00:00:13) |  00:00:00(00:00:00) |   0.0(  0.0) |   15:29:36 (Jun19) |  774.4 MB | PBS\_Generic-Start  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:29(00:06:19) |  00:06:13(00:06:06) |  61.3( 61.4) |   15:35:42 (Jun19) |   1.54 GB | PBS\_Generic\_Opt-Post  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:31(00:06:21) |  00:00:02(00:00:02) |   0.3(  0.3) |   15:35:44 (Jun19) |   1.54 GB | PBS\_Generic-Postgen HBO Optimizations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:36(00:06:26) |  00:00:05(00:00:05) |   0.8(  0.8) |   15:35:49 (Jun19) |   1.50 GB | PBS\_TechMap-Start  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:38(00:06:28) |  00:00:02(00:00:02) |   0.3(  0.3) |   15:35:51 (Jun19) |   1.50 GB | PBS\_TechMap-Premap HBO Optimizations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:09:30(00:09:16) |  00:02:52(00:02:48) |  28.2( 28.2) |   15:38:39 (Jun19) |   1.72 GB | PBS\_Techmap-Global Mapping  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:09:59(00:09:45) |  00:00:28(00:00:29) |   4.7(  4.9) |   15:39:08 (Jun19) |   1.69 GB | PBS\_TechMap-Datapath Postmap Operations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:02(00:09:47) |  00:00:03(00:00:02) |   0.5(  0.3) |   15:39:10 (Jun19) |   1.69 GB | PBS\_TechMap-Postmap HBO Optimizations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:08(00:09:53) |  00:00:06(00:00:06) |   1.0(  1.0) |   15:39:16 (Jun19) |   1.68 GB | PBS\_TechMap-Postmap Clock Gating  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:11(00:09:55) |  00:00:03(00:00:02) |   0.5(  0.3) |   15:39:18 (Jun19) |   1.68 GB | PBS\_TechMap-Postmap Cleanup  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:11(00:09:56) |  00:00:00(00:00:01) |   0.0(  0.2) |   15:39:19 (Jun19) |   1.68 GB | PBS\_Techmap-Post\_MBCI  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:20(00:10:05) |  00:00:09(00:00:09) |   1.5(  1.5) |   15:39:28 (Jun19) |   1.68 GB | PBS\_Incr\_Opt-Start  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:21(00:10:06) |  00:00:01(00:00:01) |   0.2(  0.2) |   15:39:29 (Jun19) |   1.68 GB | PBS\_Incr\_Opt-Uniquify\_Netlist  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:26(00:10:09) |  00:00:04(00:00:03) |   0.7(  0.5) |   15:39:32 (Jun19) |   1.68 GB | INIT\_CLEAN\_UP  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
Number of threads: 8 \* 1   (id: pbs\_debug, time\_info v1.57)  
Info: (\*N\*) indicates data that was populated from previously saved time\_info database  
Info: CPU time includes time of parent \+ longest thread  
Updating ST server settings  
 	Generating lib\_script file: /home/Cadence/Genus/HSA16-AI-Accelerator-main/.pbs\_vlsilab14.srmist.edu.in\_16364/lib\_script  
Start partitioning.  Summary: MEM {curr: 2.2G, peak: 2.5G, phys curr: 1.6G, phys peak: 2.4G}  
Start timing analysis.  Summary: MEM {curr: 2.2G, peak: 2.5G, phys curr: 1.6G, phys peak: 2.4G}  
Done timing analysis.  Summary: RT {elapsed: 2s, ST: 2s}, MEM {curr: 2.2G, peak: 2.5G, phys curr: 1.6G, phys peak: 2.4G}  
Design systolic16x16\_baseline is partitioned using GPS apart partitioner  
Done partitioning.  Summary: RT {elapsed: 3s, ST: 3s}, MEM {curr: 2.2G, peak: 2.5G, phys curr: 1.6G, phys peak: 2.4G}  
Start creating partition netlists.  Summary: MEM {curr: 2.2G, peak: 2.5G, phys curr: 1.6G, phys peak: 2.4G}  
Done creating partition netlists.  Summary: RT {elapsed: 2s, ST: 1s}, MEM {curr: 2.2G, peak: 2.5G, phys curr: 1.6G, phys peak: 2.4G}  
Start budgeting timing for partitions.  Summary: MEM {curr: 2.2G, peak: 2.5G, phys curr: 1.6G, phys peak: 2.4G}  
Done budgeting timing for partitions.  Summary: RT {elapsed: 3s, ST: 4s}, MEM {curr: 2.2G, peak: 2.5G, phys curr: 1.7G, phys peak: 2.4G}  
Start deriving partition netlists.  Summary: MEM {curr: 2.2G, peak: 2.5G, phys curr: 1.7G, phys peak: 2.4G}  
The inst 'pbs\_iopt\_1' is selected as pbs candidate. The instance cnt is: '66780'.  
The inst 'pbs\_iopt\_0' is selected as pbs candidate. The instance cnt is: '63324'.  
Done deriving partition netlists.  Summary: RT {elapsed: 2s, ST: 3s}, MEM {curr: 2.2G, peak: 2.5G, phys curr: 1.7G, phys peak: 2.4G}  
Wait for super-thread servers to finish loading libraries.  
Start super thread servers forking.  Summary: MEM {curr: 2.2G, peak: 2.5G, phys curr: 1.7G, phys peak: 2.4G}  
Info	: Connection established with super-threading server. \[ST-110\]  
    	: The server 'localhost\_1\_22' is forked process '18925' on this host.  
Info	: Connection established with super-threading server. \[ST-110\]  
    	: The server 'localhost\_1\_23' is forked process '18927' on this host.  
Info	: Connection established with super-threading server. \[ST-110\]  
    	: The server 'localhost\_1\_24' is forked process '18929' on this host.  
Info	: Connection established with super-threading server. \[ST-110\]  
    	: The server 'localhost\_1\_25' is forked process '18931' on this host.  
Info	: Connection established with super-threading server. \[ST-110\]  
    	: The server 'localhost\_1\_26' is forked process '18933' on this host.  
Info	: Connection established with super-threading server. \[ST-110\]  
    	: The server 'localhost\_1\_27' is forked process '18935' on this host.  
Info	: Connection established with super-threading server. \[ST-110\]  
    	: The server 'localhost\_1\_28' is forked process '18937' on this host.  
Done super thread servers forking.  Summary: RT {elapsed: 1s, ST: 0s}, MEM {curr: 2.2G, peak: 2.5G, phys curr: 1.7G, phys peak: 2.4G}  
    	Distributing super-thread jobs: {pbs\_iopt\_1 ./.pbs\_vlsilab14.srmist.edu.in\_16364/pbs\_iopt\_1.etf} {pbs\_iopt\_0 ./.pbs\_vlsilab14.srmist.edu.in\_16364/pbs\_iopt\_0.etf}  
      	Sending 'pbs\_iopt\_1 ./.pbs\_vlsilab14.srmist.edu.in\_16364/pbs\_iopt\_1.etf' to server 'localhost\_1\_27'...  
        	Sent 'pbs\_iopt\_1 ./.pbs\_vlsilab14.srmist.edu.in\_16364/pbs\_iopt\_1.etf' to server 'localhost\_1\_27'.  
      	Sending 'pbs\_iopt\_0 ./.pbs\_vlsilab14.srmist.edu.in\_16364/pbs\_iopt\_0.etf' to server 'localhost\_1\_26'...  
        	Sent 'pbs\_iopt\_0 ./.pbs\_vlsilab14.srmist.edu.in\_16364/pbs\_iopt\_0.etf' to server 'localhost\_1\_26'.  
      	Received 'pbs\_iopt\_0 ./.pbs\_vlsilab14.srmist.edu.in\_16364/pbs\_iopt\_0.etf' from server 'localhost\_1\_26'. (35076 ms elapsed)  
   	Partition:  pbs\_iopt\_0 \- PBS\_Iopt-Distributed\_Read\_DB \- Elapsed\_Time 0.00, CPU\_Time 0.00  
   	Partition:  pbs\_iopt\_0 \- PBS\_Iopt-Distributed\_Iopt \- Elapsed\_Time 32.00, CPU\_Time 32.00  
   	Start \- Partition: pbs\_iopt\_0  Slack: 0.0 TNS: 0.0 Cell-Count: 63324 Cell-Area: 0    
Init-Memory: 977.40  
   	Done  \- Partition: pbs\_iopt\_0  Slack: 0.0 TNS: 0.0 Cell-Count: 57415 Cell-Area: 0    
Peak-Memory: 1141.23 Elapsed: 33  
   	Partition:  pbs\_iopt\_0 \- PBS\_Iopt-Distributed\_Report \- Elapsed\_Time 1.00, CPU\_Time 1.00  
   	Partition:  pbs\_iopt\_0 \- PBS\_Iopt-Distributed\_Write\_DB \- Elapsed\_Time 2.00, CPU\_Time 2.00  
   	pbs\_iopt\_0 \- PBS\_Iopt-Assembly \- Elapsed\_Time 3, CPU\_Time 4.0  
   	Partition:  pbs\_iopt\_0 \- Runtime taken by the partition \- Elapsed\_Time 35.00, CPU\_Time 35.00  
      	Received 'pbs\_iopt\_1 ./.pbs\_vlsilab14.srmist.edu.in\_16364/pbs\_iopt\_1.etf' from server 'localhost\_1\_27'. (50200 ms elapsed)  
   	Partition:  pbs\_iopt\_1 \- PBS\_Iopt-Distributed\_Read\_DB \- Elapsed\_Time 0.00, CPU\_Time 1.00  
   	Partition:  pbs\_iopt\_1 \- PBS\_Iopt-Distributed\_Iopt \- Elapsed\_Time 44.00, CPU\_Time 43.00  
   	Start \- Partition: pbs\_iopt\_1  Slack: 0.0 TNS: 0.0 Cell-Count: 66780 Cell-Area: 0    
Init-Memory: 986.40  
   	Done  \- Partition: pbs\_iopt\_1  Slack: 0.0 TNS: 0.0 Cell-Count: 60817 Cell-Area: 0    
Peak-Memory: 1151.23 Elapsed: 46  
   	Partition:  pbs\_iopt\_1 \- PBS\_Iopt-Distributed\_Report \- Elapsed\_Time 2.00, CPU\_Time 2.00  
   	Partition:  pbs\_iopt\_1 \- PBS\_Iopt-Distributed\_Write\_DB \- Elapsed\_Time 3.00, CPU\_Time 4.00  
   	pbs\_iopt\_1 \- PBS\_Iopt-Assembly \- Elapsed\_Time 2, CPU\_Time 2.0  
   	Partition:  pbs\_iopt\_1 \- Runtime taken by the partition \- Elapsed\_Time 49.00, CPU\_Time 50.00  
Assembled design in-time

\+-----------+-------------------------+-----+----------------------+---------------------------+  
|   Host	|     	Machine     	| CPU | Physical Memory (MB) | Peak Physical Memory (MB) |  
\+-----------+-------------------------+-----+----------------------+---------------------------+  
| localhost | vlsilab14.srmist.edu.in |  8  |    	2242.1    	|      	2448.2       	|  
\+-----------+-------------------------+-----+----------------------+---------------------------+

\+----------------+----------------------+---------------------------+  
| 	Server 	| Physical Memory (MB) | Peak Physical Memory (MB) |  
\+----------------+----------------------+---------------------------+  
| localhost\_1\_0  |  	904.5 \[1\]   	|    	1000.0 \[1\]     	|  
| localhost\_1\_22 |   	49.1 \[2\]   	|      	\[2\] \[3\]      	|  
| localhost\_1\_24 |   	49.1 \[2\]   	|      	\[2\] \[3\]      	|  
| localhost\_1\_25 |   	49.1 \[2\]   	|      	\[2\] \[3\]      	|  
| localhost\_1\_28 |   	49.1 \[2\]   	|      	\[2\] \[3\]      	|  
| localhost\_1\_23 |   	49.1 \[2\]   	|      	\[2\] \[3\]      	|  
| localhost\_1\_26 |  	259.0 \[2\]   	|      	\[2\] \[3\]      	|  
| localhost\_1\_27 |  	252.4 \[2\]   	|      	\[2\] \[3\]      	|  
\+----------------+----------------------+---------------------------+  
\[1\] Memory of child processes is included.  
\[2\] Memory is included in parent localhost\_1\_0.  
\[3\] Peak physical memory is not available for forked background servers.

1ST\_ST \- Elapsed\_Time 72, CPU\_Time 69.65447200000006  
stamp '1ST\_ST' being created for table 'pbs\_debug'

  Total Time (Wall) |  Stage Time (Wall)  |   % (Wall)   |	Date \- Time 	|  Memory   | Stage  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:00:16(00:00:13) |  00:00:00(00:00:00) |   0.0(  0.0) |   15:29:36 (Jun19) |  774.4 MB | PBS\_Generic-Start  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:29(00:06:19) |  00:06:13(00:06:06) |  55.0( 54.8) |   15:35:42 (Jun19) |   1.54 GB | PBS\_Generic\_Opt-Post  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:31(00:06:21) |  00:00:02(00:00:02) |   0.3(  0.3) |   15:35:44 (Jun19) |   1.54 GB | PBS\_Generic-Postgen HBO Optimizations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:36(00:06:26) |  00:00:05(00:00:05) |   0.7(  0.7) |   15:35:49 (Jun19) |   1.50 GB | PBS\_TechMap-Start  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:38(00:06:28) |  00:00:02(00:00:02) |   0.3(  0.3) |   15:35:51 (Jun19) |   1.50 GB | PBS\_TechMap-Premap HBO Optimizations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:09:30(00:09:16) |  00:02:52(00:02:48) |  25.3( 25.1) |   15:38:39 (Jun19) |   1.72 GB | PBS\_Techmap-Global Mapping  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:09:59(00:09:45) |  00:00:28(00:00:29) |   4.2(  4.3) |   15:39:08 (Jun19) |   1.69 GB | PBS\_TechMap-Datapath Postmap Operations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:02(00:09:47) |  00:00:03(00:00:02) |   0.5(  0.3) |   15:39:10 (Jun19) |   1.69 GB | PBS\_TechMap-Postmap HBO Optimizations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:08(00:09:53) |  00:00:06(00:00:06) |   0.9(  0.9) |   15:39:16 (Jun19) |   1.68 GB | PBS\_TechMap-Postmap Clock Gating  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:11(00:09:55) |  00:00:03(00:00:02) |   0.5(  0.3) |   15:39:18 (Jun19) |   1.68 GB | PBS\_TechMap-Postmap Cleanup  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:11(00:09:56) |  00:00:00(00:00:01) |   0.0(  0.1) |   15:39:19 (Jun19) |   1.68 GB | PBS\_Techmap-Post\_MBCI  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:20(00:10:05) |  00:00:09(00:00:09) |   1.3(  1.3) |   15:39:28 (Jun19) |   1.68 GB | PBS\_Incr\_Opt-Start  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:21(00:10:06) |  00:00:01(00:00:01) |   0.1(  0.1) |   15:39:29 (Jun19) |   1.68 GB | PBS\_Incr\_Opt-Uniquify\_Netlist  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:26(00:10:09) |  00:00:04(00:00:03) |   0.6(  0.4) |   15:39:32 (Jun19) |   1.68 GB | INIT\_CLEAN\_UP  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:11:35(00:11:21) |  00:01:09(00:01:12) |  10.2( 10.8) |   15:40:44 (Jun19) |   1.74 GB | 1ST\_ST  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
Number of threads: 8 \* 1   (id: pbs\_debug, time\_info v1.57)  
Info: (\*N\*) indicates data that was populated from previously saved time\_info database  
Info: CPU time includes time of parent \+ longest thread  
\-------------------------------------------------------------------------------  
 hi\_fo\_buf                 	0    	0     	0     	0

       	Trick 	Calls 	Accepts   Attempts	Time(secs)  
\-----------------------------------------------------------  
   	hi\_fo\_buf     	1  (    	1 /    	1 )  0.02

 

                               	Group     
                              	Tot Wrst 	Total DRC Total  
                       	Total  Weighted  	Neg   	Max  
Operation               	Area   Slacks  	Slack  	Cap  
 init\_delay                	0    	0     	0     	0

       	Trick 	Calls 	Accepts   Attempts	Time(secs)  
\-----------------------------------------------------------

 init\_tns                  	0    	0     	0     	0

       	Trick 	Calls 	Accepts   Attempts	Time(secs)  
\-----------------------------------------------------------

 init\_area                 	0    	0     	0     	0  
 rem\_buf                   	0    	0     	0     	0  
 rem\_inv                   	0    	0     	0     	0  
 rem\_inv\_qb                	0    	0     	0     	0  
 gcomp\_mog                 	0    	0     	0     	0

       	Trick 	Calls 	Accepts   Attempts	Time(secs)  
\-----------------------------------------------------------  
     	rem\_buf    	10  (   	10 /   	10 )  0.10  
     	rem\_inv   	214  (  	213 /  	213 )  0.81  
  	rem\_inv\_qb    	80  (    	2 /    	2 )  0.57  
   	gcomp\_mog   	672  (  	320 /  	320 )  3.27  
   	glob\_area    	26  (    	0 /   	26 )  0.42

INTRMD\_CLEAN\_UP \- Elapsed\_Time 40, CPU\_Time 40.15069699999947  
stamp 'INTRMD\_CLEAN\_UP' being created for table 'pbs\_debug'

  Total Time (Wall) |  Stage Time (Wall)  |   % (Wall)   |	Date \- Time 	|  Memory   | Stage  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:00:16(00:00:13) |  00:00:00(00:00:00) |   0.0(  0.0) |   15:29:36 (Jun19) |  774.4 MB | PBS\_Generic-Start  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:29(00:06:19) |  00:06:13(00:06:06) |  51.9( 51.7) |   15:35:42 (Jun19) |   1.54 GB | PBS\_Generic\_Opt-Post  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:31(00:06:21) |  00:00:02(00:00:02) |   0.3(  0.3) |   15:35:44 (Jun19) |   1.54 GB | PBS\_Generic-Postgen HBO Optimizations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:36(00:06:26) |  00:00:05(00:00:05) |   0.7(  0.7) |   15:35:49 (Jun19) |   1.50 GB | PBS\_TechMap-Start  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:38(00:06:28) |  00:00:02(00:00:02) |   0.3(  0.3) |   15:35:51 (Jun19) |   1.50 GB | PBS\_TechMap-Premap HBO Optimizations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:09:30(00:09:16) |  00:02:52(00:02:48) |  23.9( 23.7) |   15:38:39 (Jun19) |   1.72 GB | PBS\_Techmap-Global Mapping  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:09:59(00:09:45) |  00:00:28(00:00:29) |   4.0(  4.1) |   15:39:08 (Jun19) |   1.69 GB | PBS\_TechMap-Datapath Postmap Operations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:02(00:09:47) |  00:00:03(00:00:02) |   0.4(  0.3) |   15:39:10 (Jun19) |   1.69 GB | PBS\_TechMap-Postmap HBO Optimizations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:08(00:09:53) |  00:00:06(00:00:06) |   0.8(  0.8) |   15:39:16 (Jun19) |   1.68 GB | PBS\_TechMap-Postmap Clock Gating  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:11(00:09:55) |  00:00:03(00:00:02) |   0.5(  0.3) |   15:39:18 (Jun19) |   1.68 GB | PBS\_TechMap-Postmap Cleanup  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:11(00:09:56) |  00:00:00(00:00:01) |   0.0(  0.1) |   15:39:19 (Jun19) |   1.68 GB | PBS\_Techmap-Post\_MBCI  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:20(00:10:05) |  00:00:09(00:00:09) |   1.3(  1.3) |   15:39:28 (Jun19) |   1.68 GB | PBS\_Incr\_Opt-Start  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:21(00:10:06) |  00:00:01(00:00:01) |   0.1(  0.1) |   15:39:29 (Jun19) |   1.68 GB | PBS\_Incr\_Opt-Uniquify\_Netlist  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:26(00:10:09) |  00:00:04(00:00:03) |   0.6(  0.4) |   15:39:32 (Jun19) |   1.68 GB | INIT\_CLEAN\_UP  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:11:35(00:11:21) |  00:01:09(00:01:12) |   9.7( 10.2) |   15:40:44 (Jun19) |   1.74 GB | 1ST\_ST  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:12:15(00:12:01) |  00:00:40(00:00:40) |   5.6(  5.6) |   15:41:24 (Jun19) |   1.74 GB | INTRMD\_CLEAN\_UP  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
Number of threads: 8 \* 1   (id: pbs\_debug, time\_info v1.57)  
Info: (\*N\*) indicates data that was populated from previously saved time\_info database  
Info: CPU time includes time of parent \+ longest thread  
CRB\_ST \- Elapsed\_Time 0, CPU\_Time 0.0  
stamp 'CRB\_ST' being created for table 'pbs\_debug'

  Total Time (Wall) |  Stage Time (Wall)  |   % (Wall)   |	Date \- Time 	|  Memory   | Stage  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:00:16(00:00:13) |  00:00:00(00:00:00) |   0.0(  0.0) |   15:29:36 (Jun19) |  774.4 MB | PBS\_Generic-Start  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:29(00:06:19) |  00:06:13(00:06:06) |  51.9( 51.7) |   15:35:42 (Jun19) |   1.54 GB | PBS\_Generic\_Opt-Post  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:31(00:06:21) |  00:00:02(00:00:02) |   0.3(  0.3) |   15:35:44 (Jun19) |   1.54 GB | PBS\_Generic-Postgen HBO Optimizations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:36(00:06:26) |  00:00:05(00:00:05) |   0.7(  0.7) |   15:35:49 (Jun19) |   1.50 GB | PBS\_TechMap-Start  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:38(00:06:28) |  00:00:02(00:00:02) |   0.3(  0.3) |   15:35:51 (Jun19) |   1.50 GB | PBS\_TechMap-Premap HBO Optimizations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:09:30(00:09:16) |  00:02:52(00:02:48) |  23.9( 23.7) |   15:38:39 (Jun19) |   1.72 GB | PBS\_Techmap-Global Mapping  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:09:59(00:09:45) |  00:00:28(00:00:29) |   4.0(  4.1) |   15:39:08 (Jun19) |   1.69 GB | PBS\_TechMap-Datapath Postmap Operations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:02(00:09:47) |  00:00:03(00:00:02) |   0.4(  0.3) |   15:39:10 (Jun19) |   1.69 GB | PBS\_TechMap-Postmap HBO Optimizations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:08(00:09:53) |  00:00:06(00:00:06) |   0.8(  0.8) |   15:39:16 (Jun19) |   1.68 GB | PBS\_TechMap-Postmap Clock Gating  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:11(00:09:55) |  00:00:03(00:00:02) |   0.5(  0.3) |   15:39:18 (Jun19) |   1.68 GB | PBS\_TechMap-Postmap Cleanup  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:11(00:09:56) |  00:00:00(00:00:01) |   0.0(  0.1) |   15:39:19 (Jun19) |   1.68 GB | PBS\_Techmap-Post\_MBCI  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:20(00:10:05) |  00:00:09(00:00:09) |   1.3(  1.3) |   15:39:28 (Jun19) |   1.68 GB | PBS\_Incr\_Opt-Start  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:21(00:10:06) |  00:00:01(00:00:01) |   0.1(  0.1) |   15:39:29 (Jun19) |   1.68 GB | PBS\_Incr\_Opt-Uniquify\_Netlist  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:26(00:10:09) |  00:00:04(00:00:03) |   0.6(  0.4) |   15:39:32 (Jun19) |   1.68 GB | INIT\_CLEAN\_UP  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:11:35(00:11:21) |  00:01:09(00:01:12) |   9.7( 10.2) |   15:40:44 (Jun19) |   1.74 GB | 1ST\_ST  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:12:15(00:12:01) |  00:00:40(00:00:40) |   5.6(  5.6) |   15:41:24 (Jun19) |   1.74 GB | INTRMD\_CLEAN\_UP  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:12:15(00:12:01) |  00:00:00(00:00:00) |   0.0(  0.0) |   15:41:24 (Jun19) |   1.74 GB | CRB\_ST  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
Number of threads: 8 \* 1   (id: pbs\_debug, time\_info v1.57)  
Info: (\*N\*) indicates data that was populated from previously saved time\_info database  
Info: CPU time includes time of parent \+ longest thread  
 

                               	Group     
                              	Tot Wrst 	Total DRC Total  
                       	Total  Weighted  	Neg   	Max  
Operation               	Area   Slacks  	Slack  	Cap  
 init\_delay                	0    	0     	0     	0

       	Trick 	Calls 	Accepts   Attempts	Time(secs)  
\-----------------------------------------------------------

 init\_tns                  	0    	0     	0     	0

       	Trick 	Calls 	Accepts   Attempts	Time(secs)  
\-----------------------------------------------------------

 init\_delay                	0    	0     	0     	0

       	Trick 	Calls 	Accepts   Attempts	Time(secs)  
\-----------------------------------------------------------  
 init\_area                 	0    	0     	0     	0

       	Trick 	Calls 	Accepts   Attempts	Time(secs)  
\-----------------------------------------------------------

 init\_drc                  	0    	0     	0     	0

       	Trick 	Calls 	Accepts   Attempts	Time(secs)  
\-----------------------------------------------------------

       	Trick 	Calls 	Accepts   Attempts	Time(secs)  
\-----------------------------------------------------------

       	Trick 	Calls 	Accepts   Attempts	Time(secs)  
\-----------------------------------------------------------

\# Incremental Optimization Runtime Summary:  
                   	Step	Elapsed Time(s)     	Runtime(s)   WNS(ps)       	TNS(ps)       	CELL AREA     	Leakage Power 	Dynamic Power    
\#\#\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*  
\#\#                 	INIT     	2 (1.3  %)     	4 (3.4  %)   0.0           	0             	0             	NA         	NA        	   
\#\#     	HIGH\_FANOUT\_OPTO     	1 (0.6  %)     	0 (0.0  %)   0.0           	0             	0             	NA         	NA        	   
\#\#           	SCORE\_INIT     	0 (0.0  %)     	0 (0.0  %)   0.0           	0             	0             	NA         	NA        	   
\#\#             	WNS\_OPTO     	0 (0.0  %)     	0 (0.0  %)   0.0           	0             	0             	NA         	NA        	   
\#\#             	TNS\_OPTO     	0 (0.0  %)     	0 (0.0  %)   0.0           	0             	0             	NA         	NA        	   
\#\#             	FIRST\_ST    	72 (45.3 %)    	24 (20.7 %)   NOT\_TIMED     	NOT\_TIMED     	0             	NA         	NA        	   
\#\#                 	INIT     	2 (1.3  %)     	3 (2.6  %)   0.0           	0             	0             	NA         	NA        	   
\#\#     	HIGH\_FANOUT\_OPTO     	0 (0.0  %)     	0 (0.0  %)   0.0           	0             	0             	NA         	NA        	   
\#\#           	SCORE\_INIT     	0 (0.0  %)     	0 (0.0  %)   0.0           	0             	0             	NA         	NA        	   
\#\#             	WNS\_OPTO     	0 (0.0  %)     	0 (0.0  %)   0.0           	0             	0             	NA         	NA        	   
\#\#             	TNS\_OPTO     	0 (0.0  %)     	0 (0.0  %)   0.0           	0             	0             	NA         	NA        	   
\#\#            	AREA\_OPTO    	38 (23.9 %)    	38 (32.8 %)   0.0           	0             	0             	NA         	NA        	   
\#\#                 	INIT     	0 (0.0  %)     	0 (0.0  %)   0.0           	0             	0             	NA         	NA        	   
\#\#           	LATCH\_OPTO     	0 (0.0  %)     	0 (0.0  %)   0.0           	0             	0             	NA         	NA        	   
\#\#           	SCORE\_INIT     	0 (0.0  %)     	0 (0.0  %)   0.0           	0             	0             	NA         	NA        	   
\#\#             	WNS\_OPTO     	0 (0.0  %)     	0 (0.0  %)   0.0           	0             	0             	NA         	NA        	   
\#\#             	TNS\_OPTO     	0 (0.0  %)     	0 (0.0  %)   0.0           	0             	0             	NA         	NA        	   
\#\#         	WNS\_CRR\_OPTO     	0 (0.0  %)     	0 (0.0  %)   0.0           	0             	0             	NA         	NA        	   
\#\#            	AREA\_OPTO    	44 (27.7 %)    	44 (37.9 %)   0.0           	0             	0             	NA         	NA        	   
\#\#             	DRC\_OPTO     	0 (0.0  %)     	0 (0.0  %)   0.0           	0             	0             	NA         	NA        	   
\#\#\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*  
                              	159              	116

Done incrementally optimizing.  
\==================================  
Stage : FINAL\_CLEAN\_UP  
\==================================  
  \=================  
   Message Summary  
  \=================  
\--------------------------------------------------------------------------------  
|   Id	|  Sev   |Count |               	Message Text                 	|  
\--------------------------------------------------------------------------------  
| CFM-1   |Info	|	1 |Wrote dofile.                                   	|  
| CFM-5   |Info	|	1 |Wrote formal verification information.          	|  
| CPI-506 |Warning |	1 |Command 'commit\_power\_intent' cannot proceed as 	|  
|     	|    	|  	| there is no power intent loaded.               	|  
| GLO-51  |Info	|  149 |Hierarchical instance automatically ungrouped.  	|  
|     	|    	|  	|Hierarchical instances can be automatically     	|  
|     	|    	|  	| ungrouped to allow for better area or timing   	|  
|     	|    	|  	| optimization. To prevent this ungroup, set the 	|  
|     	|    	|  	| root-level attribute 'auto\_ungroup' to 'none'. You |  
|     	|    	|  	| can also prevent individual ungroup with setting   |  
|     	|    	|  	| the attribute 'ungroup\_ok' of instances or modules |  
|     	|    	|  	| to 'false'.                                    	|  
| PA-7	|Info	|	4 |Resetting power analysis results.               	|  
|     	|    	|  	|All computed switching activities are removed.  	|  
| ST-110  |Info	|	7 |Connection established with super-threading server. |  
|     	|    	|  	|The tool is entering super-threading mode and has   |  
|     	|    	|  	| established a connection with a CPU server     	|  
|     	|    	|  	| process.  This is enabled by the root attributes   |  
|     	|    	|  	| 'super\_thread\_servers' or 'auto\_super\_thread'. 	|  
| ST-112  |Info	|   14 |A super-threading server has been shut down     	|  
|     	|    	|  	| normally.                                      	|  
|     	|    	|  	|A super-threaded optimization is complete and a CPU |  
|     	|    	|  	| server was successfully shut down.             	|  
| ST-128  |Info	|	1 |Super thread servers are launched successfully. 	|  
| SYNTH-5 |Info	|	1 |Done mapping.                                   	|  
| SYNTH-7 |Info	|	1 |Incrementally optimizing.                       	|  
| TUI-296 |Info	|	1 |The given (sub)design is already uniquified.    	|  
|     	|    	|  	|Try running the 'edit\_netlist uniquify' command on  |  
|     	|    	|  	| the parent hierarchy of this (sub)             	|  
|     	|    	|  	| design, if there exists any.                   	|  
\--------------------------------------------------------------------------------  
FINAL\_CLEAN\_UP \- Elapsed\_Time 44, CPU\_Time 44.0  
stamp 'FINAL\_CLEAN\_UP' being created for table 'pbs\_debug'

  Total Time (Wall) |  Stage Time (Wall)  |   % (Wall)   |	Date \- Time 	|  Memory   | Stage  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:00:16(00:00:13) |  00:00:00(00:00:00) |   0.0(  0.0) |   15:29:36 (Jun19) |  774.4 MB | PBS\_Generic-Start  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:29(00:06:19) |  00:06:13(00:06:06) |  49.0( 48.7) |   15:35:42 (Jun19) |   1.54 GB | PBS\_Generic\_Opt-Post  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:31(00:06:21) |  00:00:02(00:00:02) |   0.3(  0.3) |   15:35:44 (Jun19) |   1.54 GB | PBS\_Generic-Postgen HBO Optimizations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:36(00:06:26) |  00:00:05(00:00:05) |   0.7(  0.7) |   15:35:49 (Jun19) |   1.50 GB | PBS\_TechMap-Start  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:06:38(00:06:28) |  00:00:02(00:00:02) |   0.3(  0.3) |   15:35:51 (Jun19) |   1.50 GB | PBS\_TechMap-Premap HBO Optimizations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:09:30(00:09:16) |  00:02:52(00:02:48) |  22.5( 22.3) |   15:38:39 (Jun19) |   1.72 GB | PBS\_Techmap-Global Mapping  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:09:59(00:09:45) |  00:00:28(00:00:29) |   3.7(  3.9) |   15:39:08 (Jun19) |   1.69 GB | PBS\_TechMap-Datapath Postmap Operations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:02(00:09:47) |  00:00:03(00:00:02) |   0.4(  0.3) |   15:39:10 (Jun19) |   1.69 GB | PBS\_TechMap-Postmap HBO Optimizations  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:08(00:09:53) |  00:00:06(00:00:06) |   0.8(  0.8) |   15:39:16 (Jun19) |   1.68 GB | PBS\_TechMap-Postmap Clock Gating  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:11(00:09:55) |  00:00:03(00:00:02) |   0.4(  0.3) |   15:39:18 (Jun19) |   1.68 GB | PBS\_TechMap-Postmap Cleanup  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:11(00:09:56) |  00:00:00(00:00:01) |   0.0(  0.1) |   15:39:19 (Jun19) |   1.68 GB | PBS\_Techmap-Post\_MBCI  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:20(00:10:05) |  00:00:09(00:00:09) |   1.2(  1.2) |   15:39:28 (Jun19) |   1.68 GB | PBS\_Incr\_Opt-Start  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:21(00:10:06) |  00:00:01(00:00:01) |   0.1(  0.1) |   15:39:29 (Jun19) |   1.68 GB | PBS\_Incr\_Opt-Uniquify\_Netlist  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:10:26(00:10:09) |  00:00:04(00:00:03) |   0.6(  0.4) |   15:39:32 (Jun19) |   1.68 GB | INIT\_CLEAN\_UP  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:11:35(00:11:21) |  00:01:09(00:01:12) |   9.1(  9.6) |   15:40:44 (Jun19) |   1.74 GB | 1ST\_ST  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:12:15(00:12:01) |  00:00:40(00:00:40) |   5.3(  5.3) |   15:41:24 (Jun19) |   1.74 GB | INTRMD\_CLEAN\_UP  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:12:15(00:12:01) |  00:00:00(00:00:00) |   0.0(  0.0) |   15:41:24 (Jun19) |   1.74 GB | CRB\_ST  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
 00:12:59(00:12:45) |  00:00:44(00:00:44) |   5.8(  5.9) |   15:42:08 (Jun19) |   1.74 GB | FINAL\_CLEAN\_UP  
\--------------------+---------------------+--------------+--------------------+-----------+----------------------  
Number of threads: 8 \* 1   (id: pbs\_debug, time\_info v1.57)  
Info: (\*N\*) indicates data that was populated from previously saved time\_info database  
Info: CPU time includes time of parent \+ longest thread  
Info	: Done incrementally optimizing. \[SYNTH-8\]  
    	: Done incrementally optimizing 'systolic16x16\_baseline'.  
  	flow.cputime  flow.realtime  timing.setup.tns  timing.setup.wns  snapshot  
UM:\*                                                               	syn\_opt  
@file(genus\_b16.tcl) 59: report\_qor	\> flow/reports/genus/b16\_qor.rpt  
@file(genus\_b16.tcl) 60: report\_area   \> flow/reports/genus/b16\_area.rpt  
@file(genus\_b16.tcl) 61: report\_timing \> flow/reports/genus/b16\_timing.rpt  
@file(genus\_b16.tcl) 62: report\_power  \> flow/reports/genus/b16\_power.rpt  
Info	: Joules engine is used. \[RPT-16\]  
    	: Joules engine is being used for the command report\_power.  
Info   : ACTP-0001 \[ACTPInfo\] Activity propagation started for stim\#0 netlist  
   	: systolic16x16\_baseline  
Info   : ACTP-0009 \[ACTPInfo\] Activity Propagation Progress Report : 100%  
Info   : ACTP-0001 Activity propagation ended for stim\#0  
Info   : PWRA-0001 \[PwrInfo\] compute\_power effective options  
   	: \-mode : vectorless  
   	: \-skip\_propagation : 1  
   	: \-frequency\_scaling\_factor : 1.0  
   	: \-use\_clock\_freq : stim  
   	: \-stim :/stim\#0  
   	: \-fromGenus : 1  
Info   : ACTP-0001 Timing initialization started  
Info   : ACTP-0001 Timing initialization ended  
Info   : PWRA-0002 \[PwrInfo\] Skipping activity propagation due to \-skip\_ap  
   	: option....  
Warning: PWRA-0302 \[PwrWarn\] Frequency scaling is not applicable for vectorless  
   	: flow. Ignoring frequency scaling.  
Warning: PWRA-0304 \[PwrWarn\] \-stim option is not applicable with vectorless mode  
   	: of power analysis, ignored this option.  
Info   : PWRA-0002 Started 'vectorless' power computation.  
Info   : PWRA-0009 \[PwrInfo\] Power Computation Progress Report : 100%  
Info   : PWRA-0002 Finished power computation.  
Info   : PWRA-0007 \[PwrInfo\] Completed successfully.  
   	: Info=6, Warn=2, Error=0, Fatal=0  
Output file: flow/reports/genus/b16\_power.rpt  
@file(genus\_b16.tcl) 67: write\_hdl \> flow/netlists/b16\_mapped.v  
@file(genus\_b16.tcl) 68: write\_sdc \> flow/netlists/b16\_mapped.sdc  
Finished SDC export (command execution time mm:ss (real) \= 00:02).  
@file(genus\_b16.tcl) 70: quit

Lic Summary:  
\[15:42:27.124699\] Cdslmd servers: cadence-c2s  
\[15:42:27.124707\] Feature usage summary:  
\[15:42:27.124707\] Genus\_Synthesis

\+-----------+-------------------------+-----+----------------------+---------------------------+  
|   Host	|     	Machine     	| CPU | Physical Memory (MB) | Peak Physical Memory (MB) |  
\+-----------+-------------------------+-----+----------------------+---------------------------+  
| localhost | vlsilab14.srmist.edu.in |  1  |    	1695.9    	|      	2448.2       	|  
\+-----------+-------------------------+-----+----------------------+---------------------------+

\+---------------+----------------------+---------------------------+  
|	Server 	| Physical Memory (MB) | Peak Physical Memory (MB) |  
\+---------------+----------------------+---------------------------+  
| localhost\_1\_0 |    	315.2     	|      	1000.0       	|  
\+---------------+----------------------+---------------------------+

Info	: A super-threading server has been shut down normally. \[ST-112\]  
    	: The server 'localhost\_1\_0' was process '17005' on this host.  
    	: A super-threaded optimization is complete and a CPU server was successfully shut down.  
Normal exit.  
\[student14@vlsilab14 HSA16-AI-Accelerator-main\]$ grep \-A20 "Power Unit" flow/reports/genus/b16\_power.rpt  
Power Unit: W  
PDB Frames: /stim\#0/frame\#0  
  \-------------------------------------------------------------------------  
	Category     	Leakage 	Internal	Switching    	Total	Row%  
  \-------------------------------------------------------------------------  
  	memory 	0.00000e+00  0.00000e+00  0.00000e+00  0.00000e+00   0.00%  
	register 	2.52884e-05  3.53856e-01  1.83482e-02  3.72229e-01  74.39%  
   	latch 	0.00000e+00  0.00000e+00  0.00000e+00  0.00000e+00   0.00%  
   	logic 	2.72466e-05  9.48555e-02  3.32619e-02  1.28145e-01  25.61%  
    	bbox 	0.00000e+00  0.00000e+00  0.00000e+00  0.00000e+00   0.00%  
   	clock 	0.00000e+00  0.00000e+00  0.00000e+00  0.00000e+00   0.00%  
     	pad 	0.00000e+00  0.00000e+00  0.00000e+00  0.00000e+00   0.00%  
      	pm 	0.00000e+00  0.00000e+00  0.00000e+00  0.00000e+00   0.00%  
  \-------------------------------------------------------------------------  
	Subtotal 	5.25351e-05  4.48711e-01  5.16101e-02  5.00374e-01 100.00%  
  Percentage       	0.01%   	89.68%   	10.31%  	100.00% 100.00%  
  \-------------------------------------------------------------------------  
\[student14@vlsilab14 HSA16-AI-Accelerator-main\]$ grep \-A50 "Instance Count" flow/reports/genus/b16\_qor.rpt  
Instance Count  
\--------------  
Leaf Instance Count         	117225  
Physical Instance count          	0  
Sequential Instance Count    	43496  
Combinational Instance Count 	73729  
Hierarchical Instance Count      	0

Area  
\----  
Cell Area                      	0.000  
Physical Cell Area             	0.000  
Total Cell Area (Cell+Physical)	0.000  
Net Area                       	0.000  
Total Area (Cell+Physical+Net) 	0.000

Max Fanout                     	43496 (clk)  
Min Fanout                     	0 (rst\_n)  
Average Fanout                 	2.5  
Terms to net ratio             	3.7758  
Terms to instance ratio        	4.0958  
Runtime                        	792.2427669999994 seconds  
Elapsed Runtime                	782 seconds  
Genus peak memory usage        	2588.15  
Innovus peak memory usage      	no\_value  
Hostname                       	vlsilab14.srmist.edu.in  
\[student14@vlsilab14 HSA16-AI-Accelerator-main\]$ grep \-A20 "Path 1" flow/reports/genus/b16\_timing.rpt  
Path 1: MET (63 ps) Setup Check with Pin result\_reg\[0\]\[3\]\[17\]/CK-\>SE  
      	Group: clk  
 	Startpoint: (R) start  
      	Clock: (R) clk  
   	Endpoint: (R) result\_reg\[0\]\[3\]\[17\]/SE  
      	Clock: (R) clk

                 	Capture   	Launch	   
    	Clock Edge:+	2000        	0	   
    	Drv Adjust:+   	0        	0	   
   	Src Latency:+   	0        	0	   
   	Net Latency:+   	0 (I)    	0 (I)  
       	Arrival:=	2000        	0	   
                                         	   
         	Setup:-  	60             	   
   	Uncertainty:- 	100             	   
 	Required Time:=	1840             	   
  	Launch Clock:-   	0             	   
   	Input Delay:- 	200             	   
     	Data Path:-	1578             	   
         	Slack:=  	63             	   
\[student14@vlsilab14 HSA16-AI-Accelerator-main\]$

\[student14@vlsilab14 HSA16-AI-Accelerator-main\]$ tree flow  
bash: tree: command not found...  
\[student14@vlsilab14 HSA16-AI-Accelerator-main\]$ cd flow  
\[student14@vlsilab14 flow\]$ tree flow  
bash: tree: command not found...  
\[student14@vlsilab14 flow\]$ ^C  
\[student14@vlsilab14 flow\]$ cd ..  
\[student14@vlsilab14 HSA16-AI-Accelerator-main\]$ ls \-R  
.:  
flow  python  README.md  rtl  tb  vectors

./flow:  
constraints  genus  logs  netlists  reports  scripts  waves  xrun

./flow/constraints:

./flow/genus:

./flow/logs:

./flow/netlists:

./flow/reports:  
genus  xrun

./flow/reports/genus:

./flow/reports/xrun:

./flow/scripts:

./flow/waves:

./flow/xrun:

./python:  
golden\_model

./python/golden\_model:  
matmul\_reference.py

./rtl:  
baseline  common

./rtl/baseline:  
pe\_baseline.sv  systolic16x16\_baseline.sv

./rtl/common:  
hsa\_params.svh

./tb:  
baseline

./tb/baseline:  
tb\_b16.sv  tb\_pe\_baseline.sv

./vectors:  
dense  identity  ones  sparse50  sparse70  sparse90  sparse95

./vectors/dense:  
A\_matrix.mem	B\_matrix.mem	C\_expected.mem  
A\_readable.txt  B\_readable.txt  C\_readable.txt

./vectors/identity:  
A\_matrix.mem	B\_matrix.mem	C\_expected.mem  
A\_readable.txt  B\_readable.txt  C\_readable.txt

./vectors/ones:  
A\_matrix.mem	B\_matrix.mem	C\_expected.mem  
A\_readable.txt  B\_readable.txt  C\_readable.txt

./vectors/sparse50:  
A\_matrix.mem	B\_matrix.mem	C\_expected.mem  
A\_readable.txt  B\_readable.txt  C\_readable.txt

./vectors/sparse70:  
A\_matrix.mem	B\_matrix.mem	C\_expected.mem  
A\_readable.txt  B\_readable.txt  C\_readable.txt

./vectors/sparse90:  
A\_matrix.mem	B\_matrix.mem	C\_expected.mem  
A\_readable.txt  B\_readable.txt  C\_readable.txt

./vectors/sparse95:  
A\_matrix.mem	B\_matrix.mem	C\_expected.mem  
A\_readable.txt  B\_readable.txt  C\_readable.txt  
\[student14@vlsilab14 HSA16-AI-Accelerator-main\]$ ^C  
\[student14@vlsilab14 HSA16-AI-Accelerator-main\]$ ^C  
\[student14@vlsilab14 HSA16-AI-Accelerator-main\]$

\[student14@vlsilab14 lib\]$ pwfd  
bash: pwfd: command not found...  
\[student14@vlsilab14 lib\]$ pwd  
/home/Cadence/FOUNDRY/digital/45nm/dig/lib  
\[student14@vlsilab14 lib\]$ ls  
elccfg     	fast.lib  model.ff  model.tt   slow.ecsm.lib  typical.ecsm.lib  
fast.ecsm.lib  model 	model.ss  setup.elc  slow.lib   	typical.lib  
\[student14@vlsilab14 lib\]$

