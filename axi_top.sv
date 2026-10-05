`timescale 1ns/1ps

module axi_top (
    input  logic       clk,
    input  logic       btnC,
    input  logic [2:0] sw,
    output logic [7:0] led
);

    logic [31:0] input_data;
    logic        input_valid;
    logic        input_ready;

    logic [31:0] output_data;
    logic        output_valid;
    logic        output_ready;
    logic        output_last;

    logic [3:0]  mode_sel;

    // For this standalone board demonstration, switches select the IP mode.
    // 000 ADD, 001 SUB, 010 MUL, 011 MAC, 100 THRESHOLD, 101 ABS, 110 SCALE.
    assign mode_sel = {1'b0, sw};

    // The IP's AXI-Lite configuration is tied to fixed values in this
    // standalone top-level. The selected operation is provided directly
    // through the mode register below.
    //
    // A clean register interface is kept so the same IP can also be used
    // from an AXI master/Block Design later.
    logic [5:0]  awaddr;
    logic        awvalid, awready;
    logic [31:0] wdata;
    logic [3:0]  wstrb;
    logic        wvalid, wready;
    logic [1:0]  bresp;
    logic        bvalid;
    logic        bready;
    logic [5:0]  araddr;
    logic        arvalid, arready;
    logic [31:0] rdata;
    logic [1:0]  rresp;
    logic        rvalid;
    logic        rready;

    logic aresetn;

    typedef enum logic [2:0] {
        CFG_IDLE,
        CFG_AW,
        CFG_W,
        CFG_RESP,
        STREAM
    } cfg_state_t;

    cfg_state_t state;
    logic [3:0] last_mode;

    assign aresetn = ~btnC;

    assign awaddr = 6'h08;
    assign wdata  = {28'd0, mode_sel};
    assign wstrb  = 4'hF;

    assign bready = 1'b1;
    assign araddr = 6'd0;
    assign arvalid = 1'b0;
    assign rready = 1'b1;

    // One configuration write is issued whenever the selected switch mode
    // changes. After that the stream runs continuously.
    always_ff @(posedge clk) begin
        if (btnC) begin
            state        <= CFG_IDLE;
            awvalid      <= 1'b0;
            wvalid       <= 1'b0;
            input_valid  <= 1'b0;
            input_data   <= 32'd0;
            last_mode    <= 4'hF;
        end else begin
            case (state)
                CFG_IDLE: begin
                    input_valid <= 1'b0;
                    if (last_mode != mode_sel) begin
                        awvalid <= 1'b1;
                        wvalid  <= 1'b1;
                        state   <= CFG_AW;
                    end else begin
                        input_valid <= 1'b1;
                        state <= STREAM;
                    end
                end

                CFG_AW: begin
                    if (awvalid && awready)
                        awvalid <= 1'b0;
                    if (wvalid && wready)
                        wvalid <= 1'b0;

                    if ((!awvalid || (awvalid && awready)) &&
                        (!wvalid  || (wvalid  && wready))) begin
                        state <= CFG_RESP;
                    end
                end

                CFG_RESP: begin
                    if (bvalid) begin
                        last_mode   <= mode_sel;
                        input_valid <= 1'b1;
                        state       <= STREAM;
                    end
                end

                STREAM: begin
                    input_valid <= 1'b1;
                    if (last_mode != mode_sel) begin
                        input_valid <= 1'b0;
                        state <= CFG_IDLE;
                    end
                end

                default: state <= CFG_IDLE;
            endcase

            if (input_valid && input_ready)
                input_data <= {29'd0, sw};
        end
    end

    assign output_ready = 1'b1;

    always_ff @(posedge clk) begin
        if (btnC)
            led <= 8'h00;
        else if (output_valid)
            led <= output_data[7:0];
    end

    axi_processing_ip #(
        .DATA_WIDTH(32)
    ) u_ip_core (
        .aclk          (clk),
        .aresetn       (aresetn),

        .s_axi_awaddr  (awaddr),
        .s_axi_awvalid (awvalid),
        .s_axi_awready (awready),
        .s_axi_wdata   (wdata),
        .s_axi_wstrb   (wstrb),
        .s_axi_wvalid  (wvalid),
        .s_axi_wready  (wready),
        .s_axi_bresp   (bresp),
        .s_axi_bvalid  (bvalid),
        .s_axi_bready  (bready),

        .s_axi_araddr  (araddr),
        .s_axi_arvalid (arvalid),
        .s_axi_arready (arready),
        .s_axi_rdata   (rdata),
        .s_axi_rresp   (rresp),
        .s_axi_rvalid  (rvalid),
        .s_axi_rready  (rready),

        .s_axis_tdata  (input_data),
        .s_axis_tvalid (input_valid),
        .s_axis_tready (input_ready),
        .s_axis_tlast  (1'b0),

        .m_axis_tdata  (output_data),
        .m_axis_tvalid (output_valid),
        .m_axis_tready (output_ready),
        .m_axis_tlast  (output_last)
    );

endmodule
