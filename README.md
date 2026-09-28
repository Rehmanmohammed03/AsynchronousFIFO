# Asynchronous FIFO: RTL Design and UVM Verification

A parameterized dual-clock (asynchronous) FIFO written in Verilog, verified with a UVM testbench in SystemVerilog. The testbench uses separate write-side and read-side agents, a queue-based scoreboard, and covergroups in both monitors.

## Features

- Independent write and read clock domains with asynchronous, active-low resets
- Gray-code pointer crossing through 2-flop synchronizers
- Full and empty detection using an extra pointer wrap bit
- Parameterized data width and depth (defaults: 32-bit data, 256 entries)
- UVM environment with write and read agents, a reset controller and a scoreboard
- Functional coverage on write/full and read/empty conditions, including crosses

## RTL Design

### Block Diagram

```
          write clock domain (wclk)          |          read clock domain (rclk)
                                              |
 write_enable ─►┌──────────────────┐  waddr   |   raddr   ┌──────────────────┐◄─ read_enable
 wdata ────────►│ fifo_write_ctrl  │──────────┼─► mem ◄───│  fifo_read_ctrl  │
 wr_full ◄──────│  (wptr, full)    │          |   (dual   │  (rptr, empty)   │──► rd_empty
                └──────────────────┘          |    clock) └──────────────────┘
                   ▲          │ wptr_gray     |             ▲          │ rptr_gray
     rptr_sync_bin │          └───────────────┼──► write_ptr_sync ─────┘ (wptr_sync_bin)
                   │                          |
                   └──── read_ptr_sync ◄──────┼───────────────────────────┘
                                              |
```

### Modules

All RTL modules are in `rtl/async_fifo.v`.

| Module | Description |
| --- | --- |
| `fifo_wrapper` | Top level. Connects the memory, both controllers and both synchronizers. |
| `fifo_mem` | Dual-port memory with `2^ADDR_WIDTH` entries. Writes on `wclk`, registered reads on `rclk`. |
| `fifo_write_ctrl` | Binary write pointer, Gray-code conversion, `wr_full` generation. |
| `fifo_read_ctrl` | Binary read pointer, Gray-code conversion, `rd_empty` generation. |
| `write_ptr_sync` | Syncs the Gray write pointer into `rclk` (2 flops), then converts it back to binary. |
| `read_ptr_sync` | Syncs the Gray read pointer into `wclk` (2 flops), then converts it back to binary. |

### Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `DATA_WIDTH` | 32 | Width of each FIFO entry |
| `ADDR_WIDTH` | 8 | Address width; depth = `2^ADDR_WIDTH` (256) |
| `PTR_WIDTH` | `ADDR_WIDTH + 1` | Pointer width, including the wrap bit |

### How It Works

**Pointers.** Each side keeps a binary pointer that is one bit wider than the address. The lower `ADDR_WIDTH` bits address the memory. The top bit flips every time the pointer wraps around the buffer.

**Clock domain crossing.** Each pointer is converted to Gray code (`bin ^ (bin >> 1)`) before it crosses into the other domain. Only one bit changes per increment, so a pointer sampled mid-transition is either the old or the new value, never a corrupted one. Each synchronizer passes the Gray pointer through two flip-flops in the destination clock domain and then converts it back to binary.

**Full.** The FIFO is full when the write and synchronized read addresses match but their wrap bits differ:

```verilog
wr_full = (wptr_bin[ADDR_WIDTH-1:0] == rptr_bin_sync[ADDR_WIDTH-1:0]) &&
          (wptr_bin[PTR_WIDTH-1]    != rptr_bin_sync[PTR_WIDTH-1]);
```

**Empty.** The FIFO is empty when the read and synchronized write pointers are identical, wrap bit included:

```verilog
rd_empty = (rptr_bin[ADDR_WIDTH-1:0] == wptr_bin_sync[ADDR_WIDTH-1:0]) &&
           (rptr_bin[PTR_WIDTH-1]    == wptr_bin_sync[PTR_WIDTH-1]);
```

Writes are blocked while full and reads are blocked while empty (`wr_allowed` / `rd_allowed`). Because the pointer from the other side arrives two cycles late, the flags are conservative: full may clear late and empty may clear late, but the FIFO never overflows or underflows.

## Verification Environment

### Testbench Architecture

```
fifo_test
└── fifo_env
    ├── write_agent (fifo_write_agent)
    │   ├── sequencer ── fifo_write_sequence
    │   ├── driver    ── drives write_enable, wdata
    │   └── monitor   ── write_cg covergroup ──┐
    ├── read_agent (fifo_read_agent)           │ analysis ports
    │   ├── sequencer ── fifo_read_sequence    │
    │   ├── driver    ── drives read_enable    │
    │   └── monitor   ── read_cg covergroup ───┤
    ├── scoreboard (fifo_scoreboard) ◄─────────┘
    └── reset_controller (fifo_reset_controller)
```

### Files

| File | Contents |
| --- | --- |
| `tb/fifo_tb.sv` | Top module. Generates the clocks, instantiates the DUT and interfaces, publishes the virtual interfaces through `uvm_config_db`, and calls `run_test("fifo_test")`. |
| `tb/fifo_if.sv` | `fifo_write_if` and `fifo_read_if`, with `cb_driver` and `cb_monitor` clocking blocks and `DRIVER` / `MONITOR` modports. |
| `tb/fifo_pkg.sv` | `fifo_pkg`, which holds every UVM class (listed below). |

### UVM Classes (`fifo_pkg`)

| Class | Role |
| --- | --- |
| `fifo_write_txn` / `fifo_read_txn` | Sequence items. The enables are weighted 80% on and 20% off. |
| `fifo_write_sequence` | 200 random writes, then 400 writes with `write_enable` held high to fill the FIFO, then 7 idle cycles. |
| `fifo_read_sequence` | 1000 random reads. |
| `fifo_*_sequencer` / `fifo_*_driver` | Standard sequencer and driver per side. The drivers apply each item on the next clocking-block edge. |
| `fifo_write_monitor` | Samples `write_cg` every `wclk`. Sends a transaction for each accepted write (`write_enable && !wr_full`). |
| `fifo_read_monitor` | Samples `read_cg` every `rclk`. Captures `rdata` one cycle after an accepted read, to match the registered memory output. |
| `fifo_write_agent` / `fifo_read_agent` | Build and connect the sequencer, driver and monitor for each side. |
| `fifo_reset_controller` | Asserts `wreset` and `rreset` together, then releases each one in its own clock domain. |
| `fifo_scoreboard` | Pushes written data into a reference queue and pops/compares it on every read. Reports a mismatch or a read from an empty model. |
| `fifo_env` | Builds the agents, scoreboard and reset controller, and connects the monitors to the scoreboard. |
| `fifo_test` | Resets the DUT, clears the scoreboard, then runs the write and read sequences in parallel. |

### Test Flow

1. `fifo_tb` starts `wclk` with a 10 ns period (100 MHz) and `rclk` with a 14 ns period (~71.4 MHz). The two clocks are unrelated, so pointers really do cross between domains.
2. `fifo_test` calls `reset_controller.reset_fifo()` and `scoreboard.reset_scoreboard()`.
3. The write and read sequences run at the same time in a `fork ... join`.
4. Each monitor sends observed transactions to the scoreboard, which checks data integrity and ordering.
5. In `report_phase`, each monitor prints coverage for its covergroup, its coverpoints and its cross.

### Functional Coverage

| Covergroup | Coverpoints | Cross |
| --- | --- | --- |
| `write_cg` | `write_enable` {0, 1}, `wr_full` {0, 1} | `write_enable × wr_full` |
| `read_cg` | `read_enable` {0, 1}, `rd_empty` {0, 1} | `read_enable × rd_empty` |

The crosses make sure the testbench tries to write while the FIFO is full and read while it is empty. These are the cases where the design must block the operation.

## Running the Simulation

You need a simulator that supports SystemVerilog and UVM 1.2, such as Questa, VCS, Xcelium or Riviera-PRO. Compile the files in this order: RTL, interfaces, package, then the testbench top.

Questa example, run from the repository root:

```sh
vlog -sv +incdir+tb rtl/async_fifo.v tb/fifo_if.sv tb/fifo_pkg.sv tb/fifo_tb.sv
vsim -c fifo_tb -coverage -do "run -all; quit"
```

The simulation writes a waveform dump to `fifo_tb.vcd`.

## Results

### Scoreboard

Every write and read transaction passed. The scoreboard found no data mismatches and no ordering errors.

### Functional Coverage

Purely random stimulus reached **91.67%** functional coverage. The bins it missed were the two cross bins for blocked operations:

- `write_enable = 1` while `wr_full = 1`
- `read_enable = 1` while `rd_empty = 1`

200 random writes are not enough to fill a 256-entry FIFO while reads are draining it. A directed phase of back-to-back writes was added to the write sequence to fill the FIFO. That closed both crosses and brought functional coverage to **100%**.

### Waveform

`rdata` lags `raddr` by one cycle. This is expected: the memory read is registered, and `rdata` is updated with a non-blocking assignment in the NBA region after the `rclk` edge. It therefore holds data for the previous read address, while `raddr` may already have moved on. The read monitor accounts for this by sampling `rdata` one cycle after each accepted read.

## Possible Extensions

- Parameterize the testbench's `DATA_WIDTH` so it follows the RTL, instead of hard-coding `#(32)`
- Add `almost_full` / `almost_empty` flags
- Test several clock ratios, including a read clock faster than the write clock
- Assert reset partway through traffic and check that the FIFO recovers
- Add SVA assertions for overflow/underflow protection, one-bit Gray-code transitions and pointer stability while full or empty
