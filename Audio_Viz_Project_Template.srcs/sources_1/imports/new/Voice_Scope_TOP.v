`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// National University of Singapore
// Department of Electrical and Computer Engineering
// EE2026 Digital Design
// AY1819 Semester 1
// Project: Voice Scope
//////////////////////////////////////////////////////////////////////////////////

module Voice_Scope_TOP(
    input CLK,
    
    // Switches
    input switch,
    input pause_switch,
    input grid_switch,
    input tick_switch,
    input axes_switch,
    input wave_switch,
    input noise_switch,
    input freq_switch,
    
    // Buttons
    input middle_button,
    input left_button,
    input right_button,
    input up_button,
    input down_button,
    
    // Volume indicator stuff
    output [11:0] led,
    output [3:0] an,
    output [7:0] seg,
    
    // Do not touch these
    input  J_MIC3_Pin3, // PmodMIC3 audio input data (serial)
    output J_MIC3_Pin1, // PmodMIC3 chip select, 20kHz sampling clock
    output J_MIC3_Pin4, // PmodMIC3 serial clock (generated by module VoiceCapturer.v)
    // Do not touch these
    output [3:0] VGA_RED, // RGB outputs to VGA connector (4 bits per channel gives 4096 possible colors)
    output [3:0] VGA_GREEN,
    output [3:0] VGA_BLUE,
    //Do not touch these
    output VGA_VS, // horizontal & vertical sync outputs to VGA connector
    output VGA_HS
    );
    
    // 20 KILO Hz clock divider
    wire freq_20kHz;
    clk_div my_20khz (CLK, freq_20kHz);
    
    // Used to store 12-bit mic inputs.
    wire [11:0] sound_sample;
    wire [11:0] block_sample;
    wire [11:0] bar_sound_sample;
    wire [11:0] nc_sound_sample;
    wire [3:0] volumeval;
    // Generates actual mic waveform
    Voice_Capturer vc1 (CLK, freq_20kHz, J_MIC3_Pin3, J_MIC3_Pin1, J_MIC3_Pin4, sound_sample);
    // Controls LED Indicator
    wire [7:0] volume_indicator_segment;
    wire [3:0] volume_indicator_anode;
    wire [11:0] maxvalue;
    Volume_Indicator vi (CLK, sound_sample, block_sample, volume_indicator_anode , volume_indicator_segment, volumeval, maxvalue);
    bar_convertor bar (freq_20kHz, sound_sample, bar_sound_sample); // THIS ONE RETURNS THE BAR GRAPH
    noise_cancelling_filter ncf (freq_20kHz, sound_sample, nc_sound_sample); // THIS IS FOR NOISE CANCELLING
    assign led[11:0] = block_sample[11:0];
    
    // Single pulse button handling
    wire left_button_out;
    wire right_button_out;
    wire middle_button_out;
    wire up_button_out;
    wire down_button_out;
    wire button_clock;
    generate_button_clock gbc (CLK, button_clock);
    single_pulse lbut (button_clock, left_button, left_button_out);
    single_pulse rbut (button_clock, right_button, right_button_out);
    single_pulse mbut (button_clock, middle_button, middle_button_out);
    single_pulse ubut (button_clock, up_button, up_button_out);
    single_pulse dbut (button_clock, down_button, down_button_out);
    
    // Essential stuff //
    wire [11:0] VGA_HORZ_COORD;
    wire [11:0] VGA_VERT_COORD; 
    wire CLK_VGA;
    
    /********* MODE SELECTOR *********/
    wire [14:0] VGA_mode_selector;
    wire [1:0] mode;
    mode_changer mc (CLK_VGA, VGA_HORZ_COORD, VGA_VERT_COORD,
        button_clock, up_button_out, down_button_out,
        mode, VGA_mode_selector);
        
    // Changing theme //
    wire [11:0] cur_theme_wave;
    wire [11:0] cur_theme_axes;
    wire [11:0] cur_theme_grid;
    wire [11:0] cur_theme_tick;
    wire [11:0] cur_theme_background;
    theme_selector ts (button_clock, left_button_out, right_button_out, cur_theme_wave, cur_theme_axes,
        cur_theme_grid, cur_theme_tick, cur_theme_background, mode);
    
    // Generates test waveform //
    wire [9:0] wave_sample; 
    TestWave_Gen tvg (freq_20kHz, wave_sample, sound_sample, pause_switch, mode);
    // Controls whether the test waveform or actual waveform is drawn.
    wire [9:0] draw_sound;
    assign draw_sound[9:0] = (switch) ? 
        (noise_switch) ? nc_sound_sample[11:2] 
        : sound_sample[11:2] 
        : wave_sample[9:0];
    
    /********* MODE 0 - WAVEFORM ***********/
    // Text drawing //
    wire [14:0] VGA_mode_one_text;
    draw_text dt_mode_one (CLK_VGA, button_clock, VGA_mode_one_text, VGA_HORZ_COORD, VGA_VERT_COORD, 
        middle_button_out, cur_theme_wave, cur_theme_background, mode);
    // Waveform drawing //
    wire [14:0] VGA_mode_one_waveform;
    draw_waveform dw_mode_one (freq_20kHz, draw_sound, VGA_HORZ_COORD, VGA_VERT_COORD, 
        VGA_mode_one_waveform, wave_switch, pause_switch, 
        cur_theme_wave, cur_theme_background);
    // Tick drawing //
    wire [14:0] VGA_mode_one_tick;
    draw_tick dtick_mode_one (VGA_HORZ_COORD, VGA_VERT_COORD, VGA_mode_one_tick,
        tick_switch, cur_theme_tick, cur_theme_background);  
    // Grid drawing //
    wire [14:0] VGA_mode_one_grid;
    draw_grid dg_mode_one (VGA_HORZ_COORD, VGA_VERT_COORD, VGA_mode_one_grid,
        axes_switch, grid_switch, cur_theme_axes, cur_theme_grid,
        cur_theme_background);
    // Background drawing //
    wire [14:0] VGA_mode_one_back;
    assign VGA_mode_one_back = {1'b1, cur_theme_background[3:0], 1'b1, cur_theme_background[7:4],
        1'b1, cur_theme_background[11:8]}; 
    
    /************ MODE 1 - GAME ************/
    wire game_running;
    wire restart;
    wire start_recording;
    // Text drawing //
    wire [14:0] VGA_game_end_text;
    wire [14:0] VGA_game_text;
    game_record_text grt (CLK_VGA, button_clock, VGA_HORZ_COORD, VGA_VERT_COORD,
        VGA_game_text, middle_button_out, left_button_out, right_button_out, 
        mode, game_running, restart, start_recording);
    // Rest of the stuff //    
    wire [14:0] VGA_game_player;
    wire [14:0] VGA_game_cliff;
    wire [14:0] VGA_game_cloud;
    wire [14:0] VGA_game_back;
    assign VGA_game_back = {1'b1, 4'hF, 1'b1, 4'h9, 1'b1, 4'h3};  
    draw_game dgb (CLK_VGA, freq_20kHz, VGA_HORZ_COORD, VGA_VERT_COORD,
        VGA_game_end_text, VGA_game_player, VGA_game_cliff, VGA_game_cloud,
        mode, game_running, restart, start_recording, nc_sound_sample, block_sample);
    
    /************ MODE 2 - FREQUENCY MEASURE ***********/
    // Waveform drawing //
    wire [14:0] VGA_freq_wave;
    draw_freq_waveform dfw (freq_20kHz, draw_sound, VGA_HORZ_COORD, VGA_VERT_COORD,
        VGA_freq_wave);   
    // Background drawing //
    wire [14:0] VGA_freq_back = {1'b1, 4'h0, 1'b1, 4'h0, 1'b1, 4'h0};  
    // Frequency Calculator - writes to the 7seg display
    wire [100:0] frequency;
    wire [3:0] frequency_anode;
    wire [7:0] frequency_segment;
    frequency_calculator fc (CLK, freq_20kHz, sound_sample, frequency, frequency_anode, frequency_segment);
    // Text drawing //
    wire [14:0] VGA_freq_text;
    draw_freq_text draw_my_freq (CLK_VGA, VGA_freq_text, VGA_HORZ_COORD, VGA_VERT_COORD);
    
    assign seg[7:0] = (freq_switch) ? frequency_segment[7:0] : volume_indicator_segment[7:0];
    assign an[3:0] = (freq_switch) ? frequency_anode[3:0] : volume_indicator_anode[3:0];
    
    /************ MODE 3 - MUSIC VISUALISER ************/
    // Text drawing //
    wire [14:0] VGA_ball_text;
    ball_text my_bt (CLK_VGA, VGA_ball_text, VGA_HORZ_COORD, VGA_VERT_COORD);   
    wire freq_bb;
    wire [14:0] VGA_ball_waveform;
    wire [14:0] VGA_ball_colour;
    clock_div_bouncing_balls cdbb (CLK, freq_20kHz, freq_bb); 
    ball_bounce my_balls (CLK_VGA, freq_20kHz, bar_sound_sample[11:1],
        middle_button_out, button_clock, volumeval, 
        VGA_HORZ_COORD, VGA_VERT_COORD, VGA_ball_colour, VGA_ball_waveform); 
    // Background drawing //
    wire [14:0] VGA_ball_back;
    assign VGA_ball_back = 15'b100001000010000;
    
    // Do not touch - VGA controller    
    VGA_DISPLAY (CLK, VGA_HORZ_COORD, VGA_VERT_COORD, CLK_VGA, mode, VGA_mode_selector,
        VGA_RED, VGA_GREEN, VGA_BLUE, VGA_VS, VGA_HS,
        VGA_mode_one_text, VGA_mode_one_waveform, VGA_mode_one_tick, VGA_mode_one_grid, VGA_mode_one_back, 
        VGA_game_end_text, VGA_game_text, VGA_game_player, VGA_game_cliff, VGA_game_cloud, VGA_game_back,
        VGA_freq_text, VGA_freq_wave, VGA_freq_back,
        VGA_ball_text, VGA_ball_colour, VGA_ball_waveform, VGA_ball_back);                  
endmodule
