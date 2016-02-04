////////////////////////////////////////////////////////////////////////////////
// Module: id
// Authors: Matej Oblak, Iztok Jeras <iztok.jeras@redpitaya.com>
// (c) Red Pitaya  (redpitaya.com)
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// GENERAL DESCRIPTION:
//
// Module takes care of system identification.
//
// This module takes care of system identification via DNA readout at startup and
// ID register which user can define at compile time.
////////////////////////////////////////////////////////////////////////////////

module id #(
  bit [0:5*32-1] GITH = '0,  // GIT hash full length
  bit   [57-1:0] DNA = 57'h0823456789ABCDE,
  bit   [32-1:0] ID = {28'h0, 4'h1} // {reserved, board type}:  1 - release 1
)(
  // system bus
  sys_bus_if.s           bus
);

////////////////////////////////////////////////////////////////////////////////
//  Read device DNA
////////////////////////////////////////////////////////////////////////////////

logic          dna_dout ;
logic          dna_clk  ;
logic          dna_read ;
logic          dna_shift;
logic [ 9-1:0] dna_cnt  ;
logic [57-1:0] dna_value;
logic          dna_done ;

always_ff @(posedge bus.clk)
if (!bus.rstn) begin
  dna_clk   <= '0;
  dna_read  <= '0;
  dna_shift <= '0;
  dna_cnt   <= '0;
  dna_value <= '0;
  dna_done  <= '0;
end else begin
  if (!dna_done)
    dna_cnt <= dna_cnt + 1'd1;

  dna_clk   <= dna_cnt[2] ;
  dna_read  <= (dna_cnt < 9'd10);
  dna_shift <= (dna_cnt > 9'd18);

  if ((dna_cnt[2:0]==3'h0) && !dna_done)
    dna_value <= {dna_value[57-2:0], dna_dout};

  if (dna_cnt > 9'd465)
    dna_done <= 1'b1;
end

// parameter specifies a sample 57-bit DNA value for simulation
DNA_PORT #(.SIM_DNA_VALUE (DNA)) dna (
  .DOUT  (dna_dout ), // 1-bit output: DNA output data.
  .CLK   (dna_clk  ), // 1-bit input: Clock input.
  .DIN   (1'b0     ), // 1-bit input: User data input pin.
  .READ  (dna_read ), // 1-bit input: Active high load DNA, active low read input.
  .SHIFT (dna_shift)  // 1-bit input: Active high shift enable input.
);

////////////////////////////////////////////////////////////////////////////////
//  System bus connection
////////////////////////////////////////////////////////////////////////////////

// bus decoder width
localparam int unsigned BDW = 6;

always_ff @(posedge bus.clk)
if (!bus.rstn)  bus.err <= 1'b1;
else            bus.err <= 1'b0;

logic sys_en;
assign sys_en = bus.wen | bus.ren;

always_ff @(posedge bus.clk)
if (!bus.rstn) begin
  bus.ack <= 1'b0;
end else begin
  bus.ack <= sys_en;
  casez (bus.addr[BDW-1:0])
    // ID
    'h00:  bus.rdata <= ID;
    // DNA
    'h08:  bus.rdata <= {                            dna_value[32-1: 0]};
    'h0c:  bus.rdata <= {~dna_done, {64-57-1{1'b0}}, dna_value[57-1:32]};
    // GITH
    'h10:  bus.rdata <= GITH[32*0+:32];
    'h14:  bus.rdata <= GITH[32*1+:32];
    'h18:  bus.rdata <= GITH[32*2+:32];
    'h1c:  bus.rdata <= GITH[32*3+:32];
    'h2c:  bus.rdata <= GITH[32*4+:32];
    default: bus.rdata <= '0;
  endcase
end

endmodule: id
