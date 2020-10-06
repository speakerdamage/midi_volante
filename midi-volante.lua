-- MIDI Volante
-- 1.0.0 @speakerdamage
-- llllllll.co/t/TBD
--
-- Control Volante with MIDI CCs 
-- Including:
-- Connected sine LFOs
-- Random feedback head toggles
-- Random machine type switching
-- Random tape speed adjustments
--
-- E2 : Left time
-- E3 : Right time
-- K2 : Reset phase
--

local ControlSpec = require "controlspec"
local Formatters = require "formatters"

-- 11 Type 1-3 (1=studio, 2=drum, 3=tape
-- 12 Echo Level 0-127
-- 13 Rec Level 0-127
-- 14 Mechanics 0-127
-- 15 Wear 0-127
-- 16 Low Cut 0-127
-- 17 Time 0-127
-- 18 Spacing 0-127 (even=0, triplet=34, golden=94, silver=127)
-- 19 Speed 1-3 (1=double, 2=half, 3=normal)
-- 20 Repeats 0-127
-- 21 Head 1 Playback Off/On 0, 127 (0=off, 1-127=on) 
-- 22 Head 2 Playback Off/On 0, 127 (0=off, 1-127=on) 
-- 23 Head 3 Playback Off/On 0, 127 (0=off, 1-127=on) 
-- 24 Head 4 Playback Off/On 0, 127 (0=off, 1-127=on) 
-- 25 Head 1 Level 0-127
-- 26 Head 2 Level 0-127
-- 27 Head 3 Level 0-127
-- 28 Head 4 Level 0-127
-- 29 Head 1 Pan 0-127
-- 30 Head 2 Pan 0-127
-- 31 Head 3 Pan 0-127
-- 32 Head 4 Pan 0-127
-- 33 [none]
-- 34 Head 1 Feedback Off/On 0, 127 (0=off, 1-127=on)
-- 35 Head 2 Feedback Off/On 0, 127 (0=off, 1-127=on)
-- 36 Head 3 Feedback Off/On 0, 127 (0=off, 1-127=on)
-- 37 Head 4 Feedback Off/On 0, 127 (0=off, 1-127=on)
-- 38 Pause ramp speed 0-127
-- 39 Spring (level) 0-127
-- 40 Spring Decay 0-127
--
-- 41 SOS mode 0, 127 (0=normal, 1-127=SOS) 
-- 42 Pause (no ramp) 0, 127 (0=unpause, 1-127=pause)
-- 43 Pause (ramp) 0, 127 (0=unpause, 1-127=pause)
-- 44 Reverse 0, 127 (0=normal, 1-127=reverse)
-- 45 Infinite Hold (w/ oscillation) 0, 127 (0=release, 1-127=hold)
-- 46 Infinite Hold (w/o oscillation) 0-127 (0=release, 1-127=hold)
-- 47 SOS Loop Level 0-127
-- 48 SOS Repeats Level 0-127

-- TODO: 
-- assign specific CCs
-- change range on 0,127 / 1-3 items
-- timing per LFO (remove L/R)
-- user selected ranges

local SCREEN_FRAMERATE = 15
local screen_dirty = true

local NUM_LFOS = 12
local LFO_MIN_TIME = 1 -- Secs
local LFO_MAX_TIME = 60 * 60 * 24
local LFO_UPDATE_FREQ = 128
local LFO_RESOLUTION = 128 -- MIDI CC resolution was 128

local lfo_freqs = {}
local lfo_progress = {}
local lfo_values = {}

local midi_out_volante
local midi_out_channel

local machine_type = 1
local text_machine_type = "studio"
local tape_speed = 3

local cc_machine_type = 11
local cc_echo_level = 12
local cc_record_level = 13
local cc_mechanics = 14
local cc_wear = 15
local cc_low_cut = 16
local cc_time = 17
local cc_spacing = 18
local cc_tape_speed = 19
local cc_repeats = 20
local cc_h1_playback = 21
local cc_h2_playback = 22
local cc_h3_playback = 23
local cc_h4_playback = 24
local cc_h1_level = 25
local cc_h2_level = 26
local cc_h3_level = 27
local cc_h4_level = 28
local cc_h1_pan = 29
local cc_h2_pan = 30
local cc_h3_pan = 31
local cc_h4_pan = 32
local cc_h1_fdbk = 34
local cc_h2_fdbk = 35
local cc_h3_fdbk = 36
local cc_h4_fdbk = 37
local cc_pause_ramp_speed = 38
local cc_spring_level = 39
local cc_spring_decay = 40

local specs = {}
specs.TIME_L = ControlSpec.new(LFO_MIN_TIME, LFO_MAX_TIME, "exp", 0, 11, "s")
specs.TIME_R = ControlSpec.new(LFO_MIN_TIME, LFO_MAX_TIME, "exp", 0, 12, "s")

function reset_phase()
  for i = 1, NUM_LFOS do
    lfo_progress[i] = math.pi * 1.5
  end
end

local function update_freqs()
  for i = 1, NUM_LFOS do
    lfo_freqs[i] = 1 / util.linexp(1, NUM_LFOS, params:get("time_l"), params:get("time_r"), i)
  end
end

local function update_machine_type()
  machine_type = math.random(1,3)
  midi_out_volante:cc(cc_machine_type, machine_type, midi_out_channel)
  params:set("volante_machine_type", machine_type)
  screen_dirty = true
end

local function update_tape_speed()
  tape_speed = math.random(1,3)
  midi_out_volante:cc(cc_tape_speed, tape_speed, midi_out_channel)
  params:set("volante_speed", tape_speed)
  screen_dirty = true
end

local function update_spring_reverb()
  spring_level = math.random(0,127)
  spring_decay = math.random(0,127)
  midi_out_volante:cc(cc_spring_level, spring_level, midi_out_channel)
  params:set("volante_spring_level", spring_level)
  midi_out_volante:cc(cc_spring_decay, spring_decay, midi_out_channel)
  params:set("volante_spring_decay", spring_decay)
  screen_dirty = true
end

local function update_rec_level()
  rec_level = math.random(50,127)
  midi_out_volante:cc(cc_record_level, rec_level, midi_out_channel)
  params:set("volante_record_level", rec_level)
end

local function update_spacing()
  spacing = math.random(0,127)
  midi_out_volante:cc(cc_spacing, spacing, midi_out_channel)
  params:set("volante_spacing", spacing)
end

local function update_feedback_heads(thead)
  if head == 1 then
    midi_out_volante:cc(cc_h1_fdbk, math.random(0,1), midi_out_channel)
  elseif thead == 2 then
    midi_out_volante:cc(cc_h2_fdbk, math.random(0,1), midi_out_channel)
  elseif thead == 3 then
    midi_out_volante:cc(cc_h3_fdbk, math.random(0,1), midi_out_channel)
  elseif thead == 4 then
    midi_out_volante:cc(cc_h4_fdbk, math.random(0,1), midi_out_channel)
  elseif thead == 5 then
    update_tape_speed()
    update_machine_type()
  elseif thead == 6 then
    update_spring_reverb()
    update_rec_level()
    update_spacing()
  end
  screen_dirty = true
end


-- Metro callbacks

local function lfo_update()
  local delta = (1 / LFO_UPDATE_FREQ) * 2 * math.pi
  for i = 1, NUM_LFOS do
    lfo_progress[i] = lfo_progress[i] + delta * lfo_freqs[i]
    local value = util.round(util.linlin(-1, 1, 0, LFO_RESOLUTION - 1, math.sin(lfo_progress[i])))
    if value ~= lfo_values[i] then
      lfo_values[i] = value
      midi_out_volante:cc(i - 1 + params:get("midi_cc_start"), value, midi_out_channel)
      screen_dirty = true
    end
  end
  --local first_lfo_value = lfo_values[1]
  --print(first_lfo_value)
  --if first_lfo_value == 64 then
    --update_machine_type()
    --update_tape_speed()
    --update_feedback_heads()
  --end
end

function clocked_cc(rate, tapehead)
  while true do
    clock.sync(1/rate)
    update_feedback_heads(tapehead)
    
  end
end

local function screen_update()
  if screen_dirty then
    screen_dirty = false
    redraw()
  end
end


-- Encoder input
function enc(n, delta)
  if n == 2 then
    params:delta("time_l", delta * 0.1)
  elseif n == 3 then
    params:delta("time_r", delta * 0.1)
  end
end

-- Key input
function key(n, z)
  if z == 1 then
    if n == 2 then
      reset_phase()
      clock.cancel(head[6])
    end
    if n == 3 then
      head[6] = clock.run(clocked_cc,0.75,6)
    end
  end
end


function init()
  midi_out_volante = midi.connect(1)
  
  head = {}
  head[1] = clock.run(clocked_cc,3,1)
  head[2] = clock.run(clocked_cc,1,2)
  head[3] = clock.run(clocked_cc,2,3)
  head[4] = clock.run(clocked_cc,0.33,4)
  head[5] = clock.run(clocked_cc,0.5,5)
  head[6] = clock.run(clocked_cc,0.75,6)
  
  params:set("clock_tempo",10)

  -- Add params
  
  params:add_separator()

  params:add {
    type = "number",
    id = "midi_out_volante",
    name = "MIDI Out Device",
    min = 1,
    max = 4,
    default = 3,
    action = function(value)
      midi_out_volante = midi.connect(value)
    end
  }

  params:add {
    type = "number",
    id = "midi_out_channel",
    name = "MIDI Out Channel",
    min = 1,
    max = 16,
    default = 3,
    action = function(value)
      midi_out_channel = value
    end
  }

  params:add {
    type = "number",
    id = "midi_cc_start",
    name = "MIDI CC Range",
    min = 11, -- was 0
    max = 48 - NUM_LFOS, -- was 128
    default = 20,
    formatter = function(param)
      return param:get() .. "-" .. param:get() + NUM_LFOS - 1
    end
  }

  params:add_separator("LFOs")

  params:add {
    type = "control",
    id = "time_l",
    name = "Left Time",
    controlspec = specs.TIME_L,
    formatter = Formatters.format_secs,
    action = function(value)
      update_freqs()
      screen_dirty = true
    end
  }

  params:add {
    type = "control",
    id = "time_r",
    name = "Right Time",
    controlspec = specs.TIME_R,
    formatter = Formatters.format_secs,
    action = function(value)
      update_freqs()
      screen_dirty = true
    end
  }
  
  params:add_separator("Volante")
  
  params:add {
    type = "number",
    id = "volante_machine_type",
    name = "Echo Machine Type",
    min = 1,
    max = 3,
    default = 1, -- (1=studio, 2=drum, 3=tape)
    cc = 11,
    action = function(value)
      volante_machine_type = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_echo_level",
    name = "Echo Level",
    min = 0,
    max = 127,
    default = 1,
    cc = 12,
    action = function(value)
      volante_echo_level = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_record_level",
    name = "Record Level",
    min = 0,
    max = 127,
    default = 64,
    cc = 13,
    action = function(value)
      volante_record_level = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_mechanics",
    name = "Mechanics",
    min = 0,
    max = 127,
    default = 64,
    cc = 14,
    action = function(value)
      volante_mechanics = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_wear",
    name = "Wear",
    min = 0,
    max = 127,
    default = 64,
    cc = 15,
    action = function(value)
      volante_wear = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_low_cut",
    name = "Low Cut",
    min = 0,
    max = 127,
    default = 64,
    cc = 16,
    action = function(value)
      volante_low_cut = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_time",
    name = "Time",
    min = 0,
    max = 127,
    default = 70,
    cc = 17,
    action = function(value)
      volante_time = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_spacing",
    name = "Spacing",
    min = 0,
    max = 127,
    default = 64, -- (even=0, triplet=34, golden=94, silver=127)
    cc = 18,
    action = function(value)
      volante_spacing = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_speed",
    name = "Tape Speed",
    min = 1,
    max = 3,
    default = 3, -- (1=double, 2=half, 3=normal)
    cc = 19,
    action = function(value)
      volante_speed = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_repeats",
    name = "Repeats",
    min = 0,
    max = 127,
    default = 64,
    cc = 20,
    action = function(value)
      volante_repeats = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_h1_playback",
    name = "Head1 Play",
    min = 0,
    max = 1,
    default = 1, -- (0=off, 1=on)
    cc = 21,
    action = function(value)
      volante_h1_playback = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_h2_playback",
    name = "Head2 Play",
    min = 0,
    max = 1,
    default = 1, -- (0=off, 1=on)
    cc = 22,
    action = function(value)
      volante_h2_playback = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_h3_playback",
    name = "Head3 Play",
    min = 0,
    max = 1,
    default = 1, -- (0=off, 1=on)
    cc = 23,
    action = function(value)
      volante_h3_playback = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_h4_playback",
    name = "Head4 Play",
    min = 0,
    max = 1,
    default = 1, -- (0=off, 1=on)
    cc = 24,
    action = function(value)
      volante_h4_playback = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_h1_level",
    name = "Head1 Level",
    min = 0,
    max = 127,
    default = 64,
    cc = 25,
    action = function(value)
      volante_h1_level = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_h2_level",
    name = "Head2 Level",
    min = 0,
    max = 127,
    default = 64,
    cc = 26,
    action = function(value)
      volante_h2_level = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_h3_level",
    name = "Head3 Level",
    min = 0,
    max = 127,
    default = 64,
    cc = 27,
    action = function(value)
      volante_h3_level = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_h4_level",
    name = "Head4 Level",
    min = 0,
    max = 127,
    default = 64,
    cc = 28,
    action = function(value)
      volante_h4_level = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_h1_pan",
    name = "Head1 Pan",
    min = 0,
    max = 127,
    default = 25,
    cc = 29,
    action = function(value)
      volante_h1_pan = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_h2_pan",
    name = "Head2 Pan",
    min = 0,
    max = 127,
    default = 50,
    cc = 30,
    action = function(value)
      volante_h2_pan = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_h3_pan",
    name = "Head3 Pan",
    min = 0,
    max = 127,
    default = 75,
    cc = 31,
    action = function(value)
      volante_h3_pan = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_h4_pan",
    name = "Head4 Pan",
    min = 0,
    max = 127,
    default = 100,
    cc = 32,
    action = function(value)
      volante_h4_pan = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_h1_feedback",
    name = "Head1 Feedback",
    min = 0,
    max = 1,
    default = 1, -- (0=off, 1=on)
    cc = 34,
    action = function(value)
      volante_h1_feedback = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_h2_feedback",
    name = "Head2 Feedback",
    min = 0,
    max = 1,
    default = 1, -- (0=off, 1=on)
    cc = 35,
    action = function(value)
      volante_h2_feedback = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_h3_feedback",
    name = "Head3 Feedback",
    min = 0,
    max = 1,
    default = 1, -- (0=off, 1=on)
    cc = 36,
    action = function(value)
      volante_h3_feedback = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_h4_feedback",
    name = "Head4 Feedback",
    min = 0,
    max = 1,
    default = 1, -- (0=off, 1=on)
    cc = 37,
    action = function(value)
      volante_h4_feedback = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_pause_ramp_speed",
    name = "Pause Speed",
    min = 0,
    max = 127,
    default = 64,
    cc = 38,
    action = function(value)
      volante_pause_ramp_speed = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_spring_level",
    name = "Spring Level",
    min = 0,
    max = 127,
    default = 64,
    cc = 39,
    action = function(value)
      volante_spring_level = value
    end
  }
  
  params:add {
    type = "number",
    id = "volante_spring_decay",
    name = "Spring Decay",
    min = 0,
    max = 127,
    default = 64,
    cc = 40,
    action = function(value)
      volante_spring_decay = value
    end
  }

  midi_out_channel = params:get("midi_out_channel")

  reset_phase()
  update_freqs()
  lfo_update()
  
  metro.init(lfo_update, 1 / LFO_UPDATE_FREQ):start()
  metro.init(screen_update, 1 / SCREEN_FRAMERATE):start()

end


function redraw()
  screen.clear()
  screen.aa(1)

  local BAR_W, BAR_H = 1, 41
  local MARGIN_H, MARGIN_V = 6, 6
  local gutter = (128 - MARGIN_H * 2 - BAR_W * NUM_LFOS) / (NUM_LFOS - 1)

  -- Draw bars
  for i = 1, NUM_LFOS do
    local row_x = util.round(MARGIN_H + (gutter + BAR_W) * (i - 1))

    -- Dotted
    for y = 0, BAR_H - 1, 2 do
      screen.rect(row_x, MARGIN_V + y, BAR_W, 1)
      screen.level(1)
      screen.fill()
    end

    -- Fills
    local filled_height = util.linlin(0, LFO_RESOLUTION - 1, 0, BAR_H, lfo_values[i])
    screen.rect(row_x, MARGIN_V + BAR_H - filled_height, BAR_W, filled_height)
    screen.level(15)
    screen.fill()
  end

  -- Draw text
  screen.level(3)
  screen.move(MARGIN_H, 64 - 5)
  screen.text("\u{25C0} " .. params:string("time_l"))
  screen.move(128 - MARGIN_H, 64 - 5)
  screen.text_right(params:string("time_r") .. " \u{25B6}")
  screen.fill()
  screen.move(64 - MARGIN_H, 64-5)
  if machine_type == 1 then
    text_machine_type = "studio"
  elseif machine_type == 2 then
    text_machine_type = "drum"
  elseif machine_type == 3 then
    text_machine_type = "tape"
end
  screen.text_center(text_machine_type)

  screen.update()
end
