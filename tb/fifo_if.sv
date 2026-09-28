// Write-side and read-side interfaces

interface fifo_write_if #(parameter DATA_WIDTH = 32);

  logic                  wclk;
  logic                  wreset;
  logic                  write_enable;
  logic [DATA_WIDTH-1:0] wdata;
  logic                  wr_full;

  clocking cb_driver @(posedge wclk);
    default input #1step output #1step;
    input  wr_full;
    output wreset;
    output write_enable;
    output wdata;
  endclocking

  clocking cb_monitor @(posedge wclk);
    default input #1step output #1step;
    input wr_full;
    input wreset;
    input write_enable;
    input wdata;
  endclocking

  modport DRIVER  (clocking cb_driver);
  modport MONITOR (clocking cb_monitor);

endinterface


interface fifo_read_if #(parameter DATA_WIDTH = 32);

  logic                  rclk;
  logic                  rreset;
  logic                  read_enable;
  logic [DATA_WIDTH-1:0] rdata;
  logic                  rd_empty;

  clocking cb_driver @(posedge rclk);
    default input #1step output #1step;
    input  rd_empty;
    output rreset;
    output read_enable;
    input  rdata;
  endclocking

  clocking cb_monitor @(posedge rclk);
    input rd_empty;
    input rreset;
    input read_enable;
    input rdata;
  endclocking

  modport DRIVER  (clocking cb_driver);
  modport MONITOR (clocking cb_monitor);

endinterface
