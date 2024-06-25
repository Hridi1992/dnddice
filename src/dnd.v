module tt_um_dice_roller (
    input wire clk,
    input wire reset,
    input wire [7:0] dip_switch, // 8-bit DIP switch input
    input wire mode_switch,      // Mode switch input (0: Display dice type/modifier, 1: Roll dice)
    output wire [6:0] seg,       // Seven segment output
    output wire [3:0] an         // Anode control for 4 digits
);
    reg [4:0] lfsr;
    wire feedback;
    reg [5:0] random_number; // 6-bit output to handle the sum of the largest dice roll and modifier

    wire [2:0] dice_type;
    wire [4:0] modifier;

    // Assign DIP switch inputs to dice_type and modifier
    assign dice_type = dip_switch[7:5];
    assign modifier = dip_switch[4:0];

    // Define the feedback polynomial x^5 + x^3 + 1
    assign feedback = lfsr[4] ^ lfsr[2];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            lfsr <= 5'b1; // LFSR should never be zero
        end else if (mode_switch) begin
            lfsr <= {lfsr[3:0], feedback}; // Shift left and insert feedback when rolling dice
        end
    end

    // Generate random number based on dice type and add modifier
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            random_number <= 6'd1; // Initial value between 1 and max dice value
        end else if (mode_switch) begin
            case (dice_type)
                3'b000: random_number <= (lfsr % 4) + 1 + modifier;   // d4 + modifier
                3'b001: random_number <= (lfsr % 6) + 1 + modifier;   // d6 + modifier
                3'b010: random_number <= (lfsr % 8) + 1 + modifier;   // d8 + modifier
                3'b011: random_number <= (lfsr % 10) + 1 + modifier;  // d10 + modifier
                3'b100: random_number <= (lfsr % 12) + 1 + modifier;  // d12 + modifier
                3'b101: random_number <= (lfsr % 20) + 1 + modifier;  // d20 + modifier
                default: random_number <= 6'd1 + modifier;            // Default to 1 + modifier
            endcase
        end
    end

    // Instantiate the seven segment display module
   module tt_um_seven_segment_display (
        .clk(clk),
        .reset(reset),
        .mode_switch(mode_switch),
        .dice_type(dice_type),
        .modifier(modifier),
        .random_number(random_number),
        .seg(seg),
        .an(an)
    );
endmodule

module tt_um_seven_segment_display (
    input wire clk,
    input wire reset,
    input wire mode_switch,       // Mode switch input (0: Display dice type/modifier, 1: Roll dice)
    input wire [2:0] dice_type,   // Dice type to display
    input wire [4:0] modifier,    // Modifier to display
    input wire [5:0] random_number,
    output reg [6:0] seg,         // Seven segment output
    output reg [3:0] an           // Anode control for 4 digits
);
    reg [3:0] digits [3:0]; // Array to store individual digits
    reg [1:0] digit_sel;    // Digit selection
    reg [3:0] current_digit; // Current digit to display

    // Segment encoding for digits 0-9 (common cathode)
    always @(*) begin
        case (current_digit)
            4'd0: seg = 7'b0000001; // 0
            4'd1: seg = 7'b1001111; // 1
            4'd2: seg = 7'b0010010; // 2
            4'd3: seg = 7'b0000110; // 3
            4'd4: seg = 7'b1001100; // 4
            4'd5: seg = 7'b0100100; // 5
            4'd6: seg = 7'b0100000; // 6
            4'd7: seg = 7'b0001111; // 7
            4'd8: seg = 7'b0000000; // 8
            4'd9: seg = 7'b0000100; // 9
            default: seg = 7'b1111111; // Default blank
        endcase
    end

    // Break down random number into digits or display dice type and modifier
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            digits[0] <= 0;
            digits[1] <= 0;
            digits[2] <= 0;
            digits[3] <= 0;
        end else if (mode_switch) begin
            // Display the rolled number
            digits[0] <= random_number % 10;
            digits[1] <= (random_number / 10) % 10;
            digits[2] <= (random_number / 100) % 10;
            digits[3] <= (random_number / 1000) % 10;
        end else begin
            // Display the dice type and modifier
            case (dice_type)
                3'b000: begin
                    digits[0] <= 4; // Display "04" for d4
                    digits[1] <= 0;
                end
                3'b001: begin
                    digits[0] <= 6; // Display "06" for d6
                    digits[1] <= 0;
                end
                3'b010: begin
                    digits[0] <= 8; // Display "08" for d8
                    digits[1] <= 0;
                end
                3'b011: begin
                    digits[0] <= 1; // Display "10" for d10
                    digits[1] <= 0;
                end
                3'b100: begin
                    digits[0] <= 1; // Display "12" for d12
                    digits[1] <= 2;
                end
                3'b101: begin
                    digits[0] <= 2; // Display "20" for d20
                    digits[1] <= 0;
                end
                default: begin
                    digits[0] <= 0;
                    digits[1] <= 0;
                end
            endcase
            digits[2] <= modifier % 10;
            digits[3] <= (modifier / 10) % 10;
        end
    end

    // Display digit selection and control
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            digit_sel <= 0;
            an <= 4'b1111;
        end else begin
            digit_sel <= digit_sel + 1;
            an <= 4'b1111;
            an[digit_sel] <= 0;
            current_digit <= digits[digit_sel];
        end
    end
endmodule
