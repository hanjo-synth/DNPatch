-- Digitone CC Randomizer v1.1
-- Adapted by HANJO + ChatGPT, Tokyo, Japan.
--
-- K3: Randomize CC values on the current page.
-- E1: Change page.
-- E2: Select CC slot.
-- K2 + E3: Change edit mode (CC Target, Value, MIDI Channel).
-- E3: Adjust selected CC target, value, or MIDI channel based on edit mode.
-- CC = -1 disables that slot from being randomized or triggered.

local midi_out
local channel = 9

local num_slots_per_page = 8
local num_pages = 9
local current_page = 1

local page_data = {
  {
    title = "TRIG",
    cc_targets = {5, 13, 14, 15},
    cc_values = {0, 0, 0, 0}
  },
  {
    title = "SYN1",
    cc_targets = {90, 91, 92, 16, 17, 18, 19, 20},
    cc_values = {0, 0, 0, 0, 0, 0, 0, 0}
  },
  {
    title = "SYN2a",
    cc_targets = {75, 76, 77, 78, 79, 80, 81, 82},
    cc_values = {0, 0, 0, 0, 0, 0, 0, 0}
  },
  {
    title = "SYN2b",
    cc_targets = {83, 84, 85, 86, 87, 88, 89},
    cc_values = {0, 0, 0, 0, 0, 0, 0}
  },
  {
    title = "FILTER",
    cc_targets = {23, 24, 74, 70, 71, 72, 73, 25},
    cc_values = {0, 0, 0, 0, 0, 0, 0, 0}
  },
  {
    title = "ADSR",
    cc_targets = {104, 105, 106, 107},
    cc_values = {0, 0, 0, 0}
  },
  {
    title = "AMP",
    cc_targets = {9, 10, 7, 12, 13, 14, 102},
    cc_values = {0, 0, 0, 0, 0, 0, 0}
  },
  {
    title = "LFO1",
    cc_targets = {28, 108, 109, 110, 111, 112, 113, 29},
    cc_values = {0, 0, 0, 0, 0, 0, 0, 0}
  },
  {
    title = "LFO2",
    cc_targets = {30, 114, 115, 116, 117, 118, 119, 31},
    cc_values = {0, 0, 0, 0, 0, 0, 0, 0}
  }
}

local selected_slot = 1
local edit_mode = "cc"

function init()
  midi_out = midi.connect(1)

  params:add_separator("CC Randomizer Settings")
  params:add_number("midi_channel", "MIDI Channel", 1, 16, 1)
  params:set_action("midi_channel", function(val) channel = val end)

  params:add_number("cc_val_min", "Value Min", 0, 127, 0)
  params:add_number("cc_val_max", "Value Max", 0, 127, 127)

  clock.run(redraw_loop)
end

function get_current_page_data()
  return page_data[current_page]
end

function send_dice_roll()
  local current_data = get_current_page_data()
  local val_min = params:get("cc_val_min")
  local val_max = params:get("cc_val_max")
  local ch = params:get("midi_channel")

  for i = 1, num_slots_per_page do
    local cc = current_data.cc_targets[i]
    if cc and cc ~= -1 then
      local val
      if current_data.title == "SYN1" and cc == 90 and i == 1 then
        val = math.random(0, 7)
      else
        val = math.random(val_min, val_max)
      end
      current_data.cc_values[i] = val
      midi_out:cc(cc, val, ch)
      print("🎲 Page " .. current_page .. " Slot " .. i .. " → CC " .. cc .. " = " .. val)
    end
  end
end

function key(n, z)
  if n == 3 and z == 1 then
    send_dice_roll()
  elseif n == 2 and z == 1 then
    if edit_mode == "cc" then
      edit_mode = "value"
    elseif edit_mode == "value" then
      edit_mode = "midi"
    else
      edit_mode = "cc"
    end
  end
end

function enc(n, d)
  if n == 1 then
    current_page = util.clamp(current_page + d, 1, num_pages)
    selected_slot = 1
  elseif n == 2 then
    selected_slot = util.clamp(selected_slot + d, 1, num_slots_per_page)
  elseif n == 3 then
    local current_data = get_current_page_data()
    if edit_mode == "cc" then
      if current_data.cc_targets[selected_slot] ~= nil then
        current_data.cc_targets[selected_slot] = util.clamp(current_data.cc_targets[selected_slot] + d, -1, 127)
      end
    elseif edit_mode == "value" then
      if current_data.cc_targets[selected_slot] and current_data.cc_targets[selected_slot] ~= -1 then
        current_data.cc_values[selected_slot] = util.clamp(current_data.cc_values[selected_slot] + d, 0, 127)
        midi_out:cc(current_data.cc_targets[selected_slot], current_data.cc_values[selected_slot], params:get("midi_channel"))
      end
    elseif edit_mode == "midi" then
      local new_channel = util.clamp(params:get("midi_channel") + d, 1, 16)
      params:set("midi_channel", new_channel)
    end
  end
end

function redraw()
  screen.clear()
  screen.font_size(8)

  local current_data = get_current_page_data()
  local title = current_data.title
  local title_x = (128 - (#title * 6)) / 2 + 6
  screen.move(title_x, 5)
  screen.text(title)

  for i = 1, 4 do
    local y = 15 + (i - 1) * 10
    draw_slot(i, y, current_data)
  end

  for i = 5, 8 do
    local y = 15 + (i - 5) * 10
    draw_slot(i, y, current_data, 68)
  end

  screen.move(4, 60)
  screen.text("K3: Roll")
  screen.move(54, 60)
  screen.text(string.format("E1:%02d", current_page))
  screen.move(96, 60)
  screen.text(edit_mode == "cc" and "CC" or edit_mode == "value" and "VAL" or string.format("MIDI %02d", params:get("midi_channel")))
  screen.update()
end

function draw_slot(i, y, current_data, x_offset)
  local x = x_offset or 2
  local marker = (selected_slot == i) and ">" or " "
  screen.move(x, y)
  local cc = current_data.cc_targets[i]
  if cc ~= nil then
    local cc_str = (cc == -1) and "OFF " or string.format("CC%3d", cc)
    screen.text(string.format("%s%d: %s→%3d", marker, i, cc_str, current_data.cc_values[i] or 0))
  end
end

function redraw_loop()
  while true do
    redraw()
    clock.sleep(1 / 15)
  end
end

