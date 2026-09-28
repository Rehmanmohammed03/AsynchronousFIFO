// Testbench top: clocks, DUT, interfaces, config_db, run_test

`timescale 1ns/1ps

`include "uvm_macros.svh"

module fifo_tb;

  import uvm_pkg::*;
  import fifo_pkg::*;

  logic wclk;
  logic rclk;

  initial begin
    wclk = 1'b0;
    forever #5 wclk = ~wclk;
  end

  initial begin
    rclk = 1'b0;
    forever #7 rclk = ~rclk;
  end

  fifo_write_if write_if();
  fifo_read_if  read_if();

  assign write_if.wclk = wclk;
  assign read_if.rclk  = rclk;

  fifo_wrapper dut (
    .wclk         (write_if.wclk),
    .rclk         (read_if.rclk),
    .wreset       (write_if.wreset),
    .rreset       (read_if.rreset),
    .write_enable (write_if.write_enable),
    .read_enable  (read_if.read_enable),
    .wdata        (write_if.wdata),
    .rdata        (read_if.rdata),
    .wr_full      (write_if.wr_full),
    .rd_empty     (read_if.rd_empty)
  );

  initial begin
    $dumpfile("fifo_tb.vcd");
    $dumpvars(0, fifo_tb);
  end

  initial begin
    uvm_config_db#(virtual fifo_write_if.DRIVER )::set(null, "uvm_test_top.env.write_agent.driver",  "vif",   write_if);
    uvm_config_db#(virtual fifo_write_if.MONITOR)::set(null, "uvm_test_top.env.write_agent.monitor", "vif",   write_if);
    uvm_config_db#(virtual fifo_read_if.DRIVER  )::set(null, "uvm_test_top.env.read_agent.driver",   "vif",   read_if);
    uvm_config_db#(virtual fifo_read_if.MONITOR )::set(null, "uvm_test_top.env.read_agent.monitor",  "vif",   read_if);
    uvm_config_db#(virtual fifo_write_if.DRIVER )::set(null, "uvm_test_top.env.reset_controller",    "w_vif", write_if);
    uvm_config_db#(virtual fifo_read_if.DRIVER  )::set(null, "uvm_test_top.env.reset_controller",    "r_vif", read_if);
  end

  initial begin
    run_test("fifo_test");
  end

endmodule
