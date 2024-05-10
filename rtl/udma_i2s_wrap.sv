//-----------------------------------------------------------------------------
// Copyright (C) 2022 ETH Zurich, University of Bologna
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
// SPDX-License-Identifier: SHL-0.51
//
// Manuel Eggimann <meggimann@iis.ee.ethz.ch>
//-----------------------------------------------------------------------------


/*
 * Copyright (C) 2018-2020 ETH Zurich, University of Bologna
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the "License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 *
 *                http://solderpad.org/licenses/SHL-0.51.
 *
 * Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * Alfio Di Mauro <adimauro@iis.ee.ethz.ch>
 *
 */
module udma_i2s_wrap
  import udma_pkg::udma_evt_t;
  import i2s_pkg::i2s_to_pad_t;
  import i2s_pkg::pad_to_i2s_t;
(
  input  logic         sys_clk_i,
  input  logic         periph_clk_i,
  input  logic         rstn_i,

	input  logic  [31:0] cfg_data_i,
	input  logic   [4:0] cfg_addr_i,
	input  logic         cfg_valid_i,
	input  logic         cfg_rwn_i,
	output logic         cfg_ready_o,
  output logic  [31:0] cfg_data_o,

  output udma_evt_t    events_o,
  input  udma_evt_t    events_i,

  // UDMA CHANNEL CONNECTION
  UDMA_LIN_CH.rx_out   rx_ch[0:0],
  UDMA_LIN_CH.tx_in    tx_ch[0:0],

  // PAD SIGNALS CONNECTION
  output  i2s_to_pad_t i2s_to_pad,
  input   pad_to_i2s_t pad_to_i2s
);

import udma_pkg::TRANS_SIZE;
import udma_pkg::L2_AWIDTH_NOAL;

udma_i2s_top #(.L2_AWIDTH_NOAL(L2_AWIDTH_NOAL), .TRANS_SIZE(TRANS_SIZE)) i_udma_i2s_top (
    .sys_clk_i          (sys_clk_i       ),
    .periph_clk_i       (periph_clk_i    ),
    .rstn_i             (rstn_i          ),
    .dft_test_mode_i    ( 1'b0           ),
    .dft_cg_enable_i    ( 1'b0           ),

    .cfg_data_i         (cfg_data_i      ),
    .cfg_addr_i         (cfg_addr_i      ),
    .cfg_valid_i        (cfg_valid_i     ),
    .cfg_rwn_i          (cfg_rwn_i       ),
    .cfg_ready_o        (cfg_ready_o     ),
    .cfg_data_o         (cfg_data_o      ),

    .cfg_rx_startaddr_o (rx_ch[0].startaddr  ),
    .cfg_rx_size_o      (rx_ch[0].size       ),
    .cfg_rx_continuous_o(rx_ch[0].continuous ),
    .cfg_rx_en_o        (rx_ch[0].cen        ),
    .cfg_rx_clr_o       (rx_ch[0].clr        ),
    .cfg_rx_en_i        (rx_ch[0].en         ),
    .cfg_rx_pending_i   (rx_ch[0].pending    ),
    .cfg_rx_curr_addr_i (rx_ch[0].curr_addr  ),
    .cfg_rx_bytes_left_i(rx_ch[0].bytes_left ),

    .cfg_tx_startaddr_o (tx_ch[0].startaddr ),
    .cfg_tx_size_o      (tx_ch[0].size      ),
    .cfg_tx_continuous_o(tx_ch[0].continuous),
    .cfg_tx_en_o        (tx_ch[0].cen       ),
    .cfg_tx_clr_o       (tx_ch[0].clr       ),
    .cfg_tx_en_i        (tx_ch[0].en        ),
    .cfg_tx_pending_i   (tx_ch[0].pending   ),
    .cfg_tx_curr_addr_i (tx_ch[0].curr_addr ),
    .cfg_tx_bytes_left_i(tx_ch[0].bytes_left),

    .data_tx_req_o      (tx_ch[0].req       ),
    .data_tx_gnt_i      (tx_ch[0].gnt       ),
    .data_tx_datasize_o (tx_ch[0].datasize  ),
    .data_tx_i          (tx_ch[0].data      ),
    .data_tx_valid_i    (tx_ch[0].valid     ),
    .data_tx_ready_o    (tx_ch[0].ready     ),

    .data_rx_datasize_o (rx_ch[0].datasize  ),
    .data_rx_o          (rx_ch[0].data      ),
    .data_rx_valid_o    (rx_ch[0].valid     ),
    .data_rx_ready_i    (rx_ch[0].ready     ),

    .pad_slave_sd0_i   ( pad_to_i2s.slave_sd0_in   ),
    .pad_slave_sd1_i   ( pad_to_i2s.slave_sd1_in   ),
    .pad_slave_sck_i   ( pad_to_i2s.slave_sck_in   ),
    .pad_slave_sck_o   ( i2s_to_pad.slave_sck_out  ),
    .pad_slave_sck_oe  ( i2s_to_pad.slave_sck_oe   ),
    .pad_slave_ws_i    ( pad_to_i2s.slave_ws_in    ),
    .pad_slave_ws_o    ( i2s_to_pad.slave_ws_out   ),
    .pad_slave_ws_oe   ( i2s_to_pad.slave_ws_oe    ),

    .pad_master_sd0_o  ( i2s_to_pad.master_sd0_out ),
    .pad_master_sd1_o  ( i2s_to_pad.master_sd1_out ),
    .pad_master_sck_i  ( pad_to_i2s.master_sck_in  ),
    .pad_master_sck_o  ( i2s_to_pad.master_sck_out ),
    .pad_master_sck_oe ( i2s_to_pad.master_sck_oe  ),
    .pad_master_ws_i   ( pad_to_i2s.master_ws_in   ),
    .pad_master_ws_o   ( i2s_to_pad.master_ws_out  ),
    .pad_master_ws_oe  ( i2s_to_pad.master_ws_oe   ),
);

// padding unused events
assign events_o[0] = rx_ch[0].events;
assign events_o[1] = tx_ch[0].events;

// assigning unused signals
assign rx_ch[0].stream = '0;
assign rx_ch[0].stream_id = '0;
assign rx_ch[0].destination = '0;
assign tx_ch[0].destination = '0;

endmodule : udma_i2s_wrap
