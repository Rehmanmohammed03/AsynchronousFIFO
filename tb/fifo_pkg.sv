// UVM testbench package: transactions, sequences, agents, scoreboard, env, test

`include "uvm_macros.svh"

package fifo_pkg;

  import uvm_pkg::*;

  // =========================================================================
  // Transactions
  // =========================================================================
  class fifo_write_txn #(parameter DATA_WIDTH = 32) extends uvm_sequence_item;
    rand bit                  write_enable;
    rand bit [DATA_WIDTH-1:0] wdata;
    bit                       wr_full;

    constraint write_enable_c { write_enable dist { 1 := 8, 0 := 2 }; }

    `uvm_object_param_utils_begin(fifo_write_txn#(DATA_WIDTH))
      `uvm_field_int(write_enable, UVM_ALL_ON)
      `uvm_field_int(wdata, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "fifo_write_txn");
      super.new(name);
    endfunction
  endclass


  class fifo_read_txn #(parameter DATA_WIDTH = 32) extends uvm_sequence_item;
    rand bit             read_enable;
    bit [DATA_WIDTH-1:0] rdata;
    bit                  rd_empty;

    constraint read_enable_c { read_enable dist { 1 := 8, 0 := 2 }; }

    `uvm_object_param_utils_begin(fifo_read_txn#(DATA_WIDTH))
      `uvm_field_int(read_enable, UVM_ALL_ON)
      `uvm_field_int(rdata, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "fifo_read_txn");
      super.new(name);
    endfunction
  endclass


  // =========================================================================
  // Sequences
  // =========================================================================
  class fifo_write_sequence extends uvm_sequence #(fifo_write_txn#(32));
    `uvm_object_utils(fifo_write_sequence)

    function new(string name = "fifo_write_sequence");
      super.new(name);
    endfunction

    task body();
      fifo_write_txn #(32) req;

      repeat (200) begin
        req = fifo_write_txn#(32)::type_id::create("req");
        start_item(req);
        assert(req.randomize());
        finish_item(req);
      end

      repeat (400) begin
        req = fifo_write_txn#(32)::type_id::create("req");
        start_item(req);
        req.write_enable = 1;
        assert(req.randomize());
        finish_item(req);
      end

      repeat (7) begin
        req = fifo_write_txn#(32)::type_id::create("req");
        start_item(req);
        req.write_enable = 0;
        assert(req.randomize());
        finish_item(req);
      end
    endtask
  endclass


  class fifo_read_sequence extends uvm_sequence #(fifo_read_txn#(32));
    `uvm_object_utils(fifo_read_sequence)

    function new(string name = "fifo_read_sequence");
      super.new();
    endfunction

    task body();
      fifo_read_txn #(32) req;

      repeat (1000) begin
        req = fifo_read_txn#(32)::type_id::create("req");
        start_item(req);
        assert(req.randomize());
        finish_item(req);
      end
    endtask
  endclass


  // =========================================================================
  // Sequencers
  // =========================================================================
  class fifo_write_sequencer extends uvm_sequencer #(fifo_write_txn#(32));
    `uvm_component_utils(fifo_write_sequencer)

    function new(string name = "fifo_write_sequencer", uvm_component parent = null);
      super.new(name, parent);
    endfunction
  endclass


  class fifo_read_sequencer extends uvm_sequencer #(fifo_read_txn#(32));
    `uvm_component_utils(fifo_read_sequencer)

    function new(string name = "fifo_read_sequencer", uvm_component parent = null);
      super.new(name, parent);
    endfunction
  endclass


  // =========================================================================
  // Drivers
  // =========================================================================
  class fifo_write_driver extends uvm_driver #(fifo_write_txn#(32));
    virtual fifo_write_if.DRIVER vif;
    `uvm_component_utils(fifo_write_driver)

    function new(string name = "fifo_write_driver", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual fifo_write_if.DRIVER)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "Write virtual interface not found")
    endfunction

    task run_phase(uvm_phase phase);
      fifo_write_txn #(32) req;
      forever begin
        seq_item_port.get_next_item(req);
        @(vif.cb_driver);
        vif.cb_driver.write_enable <= req.write_enable;
        vif.cb_driver.wdata        <= req.wdata;
        seq_item_port.item_done();
      end
    endtask
  endclass


  class fifo_read_driver extends uvm_driver #(fifo_read_txn#(32));
    virtual fifo_read_if.DRIVER vif;
    `uvm_component_utils(fifo_read_driver)

    function new(string name = "fifo_read_driver", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual fifo_read_if.DRIVER)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "read virtual interface not found")
    endfunction

    task run_phase(uvm_phase phase);
      fifo_read_txn #(32) req;
      forever begin
        seq_item_port.get_next_item(req);
        @(vif.cb_driver);
        vif.cb_driver.read_enable <= req.read_enable;
        seq_item_port.item_done();
      end
    endtask
  endclass


  // =========================================================================
  // Monitors (with functional coverage)
  // =========================================================================
  class fifo_write_monitor extends uvm_monitor;
    virtual fifo_write_if.MONITOR vif;
    uvm_analysis_port #(fifo_write_txn#(32)) analysis_port;
    `uvm_component_utils(fifo_write_monitor)

    covergroup write_cg;
      cp_write_enable : coverpoint vif.cb_monitor.write_enable {
        bins no_write = {0};
        bins write    = {1};
      }
      cp_wr_full : coverpoint vif.cb_monitor.wr_full {
        bins not_full = {0};
        bins full     = {1};
      }
      write_full_cross : cross cp_write_enable, cp_wr_full;
    endgroup

    function new(string name = "fifo_write_monitor", uvm_component parent = null);
      super.new(name, parent);
      analysis_port = new("analysis_port", this);
      write_cg      = new();
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual fifo_write_if.MONITOR)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "write monitor virtual interface not found")
    endfunction

    task run_phase(uvm_phase phase);
      fifo_write_txn #(32) tx;
      forever begin
        @(vif.cb_monitor);
        write_cg.sample();

        if (vif.cb_monitor.write_enable && !vif.cb_monitor.wr_full) begin
          tx = fifo_write_txn#(32)::type_id::create("tx");
          tx.write_enable = vif.cb_monitor.write_enable;
          tx.wdata        = vif.cb_monitor.wdata;
          analysis_port.write(tx);
        end
      end
    endtask

    function void report_phase(uvm_phase phase);
      `uvm_info("WRITE_COV", $sformatf("WRITE COVERAGE = %0.2f%%", write_cg.get_coverage()), UVM_MEDIUM)
      `uvm_info("WRITE_COV", $sformatf("write_enable = %0.2f%%", write_cg.cp_write_enable.get_coverage()), UVM_MEDIUM)
      `uvm_info("WRITE_COV", $sformatf("wr_full = %0.2f%%", write_cg.cp_wr_full.get_coverage()), UVM_MEDIUM)
      `uvm_info("WRITE_COV", $sformatf("write_full_cross = %0.2f%%", write_cg.write_full_cross.get_coverage()), UVM_MEDIUM)
    endfunction
  endclass


  class fifo_read_monitor extends uvm_monitor;
    virtual fifo_read_if.MONITOR vif;
    uvm_analysis_port #(fifo_read_txn#(32)) analysis_port;
    `uvm_component_utils(fifo_read_monitor)

    covergroup read_cg;
      cp_read_enable : coverpoint vif.cb_monitor.read_enable {
        bins no_read = {0};
        bins read    = {1};
      }
      cp_rd_empty : coverpoint vif.cb_monitor.rd_empty {
        bins not_empty = {0};
        bins empty     = {1};
      }
      read_empty_cross : cross cp_read_enable, cp_rd_empty;
    endgroup

    function new(string name = "fifo_read_monitor", uvm_component parent = null);
      super.new(name, parent);
      analysis_port = new("analysis_port", this);
      read_cg       = new();
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual fifo_read_if.MONITOR)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "read monitor virtual interface not found")
    endfunction

    task run_phase(uvm_phase phase);
      fifo_read_txn #(32) tx;
      bit pending_read;

      pending_read = 1'b0;

      forever begin
        @(vif.cb_monitor);
        read_cg.sample();

        // rdata is registered, so it is valid one cycle after an accepted read
        if (pending_read) begin
          tx = fifo_read_txn#(32)::type_id::create("tx");
          tx.read_enable = 1'b1;
          tx.rdata       = vif.cb_monitor.rdata;
          analysis_port.write(tx);
        end

        pending_read = vif.cb_monitor.read_enable && !vif.cb_monitor.rd_empty;
      end
    endtask

    function void report_phase(uvm_phase phase);
      `uvm_info("READ_COV", $sformatf("READ COVERAGE = %0.2f%%", read_cg.get_coverage()), UVM_MEDIUM)
      `uvm_info("READ_COV", $sformatf("read_enable = %0.2f%%", read_cg.cp_read_enable.get_coverage()), UVM_MEDIUM)
      `uvm_info("READ_COV", $sformatf("rd_empty = %0.2f%%", read_cg.cp_rd_empty.get_coverage()), UVM_MEDIUM)
      `uvm_info("READ_COV", $sformatf("read_empty_cross = %0.2f%%", read_cg.read_empty_cross.get_coverage()), UVM_MEDIUM)
    endfunction
  endclass


  // =========================================================================
  // Agents
  // =========================================================================
  class fifo_write_agent extends uvm_agent;
    fifo_write_sequencer sequencer;
    fifo_write_driver    driver;
    fifo_write_monitor   monitor;
    `uvm_component_utils(fifo_write_agent)

    function new(string name = "fifo_write_agent", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sequencer = fifo_write_sequencer::type_id::create("sequencer", this);
      driver    = fifo_write_driver::type_id::create("driver", this);
      monitor   = fifo_write_monitor::type_id::create("monitor", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
  endclass


  class fifo_read_agent extends uvm_agent;
    fifo_read_sequencer sequencer;
    fifo_read_driver    driver;
    fifo_read_monitor   monitor;
    `uvm_component_utils(fifo_read_agent)

    function new(string name = "fifo_read_agent", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sequencer = fifo_read_sequencer::type_id::create("sequencer", this);
      driver    = fifo_read_driver::type_id::create("driver", this);
      monitor   = fifo_read_monitor::type_id::create("monitor", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
  endclass


  // =========================================================================
  // Reset controller
  // =========================================================================
  class fifo_reset_controller extends uvm_component;
    virtual fifo_write_if.DRIVER w_vif;
    virtual fifo_read_if.DRIVER  r_vif;
    `uvm_component_utils(fifo_reset_controller)

    function new(string name = "fifo_reset_controller", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual fifo_write_if.DRIVER)::get(this, "", "w_vif", w_vif))
        `uvm_fatal("NOVIF", "Write virtual interface not found")
      if (!uvm_config_db#(virtual fifo_read_if.DRIVER)::get(this, "", "r_vif", r_vif))
        `uvm_fatal("NOVIF", "Read virtual interface not found")
    endfunction

    task reset_fifo();
      w_vif.cb_driver.wreset <= 1'b0;
      r_vif.cb_driver.rreset <= 1'b0;

      repeat (2) @(w_vif.cb_driver);
      repeat (2) @(r_vif.cb_driver);

      @(w_vif.cb_driver);
      w_vif.cb_driver.wreset <= 1'b1;
      @(r_vif.cb_driver);
      r_vif.cb_driver.rreset <= 1'b1;
    endtask
  endclass


  // =========================================================================
  // Scoreboard
  // =========================================================================
  `uvm_analysis_imp_decl(_write)
  `uvm_analysis_imp_decl(_read)

  class fifo_scoreboard extends uvm_scoreboard;
    bit [31:0] expected_queue[$];

    uvm_analysis_imp_write #(fifo_write_txn#(32), fifo_scoreboard) write_export;
    uvm_analysis_imp_read  #(fifo_read_txn#(32),  fifo_scoreboard) read_export;

    `uvm_component_utils(fifo_scoreboard)

    function new(string name = "fifo_scoreboard", uvm_component parent = null);
      super.new(name, parent);
      write_export = new("write_export", this);
      read_export  = new("read_export", this);
    endfunction

    function void write_write(fifo_write_txn#(32) tx);
      expected_queue.push_back(tx.wdata);
    endfunction

    function void write_read(fifo_read_txn#(32) tx);
      bit [31:0] expected_data;

      if (expected_queue.size() == 0) begin
        `uvm_error("FIFO_SCB", "Read occured but expected queue is empty")
        return;
      end

      expected_data = expected_queue.pop_front();

      if (tx.rdata !== expected_data)
        `uvm_error("FIFO_SCB", $sformatf("FIFO DATA MISMATCH : expected = %0d , actual = %0d ", expected_data, tx.rdata))
      else
        `uvm_info("FIFO_SCB", $sformatf("FIFO DATA MATCH: data %0d ", tx.rdata), UVM_MEDIUM)
    endfunction

    function void reset_scoreboard();
      expected_queue.delete();
      `uvm_info("FIFO_SCB", "Scoreboard reference queue cleared due to FIFO reset", UVM_MEDIUM)
    endfunction
  endclass


  // =========================================================================
  // Environment
  // =========================================================================
  class fifo_env extends uvm_env;
    fifo_write_agent      write_agent;
    fifo_read_agent       read_agent;
    fifo_scoreboard       scoreboard;
    fifo_reset_controller reset_controller;
    `uvm_component_utils(fifo_env)

    function new(string name = "fifo_env", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      write_agent      = fifo_write_agent::type_id::create("write_agent", this);
      read_agent       = fifo_read_agent::type_id::create("read_agent", this);
      scoreboard       = fifo_scoreboard::type_id::create("scoreboard", this);
      reset_controller = fifo_reset_controller::type_id::create("reset_controller", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      write_agent.monitor.analysis_port.connect(scoreboard.write_export);
      read_agent.monitor.analysis_port.connect(scoreboard.read_export);
    endfunction
  endclass


  // =========================================================================
  // Test
  // =========================================================================
  class fifo_test extends uvm_test;
    fifo_env env;
    `uvm_component_utils(fifo_test)

    function new(string name = "fifo_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = fifo_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
      fifo_write_sequence write_seq;
      fifo_read_sequence  read_seq;

      phase.raise_objection(this);

      env.reset_controller.reset_fifo();
      env.scoreboard.reset_scoreboard();

      write_seq = fifo_write_sequence::type_id::create("write_seq");
      read_seq  = fifo_read_sequence::type_id::create("read_seq");

      fork
        write_seq.start(env.write_agent.sequencer);
        read_seq.start(env.read_agent.sequencer);
      join

      phase.drop_objection(this);
    endtask
  endclass

endpackage
