// Asynchronous FIFO RTL
// fifo_mem, fifo_write_ctrl, fifo_read_ctrl, write_ptr_sync, read_ptr_sync, fifo_wrapper (top)

// ---------------------------------------------------------------------------
// Dual-clock FIFO memory
// ---------------------------------------------------------------------------
module fifo_mem #(parameter DATA_WIDTH = 32,
                  parameter ADDR_WIDTH = 8)
  ( input                   rclk, wclk,
    input  [ADDR_WIDTH-1:0] waddr,
    input  [ADDR_WIDTH-1:0] raddr,
    input  [DATA_WIDTH-1:0] wdata,
    input                   write_allowed,
    input                   read_allowed,
    output reg [DATA_WIDTH-1:0] rdata );

  reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

  always @(posedge wclk)
    if (write_allowed)
      mem[waddr] <= wdata;

  always @(posedge rclk)
    if (read_allowed)
      rdata <= mem[raddr];

endmodule


// ---------------------------------------------------------------------------
// Write controller: binary write pointer, Gray conversion, full flag
// ---------------------------------------------------------------------------
module fifo_write_ctrl #(parameter ADDR_WIDTH = 8,
                         parameter PTR_WIDTH  = ADDR_WIDTH + 1)
  ( input                  wclk,
    input                  wreset,
    input                  write_enable,
    input  [PTR_WIDTH-1:0] rptr_bin_sync,
    output [ADDR_WIDTH-1:0] waddr,
    output [PTR_WIDTH-1:0] wptr_gray,
    output                 wr_full,
    output                 wr_allowed );

  reg [PTR_WIDTH-1:0] wptr_bin;

  assign waddr      = wptr_bin[ADDR_WIDTH-1:0];
  assign wr_allowed = write_enable && !wr_full;

  always @(posedge wclk, negedge wreset) begin
    if (!wreset)
      wptr_bin <= {PTR_WIDTH{1'b0}};
    else if (write_enable && !wr_full)
      wptr_bin <= wptr_bin + 1'b1;
  end

  assign wr_full = (wptr_bin[ADDR_WIDTH-1:0] == rptr_bin_sync[ADDR_WIDTH-1:0]) &&
                   (wptr_bin[PTR_WIDTH-1]    != rptr_bin_sync[PTR_WIDTH-1]);

  assign wptr_gray = wptr_bin ^ (wptr_bin >> 1);

endmodule


// ---------------------------------------------------------------------------
// Read controller: binary read pointer, Gray conversion, empty flag
// ---------------------------------------------------------------------------
module fifo_read_ctrl #(parameter ADDR_WIDTH = 8,
                        parameter PTR_WIDTH  = ADDR_WIDTH + 1)
  ( input                  rclk,
    input                  rreset,
    input                  read_enable,
    input  [PTR_WIDTH-1:0] wptr_bin_sync,
    output [ADDR_WIDTH-1:0] raddr,
    output [PTR_WIDTH-1:0] rptr_gray,
    output                 rd_empty,
    output                 rd_allowed );

  reg [PTR_WIDTH-1:0] rptr_bin;

  assign raddr      = rptr_bin[ADDR_WIDTH-1:0];
  assign rd_allowed = read_enable && !rd_empty;

  assign rd_empty = (rptr_bin[ADDR_WIDTH-1:0] == wptr_bin_sync[ADDR_WIDTH-1:0]) &&
                    (rptr_bin[PTR_WIDTH-1]    == wptr_bin_sync[PTR_WIDTH-1]);

  always @(posedge rclk, negedge rreset) begin
    if (!rreset)
      rptr_bin <= {PTR_WIDTH{1'b0}};
    else if (read_enable && !rd_empty)
      rptr_bin <= rptr_bin + 1'b1;
  end

  assign rptr_gray = rptr_bin ^ (rptr_bin >> 1);

endmodule


// ---------------------------------------------------------------------------
// Write pointer synchronizer: Gray wptr -> rclk domain (2 flops) -> binary
// ---------------------------------------------------------------------------
module write_ptr_sync #(parameter ADDR_WIDTH = 8,
                        parameter PTR_WIDTH  = ADDR_WIDTH + 1)
  ( input                      rclk,
    input                      rreset,
    input      [PTR_WIDTH-1:0] wptr_gray,
    output reg [PTR_WIDTH-1:0] wptr_sync_bin );

  reg [PTR_WIDTH-1:0] sync_ff1;
  reg [PTR_WIDTH-1:0] sync_ff2;

  always @(posedge rclk, negedge rreset) begin
    if (!rreset) begin
      sync_ff1 <= 0;
      sync_ff2 <= 0;
    end
    else begin
      sync_ff1 <= wptr_gray;
      sync_ff2 <= sync_ff1;
    end
  end

  integer i;
  always @(*) begin
    wptr_sync_bin[PTR_WIDTH-1] = sync_ff2[PTR_WIDTH-1];
    for (i = PTR_WIDTH-2; i >= 0; i = i-1)
      wptr_sync_bin[i] = wptr_sync_bin[i+1] ^ sync_ff2[i];
  end

endmodule


// ---------------------------------------------------------------------------
// Read pointer synchronizer: Gray rptr -> wclk domain (2 flops) -> binary
// ---------------------------------------------------------------------------
module read_ptr_sync #(parameter ADDR_WIDTH = 8,
                       parameter PTR_WIDTH  = ADDR_WIDTH + 1)
  ( input                      wclk,
    input                      wreset,
    input      [PTR_WIDTH-1:0] rptr_gray,
    output reg [PTR_WIDTH-1:0] rptr_sync_bin );

  reg [PTR_WIDTH-1:0] sync_ff3;
  reg [PTR_WIDTH-1:0] sync_ff4;

  always @(posedge wclk, negedge wreset) begin
    if (!wreset) begin
      sync_ff3 <= 0;
      sync_ff4 <= 0;
    end
    else begin
      sync_ff3 <= rptr_gray;
      sync_ff4 <= sync_ff3;
    end
  end

  integer i;
  always @(*) begin
    rptr_sync_bin[PTR_WIDTH-1] = sync_ff4[PTR_WIDTH-1];
    for (i = PTR_WIDTH-2; i >= 0; i = i-1)
      rptr_sync_bin[i] = rptr_sync_bin[i+1] ^ sync_ff4[i];
  end

endmodule


// ---------------------------------------------------------------------------
// Top level
// ---------------------------------------------------------------------------
module fifo_wrapper #(parameter DATA_WIDTH = 32,
                      parameter ADDR_WIDTH = 8,
                      parameter PTR_WIDTH  = ADDR_WIDTH + 1)
  ( input                   wclk,
    input                   rclk,
    input                   wreset,
    input                   rreset,
    input                   write_enable,
    input                   read_enable,
    input  [DATA_WIDTH-1:0] wdata,
    output [DATA_WIDTH-1:0] rdata,
    output                  wr_full,
    output                  rd_empty );

  wire [ADDR_WIDTH-1:0] waddr;
  wire [ADDR_WIDTH-1:0] raddr;
  wire [PTR_WIDTH-1:0]  wptr_gray;
  wire [PTR_WIDTH-1:0]  rptr_gray;
  wire [PTR_WIDTH-1:0]  wptr_sync_bin;
  wire [PTR_WIDTH-1:0]  rptr_sync_bin;
  wire                  wr_allowed;
  wire                  rd_allowed;

  fifo_mem #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) u_fifo_mem (
    .wclk          (wclk),
    .rclk          (rclk),
    .waddr         (waddr),
    .raddr         (raddr),
    .wdata         (wdata),
    .rdata         (rdata),
    .write_allowed (wr_allowed),
    .read_allowed  (rd_allowed)
  );

  fifo_write_ctrl #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .PTR_WIDTH (PTR_WIDTH)
  ) u_write_ctrl (
    .wclk          (wclk),
    .wreset        (wreset),
    .write_enable  (write_enable),
    .rptr_bin_sync (rptr_sync_bin),
    .waddr         (waddr),
    .wptr_gray     (wptr_gray),
    .wr_full       (wr_full),
    .wr_allowed    (wr_allowed)
  );

  write_ptr_sync #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .PTR_WIDTH (PTR_WIDTH)
  ) u_write_ptr_sync (
    .rclk          (rclk),
    .rreset        (rreset),
    .wptr_gray     (wptr_gray),
    .wptr_sync_bin (wptr_sync_bin)
  );

  fifo_read_ctrl #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .PTR_WIDTH (PTR_WIDTH)
  ) u_read_ctrl (
    .rclk          (rclk),
    .rreset        (rreset),
    .read_enable   (read_enable),
    .wptr_bin_sync (wptr_sync_bin),
    .raddr         (raddr),
    .rptr_gray     (rptr_gray),
    .rd_empty      (rd_empty),
    .rd_allowed    (rd_allowed)
  );

  read_ptr_sync #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .PTR_WIDTH (PTR_WIDTH)
  ) u_read_ptr_sync (
    .wclk          (wclk),
    .wreset        (wreset),
    .rptr_gray     (rptr_gray),
    .rptr_sync_bin (rptr_sync_bin)
  );

endmodule
