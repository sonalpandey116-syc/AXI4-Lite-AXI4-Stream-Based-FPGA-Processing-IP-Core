`timescale 1ns/1ps

module axi_processing_ip #(
    parameter int DATA_WIDTH = 32
)(
    input  logic aclk,
    input  logic aresetn,

    input  logic [5:0]  s_axi_awaddr,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,

    input  logic [31:0] s_axi_wdata,
    input  logic [3:0]  s_axi_wstrb,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,

    output logic [1:0]  s_axi_bresp,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,

    input  logic [5:0]  s_axi_araddr,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,

    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,

    input  logic [DATA_WIDTH-1:0] s_axis_tdata,
    input  logic                  s_axis_tvalid,
    output logic                  s_axis_tready,
    input  logic                  s_axis_tlast,

    output logic [DATA_WIDTH-1:0] m_axis_tdata,
    output logic                  m_axis_tvalid,
    input  logic                  m_axis_tready,
    output logic                  m_axis_tlast
);

    localparam logic [5:0] ADDR_CONTROL  = 6'h00;
    localparam logic [5:0] ADDR_STATUS   = 6'h04;
    localparam logic [5:0] ADDR_MODE     = 6'h08;
    localparam logic [5:0] ADDR_CONSTANT = 6'h0C;
    localparam logic [5:0] ADDR_GAIN     = 6'h10;
    localparam logic [5:0] ADDR_OFFSET   = 6'h14;
    localparam logic [5:0] ADDR_LENGTH   = 6'h18;
    localparam logic [5:0] ADDR_VERSION  = 6'h1C;

    localparam logic [3:0] MODE_ADD       = 4'd0;
    localparam logic [3:0] MODE_SUB       = 4'd1;
    localparam logic [3:0] MODE_MUL       = 4'd2;
    localparam logic [3:0] MODE_MAC       = 4'd3;
    localparam logic [3:0] MODE_THRESHOLD = 4'd4;
    localparam logic [3:0] MODE_ABS       = 4'd5;
    localparam logic [3:0] MODE_SCALE     = 4'd6;

    logic        enable_reg;
    logic        start_reg;
    logic [3:0]  mode_reg;
    logic [31:0] constant_reg;
    logic [31:0] gain_reg;
    logic [31:0] offset_reg;
    logic [31:0] length_reg;

    logic        busy_reg;
    logic        done_reg;
    logic        overflow_reg;
    logic        error_reg;
    logic [31:0] sample_count;

    logic [5:0]  awaddr_reg;
    logic [31:0] wdata_reg;
    logic [3:0]  wstrb_reg;
    logic        awaddr_received;
    logic        wdata_received;

    logic signed [(2*DATA_WIDTH)-1:0] mac_accumulator;
    logic signed [DATA_WIDTH-1:0] input_signed;
    logic signed [DATA_WIDTH-1:0] constant_signed;
    logic signed [DATA_WIDTH-1:0] gain_signed;
    logic signed [DATA_WIDTH-1:0] offset_signed;
    logic signed [(2*DATA_WIDTH)-1:0] multiplication_result;
    logic signed [(2*DATA_WIDTH)-1:0] mac_next;
    logic signed [(2*DATA_WIDTH)-1:0] scale_result;
    logic signed [DATA_WIDTH-1:0] processed_data;

    // Encourage DSP48 inference for the real multiply datapath.
    (* use_dsp = "yes" *) logic signed [(2*DATA_WIDTH)-1:0] mult_dsp;

    always_comb begin
        s_axi_awready = !awaddr_received && !s_axi_bvalid;
        s_axi_wready  = !wdata_received  && !s_axi_bvalid;
        s_axi_arready = !s_axi_rvalid;
        s_axis_tready = enable_reg && (!m_axis_tvalid || m_axis_tready);
    end

    always_comb begin
        input_signed    = $signed(s_axis_tdata);
        constant_signed = $signed(constant_reg[DATA_WIDTH-1:0]);
        gain_signed     = $signed(gain_reg[DATA_WIDTH-1:0]);
        offset_signed   = $signed(offset_reg[DATA_WIDTH-1:0]);

        mult_dsp             = input_signed * gain_signed;
        multiplication_result = mult_dsp;
        mac_next              = mac_accumulator + multiplication_result;
        scale_result          = multiplication_result + offset_signed;

        unique case (mode_reg)
            MODE_ADD:
                processed_data = input_signed + constant_signed;
            MODE_SUB:
                processed_data = input_signed - constant_signed;
            MODE_MUL:
                processed_data = multiplication_result[DATA_WIDTH-1:0];
            MODE_MAC:
                processed_data = mac_next[DATA_WIDTH-1:0];
            MODE_THRESHOLD:
                processed_data = (input_signed >= constant_signed) ?
                                 input_signed : '0;
            MODE_ABS:
                processed_data = (input_signed < 0) ?
                                 -input_signed : input_signed;
            MODE_SCALE:
                processed_data = scale_result[DATA_WIDTH-1:0];
            default:
                processed_data = '0;
        endcase
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            awaddr_reg      <= '0;
            wdata_reg       <= '0;
            wstrb_reg       <= '0;
            awaddr_received <= 1'b0;
            wdata_received  <= 1'b0;

            s_axi_bvalid    <= 1'b0;
            s_axi_bresp     <= 2'b00;
            s_axi_rvalid    <= 1'b0;
            s_axi_rdata     <= '0;
            s_axi_rresp     <= 2'b00;

            enable_reg      <= 1'b1;
            start_reg       <= 1'b0;
            mode_reg        <= MODE_ADD;
            constant_reg    <= 32'd1;
            gain_reg        <= 32'd2;
            offset_reg      <= 32'd0;
            length_reg      <= 32'd0;

            busy_reg        <= 1'b0;
            done_reg        <= 1'b0;
            overflow_reg    <= 1'b0;
            error_reg       <= 1'b0;
            sample_count    <= '0;
            mac_accumulator <= '0;

            m_axis_tdata    <= '0;
            m_axis_tvalid   <= 1'b0;
            m_axis_tlast    <= 1'b0;
        end else begin
            if (s_axi_awvalid && s_axi_awready) begin
                awaddr_reg      <= s_axi_awaddr;
                awaddr_received <= 1'b1;
            end

            if (s_axi_wvalid && s_axi_wready) begin
                wdata_reg      <= s_axi_wdata;
                wstrb_reg      <= s_axi_wstrb;
                wdata_received <= 1'b1;
            end

            if (awaddr_received && wdata_received && !s_axi_bvalid) begin
                case (awaddr_reg)
                    ADDR_CONTROL: begin
                        if (wstrb_reg[0]) begin
                            enable_reg <= wdata_reg[0];
                            start_reg  <= wdata_reg[1];
                            if (wdata_reg[1]) begin
                                sample_count    <= '0;
                                mac_accumulator <= '0;
                                done_reg        <= 1'b0;
                                overflow_reg    <= 1'b0;
                                error_reg       <= 1'b0;
                            end
                        end
                    end
                    ADDR_MODE:
                        if (wstrb_reg[0]) mode_reg <= wdata_reg[3:0];
                    ADDR_CONSTANT:
                        if (|wstrb_reg) constant_reg <= wdata_reg;
                    ADDR_GAIN:
                        if (|wstrb_reg) gain_reg <= wdata_reg;
                    ADDR_OFFSET:
                        if (|wstrb_reg) offset_reg <= wdata_reg;
                    ADDR_LENGTH:
                        if (|wstrb_reg) length_reg <= wdata_reg;
                    default:
                        error_reg <= 1'b1;
                endcase

                awaddr_received <= 1'b0;
                wdata_received  <= 1'b0;
                s_axi_bvalid    <= 1'b1;
                s_axi_bresp     <= 2'b00;
            end

            if (s_axi_bvalid && s_axi_bready)
                s_axi_bvalid <= 1'b0;

            if (s_axi_arvalid && s_axi_arready) begin
                case (s_axi_araddr)
                    ADDR_CONTROL: s_axi_rdata <= {30'd0, start_reg, enable_reg};
                    ADDR_STATUS:  s_axi_rdata <= {28'd0, error_reg, overflow_reg, done_reg, busy_reg};
                    ADDR_MODE:    s_axi_rdata <= {28'd0, mode_reg};
                    ADDR_CONSTANT: s_axi_rdata <= constant_reg;
                    ADDR_GAIN:     s_axi_rdata <= gain_reg;
                    ADDR_OFFSET:   s_axi_rdata <= offset_reg;
                    ADDR_LENGTH:   s_axi_rdata <= length_reg;
                    ADDR_VERSION:  s_axi_rdata <= 32'h0001_0000;
                    default:       s_axi_rdata <= 32'h0000_0000;
                endcase
                s_axi_rresp  <= 2'b00;
                s_axi_rvalid <= 1'b1;
            end

            if (s_axi_rvalid && s_axi_rready)
                s_axi_rvalid <= 1'b0;

            if (m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 1'b0;
                m_axis_tlast  <= 1'b0;
                busy_reg      <= 1'b0;
            end

            if (s_axis_tvalid && s_axis_tready) begin
                m_axis_tdata  <= processed_data;
                m_axis_tvalid <= 1'b1;
                m_axis_tlast  <= s_axis_tlast;
                busy_reg      <= 1'b1;
                sample_count  <= sample_count + 32'd1;

                if (mode_reg == MODE_MAC)
                    mac_accumulator <= mac_next;

                if (s_axis_tlast)
                    done_reg <= 1'b1;
            end
        end
    end
endmodule
