// RockPaperScissors 主模組
module RockPaperScissors(
    input wire CLK,                  // 系統時鐘
    input wire RESET,                // 重置信號
    input wire BTN_ROCK,             // 選擇「石頭」的按鈕
    input wire BTN_PAPER,            // 選擇「布」的按鈕
    input wire BTN_SCISSORS,         // 選擇「剪刀」的按鈕
    output reg LED_ROCK,             // 顯示玩家選擇「石頭」
    output reg LED_PAPER,            // 顯示玩家選擇「布」
    output reg LED_SCISSORS,         // 顯示玩家選擇「剪刀」
    output reg LED_C_ROCK,           // 顯示電腦選擇「石頭」
    output reg LED_C_PAPER,          // 顯示電腦選擇「布」
    output reg LED_C_SCISSORS,       // 顯示電腦選擇「剪刀」
    output reg LED_WIN,              // 顯示玩家勝利
    output reg LED_LOSE,             // 顯示玩家失敗
    output reg LED_TIE,              // 顯示平局
    output reg BUZZER,               // 蜂鳴器輸出，用於失敗提示
    // LED 矩陣輸出
    output wire [7:0] row_R,         // LED 矩陣紅色行數據
    output wire [7:0] row_G,         // LED 矩陣綠色行數據
    output wire [3:0] COMM            // LED 矩陣列選擇
);
    // 實例化 Debouncer 模組
    wire btn_rock_db;
    wire btn_paper_db;
    wire btn_scissors_db;
    
    Debouncer db_rock (
        .clk(CLK),
        .reset(RESET),
        .button_in(BTN_ROCK),
        .button_out(btn_rock_db)
    );
    
    Debouncer db_paper (
        .clk(CLK),
        .reset(RESET),
        .button_in(BTN_PAPER),
        .button_out(btn_paper_db)
    );
    
    Debouncer db_scissors (
        .clk(CLK),
        .reset(RESET),
        .button_in(BTN_SCISSORS),
        .button_out(btn_scissors_db)
    );
    
    // 狀態機狀態定義
    parameter IDLE = 2'd0;
    parameter PLAYER_CHOICE = 2'd1;
    parameter COMPUTER_CHOICE = 2'd2;
    parameter RESULT = 2'd3;
    
    reg [1:0] current_state, next_state;
    
    // 玩家和電腦的選擇定義
    parameter CHOICE_ROCK = 2'd0;      // 石頭
    parameter CHOICE_PAPER = 2'd1;     // 布
    parameter CHOICE_SCISSORS = 2'd2;  // 剪刀
    
    reg [1:0] player_choice;
    reg [1:0] computer_choice;
    
    // 遊戲結果定義
    parameter RESULT_WIN = 2'd0;   // 玩家勝利
    parameter RESULT_LOSE = 2'd1;  // 玩家失敗
    parameter RESULT_TIE = 2'd2;    // 平局
    
    reg [1:0] game_result;
    
    // 簡單的偽隨機生成器（基於計數器）
    reg [23:0] rand_counter;
    
    // 蜂鳴器控制參數
    reg [23:0] buzzer_counter;
    parameter BUZZER_ON_DURATION = 5000000; // 約0.1秒對於50MHz時鐘
    
    // LED 矩陣圖案定義
    // '0' 代表亮起，'1' 代表不亮
    // X 的圖案（紅色）
    parameter [63:0] PATTERN_X_R = 64'b10000001_01000010_00100100_00011000_00011000_00100100_01000010_10000001;
    parameter [63:0] PATTERN_X_G = 64'd0; // 不顯示綠色
    
    // Y 的圖案（綠色）
    parameter [63:0] PATTERN_Y_R = 64'd0; // 不顯示紅色
    parameter [63:0] PATTERN_Y_G = 64'b10000001_01000010_00100100_00011000_00011000_00011000_00011000_00011000;
        
    // LED 矩陣控制信號
    reg [63:0] pattern_R;
    reg [63:0] pattern_G;
    
    // 實例化 MatrixController 模組
    MatrixController matrix (
        .clk(CLK),
        .reset(RESET),
        .pattern_R(pattern_R),
        .pattern_G(pattern_G),
        .COMM(COMM),
        .DATA_R(row_R),
        .DATA_G(row_G),
        .DATA_B() // 未使用藍色，固定為不亮
    );
    
    // 狀態機和隨機計數器邏輯
    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            current_state <= IDLE;
            rand_counter <= 0;
            buzzer_counter <= 0;
        end else begin
            current_state <= next_state;
            rand_counter <= rand_counter + 1;
            if (BUZZER_ON_DURATION <= buzzer_counter)
                buzzer_counter <= 0;
            else if (game_result == RESULT_LOSE && buzzer_counter != BUZZER_ON_DURATION)
                buzzer_counter <= buzzer_counter + 1;
        end
    end
    
    // 下一狀態邏輯
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (btn_rock_db || btn_paper_db || btn_scissors_db)
                    next_state = PLAYER_CHOICE;
                else
                    next_state = IDLE;
            end
            PLAYER_CHOICE: begin
                next_state = COMPUTER_CHOICE;
            end
            COMPUTER_CHOICE: begin
                next_state = RESULT;
            end
            RESULT: begin
                if (~(btn_rock_db || btn_paper_db || btn_scissors_db))
                    next_state = IDLE;
                else
                    next_state = RESULT;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // 遊戲邏輯和 LED 控制
    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            // 初始化所有 LED
            LED_ROCK <= 0;
            LED_PAPER <= 0;
            LED_SCISSORS <= 0;
            LED_C_ROCK <= 0;
            LED_C_PAPER <= 0;
            LED_C_SCISSORS <= 0;
            LED_WIN <= 0;
            LED_LOSE <= 0;
            LED_TIE <= 0;
            BUZZER <= 0;
            // 初始化選擇和結果
            player_choice <= CHOICE_ROCK;
            computer_choice <= CHOICE_ROCK;
            game_result <= RESULT_TIE;
            // 初始化 LED 矩陣
            pattern_R <= 64'd0;
            pattern_G <= 64'd0;
        end else begin
            case (current_state)
                IDLE: begin
                    // 清除所有 LED
                    LED_ROCK <= 0;
                    LED_PAPER <= 0;
                    LED_SCISSORS <= 0;
                    LED_C_ROCK <= 0;
                    LED_C_PAPER <= 0;
                    LED_C_SCISSORS <= 0;
                    LED_WIN <= 0;
                    LED_LOSE <= 0;
                    LED_TIE <= 0;
                    BUZZER <= 0;
                    // 清除 LED 矩陣
                    pattern_R <= 64'd0;
                    pattern_G <= 64'd0;
                end
                PLAYER_CHOICE: begin
                    // 捕捉玩家的選擇並顯示
                    if (btn_rock_db) begin
                        player_choice <= CHOICE_ROCK;
                        LED_ROCK <= 1;
                        LED_PAPER <= 0;
                        LED_SCISSORS <= 0;
                    end else if (btn_paper_db) begin
                        player_choice <= CHOICE_PAPER;
                        LED_ROCK <= 0;
                        LED_PAPER <= 1;
                        LED_SCISSORS <= 0;
                    end else if (btn_scissors_db) begin
                        player_choice <= CHOICE_SCISSORS;
                        LED_ROCK <= 0;
                        LED_PAPER <= 0;
                        LED_SCISSORS <= 1;
                    end
                end
                COMPUTER_CHOICE: begin
                    // 電腦隨機選擇並顯示
                    computer_choice <= rand_counter[3:2]; // 增加偽隨機性，使用更多位元
                    case (computer_choice)
                        CHOICE_ROCK: begin
                            LED_C_ROCK <= 1;
                            LED_C_PAPER <= 0;
                            LED_C_SCISSORS <= 0;
                        end
                        CHOICE_PAPER: begin
                            LED_C_ROCK <= 0;
                            LED_C_PAPER <= 1;
                            LED_C_SCISSORS <= 0;
                        end
                        CHOICE_SCISSORS: begin
                            LED_C_ROCK <= 0;
                            LED_C_PAPER <= 0;
                            LED_C_SCISSORS <= 1;
                        end
                        default: begin
                            LED_C_ROCK <= 0;
                            LED_C_PAPER <= 0;
                            LED_C_SCISSORS <= 0;
                        end
                    endcase
                end
                RESULT: begin
                    // 判斷遊戲結果並顯示
                    if (player_choice == computer_choice) begin
                        game_result <= RESULT_TIE;
                        LED_TIE <= 1;
                        LED_WIN <= 0;
                        LED_LOSE <= 0;
                        // 清除 LED 矩陣
                        pattern_R <= 64'd0;
                        pattern_G <= 64'd0;
                        BUZZER <= 0;
                    end else if (
                        (player_choice == CHOICE_ROCK && computer_choice == CHOICE_SCISSORS) ||
                        (player_choice == CHOICE_PAPER && computer_choice == CHOICE_ROCK) ||
                        (player_choice == CHOICE_SCISSORS && computer_choice == CHOICE_PAPER)
                    ) begin
                        game_result <= RESULT_WIN;
                        LED_TIE <= 0;
                        LED_WIN <= 1;
                        LED_LOSE <= 0;
                        // 顯示 Y 在 LED 矩陣
                        pattern_R <= 64'd0;
                        pattern_G <= PATTERN_Y_G;
                        BUZZER <= 0;
                    end else begin
                        game_result <= RESULT_LOSE;
                        LED_TIE <= 0;
                        LED_WIN <= 0;
                        LED_LOSE <= 1;
                        // 顯示 X 在 LED 矩陣
                        pattern_R <= PATTERN_X_R;
                        pattern_G <= 64'd0;
                        BUZZER <= 1; // 觸發蜂鳴器
                    end
                end
                default: begin
                    // 默認情況下，保持當前狀態
                end
            endcase
            
            // 蜂鳴器控制邏輯
            if (game_result == RESULT_LOSE && buzzer_counter < BUZZER_ON_DURATION) begin
                BUZZER <= 1;
            end else begin
                BUZZER <= 0;
            end
        end
    end
    endmodule
// MatrixController 模組：控制全彩 8x8 LED 矩陣的顯示
module MatrixController(
    input wire clk,                // 系統時鐘
    input wire reset,              // 重置信號
    input wire [63:0] pattern_R,   // 紅色圖案（8列，每列8位）
    input wire [63:0] pattern_G,   // 綠色圖案（8列，每列8位）
    output reg [3:0] COMM,         // COMM[3:0] 控制列選擇
    output reg [7:0] DATA_R,       // 紅色行數據
    output reg [7:0] DATA_G,       // 綠色行數據
    output reg [7:0] DATA_B        // 藍色行數據（固定為1，表示不亮）
);
    // 列計數器
    reg [2:0] column_counter;
    // 掃描速度控制計數器
    reg [15:0] scan_counter;
    parameter SCAN_DELAY = 2500;    // 調整掃描速度（根據時鐘頻率）

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            column_counter <= 0;
            scan_counter <= 0;
            COMM <= 4'b1111;          // 初始狀態，所有列不激活
            DATA_R <= 8'b11111111;    // 全部行不亮
            DATA_G <= 8'b11111111;    // 全部行不亮
            DATA_B <= 8'b11111111;    // 全部行不亮
        end else begin
            if (scan_counter < SCAN_DELAY) begin
                scan_counter <= scan_counter + 1;
            end else begin
                scan_counter <= 0;
                // 切換到下一列
                if (column_counter < 7) begin
                    column_counter <= column_counter + 1;
                end else begin
                    column_counter <= 0;
                end
                // 設定 COMM[3:0]，COMM[3] 為 Enable，COMM[2:0] 為列選擇
                COMM <= {1'b1, column_counter};
                // 設定行數據（'0' 代表亮起，'1' 代表不亮）
                DATA_R <= ~pattern_R[(column_counter*8) +: 8];
                DATA_G <= ~pattern_G[(column_counter*8) +: 8];
                DATA_B <= 8'b11111111;    // 固定為不亮，除非需要藍色顯示
            end
        end
    end
endmodule 
// Debouncer 模組：對按鈕輸入進行防抖動處理
module Debouncer(
    input wire clk,          // 系統時鐘
    input wire reset,        // 重置信號
    input wire button_in,    // 原始按鈕輸入
    output reg button_out    // 防抖後的按鈕輸出
);
    // 防抖動參數
    parameter DEBOUNCE_COUNTER_MAX = 500000; // 約10ms對於50MHz時鐘
    
    reg [19:0] counter;           // 計數器
    reg button_sync_0, button_sync_1; // 同步寄存器
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 0;
            button_sync_0 <= 0;
            button_sync_1 <= 0;
            button_out <= 0;
        end else begin
            // 同步按鈕輸入以避免亞穩定
            button_sync_0 <= button_in;
            button_sync_1 <= button_sync_0;
            
            if (button_sync_1 == button_out) begin
                counter <= 0;
            end else begin
                counter <= counter + 1;
                if (counter == DEBOUNCE_COUNTER_MAX) begin
                    button_out <= button_sync_1;
                    counter <= 0;
                end
            end
        end
    end
endmodule 
