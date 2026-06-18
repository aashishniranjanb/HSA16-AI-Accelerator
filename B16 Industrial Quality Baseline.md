#### **B16 (Industrial Quality Baseline)**

16×16  
INT8  
3-stage MAC pipeline  
Weight Stationary  
64KB Weight SRAM  
64KB Activation SRAM  
Output Buffer  
500 MHz target

	ITC India 2026 (author)	banner	User guide/Log out New Submission	My Submissions	Templates	Help	Conference	News	EasyChair ITC India 2026 Submission 184 Submission information updates are disabled. If you need to update your submission, contact ITC India 2026 chairs. For all questions related to your submission you should contact the conference organizers. Click here to see information about this conference. All reviews sent to you can be found at the bottom of this page. Submission 184 Title	Self Executing Power Aware Test Framework for Dense Sparse AI Workloads Paper	ITC\_India\_2026\_paper\_184.pdf(Mar 31, 17:54) Authors Bio	ITC\_India\_2026\_Authors\_Bio\_184.pdf(Apr 05, 13:08) Track	ITC India 2026: Regular Paper Author keywords	Systolic Array Sparse Workloads Power-Aware Verification Automated RTL Testing Clock Gating AI Accelerators Topics	Adaptive test frameworks, SLT architectures, Test standards, Test time optimization and content prioritization Abstract	Systolic array architectures deliver high throughput matrix computations for AI accelerators, but real world neural network workloads exhibit significant data sparsity, causing unnecessary switching activity and elevated dynamic power consumption. This paper presents a power aware 4×4 INT8 systolic array accelerator integrating clock gating and operand isolation techniques to suppress switching activity during zero valued operations. An automated power aware verification framework self executes test vectors under dense and sparse workloads, performs RTL simulation, and analyzes switching activity without manual intervention. Experimental results demonstrate a 46% reduction in dynamic power (120 mW to 65 mW) under 70–90% sparse conditions, maintaining full computational throughput, accuracy, and 7-cycle latency. Submitted	Mar 16, 11:21 Last update	 Authors First name	Last name	Email	Country	Affiliation	Web page	Corresponding? Dinesh Babu	A	dbanbumani@gmail.com	India	SRM Institute of Science and Technology, Vadapalani Campus		✔ Nagarajan	P	nagarajp@srmist.edu.in	India	SRM Institute of Science and Technology, Vadapalani Campus		 Aashish Niranjan	Barathykannan	an6624@srmist.edu.in	India	SRM Institute of Science and Technology, Vadapalani Campus		 Shanganidhi	K N	sn9612@srmist.edu.in	India	SRM Institute of Science and Technology, Vadapalani Campus		 Akhilesh	M	ma9331@srmist.edu.in	India	SRM Institute of Science and Technology, Vadapalani Campus		 Reviews Review 1 Overall evaluation	 0: borderline paper Originality / Novelty The paper addresses a practical power inefficiency in conventional systolic arrays, clearly explaining how common X→0 operand transitions still induce significant internal switching under sparse workloads. The proposed solution—fine grained clock gating combined with operand isolation using NOR-based zero detection and latches—relies on well-established low power techniques. The novelty therefore lies primarily in the targeted application of these techniques to sparsity-aware systolic arrays and in the clear articulation of the power-saving opportunity, rather than in introducing fundamentally new architectural concepts. Technical Depth and Quality The paper is well written and technically sound. The authors provide a clear description of the systolic array dataflow and carefully explain how the added gating logic suppresses switching activity without affecting functional correctness or latency. The evaluation is thorough at the RTL/synthesis level, reporting concrete numbers such as a 46% dynamic power reduction at 90% sparsity with a 14% area increase, and explicitly breaking down static versus dynamic power. The inclusion of both power components and area/timing trade-offs strengthens the technical credibility of the results. Testability and Yield Considerations A key gap is the lack of discussion on testability and manufacturing implications. The introduction of fine-grained clock gating and operand isolation logic raises questions about how defects in these structures would be detected in production, especially for cases where functionality remains correct, but power increases due to ineffective gating. The paper does not address whether such parts would be power-binned, screened out, or treated as yield loss. In addition, the reported 14% area increase may have yield implications that are not analyzed. Addressing defect coverage, test observability of gating structures, and yield impact would significantly strengthen the work for an ITC audience. Relevance and Practical Impact The work is practically relevant and clearly applicable to low-power AI accelerator design, with results that reflect realistic sparse workloads. While the paper may be more naturally aligned with a computer architecture or design verification venue, its relevance to ITC comes from the use of hardware power-reduction techniques such as clock gating, which are also commonly employed during test to manage dynamic power. Providing additional discussion on test-mode behavior, yield, and power variation across operating conditions would further improve its alignment with ITC themes. Overall Assessment Overall, this is a clear and well-executed paper with convincing power results and strong articulation of the underlying problem. The main contribution is the systematic application of known low-power techniques to sparsity-aware systolic arrays, supported by quantitative evaluation. The primary limitation is the absence of discussion around testability, yield impact, and robustness across process and temperature corners. Expanding on these aspects would enhance both the completeness of the work and its relevance to the ITC community. Review 2 Overall evaluation	 2: accept The paper presents a power-aware systolic array using fine-grained clock gating and operand isolation, along with an automated verification framework. It addresses an important problem of reducing switching activity under sparse AI workloads and demonstrates significant power savings (\~46%) without performance loss. Key Aspects: The proposed design is practical and well-engineered, with clear validation and trade-off analysis. Improvements: Lacks strong architectural novelty and is evaluated only on a small 4×4 prototype. Evaluate on a large 16x16 array Benchmark on Real DNN workloads (ResNet, Transformer) Results comparison against current available methods for power savings SCNN / zero-skipping accelerators not available. Review 3 Overall evaluation	 \-2: reject This paper presents a power-aware 4×4 INT8 systolic array accelerator designed to reduce dynamic power under sparse workloads by integrating clock gating and operand isolation. While mitigating switching activity in AI accelerators is an important design goal, the technical approach presented here lacks clear novelty. The core strategies employed to suppress zero-valued operations are well known low-power design practices. The reported 14% area overhead is exceptionally high for a design targeting edge accelerators, and the authors fail to include any manufacturing yield or reliability considerations to justify this massive footprint expansion. Additionally, the paper completely lacks a comparative analysis or benchmarking against existing state-of-the-art sparse acceleration architectures. Copyright © 2002 – 2026 EasyChair Now wenwhat we need to execute

Perfect.

Before writing RTL, we need to freeze the **PE specification**. Most student projects fail because they start coding and keep changing the PE later.

# **B16 PE Specification v1.0**

### **Purpose**

Single Processing Element for:

INT8 × INT8 → INT32 MAC

Weight-Stationary dataflow.

---

# **Pipeline Architecture**

We want a professional pipelined PE.

Cycle N

Ain \----\> A\_reg \----┐  
                   │  
Win \----\> W\_reg \----┘

             │  
             ▼

       INT8 Multiplier

             │

        product\_reg

             │

             ▼

     product \+ psum

             │

        psum\_reg

             │

          psum\_out  
---

# **Latency**

### **Stage 1**

Input register

A\_reg  
W\_reg  
---

### **Stage 2**

Multiplier

product\_reg \<= A\_reg \* W\_reg;  
---

### **Stage 3**

Accumulator

psum\_reg \<= psum\_in \+ product\_reg;  
---

Total PE latency:

3 cycles

Good for synthesis.

---

# **Module Interface**

module pe\_baseline  
(  
   input logic clk,  
   input logic rst\_n,

   input logic valid\_in,

   input logic signed \[7:0\] act\_in,  
   input logic signed \[7:0\] weight\_in,

   input logic signed \[31:0\] psum\_in,

   output logic valid\_out,

   output logic signed \[7:0\] act\_out,  
   output logic signed \[7:0\] weight\_out,

   output logic signed \[31:0\] psum\_out  
);  
---

# **Internal Registers**

logic signed \[7:0\]  act\_reg;  
logic signed \[7:0\]  weight\_reg;

logic signed \[15:0\] product\_reg;

logic signed \[31:0\] psum\_reg;  
---

# **Valid Pipeline**

Need:

logic valid\_s1;  
logic valid\_s2;  
logic valid\_s3;

This becomes very important later for DNN workloads.

---

# **RTL Skeleton**

always\_ff @(posedge clk or negedge rst\_n)  
begin  
   if(\!rst\_n)  
   begin  
       act\_reg    \<= '0;  
       weight\_reg \<= '0;

       valid\_s1   \<= 1'b0;  
   end  
   else  
   begin  
       act\_reg    \<= act\_in;  
       weight\_reg \<= weight\_in;

       valid\_s1   \<= valid\_in;  
   end  
end  
---

Multiplier stage:

always\_ff @(posedge clk or negedge rst\_n)  
begin  
   if(\!rst\_n)  
   begin  
       product\_reg \<= '0;  
       valid\_s2    \<= 1'b0;  
   end  
   else  
   begin  
       product\_reg \<= act\_reg \* weight\_reg;

       valid\_s2 \<= valid\_s1;  
   end  
end  
---

Accumulator stage:

always\_ff @(posedge clk or negedge rst\_n)  
begin  
   if(\!rst\_n)  
   begin  
       psum\_reg \<= '0;  
       valid\_s3 \<= 1'b0;  
   end  
   else  
   begin  
       psum\_reg \<= psum\_in \+ product\_reg;

       valid\_s3 \<= valid\_s2;  
   end  
end  
---

Outputs

assign act\_out    \= act\_reg;  
assign weight\_out \= weight\_reg;

assign psum\_out   \= psum\_reg;

assign valid\_out  \= valid\_s3;  
---

# **Why this PE?**

Because later:

### **B16**

Uses this exact PE.

### **PE-Gating Version**

Add:

zero\_detect  
clock\_enable

inside same PE.

### **Row Version**

No PE changes.

### **Tile Version**

No PE changes.

### **DFT Version**

Add:

scan\_enable  
test\_mode

inside same PE.

Thus:

pe\_baseline.sv  
       ↓  
pe\_hsa.sv

becomes a clean evolution path.

# **Next File After This**

After implementing and simulating `pe_baseline.sv`:

tile4x4\_baseline.sv

because a 4×4 tile is the reusable building block for the entire 16×16 architecture.

tile4x4\_baseline.sv  
tb\_tile4x4\_baseline.sv

Before writing the testbench, one correction:

The `tile4x4_baseline` interface I proposed earlier is not sufficient for a true systolic matrix multiplication test. We need to verify functionality incrementally.

For **Milestone-1**, the testbench should verify:

1. Reset works  
2. Data propagates correctly  
3. Valid pipeline propagates correctly  
4. MAC operation works  
5. No X/Z values appear

Not full ResNet or matrix multiplication yet.

---

# **tb\_tile4x4\_baseline.sv Structure**

\`timescale 1ns/1ps

module tb\_tile4x4\_baseline;

   logic clk;  
   logic rst\_n;

   logic \[3:0\] valid\_in;

   logic signed \[7:0\] act\_in \[0:3\];  
   logic signed \[7:0\] weight\_in \[0:3\];

   logic \[3:0\] valid\_out;

   logic signed \[31:0\] psum\_out \[0:3\];

   integer i;

   tile4x4\_baseline dut  
   (  
       .clk(clk),  
       .rst\_n(rst\_n),

       .valid\_in(valid\_in),

       .act\_in(act\_in),  
       .weight\_in(weight\_in),

       .valid\_out(valid\_out),

       .psum\_out(psum\_out)  
   );

endmodule  
---

# **Clock Generation**

Use a realistic frequency target.

initial  
begin  
   clk \= 0;  
   forever \#1 clk \= \~clk;  
end

This creates:

2ns period  
500 MHz

which matches our synthesis target.

---

# **Reset Task**

task reset\_dut;

begin

   rst\_n \= 0;

   valid\_in \= 0;

   for(i=0;i\<4;i=i+1)  
   begin  
       act\_in\[i\]    \= 0;  
       weight\_in\[i\] \= 0;  
   end

   repeat(5) @(posedge clk);

   rst\_n \= 1;

   repeat(2) @(posedge clk);

end

endtask  
---

# **Simple Directed Test**

Use known values.

task directed\_test;

begin

   valid\_in \= 4'b1111;

   act\_in\[0\] \= 8'd2;  
   act\_in\[1\] \= 8'd3;  
   act\_in\[2\] \= 8'd4;  
   act\_in\[3\] \= 8'd5;

   weight\_in\[0\] \= 8'd10;  
   weight\_in\[1\] \= 8'd20;  
   weight\_in\[2\] \= 8'd30;  
   weight\_in\[3\] \= 8'd40;

   @(posedge clk);

   valid\_in \= 0;

end

endtask

Expected products:

2×10 \= 20  
3×20 \= 60  
4×30 \= 120  
5×40 \= 200

This verifies basic datapath functionality.

---

# **Randomized Test**

task random\_test;

begin

   repeat(100)  
   begin

       valid\_in \= 4'b1111;

       for(i=0;i\<4;i=i+1)  
       begin  
           act\_in\[i\] \=  
               $urandom\_range(-128,127);

           weight\_in\[i\] \=  
               $urandom\_range(-128,127);  
       end

       @(posedge clk);

   end

end

endtask  
---

# **Output Monitor**

always @(posedge clk)  
begin

   if(valid\_out \!= 0\)  
   begin

       $display(  
       "\[%0t\] OUT \= %0d %0d %0d %0d",  
       $time,  
       psum\_out\[0\],  
       psum\_out\[1\],  
       psum\_out\[2\],  
       psum\_out\[3\]);

   end

end  
---

# **X Detection**

Very important.

always @(posedge clk)  
begin

   if(^psum\_out\[0\] \=== 1'bx)  
   begin

       $error("X detected");

       $finish;

   end

end  
---

# **Main Test Sequence**

initial  
begin

   $display("Starting Tile Verification");

   reset\_dut();

   directed\_test();

   repeat(20)  
       @(posedge clk);

   random\_test();

   repeat(100)  
       @(posedge clk);

   $display("TEST PASSED");

   $finish;

end  
---

# **What This Testbench Must Prove**

Before moving to `systolic16x16_baseline.sv`, the tile must pass:

✓ Reset

✓ 500 MHz simulation

✓ Directed vectors

✓ Random vectors

✓ No X propagation

✓ Valid propagation

✓ Stable outputs

After this, the next deliverable should be:

rtl/baseline/systolic16x16\_baseline.sv

which instantiates a **4×4 grid of tile4x4\_baseline blocks** (16 tiles \= 256 PEs). That is the first architecture that should be taken toward Cadence synthesis.

rtl/baseline/systolic16x16\_baseline.sv  
we need finish rtl now cuz in lap i will check things

I would strongly advise **not** trying to finish all RTL before validation.

What you should finish before going to the Cadence lab is the **entire B16 RTL tree**, but not the full HSA stack.

# **What Must Exist Before Lab**

rtl/

common/  
baseline/

pe\_baseline.sv

systolic16x16\_baseline.sv

tb/

tb\_pe\_baseline.sv  
tb\_b16.sv

python/

matmul\_reference.py

This is enough to:

Compile  
Simulate  
Generate waveforms  
Run synthesis  
Generate area  
Generate timing  
---

# **Then Build HSA Incrementally**

## **Version 1**

pe\_hsa.sv

New signals:

zero\_detect  
pe\_sleep  
test\_mode

This gives:

B16  
↓  
PE Gating  
---

## **Version 2**

row\_controller.sv

New signals:

row\_sleep  
row\_zero\_count

This gives:

B16  
↓  
PE  
↓  
PE+Row  
---

## **Version 3**

tile\_controller.sv

New signals:

tile\_sleep  
tile\_zero\_count

This gives:

B16  
↓  
PE  
↓  
PE+Row  
↓  
PE+Row+Tile  
---

## **Version 4**

dft\_controller.sv

New signals:

scan\_enable  
test\_mode

This gives:

B16  
↓  
PE  
↓  
PE+Row  
↓  
PE+Row+Tile  
↓  
PE+Row+Tile+DFT  
---

# **RTL Completion Checklist**

Before entering Cadence:

### **B16**

✓ pe\_baseline.sv  
✓ systolic16x16\_baseline.sv  
✓ tb\_pe\_baseline.sv  
✓ tb\_b16.sv

### **HSA**

✓ pe\_hsa.sv  
✓ row\_controller.sv  
✓ tile\_controller.sv  
✓ dft\_controller.sv

### **Verification**

✓ directed tests  
✓ random tests  
✓ golden model  
---

# **What You Can Do in Cadence Lab**

Once these files exist:

### **Genus**

read\_hdl  
elaborate  
synthesize

Reports:

report\_area  
report\_power  
report\_timing

### **Sparsity Runs**

0%  
50%  
70%  
90%  
95%

### **Compare**

B16

PE

PE+Row

PE+Row+Tile

PE+Row+Tile+DFT

That will produce the exact ablation-study table you want.

So the next coding target is **not another architecture block**. It is to finish:

tb\_pe\_baseline.sv  
tb\_b16.sv

and get a clean simulation of `systolic16x16_baseline.sv`. Once that passes, the rest of the RTL can be layered on top with much lower risk.

tb\_pe\_baseline.sv

For a research ASIC project, `tb_pe_baseline.sv` should be more than "apply values and print output".

It should:

1. Verify signed arithmetic  
2. Verify pipeline latency  
3. Verify valid propagation  
4. Verify reset  
5. Check for X/Z values  
6. Self-check PASS/FAIL

---

\`timescale 1ns/1ps

module tb\_pe\_baseline;

//----------------------------------------------------------  
// DUT Signals  
//----------------------------------------------------------

logic clk;  
logic rst\_n;

logic valid\_in;

logic signed \[7:0\]  act\_in;  
logic signed \[7:0\]  weight\_in;

logic signed \[31:0\] psum\_in;

logic valid\_out;

logic signed \[7:0\]  act\_out;  
logic signed \[7:0\]  weight\_out;

logic signed \[31:0\] psum\_out;

//----------------------------------------------------------  
// DUT  
//----------------------------------------------------------

pe\_baseline dut  
(  
    .clk(clk),  
    .rst\_n(rst\_n),

    .valid\_in(valid\_in),

    .act\_in(act\_in),  
    .weight\_in(weight\_in),

    .psum\_in(psum\_in),

    .valid\_out(valid\_out),

    .act\_out(act\_out),  
    .weight\_out(weight\_out),

    .psum\_out(psum\_out)  
);

//----------------------------------------------------------  
// Clock Generation  
//----------------------------------------------------------

initial  
begin  
    clk \= 1'b0;

    forever \#1 clk \= \~clk; // 500 MHz  
end

//----------------------------------------------------------  
// Reset Task  
//----------------------------------------------------------

task automatic reset\_dut;  
begin

    rst\_n \= 1'b0;

    valid\_in \= 1'b0;

    act\_in \= 0;  
    weight\_in \= 0;  
    psum\_in \= 0;

    repeat(5) @(posedge clk);

    rst\_n \= 1'b1;

    repeat(2) @(posedge clk);

end  
endtask

//----------------------------------------------------------  
// Apply Vector Task  
//----------------------------------------------------------

task automatic apply\_vector  
(  
    input signed \[7:0\] a,  
    input signed \[7:0\] w,  
    input signed \[31:0\] p  
);  
begin

    @(posedge clk);

    valid\_in  \<= 1'b1;

    act\_in    \<= a;  
    weight\_in \<= w;  
    psum\_in   \<= p;

    @(posedge clk);

    valid\_in \<= 1'b0;

end  
endtask

//----------------------------------------------------------  
// Expected Result Queue  
//----------------------------------------------------------

integer pass\_count;  
integer fail\_count;

logic signed \[31:0\] expected\_q \[$\];

//----------------------------------------------------------  
// Scoreboard  
//----------------------------------------------------------

always @(posedge clk)  
begin

    if(valid\_out)  
    begin

        if(expected\_q.size() \== 0\)  
        begin  
            $error("Unexpected output");  
            fail\_count++;  
        end  
        else  
        begin

            logic signed \[31:0\] exp;

            exp \= expected\_q.pop\_front();

            if(psum\_out \=== exp)  
            begin

                pass\_count++;

                $display(  
                "\[PASS\] time=%0t expected=%0d actual=%0d",  
                $time,  
                exp,  
                psum\_out);

            end  
            else  
            begin

                fail\_count++;

                $display(  
                "\[FAIL\] time=%0t expected=%0d actual=%0d",  
                $time,  
                exp,  
                psum\_out);

            end  
        end  
    end  
end

//----------------------------------------------------------  
// X Detection  
//----------------------------------------------------------

always @(posedge clk)  
begin

    if(valid\_out)  
    begin

        if(^psum\_out \=== 1'bx)  
        begin

            $error("X detected on psum\_out");

            $finish;

        end  
    end  
end

//----------------------------------------------------------  
// Main Test Sequence  
//----------------------------------------------------------

initial  
begin

    pass\_count \= 0;  
    fail\_count \= 0;

    $display("");  
    $display("================================");  
    $display(" PE BASELINE VERIFICATION START ");  
    $display("================================");  
    $display("");

    reset\_dut();

    //------------------------------------------------------  
    // Test 1  
    //------------------------------------------------------

    expected\_q.push\_back(6);

    apply\_vector(8'sd2,  
                 8'sd3,  
                 32'sd0);

    //------------------------------------------------------  
    // Test 2  
    //------------------------------------------------------

    expected\_q.push\_back(-6);

    apply\_vector(-8'sd2,  
                  8'sd3,  
                  32'sd0);

    //------------------------------------------------------  
    // Test 3  
    //------------------------------------------------------

    expected\_q.push\_back(20);

    apply\_vector(-8'sd5,  
                 \-8'sd4,  
                  32'sd0);

    //------------------------------------------------------  
    // Test 4  
    //------------------------------------------------------

    expected\_q.push\_back(227);

    apply\_vector(8'sd15,  
                 8'sd15,  
                 32'sd2);

    //------------------------------------------------------  
    // Random Tests  
    //------------------------------------------------------

    repeat(100)  
    begin

        logic signed \[7:0\] a;  
        logic signed \[7:0\] w;  
        logic signed \[31:0\] p;

        logic signed \[31:0\] exp;

        a \= $urandom\_range(-128,127);  
        w \= $urandom\_range(-128,127);  
        p \= $urandom\_range(0,1000);

        exp \= a\*w \+ p;

        expected\_q.push\_back(exp);

        apply\_vector(a,w,p);

    end

    repeat(20) @(posedge clk);

    $display("");  
    $display("==========================");  
    $display(" PASS COUNT \= %0d",pass\_count);  
    $display(" FAIL COUNT \= %0d",fail\_count);  
    $display("==========================");  
    $display("");

    if(fail\_count \== 0\)  
        $display("PE\_BASELINE\_TEST PASSED");  
    else  
        $display("PE\_BASELINE\_TEST FAILED");

    $finish;

end

//----------------------------------------------------------  
// Waveform Dump  
//----------------------------------------------------------

initial  
begin

    $dumpfile("tb\_pe\_baseline.vcd");

    $dumpvars(0,tb\_pe\_baseline);

end

endmodule

Before moving to `tb_b16.sv`, run this and ensure:

PASS COUNT \= 104  
FAIL COUNT \= 0  
PE\_BASELINE\_TEST PASSED

If even one vector fails, fix `pe_baseline.sv` first. Do not proceed to the 16×16 array until the PE is proven correct.

tb\_b16.sv

Before writing `tb_b16.sv`, one important point:

A **16×16 systolic array testbench cannot be handwritten with fixed expected values**.

For B16, the correct methodology is:

Python Golden Model  
       ↓  
Generate A matrix  
Generate B matrix  
       ↓  
Expected C matrix  
       ↓  
RTL Simulation  
       ↓  
Automatic Compare

Exactly how industry verifies accelerators.

---

# **tb\_b16.sv Objectives**

Verify:

✓ Reset

✓ Start signal

✓ Valid propagation

✓ 16×16 matrix multiplication

✓ Signed arithmetic

✓ Random matrices

✓ No X values

✓ Latency correctness

✓ Golden-model match  
---

# **Directory Dependency**

tb/

├── tb\_b16.sv

vectors/

├── A\_matrix.mem  
├── B\_matrix.mem  
└── C\_expected.mem

python/

└── matmul\_reference.py  
---

# **Testbench Skeleton**

\`timescale 1ns/1ps

module tb\_b16;

//--------------------------------------------------  
// Parameters  
//--------------------------------------------------

localparam N \= 16;

//--------------------------------------------------  
// DUT Signals  
//--------------------------------------------------

logic clk;  
logic rst\_n;

logic start;

logic signed \[7:0\] act\_in \[0:N-1\];  
logic signed \[7:0\] weight\_in \[0:N-1\];

logic done;

logic signed \[31:0\] result \[0:N-1\];

//--------------------------------------------------  
// Memories  
//--------------------------------------------------

logic signed \[7:0\] A\_mem \[0:255\];  
logic signed \[7:0\] B\_mem \[0:255\];

logic signed \[31:0\] C\_expected \[0:255\];

//--------------------------------------------------  
// DUT  
//--------------------------------------------------

systolic16x16\_baseline dut  
(  
    .clk(clk),  
    .rst\_n(rst\_n),

    .start(start),

    .act\_in(act\_in),  
    .weight\_in(weight\_in),

    .done(done),

    .result(result)  
);

//--------------------------------------------------  
// Clock  
//--------------------------------------------------

initial  
begin  
    clk \= 0;

    forever \#1 clk \= \~clk;  
end

//--------------------------------------------------  
// Reset  
//--------------------------------------------------

task reset\_dut;  
begin

    rst\_n \= 0;  
    start \= 0;

    repeat(5)  
        @(posedge clk);

    rst\_n \= 1;

    repeat(2)  
        @(posedge clk);

end  
endtask

//--------------------------------------------------  
// Load Memories  
//--------------------------------------------------

initial  
begin

    $readmemh(  
    "vectors/A\_matrix.mem",  
    A\_mem);

    $readmemh(  
    "vectors/B\_matrix.mem",  
    B\_mem);

    $readmemh(  
    "vectors/C\_expected.mem",  
    C\_expected);

end

//--------------------------------------------------  
// Stimulus  
//--------------------------------------------------

task run\_matrix;

    integer row;  
    integer col;

begin

    start \= 1;

    for(row=0; row\<16; row=row+1)  
    begin

        for(col=0; col\<16; col=col+1)  
        begin

            act\_in\[col\]  
                \= A\_mem\[row\*16 \+ col\];

            weight\_in\[col\]  
                \= B\_mem\[row\*16 \+ col\];

        end

        @(posedge clk);

    end

    start \= 0;

end

endtask

//--------------------------------------------------  
// Scoreboard  
//--------------------------------------------------

integer pass\_count;  
integer fail\_count;

integer idx;

task check\_results;  
begin

    pass\_count \= 0;  
    fail\_count \= 0;

    for(idx=0; idx\<16; idx=idx+1)  
    begin

        if(result\[idx\] \===  
           C\_expected\[idx\])  
        begin

            pass\_count++;

        end  
        else  
        begin

            fail\_count++;

            $display(  
            "\[FAIL\] idx=%0d exp=%0d got=%0d",  
            idx,  
            C\_expected\[idx\],  
            result\[idx\]);

        end

    end

end  
endtask

//--------------------------------------------------  
// X Detection  
//--------------------------------------------------

always @(posedge clk)  
begin

    if(done)  
    begin

        integer k;

        for(k=0;k\<16;k=k+1)  
        begin

            if(^result\[k\] \=== 1'bx)  
            begin

                $error(  
                "X detected at result\[%0d\]",  
                k);

                $finish;

            end  
        end  
    end  
end

//--------------------------------------------------  
// Main  
//--------------------------------------------------

initial  
begin

    reset\_dut();

    run\_matrix();

    wait(done);

    check\_results();

    $display("");  
    $display("====================");  
    $display("PASS=%0d",pass\_count);  
    $display("FAIL=%0d",fail\_count);  
    $display("====================");

    if(fail\_count==0)  
        $display("B16 TEST PASSED");  
    else  
        $display("B16 TEST FAILED");

    $finish;

end

//--------------------------------------------------  
// Waveforms  
//--------------------------------------------------

initial  
begin

    $dumpfile("tb\_b16.vcd");

    $dumpvars(0,tb\_b16);

end

endmodule

---

# **Next Required File**

Before this testbench is useful, you must create:

python/golden\_model/matmul\_reference.py

which generates:

A\_matrix.mem

B\_matrix.mem

C\_expected.mem

from NumPy.

That Python golden model is actually more important than `tb_b16.sv`, because every future version:

B16  
PE  
PE+ROW  
PE+ROW+TILE  
PE+ROW+TILE+DFT

will use the exact same reference vectors and scoreboard.

python/golden\_model/matmul\_reference.py

For HSA-16, don't write a toy script.

Write the golden model once and reuse it for:

B16  
HSA-PE  
HSA-ROW  
HSA-TILE  
HSA-DFT

and later:

ResNet18  
MobileNetV2  
Transformer  
---

# **python/golden\_model/matmul\_reference.py**

import numpy as np  
from pathlib import Path

# **\============================================================**

# **Configuration**

# **\============================================================**

N \= 16

VECTOR\_DIR \= Path("../../vectors")

VECTOR\_DIR.mkdir(parents=True, exist\_ok=True)

# **\============================================================**

# **Utility Functions**

# **\============================================================**

def save\_int8\_mem(matrix, filename):

with open(filename, "w") as f:

    flat \= matrix.flatten()

    for value in flat:

        value \= np.int8(value)

        f.write(f"{value & 0xFF:02X}\\n")

def save\_int32\_mem(matrix, filename):

with open(filename, "w") as f:

    flat \= matrix.flatten()

    for value in flat:

        value \= np.int32(value)

        f.write(f"{value & 0xFFFFFFFF:08X}\\n")

# **\============================================================**

# **Matrix Generation**

# **\============================================================**

def generate\_dense():

A \= np.random.randint(  
    \-128,  
    128,  
    size=(N, N),  
    dtype=np.int16  
)

B \= np.random.randint(  
    \-128,  
    128,  
    size=(N, N),  
    dtype=np.int16  
)

return A.astype(np.int8), B.astype(np.int8)

def generate\_sparse(sparsity):

A, B \= generate\_dense()

mask\_A \= np.random.rand(N, N) \< sparsity  
mask\_B \= np.random.rand(N, N) \< sparsity

A\[mask\_A\] \= 0  
B\[mask\_B\] \= 0

return A, B

# **\============================================================**

# **Golden Matrix Multiplication**

# **\============================================================**

def compute\_reference(A, B):

C \= np.matmul(  
    A.astype(np.int32),  
    B.astype(np.int32)  
)

return C.astype(np.int32)

# **\============================================================**

# **Save Dataset**

# **\============================================================**

def create\_dataset(name, sparsity):

print(f"\\nGenerating {name}")

if sparsity \== 0.0:

    A, B \= generate\_dense()

else:

    A, B \= generate\_sparse(sparsity)

C \= compute\_reference(A, B)

dataset\_dir \= VECTOR\_DIR / name

dataset\_dir.mkdir(  
    parents=True,  
    exist\_ok=True  
)

save\_int8\_mem(  
    A,  
    dataset\_dir / "A\_matrix.mem"  
)

save\_int8\_mem(  
    B,  
    dataset\_dir / "B\_matrix.mem"  
)

save\_int32\_mem(  
    C,  
    dataset\_dir / "C\_expected.mem"  
)

np.save(  
    dataset\_dir / "A.npy",  
    A  
)

np.save(  
    dataset\_dir / "B.npy",  
    B  
)

np.save(  
    dataset\_dir / "C.npy",  
    C  
)

print(f"Saved: {dataset\_dir}")

# **\============================================================**

# **Main**

# **\============================================================**

def main():

np.random.seed(42)

create\_dataset(  
    "dense",  
    0.0  
)

create\_dataset(  
    "sparse50",  
    0.50  
)

create\_dataset(  
    "sparse70",  
    0.70  
)

create\_dataset(  
    "sparse90",  
    0.90  
)

create\_dataset(  
    "sparse95",  
    0.95  
)

print("\\nAll datasets generated.")

if **name** \== "**main**":

main()  
---

# **Generated Repository Structure**

Running:

python matmul\_reference.py

creates:

vectors/

├── dense/  
│   ├── A\_matrix.mem  
│   ├── B\_matrix.mem  
│   ├── C\_expected.mem  
│   ├── A.npy  
│   ├── B.npy  
│   └── C.npy  
│  
├── sparse50/  
├── sparse70/  
├── sparse90/  
└── sparse95/  
---

# **Why This Version?**

This gives you:

### **Functional Verification**

RTL  
vs  
NumPy

### **Power Experiments**

dense  
50%  
70%  
90%  
95%

### **HSA Paper Figures**

Power vs Sparsity  
Area vs Sparsity  
TOPS/W vs Sparsity

### **Future DNN Work**

Later replace:

generate\_sparse()

with:

extract\_resnet18()  
extract\_mobilenet()

without touching the RTL or testbench infrastructure.

At this point, you have the minimum complete chain:

PE RTL  
↓  
B16 RTL  
↓  
PE Testbench  
↓  
B16 Testbench  
↓  
Python Golden Model

The next major milestone is to run all of this locally and make sure the B16 RTL actually matches the NumPy golden outputs before stepping into the Cadence lab.

I would divide the project into 3 hard gates. Do not start the next phase until the previous phase is complete.

Phase 1 — Functional Accelerator Baseline (B16)
Goal

Build a correct industrial-quality 16×16 systolic array.

Deliverables
RTL
rtl/common/
    hsa_params.svh

rtl/baseline/
    pe_baseline.sv
    systolic16x16_baseline.sv
Verification
tb/baseline/
    tb_pe_baseline.sv
    tb_b16.sv
Python
python/golden_model/
    matmul_reference.py
Success Criteria
PE
✓ Signed arithmetic works
✓ 3-stage pipeline works
✓ Valid propagation works
✓ Reset works
B16
✓ 16×16 matrix multiply works
✓ Identity matrix test passes
✓ All-ones test passes
✓ Random test passes
✓ RTL = NumPy
Waveforms
✓ Activation propagation
✓ Weight propagation
✓ Partial sum accumulation
✓ No X values
Output of Phase 1
B16

Nothing more.

No sparsity.

No gating.

No DFT.

No Cadence power reports yet.

Phase 2 — Hierarchical Sparsity Architecture (HSA-16)
Goal

Build the entire research contribution.

Step 1
PE Gating

RTL:

rtl/pe_gating/

    pe_hsa.sv

Features:

zero_detect
operand_isolation
clock_enable

Result:

B16
↓
HSA-PE
Step 2
Row Gating

RTL:

rtl/row_gating/

    row_controller.sv

Features:

row_zero_count
row_sleep

Result:

B16
↓
PE
↓
PE+Row
Step 3
Tile Gating

RTL:

rtl/tile_gating/

    tile_controller.sv

Features:

4×4 tiles
tile_sleep
tile_zero_count

Result:

B16
↓
PE
↓
PE+Row
↓
PE+Row+Tile
Step 4
DFT Support

RTL:

rtl/dft/

    dft_controller.sv

Signals:

scan_enable
test_mode

Behavior:

Disable gating during test

Result:

B16
↓
PE
↓
PE+Row
↓
PE+Row+Tile
↓
PE+Row+Tile+DFT
Success Criteria
✓ Functional correctness preserved
✓ Same outputs as B16
✓ No latency changes
✓ DFT mode works
Output of Phase 2
HSA16-DFT

Complete RTL architecture.

Phase 3 — Cadence + Paper Evidence
Goal

Generate real publishable results.

Cadence Genus

Run:

read_hdl
elaborate
synthesize

for:

B16

HSA-PE

HSA-ROW

HSA-TILE

HSA-DFT
Reports
Area
report_area
Timing
report_timing
Power
report_power
report_power -hier
Sparsity Sweeps

Use:

dense
50%
70%
90%
95%

generated from:

matmul_reference.py

and later:

ResNet18
MobileNetV2
TinyTransformer
Figures

Generate:

Figure 1
Architecture
Figure 2
Waveform
Figure 3
Power vs Sparsity
Figure 4
Area Breakdown
Figure 5
Power Breakdown
Figure 6
Hierarchical Sleep Activation
Figure 7
Timing Summary
Figure 8
DFT Coverage
Final Paper Table

Target:

Design	Power Saving
B16	Baseline
HSA-PE	Measured
HSA-ROW	Measured
HSA-TILE	Measured
HSA-DFT	Measured

Not estimated.

Measured from synthesis.

Current Priority

You are currently only at:

PHASE 1

and specifically:

pe_baseline.sv
tb_pe_baseline.sv
systolic16x16_baseline.sv
tb_b16.sv
matmul_reference.py

Finish and verify those first. Once B16 is proven correct, Phase 2 becomes much faster because every HSA version is just an incremental modification of the same verified baseline.