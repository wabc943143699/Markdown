module if_cam/* 2025 5.31 5:33 这个是新的了*/ #(parameter APPEND_WIDTH = 81,
                parameter APPEND_NUM = 8,
                parameter DATA_WIDTH = 32,
                parameter RDY_CNT = 4,
                parameter CAM_NUM = 32)
(
    input clk       ,
    input rst_n     ,

    input vld_in    ,
    input is_gat_self, //no use
    input [DATA_WIDTH-1:0] data_in   ,
    input [APPEND_WIDTH-1:0] append_in ,

    input search_vld,
    input [DATA_WIDTH-1:0] search_in ,

    input rdy_in ,//拉低时data不输出

    output logic vld_out   ,
    output logic [APPEND_NUM-1:0]is_gat_self_out,
    output logic [DATA_WIDTH-1:0] data_out  ,
    output logic [APPEND_NUM-1:0][APPEND_WIDTH-1:0] append_out ,
    output logic [$clog2(APPEND_NUM)-1:0] append_num, //记录输出的这行里存了几个数, append_num=4表示有5个有效数据, append_num=0表示有1个有效数据(要在vld_out有效的时候)

    output logic notfound,
    output logic rdy_out  
);

//------output--------------------------------------
logic                                       vld_out_r;
logic [DATA_WIDTH-1:0]                      data_out_r;
logic [APPEND_NUM-1:0][APPEND_WIDTH-1:0]    append_out_r;
logic [$clog2(APPEND_NUM)-1:0]              append_num_r;
logic                                       notfound_r;

//------------------------------------------------
logic [CAM_NUM-1:0][DATA_WIDTH-1:0] data_cam_reg;
logic [CAM_NUM-1:0]                 is_equal;
logic [$clog2(CAM_NUM)-1:0]                 is_equal_index;
logic [CAM_NUM-1:0][$clog2(APPEND_NUM)-1:0] append_num_cnt;
logic [CAM_NUM-1:0] cam_is_used;
logic [$clog2(CAM_NUM):0] cam_is_used_cnt;
logic [CAM_NUM-1:0] cam_is_no_used_onehot;
logic [$clog2(CAM_NUM)-1:0] cam_is_no_used_onehot_index;

logic [CAM_NUM-1:0] is_search_equal;
logic [CAM_NUM-1:0] is_search_equal_onehot;
logic [$clog2(CAM_NUM)-1:0] is_search_equal_onehot_index;

logic [APPEND_WIDTH-1:0] append_in_dly;

logic spec_in;
//----------sram_wr------din_wr == append_in---------------
logic [$clog2(CAM_NUM)-1:0] addr_wr;
logic [APPEND_NUM-1:0] en_wr;
logic [APPEND_NUM-1:0][APPEND_WIDTH-1:0] dout_r;

logic spec_in_dly;


always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        append_in_dly <= 'd0;
        spec_in_dly <= 1'b0;
    end
    else if(rdy_in) begin
        append_in_dly <= append_in;
        spec_in_dly <= spec_in;
    end
end

//always_comb begin
//    for(int i = 0;i<APPEND_NUM;i = i+1) begin
//        if(spec_in_dly) begin
//            if(i<=append_num_r) begin
//                append_out_r[i] =  dout_r[i];
//            end
//            else if(i==append_num_r + 1'b1) begin
//                append_out_r[i] =  append_in_dly;
//            end
//            else begin
//                append_out_r[i] = 'd0;
//            end
//        end
//        else begin
//            if(i<=append_num_r) begin
//                append_out_r[i] =  dout_r[i];
//            end
//            else begin
//                append_out_r[i] = 'd0;
//            end
//        end
//    end
//end
generate 
    for(genvar i=0;i<APPEND_NUM;i=i+1) begin : append_out_r_gen
        assign append_out_r[i] = (i<=append_num_r) ? dout_r[i] :
                                 (spec_in_dly && (i == (append_num_r + 1'b1))) ? append_in_dly : 'd0;
    end
endgenerate

assign append_out = append_out_r;

always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        append_num_r <= 'd0;
        data_out_r <= 'd0;
    end
    else if(rdy_in) begin
        for(int i = 0;i < CAM_NUM;i = i + 1) begin
            if(is_search_equal_onehot[i]) begin
                append_num_r <= append_num_cnt[i];
                data_out_r <= data_cam_reg[i];
            end
        end
    end
end
assign data_out = data_out_r;
assign append_num = append_num_r;
always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        notfound_r <= 1'b0;
        vld_out_r <= 1'b0;
    end
    else if(rdy_in) begin
        notfound_r <= search_vld && (is_search_equal == 0);
        vld_out_r <= search_vld && (is_search_equal != 0);
    end
end
assign vld_out = vld_out_r;
assign notfound = notfound_r;

assign spec_in = vld_in && search_vld && (search_in==data_in) && (is_equal_index==is_search_equal_onehot_index);
assign cam_is_no_used_onehot = (~cam_is_used)&(~((~cam_is_used)-1)); // 将最低位置的0的位置标记为1

always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        data_cam_reg <= '{default:0};
    end
    else if(rdy_in) begin
        for(int i = 0;i < CAM_NUM;i = i + 1) begin
            if(vld_in && (is_equal==0) && cam_is_no_used_onehot[i]) begin
                data_cam_reg[i] <= data_in;
            end
        end
    end
end

always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        cam_is_used <= 'd0;
    end
    else if(rdy_in) begin
        cam_is_used <= ((vld_in && (is_equal==0)) && (search_vld && (is_search_equal==0))) ? (cam_is_used | cam_is_no_used_onehot) : 
                       ((vld_in && (is_equal==0)) && (search_vld && (is_search_equal!=0))) ? (cam_is_used | cam_is_no_used_onehot ^ is_search_equal_onehot) :
                       ((vld_in && (is_equal!=0)) && (search_vld && (is_search_equal!=0))) ? (cam_is_used ^ is_search_equal_onehot) :
                                                                                             (cam_is_used);
    end
end

always_comb begin : cam_is_used_cnt_gen
    cam_is_used_cnt = 'd0;
    for(int i = 0; i < CAM_NUM; i = i + 1) begin
        if(cam_is_used[i]) begin
            cam_is_used_cnt = cam_is_used_cnt + 1'b1;
        end
    end
end
assign rdy_out = cam_is_used_cnt >= RDY_CNT ? 1'b0 : 1'b1;

always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        append_num_cnt <= '{default:0};
    end
    else if(rdy_in) begin
        for(int i = 0;i < CAM_NUM;i = i + 1) begin
            if(vld_in && (is_equal==0) && cam_is_no_used_onehot[i]) begin
                append_num_cnt[i] <= 'd0;
            end
            else if(vld_in && is_equal[i]) begin
                append_num_cnt[i] <= append_num_cnt[i] + 'd1;
            end
        end
    end
end


always_comb begin : is_equal_gen
    for(int i = 0; i < CAM_NUM; i = i + 1) begin
        is_equal[i] = vld_in && cam_is_used[i] && (data_cam_reg[i] == data_in) && (!(append_num_cnt[i]==(CAM_NUM-1)));
    end
end
always_comb begin
    cam_is_no_used_onehot_index = 'd0;
    is_equal_index = 'd0;
    for(int i = 0;i < CAM_NUM;i = i + 1) begin
        if(cam_is_no_used_onehot[i]) begin
            cam_is_no_used_onehot_index = i;
        end
        if(is_equal[i]) begin
            is_equal_index = i;
        end
    end
end

always_comb begin
    for(int i = 0; i < CAM_NUM;i = i + 1) begin
        is_search_equal[i] = search_vld && cam_is_used[i] && (search_in==data_cam_reg[i]);
    end    
end
assign is_search_equal_onehot = is_search_equal&(~(is_search_equal-1));
always_comb begin
    is_search_equal_onehot_index = 'd0;
    for(int i = 0; i < CAM_NUM;i = i + 1) begin
        if(is_search_equal_onehot[i]) begin
            is_search_equal_onehot_index = i;
        end
    end
end
assign addr_wr = (is_equal==0) ? cam_is_no_used_onehot_index : is_equal_index;
always_comb begin : sram_wr_gen
    for(int i = 0; i < CAM_NUM; i = i + 1) begin
        if(vld_in && (is_equal==0) && cam_is_no_used_onehot[i]) begin
            en_wr[0] = 1'b1;
        end
        for(int j = 0; j < APPEND_NUM-1; j = j + 1) begin
            en_wr[j+1] = ((is_equal[i]) & (append_num_cnt[i] == j));
        end
    end
end


generate
    for(genvar i = 0;i < APPEND_NUM;i = i + 1) begin
//        sram_wrapper_32x24 #(
//            .DATA_WIDTH(APPEND_WIDTH),
//            .ADDR_WIDTH($clog2(CAM_NUM)),
//            .ADDR_SPACE(CAM_NUM)
//        ) u_sram_wrapper_32x24
//        (
//            .clk_w  (clk), 
//            .addr_w (addr_wr),
//            .din_w  (append_in), 
//            .mask_w ({APPEND_WIDTH{1'b1}}),
//            .ce_w   (1'b0),   //low
//            .en_w   (~en_wr[i]),       //low

//            .clk_r  (clk), 
//            .addr_r (is_search_equal_onehot_index),
//            .ce_r   (1'b0),  
//            .en_r   (~(search_vld&&(is_search_equal!=0))),  
//            .dout_r (dout_r[i])    
//        );
        if_cam_sram_32x81 u_if_cam_sram_32x81 (
          .clka(clk),    // input wire clka
          .ena(1'b1),      // input wire ena
          .wea(en_wr[i]),      // input wire [0 : 0] wea
          .addra(addr_wr),  // input wire [4 : 0] addra
          .dina(append_in),    // input wire [23 : 0] dina
          .clkb(clk),    // input wire clkb
          .enb(1'b1),      // input wire enb
          .addrb(is_search_equal_onehot_index),  // input wire [4 : 0] addrb
          .doutb(dout_r[i])  // output wire [23 : 0] doutb
        );
    end
endgenerate



endmodule
