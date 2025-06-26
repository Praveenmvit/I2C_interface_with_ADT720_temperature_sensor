// Code your testbench here
// or browse Examples
// Code your testbench here
// or browse Examples
`include "ADT720_temperature_sensor.sv" 
module i2c_top_tb;

  reg clk = 0, rst = 0, newd = 0, op;
  reg [7:0] addr;
  reg [15:0] din;
  wire [15:0] dout;
  wire busy,ack_err;
  wire done;
  i2c_top dut (clk,rst, newd, op, addr, din, dout, busy, ack_err, done);

  always #5 clk = ~clk;

  initial begin
  	rst = 1;
    repeat(5) @(posedge clk);
  	rst = 0;
    repeat(40) @(posedge clk);
    //////////// write operation

    for(int i = 0; i < 1 ; i++)
    begin
      newd = 1;
      op = 0;
      addr = $urandom_range(5,8);
      din  = $urandom_range(1,50);
      repeat(5) @(posedge clk);
      newd <= 1'b0;
      //#20000 $stop;
      @(posedge done);
      
      $display("[WR] din : %0d addr: %0d",din, addr);
      @(posedge clk);

    end

    ////////////read operation

    for(int i = 0; i < 1 ; i++)
    begin
      newd = 1;
      op = 1;
      addr = $urandom_range(5,8);
      din = 0;
      repeat(5) @(posedge clk);
      newd <= 1'b0;  
      @(posedge done);
      $display("[RD] dout : %0d addr: %0d",dout, addr);
      @(posedge clk);
    end

    repeat(10) @(posedge clk);
    $stop;
  end
  initial 
    begin
      $dumpfile("dump.vcd");
      $dumpvars;
    end

endmodule

module i2c_top(
input clk, rst, newd, op,
input [7:0] addr,
  input [15:0] din,
  output [15:0] dout,
output busy,ack_err,
output done
);
  wire sda, scl;
  wire ack_errm, ack_errs;
  wire done_slave;

  master master_design (clk, rst, newd, addr, op, din, dout, busy, ack_errm , done, sda, scl);
  memory_slave slave (clk, rst, scl, sda, ack_errs, done_slave);

  assign ack_err = ack_errs | ack_errm;


endmodule
