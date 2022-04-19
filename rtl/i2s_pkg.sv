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

package i2s_pkg;
  // i2s structure
	typedef struct packed {
    logic        master_sd0;
    logic        master_sd1;
    logic        master_sck;
    logic        master_sck_oe;
    logic        master_ws;
    logic        master_ws_oe;

    logic        slave_sck;
    logic        slave_sck_oe;
    logic        slave_ws;
    logic        slave_ws_oe;
	} i2s_to_pad_t;
	typedef struct packed {
    logic        master_sck;
    logic        master_ws;

    logic        slave_sd0;
    logic        slave_sd1;
    logic        slave_sck;
    logic        slave_ws;
	} pad_to_i2s_t;
endpackage
