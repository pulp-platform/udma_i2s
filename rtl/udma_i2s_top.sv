// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

///////////////////////////////////////////////////////////////////////////////
//
// Description: I2S 2 channels implementation
//
///////////////////////////////////////////////////////////////////////////////
//
// Authors    : Antonio Pullini (pullinia@iis.ee.ethz.ch)
//
///////////////////////////////////////////////////////////////////////////////

`define CFG_USE_CLK0         2'b00
`define CFG_USE_CLK1         2'b01
`define CFG_USE_EXTCLK_INTWS 2'b10
`define CFG_USE_EXTCLK_EXTWS 2'b11

module udma_i2s_top
#(
    parameter L2_AWIDTH_NOAL = 12,
    parameter TRANS_SIZE     = 16,
    parameter BUFFER_WIDTH   = 4
)
(
    input  logic                      sys_clk_i,
    input  logic                      periph_clk_i,
    input  logic                      rstn_i,

    input  logic                      dft_test_mode_i,
    input  logic                      dft_cg_enable_i,

    input  logic                      pad_slave_sd0_i,
    input  logic                      pad_slave_sd1_i,
    input  logic                      pad_slave_sck_i,
    output logic                      pad_slave_sck_o,
    output logic                      pad_slave_sck_oe,
    input  logic                      pad_slave_ws_i,
    output logic                      pad_slave_ws_o,
    output logic                      pad_slave_ws_oe,

    output logic                      pad_master_sd0_o,
    output logic                      pad_master_sd1_o,
    input  logic                      pad_master_sck_i,
    output logic                      pad_master_sck_o,
    output logic                      pad_master_sck_oe,
    input  logic                      pad_master_ws_i,
    output logic                      pad_master_ws_o,
    output logic                      pad_master_ws_oe,

    input  logic               [31:0] cfg_data_i,
    input  logic                [4:0] cfg_addr_i,
    input  logic                      cfg_valid_i,
    input  logic                      cfg_rwn_i,
    output logic                      cfg_ready_o,
    output logic               [31:0] cfg_data_o,

    output logic [L2_AWIDTH_NOAL-1:0] cfg_rx_startaddr_o,
    output logic     [TRANS_SIZE-1:0] cfg_rx_size_o,
    output logic                      cfg_rx_continuous_o,
    output logic                      cfg_rx_en_o,
    output logic                      cfg_rx_clr_o,
    input  logic                      cfg_rx_en_i,
    input  logic                      cfg_rx_pending_i,
    input  logic [L2_AWIDTH_NOAL-1:0] cfg_rx_curr_addr_i,
    input  logic     [TRANS_SIZE-1:0] cfg_rx_bytes_left_i,

    output logic [L2_AWIDTH_NOAL-1:0] cfg_tx_startaddr_o,
    output logic     [TRANS_SIZE-1:0] cfg_tx_size_o,
    output logic                      cfg_tx_continuous_o,
    output logic                      cfg_tx_en_o,
    output logic                      cfg_tx_clr_o,
    input  logic                      cfg_tx_en_i,
    input  logic                      cfg_tx_pending_i,
    input  logic [L2_AWIDTH_NOAL-1:0] cfg_tx_curr_addr_i,
    input  logic     [TRANS_SIZE-1:0] cfg_tx_bytes_left_i,

    output logic                [1:0] data_rx_datasize_o,
    output logic               [31:0] data_rx_o,
    output logic                      data_rx_valid_o,
    input  logic                      data_rx_ready_i,

    output logic                      data_tx_req_o,
    input  logic                      data_tx_gnt_i,
    output logic                [1:0] data_tx_datasize_o,
    input  logic               [31:0] data_tx_i,
    input  logic                      data_tx_valid_i,
    output logic                      data_tx_ready_o            

);

    localparam NUM_CHANNELS = 2;

    logic   [NUM_CHANNELS-1:0]  [1:0] s_cfg_ch_mode;
    logic   [NUM_CHANNELS-1:0]        s_cfg_pdm_en;
    logic   [NUM_CHANNELS-1:0]        s_cfg_pdm_usefilter;
    logic   [NUM_CHANNELS-1:0]        s_cfg_pdm_update;
    logic   [NUM_CHANNELS-1:0]  [9:0] s_cfg_pdm_decimation;
    logic   [NUM_CHANNELS-1:0]  [2:0] s_cfg_pdm_shift;
    logic   [NUM_CHANNELS-1:0]        s_cfg_useddr;
    logic   [NUM_CHANNELS-1:0]        s_cfg_snap_cam;
    logic   [NUM_CHANNELS-1:0]        s_cfg_lsb_first;

    logic                [4:0]        s_cfg_ext_bits_word;

    logic                             s_cfg0_gen_clk_en;
    logic                             s_cfg0_gen_clk_end;
    logic               [15:0]        s_cfg0_gen_clk_div;
    logic                [4:0]        s_cfg0_bits_word;

    logic                             s_cfg1_gen_clk_en;
    logic                             s_cfg1_gen_clk_end;
    logic               [15:0]        s_cfg1_gen_clk_div;
    logic                [4:0]        s_cfg1_bits_word;

    logic   [NUM_CHANNELS-1:0] [31:0] s_fifo_data;
    logic   [NUM_CHANNELS-1:0]        s_fifo_valid;
    logic   [NUM_CHANNELS-1:0]        s_fifo_ready;

    logic                      [31:0] s_data_tx;
    logic                             s_data_tx_valid;
    logic                             s_data_tx_ready;

    logic                      [31:0] s_data_tx_dc;
    logic                             s_data_tx_dc_valid;
    logic                             s_data_tx_dc_ready;


    assign data_rx_o       = s_fifo_data[0];
    assign data_rx_valid_o = s_fifo_valid[0];
    assign s_fifo_ready[0]     = data_rx_ready_i;
    assign s_fifo_ready[1]     = 1'b1;

    udma_i2s_reg_if #(
        .L2_AWIDTH_NOAL(L2_AWIDTH_NOAL),
        .TRANS_SIZE(TRANS_SIZE),
        .NUM_CHANNELS(NUM_CHANNELS)
    ) u_reg_if (
        .clk_i                  ( sys_clk_i           ),
        .rstn_i                 ( rstn_i              ),

        .cfg_data_i             ( cfg_data_i          ),
        .cfg_addr_i             ( cfg_addr_i          ),
        .cfg_valid_i            ( cfg_valid_i         ),
        .cfg_rwn_i              ( cfg_rwn_i           ),
        .cfg_ready_o            ( cfg_ready_o         ),
        .cfg_data_o             ( cfg_data_o          ),

        .cfg_rx_ch0_startaddr_o ( cfg_rx_startaddr_o  ),
        .cfg_rx_ch0_size_o      ( cfg_rx_size_o       ),
        .cfg_rx_ch0_datasize_o  ( data_rx_datasize_o  ),
        .cfg_rx_ch0_continuous_o( cfg_rx_continuous_o ),
        .cfg_rx_ch0_en_o        ( cfg_rx_en_o         ),
        .cfg_rx_ch0_clr_o       ( cfg_rx_clr_o        ),
        .cfg_rx_ch0_en_i        ( cfg_rx_en_i         ),
        .cfg_rx_ch0_pending_i   ( cfg_rx_pending_i    ),
        .cfg_rx_ch0_curr_addr_i ( cfg_rx_curr_addr_i  ),
        .cfg_rx_ch0_bytes_left_i( cfg_rx_bytes_left_i ),

        .cfg_rx_ch1_startaddr_o ( cfg_tx_startaddr_o  ),
        .cfg_rx_ch1_size_o      ( cfg_tx_size_o       ),
        .cfg_rx_ch1_datasize_o  ( data_tx_datasize_o  ),
        .cfg_rx_ch1_continuous_o( cfg_tx_continuous_o ),
        .cfg_rx_ch1_en_o        ( cfg_tx_en_o         ),
        .cfg_rx_ch1_clr_o       ( cfg_tx_clr_o        ),
        .cfg_rx_ch1_en_i        ( cfg_tx_en_i         ),
        .cfg_rx_ch1_pending_i   ( cfg_tx_pending_i    ),
        .cfg_rx_ch1_curr_addr_i ( cfg_tx_curr_addr_i  ),
        .cfg_rx_ch1_bytes_left_i( cfg_tx_bytes_left_i ),

        .cfg_i2s_ch_mode_o      ( s_cfg_ch_mode           ),
        .cfg_i2s_snap_cam_o     ( s_cfg_snap_cam          ),
        .cfg_i2s_useddr_o       ( s_cfg_useddr            ),
        .cfg_i2s_update_o       ( s_cfg_pdm_update        ),
        .cfg_i2s_decimation_o   ( s_cfg_pdm_decimation    ),
        .cfg_i2s_shift_o        ( s_cfg_pdm_shift         ),
        .cfg_i2s_pdm_en_o       ( s_cfg_pdm_en            ),
        .cfg_i2s_pdm_usefilter_o( s_cfg_pdm_usefilter     ),
        .cfg_i2s_lsb_first_o    ( s_cfg_lsb_first         ),

        .cfg_i2s_ext_bits_word_o( s_cfg_ext_bits_word     ),
        .cfg_i2s_0_gen_clk_en_o ( s_cfg0_gen_clk_en       ),
        .cfg_i2s_0_gen_clk_en_i ( s_cfg0_gen_clk_end      ),
        .cfg_i2s_0_gen_clk_div_o( s_cfg0_gen_clk_div      ),
        .cfg_i2s_0_bits_word_o  ( s_cfg0_bits_word        ),
        .cfg_i2s_1_gen_clk_en_o ( s_cfg1_gen_clk_en       ),
        .cfg_i2s_1_gen_clk_en_i ( s_cfg1_gen_clk_end      ),
        .cfg_i2s_1_gen_clk_div_o( s_cfg1_gen_clk_div      ),
        .cfg_i2s_1_bits_word_o  ( s_cfg1_bits_word        )
    );

    io_tx_fifo #(
      .DATA_WIDTH(32),
      .BUFFER_DEPTH(2)
      ) u_fifo (
        .clk_i   ( sys_clk_i       ),
        .rstn_i  ( rstn_i          ),
        .clr_i   ( 1'b0            ),
        .data_o  ( s_data_tx       ),
        .valid_o ( s_data_tx_valid ),
        .ready_i ( s_data_tx_ready ),
        .req_o   ( data_tx_req_o   ),
        .gnt_i   ( data_tx_gnt_i   ),
        .valid_i ( data_tx_valid_i ),
        .data_i  ( data_tx_i       ),
        .ready_o ( data_tx_ready_o )
    );

    udma_dc_fifo #(32,4) u_dc_fifo_tx
    (
        .src_clk_i    ( sys_clk_i          ),  
        .src_rstn_i   ( rstn_i             ),  
        .src_data_i   ( s_data_tx          ),
        .src_valid_i  ( s_data_tx_valid    ),
        .src_ready_o  ( s_data_tx_ready    ),
        .dst_clk_i    ( periph_clk_i       ),
        .dst_rstn_i   ( rstn_i             ),
        .dst_data_o   ( s_data_tx_dc       ),
        .dst_valid_o  ( s_data_tx_dc_valid ),
        .dst_ready_i  ( s_data_tx_dc_ready )
    );

    assign s_data_tx_dc_ready = 1'b1;

    udma_dc_fifo #(32,4) u_dc_fifo_rx
    (
        .src_clk_i    ( periph_clk_i       ),  
        .src_rstn_i   ( rstn_i             ),  
        .src_data_i   ( s_data_rx_dc       ),
        .src_valid_i  ( s_data_rx_dc_valid ),
        .src_ready_o  ( s_data_rx_dc_ready ),
        .dst_clk_i    ( sys_clk_i          ),
        .dst_rstn_i   ( rstn_i             ),
        .dst_data_o   ( data_rx_o          ),
        .dst_valid_o  ( data_rx_valid_o    ),
        .dst_ready_i  ( data_rx_ready_i    )
    );
 
    assign s_data_rx_dc = 'h0;
    assign s_data_rx_dc_valid = 'h0;

    
    // i2s_txrx #(
    //     .NUM_CHANNELS(NUM_CHANNELS),
    //     .BUFFER_WIDTH(4)
    // ) i_i2s_txrx (
    //     .sys_clk_i           ( sys_clk_i            ),
    //     .periph_clk_i        ( periph_clk_i         ),
    //     .rstn_i              ( rstn_i               ),

    //     .dft_test_mode_i ( dft_test_mode_i ),
    //     .dft_cg_enable_i ( dft_cg_enable_i ),

    //     .pad_slave_sd0_i   ( pad_slave_sd0_i   ),
    //     .pad_slave_sd1_i   ( pad_slave_sd1_i   ),
    //     .pad_slave_sck_i   ( pad_slave_sck_i   ),
    //     .pad_slave_sck_o   ( pad_slave_sck_o   ),
    //     .pad_slave_sck_oe  ( pad_slave_sck_oe  ),
    //     .pad_slave_ws_i    ( pad_slave_ws_i    ),
    //     .pad_slave_ws_o    ( pad_slave_ws_o    ),
    //     .pad_slave_ws_oe   ( pad_slave_ws_oe   ),

    //     .pad_master_sd0_o  ( pad_master_sd0_o  ),
    //     .pad_master_sd1_o  ( pad_master_sd1_o  ),
    //     .pad_master_sck_i  ( pad_master_sck_i  ),
    //     .pad_master_sck_o  ( pad_master_sck_o  ),
    //     .pad_master_sck_oe ( pad_master_sck_oe ),
    //     .pad_master_ws_i   ( pad_master_ws_i   ),
    //     .pad_master_ws_o   ( pad_master_ws_o   ),
    //     .pad_master_ws_oe  ( pad_master_ws_oe  ),

    //     .cfg_pdm_ch_mode_i    ( s_cfg_ch_mode        ),
    //     .cfg_pdm_decimation_i ( s_cfg_pdm_decimation ),
    //     .cfg_pdm_shift_i      ( s_cfg_pdm_shift      ),
    //     .cfg_pdm_en_i         ( s_cfg_pdm_en         ),

    //     .cfg_i2s_slv_ch_mode_i ( s_cfg_ch_mode ),
    //     .cfg_i2s_slv_lsb_i     (  ),
    //     .cfg_i2s_slv_wlen_i    (  ),
    //     .cfg_i2s_slv_wnum_i    (  ),
    //     .cfg_i2s_slv_en_i      (  ),

    //     .cfg_i2s_mst_ch_mode_i ( s_cfg_ch_mode ),
    //     .cfg_i2s_mst_lsb_i     (  ),
    //     .cfg_i2s_mst_wlen_i    (  ),
    //     .cfg_i2s_mst_wnum_i    (  ),
    //     .cfg_i2s_mst_en_i      (  ),

    //     .fifo_rx_data_o       ( s_fifo_rx_data   ),         
    //     .fifo_rx_data_valid_o ( s_fifo_rx_valid  ),   
    //     .fifo_rx_data_ready_i ( s_fifo_rx_ready  ),   

    //     .fifo_tx_data_o       ( s_fifo_tx_data   ),         
    //     .fifo_tx_data_valid_o ( s_fifo_tx_valid  ),   
    //     .fifo_tx_data_ready_i ( s_fifo_tx_ready  ),   

    //     .fifo_err_o          (                      ),
    //     .fifo_err_clr_i      ( '0                   )
    // );

endmodule

