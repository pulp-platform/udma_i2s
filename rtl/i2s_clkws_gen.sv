module i2s_clkws_gen (
                      input logic        clk_i,
                      input logic        rstn_i,

                      input logic        dft_test_mode_i,
                      input logic        dft_cg_enable_i,

                      input logic        pad_slave_sck_i,
                      output logic       pad_slave_sck_o,
                      output logic       pad_slave_sck_oe,
                      input logic        pad_slave_ws_i,
                      output logic       pad_slave_ws_o,
                      output logic       pad_slave_ws_oe,
                      input logic        pad_master_sck_i,
                      output logic       pad_master_sck_o,
                      output logic       pad_master_sck_oe,
                      input logic        pad_master_ws_i,
                      output logic       pad_master_ws_o,
                      output logic       pad_master_ws_oe,

                      input logic        master_en_i,
                      input logic        slave_en_i,
                      input logic        pdm_en_i,

                      input logic        pdm_clk_i,

                      input logic [15:0] cfg_div_0_i,  //master clock divider
                      input logic [15:0] cfg_div_1_i,  //slave clock divider
                      
                      //DSP reg
                      input logic        cfg_slave_dsp_en_i,
                      input logic [15:0] cfg_slave_dsp_setup_time_i,
                      input logic        cfg_slave_dsp_mode_i,

                      input logic        cfg_master_dsp_en_i,
                      input logic [15:0] cfg_master_dsp_setup_time_i,
                      input logic        cfg_master_dsp_mode_i,

                      input logic        master_ready_to_send,

                      input logic [4:0]  cfg_word_size_0_i,
                      input logic [3:0]  cfg_word_num_0_i,
                      input logic [4:0]  cfg_word_size_1_i,
                      input logic [3:0]  cfg_word_num_1_i,

                      input logic        sel_master_num_i,
                      input logic        sel_master_ext_i,
                      input logic        sel_slave_num_i,
                      input logic        sel_slave_ext_i,

                      output logic       clk_pdm_o,
                      output logic       clk_master_o,
                      output logic       clk_slave_o,
                      output logic       ws_master_o,
                      output logic       ws_slave_o

                      );

   logic                   s_clk_gen_0;
   logic                   s_clk_gen_1;

   logic                   s_clk_gen_0_en;
   logic                   s_clk_gen_1_en;

   logic                   s_clk_int_master;
   logic                   s_clk_int_slave;

   logic                   s_clk_ext_master;
   logic                   s_clk_ext_slave;

   logic                   s_clk_master;
   logic                   s_clk_slave;

   logic                   s_sync_ws_slv_en;
   
   logic                   s_ws_int_master;
   logic                   s_ws_int_slave;

   logic                   s_ws_ext_master;
   logic                   s_ws_ext_slave;

   logic                   s_ws_master;
   logic                   s_ws_slave;

   assign pad_slave_sck_oe = pdm_en_i ? 1'b1 : (slave_en_i & ~sel_slave_ext_i);
   assign pad_slave_ws_oe  = pdm_en_i ? 1'b0 : (slave_en_i & ~sel_slave_ext_i);
   assign pad_slave_ws_o   = pdm_en_i ? 1'b0 : s_ws_slave;

   assign pad_master_sck_oe = master_en_i & ~sel_master_ext_i;
   assign pad_master_sck_o  = s_clk_master;
   assign pad_master_ws_oe  = master_en_i & ~sel_master_ext_i;
   assign pad_master_ws_o   = s_ws_master;
   
   assign s_sync_ws_slv_en = slave_en_i & ~cfg_slave_dsp_en_i;
   assign s_sync_ws_dsp_slave_en = slave_en_i & cfg_slave_dsp_en_i;

   assign s_sync_ws_mst_en = master_en_i & ~cfg_master_dsp_en_i;
   assign s_sync_ws_dsp_master_en = master_en_i & cfg_master_dsp_en_i & master_ready_to_send;

   assign s_clk_gen_0_en = pdm_en_i | ((master_en_i | slave_en_i) & ((~sel_master_num_i & ~sel_master_ext_i) | (~sel_slave_num_i & ~sel_slave_ext_i)));
   assign s_clk_gen_1_en =             (master_en_i | slave_en_i) & (( sel_master_num_i & ~sel_master_ext_i) | ( sel_slave_num_i & ~sel_slave_ext_i));

   i2s_clk_gen i_clkgen0
     (
      .clk_i        ( clk_i ),
      .rstn_i       ( rstn_i ),
      .test_mode_i  ( dft_test_mode_i ),
      .sck_o        ( s_clk_gen_0 ),
      .cfg_clk_en_i ( s_clk_gen_0_en ),
      .cfg_clk_en_o (  ),
      .cfg_div_i    ( cfg_div_0_i )
      );

   i2s_clk_gen i_clkgen1
     (
      .clk_i        ( clk_i ),
      .rstn_i       ( rstn_i ),
      .test_mode_i  ( dft_test_mode_i ),
      .sck_o        ( s_clk_gen_1 ),
      .cfg_clk_en_i ( s_clk_gen_1_en ),
      .cfg_clk_en_o (  ),
      .cfg_div_i    ( cfg_div_1_i )
      );

`ifndef PULP_FPGA_EMUL
   pulp_clock_mux2 i_clk_slave_out
     (
      .clk0_i(s_clk_slave),
      .clk1_i(pdm_clk_i),
      .clk_sel_i(pdm_en_i),
      .clk_o(pad_slave_sck_o)
      );

   pulp_clock_mux2 i_clock_int_master
     (
      .clk0_i(s_clk_gen_0),
      .clk1_i(s_clk_gen_1),
      .clk_sel_i(sel_master_num_i),
      .clk_o(s_clk_int_master)
      );

   pulp_clock_mux2 i_clock_int_slave
     (
      .clk0_i(s_clk_gen_0),
      .clk1_i(s_clk_gen_1),
      .clk_sel_i(sel_slave_num_i),
      .clk_o(s_clk_int_slave)
      );

   pulp_clock_mux2 i_clock_ext_master
     (
      .clk0_i(pad_master_sck_i),
      .clk1_i(pad_slave_sck_i),
      .clk_sel_i(sel_master_num_i),
      .clk_o(s_clk_ext_master)
      );

   pulp_clock_mux2 i_clock_ext_slave
     (
      .clk0_i(pad_master_sck_i),
      .clk1_i(pad_slave_sck_i),
      .clk_sel_i(sel_slave_num_i),
      .clk_o(s_clk_ext_slave)
      );

   pulp_clock_mux2 i_clock_master
     (
      .clk0_i(s_clk_int_master),
      .clk1_i(s_clk_ext_master),
      .clk_sel_i(sel_master_ext_i),
      .clk_o(s_clk_master)
      );

   pulp_clock_mux2 i_clock_slave
     (
      .clk0_i(s_clk_int_slave),
      .clk1_i(s_clk_ext_slave),
      .clk_sel_i(sel_slave_ext_i),
      .clk_o(s_clk_slave)
      );
`else
   assign pad_slave_sck_o  = pdm_en_i         ? pdm_clk_i        : s_clk_slave;
   assign s_clk_int_master = sel_master_num_i ? s_clk_gen_1      : s_clk_gen_0;
   assign s_clk_int_slave  = sel_slave_num_i  ? s_clk_gen_1      : s_clk_gen_0;
   assign s_clk_ext_master = sel_master_num_i ? pad_slave_sck_i  : pad_master_sck_i;
   assign s_clk_ext_slave  = sel_slave_num_i  ? pad_slave_sck_i  : pad_master_sck_i;
  
   assign s_clk_master     = sel_master_ext_i ? s_clk_ext_master : s_clk_int_master;
   assign s_clk_slave      = sel_slave_ext_i  ? s_clk_ext_slave  : s_clk_int_slave;
`endif

   pulp_clock_gating i_pdm_cg
     (
      .clk_i(s_clk_gen_0),
      .en_i(pdm_en_i),
      .test_en_i(dft_cg_enable_i),
      .clk_o(clk_pdm_o)
      );

   pulp_clock_gating i_master_cg
     (
      .clk_i(s_clk_master),
      .en_i(master_en_i),
      .test_en_i(dft_cg_enable_i),
      .clk_o(clk_master_o)
      );

   pulp_clock_gating i_slave_cg
     (
      .clk_i(s_clk_slave),
      .en_i(slave_en_i),
      .test_en_i(dft_cg_enable_i),
      .clk_o(clk_slave_o)
      );

   pulp_sync #(2) i_master_en_sync
     (
      .clk_i(s_clk_master),
      .rstn_i(rstn_i),
      .serial_i(s_sync_ws_mst_en),
      .serial_o(s_ws_gen_0_en)
      );

   pulp_sync #(2) i_slave_en_sync
     (
      .clk_i(s_clk_slave),
      .rstn_i(rstn_i),
      .serial_i(s_sync_ws_slv_en),
      .serial_o(s_ws_gen_1_en)
      );
   
   //WS DSP slave sync
   pulp_sync #(2) i_slave_dsp_en_sync
     (
      .clk_i(s_clk_slave),
      .rstn_i(rstn_i),
      .serial_i(s_sync_ws_dsp_slave_en),
      .serial_o(s_slave_ws_gen_dsp_en)
      );


   pulp_sync #(2) i_master_dsp_en_sync
     (
      .clk_i(s_clk_master),
      .rstn_i(rstn_i),
      .serial_i(s_sync_ws_dsp_master_en),
      .serial_o(s_master_ws_gen_dsp_en)
      );
  

   i2s_ws_gen i_ws_gen_0
     (
      .sck_i           ( s_clk_master       ),
      .rstn_i          ( rstn_i             ),
      .cfg_ws_en_i     (  s_ws_gen_0_en     ), // s_sync_ws_mst_en
      .ws_o            ( s_ws_int_0         ),
      .cfg_data_size_i ( cfg_word_size_0_i  ),
      .cfg_word_num_i  ( cfg_word_num_0_i   )
      );

   i2s_ws_gen i_ws_gen_1
     (
      .sck_i           ( s_clk_slave        ),
      .rstn_i          ( rstn_i             ),
      .cfg_ws_en_i     ( s_ws_gen_1_en       ), //s_sync_ws_slv_en
      .ws_o            ( s_ws_int_1         ),
      .cfg_data_size_i ( cfg_word_size_1_i  ),
      .cfg_word_num_i  ( cfg_word_num_1_i   )
      );
   
   //WS DSP slave generator
   i2s_dsp_ws_gen i_ws_dsp_slave_gen(
     .sck_i(s_clk_slave),
     .rstn_i(rstn_i),
     .cfg_ws_en_i( s_sync_ws_dsp_slave_en  ), //   s_slave_ws_gen_dsp_en
  
     .cfg_num_bits_i(cfg_word_size_1_i),
     .cfg_num_words_i(cfg_word_num_1_i),
  
     .cfg_dsp_setup_time_i(cfg_slave_dsp_setup_time_i),
     .cfg_dsp_mode_i(cfg_slave_dsp_mode_i),
  
     .ws_o(s_slave_ws_dsp_int)
   );

   i2s_dsp_ws_gen i_ws_dsp_master_gen(
     .sck_i(s_clk_master),
     .rstn_i(rstn_i),
     .cfg_ws_en_i( s_sync_ws_dsp_master_en   ), //s_master_ws_gen_dsp_en
  
     .cfg_num_bits_i(cfg_word_size_0_i),
     .cfg_num_words_i(cfg_word_num_0_i),
  
     .cfg_dsp_setup_time_i(cfg_master_dsp_setup_time_i),
     .cfg_dsp_mode_i(cfg_master_dsp_mode_i),
  
     .ws_o(s_master_ws_dsp_int)
   );

   //assign s_ws_int_master = sel_master_num_i ? s_ws_int_1 : s_ws_int_0;
   //assign s_ws_int_slave  = sel_slave_num_i  ? s_ws_int_1 : s_ws_int_0;
   
   //assign s_ws_int_master  = cfg_master_dsp_en_i? s_master_ws_dsp_int :(sel_master_num_i  ? s_ws_int_1 : s_ws_int_0) ;
   //assign s_ws_int_slave  = cfg_slave_dsp_en_i? s_slave_ws_dsp_int :(sel_slave_num_i  ? s_ws_int_1 : s_ws_int_0) ;

   assign s_ws_int_master  = cfg_master_dsp_en_i? (sel_master_num_i  ? s_slave_ws_dsp_int : s_master_ws_dsp_int):(sel_master_num_i  ? s_ws_int_1 : s_ws_int_0) ;
   assign s_ws_int_slave  = cfg_slave_dsp_en_i? (sel_slave_num_i  ? s_slave_ws_dsp_int : s_master_ws_dsp_int) :(sel_slave_num_i  ? s_ws_int_1 : s_ws_int_0) ;
   
   assign s_ws_ext_master = sel_master_num_i ? pad_slave_ws_i : pad_master_ws_i;
   assign s_ws_ext_slave  = sel_slave_num_i  ? pad_slave_ws_i : pad_master_ws_i;

   assign s_ws_master = sel_master_ext_i ? s_ws_ext_master : s_ws_int_master;
   assign s_ws_slave  = sel_slave_ext_i  ? s_ws_ext_slave  : s_ws_int_slave;

   assign ws_master_o = s_ws_master;
   assign ws_slave_o  = s_ws_slave;

endmodule // i2s_clk_gen
