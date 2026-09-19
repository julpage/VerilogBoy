`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Wenting Zhang
//
// Create Date:    22:24:55 04/08/2018
// Module Name:    sound_length_ctr
// Project Name:   VerilogBoy
// Description:
//   Sound length control for all channels
// Dependencies:
//   none
// Additional Comments:
//   通道输出时长定时器
//   Channel 3 has a different length
//////////////////////////////////////////////////////////////////////////////////
module apu_length_ctr #(
    // 6bit(64) for Ch124, 8bit(256) for Ch3
    parameter WIDTH = 6
)  (
    input clk,
    input rst,
    input dacOn,
    input clk_256hz,
    input renewLength,
    input trigger,
    input lenEn,
    input [WIDTH-1:0] length,
    output reg active
);
    
    
    localparam [WIDTH:0] MAX_LENGTH = (1 << WIDTH); // 64 256
    
    
    // 03-trigger.s test 2,"Enabling in second half of length period shouldn't clock length"
    // 03-trigger.s test 3,"Enabling in first half of length period should clock length"
    // 03-trigger.s test 4,"Anything besides enabling shouldnt't clock"
    wire pluse_clockLength;
    edgedet u_ed1 (
        .clk (clk),
        .i   (clk_256hz & lenEn),
        .o   (pluse_clockLength)
    );
    
    
    // Length Control
    reg [WIDTH:0] length_left;
    
    always @(posedge clk) begin

        if (rst) begin
            // 02-len ctr.s test 16,"Volume reaching 0 shouldn't disable channel"
            // 03-trigger.s test 12,"Other trigger effects should still occur when disabled"
            active      <= 1'b0;
            length_left <= {WIDTH{1'b0}};
        end
        else if (renewLength) begin
            // 02-len ctr.s test 3,"Length can be reloaded at any time"
            // 02-len ctr.s test 4,"Attempting to load length with 0 should load with maximum"
            // 02-len ctr.s test 12,"Disabled channel should still convert 0 load to max length"
            length_left <= MAX_LENGTH - {1'b0, length}; // apu关闭时 dmg可写 cgb不可写
        end
        else if (trigger) begin
            // 02-len ctr.s test 8,"Disabling length shouldn't re-enable channel"
            // 02-len ctr.s test 10,"Reloading shouldn't re-enable channel"
            // 02-len ctr.s test 14,"Disabled DAC should prevent enable at trigger"
            // 02-len ctr.s test 15,"Enabling DAC shouldn't re-enable channel"
            active <= (dacOn) ? 1'b1 : 1'b0;
            
            if (!lenEn) begin
                // 02-len ctr.s test 7,"Trigger with disabled length should convert 0 length to maximum"
                // 03-trigger.s test 7,"Trigger should un-freeze length that reached zero"
                // 03-trigger.s test 10,"Trigger shouldn't otherwise affect length"
                length_left <= (length_left == 0) ? MAX_LENGTH : length_left;
            end
            else begin
                if (length_left == 0) begin
                    // 02-len ctr.s test 6,"Trigger should treat 0 length as maximum"
                    // 03-trigger.s test 8,"Trigger that un-freezes enabled length should clock it"
                    length_left <= MAX_LENGTH - ((clk_256hz) ? (1) : (0));
                end
                else if (length_left == 1 && pluse_clockLength) begin
                    // 03-trigger.s test 9,"Triggering that clocks length of 1 should clock twice and shouldn't freeze"
                    length_left <= MAX_LENGTH - 1;
                end
                else begin
                    // 02-len ctr.s test 5,"Trigger shouldn't affect length"
                    length_left <= length_left - ((pluse_clockLength) ? (1) : (0));
                end
            end
        end
        else if (pluse_clockLength) begin
            if (lenEn && (length_left != 0)) begin
                // 02-len ctr.s test 9,"Disabling length should stop length clocking"
                // 02-len ctr.s test 11,"Disabled channel should still clock length"
                // 03-trigger.s test 6,"If length already reached zero, shouldn't clock"
                length_left <= length_left - 1;
            end
            if (length_left <= 1) begin
                // 02-len ctr.s test 2,"Length becoming 0 should clear status"
                // 03-trigger.s test 5,"If clock makes length zero, should disable chan"
                active <= 1'b0;
            end
        end
        else if (!dacOn) begin
            // 02-len ctr.s test 13,"Disabling DAC should disable channel immediately"
            // 03-trigger.s test 11,"Disabled DAC shouldn't stop other trigger effects"
            active <= 1'b0;
        end
        
    end
    
    
endmodule
