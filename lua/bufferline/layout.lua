--
-- layout.lua
--

local vim = vim
local nvim = require("bufferline.nvim")
local utils = require("bufferline.utils")
local Buffer = require("bufferline.buffer")
local len = utils.len
local strwidth = nvim.strwidth

local SIDES_OF_BUFFER = 2

local function get_tab_dir(tabnr)
  local dir = vim.fn.getcwd(0, tabnr)
  local home = os.getenv("HOME")
  local idx, chars = string.find(dir, home)
  if idx == 1 then
    dir = "~" .. string.sub(dir, idx + chars)
  end
  return dir
end

local function get_tabpage_names()
  local tabnr_to_dir = {}
  local dir_to_name = {}
  local name_to_dir = {}
  local total_tabpages = vim.fn.tabpagenr("$")
  for i = 1, total_tabpages do
    local dir = get_tab_dir(i)
    tabnr_to_dir[i] = dir
    local name = utils.basename(dir)
    if dir_to_name[dir] == nil then
      dir_to_name[dir] = name
    end
    if name_to_dir[name] == nil or name_to_dir[name] == dir then
      name_to_dir[name] = dir
    else
      local other_dir = name_to_dir[name]
      local new_name, new_other_name = Buffer.get_unique_name(dir, other_dir)
      dir_to_name[dir] = new_name
      dir_to_name[other_dir] = new_other_name
      name_to_dir[name] = nil
      name_to_dir[new_name] = dir
      name_to_dir[new_other_name] = other_dir
    end
  end
  local tabnr_to_name = {}
  for tabnr, dir in pairs(tabnr_to_dir) do
    tabnr_to_name[tabnr] = dir_to_name[dir]
  end
  local num_distinct_names = #vim.tbl_keys(name_to_dir)
  return tabnr_to_name, num_distinct_names
end

local function get_tabpage_display()
  local total_tabpages = vim.fn.tabpagenr("$")
  if total_tabpages == 1 then
    return ""
  end
  local current_tabpage = vim.fn.tabpagenr()
  local tab_names, num_unique = get_tabpage_names()
  local count = string.format("%d/%d", current_tabpage, total_tabpages)
  if num_unique > 1 then
    count = tab_names[current_tabpage] .. " " .. count
  end
  return count
end

local function calculate_buffers_width(state, base_width)
  local opts = vim.g.bufferline
  local has_numbers = opts.icons == "both" or opts.icons == "numbers"

  local sum = 0
  local widths = {}

  for i, buffer_number in ipairs(state.buffers) do
    local buffer_data = state.get_buffer_data(buffer_number)
    local buffer_name = buffer_data.name or "[no name]"

    local width = base_width
      + strwidth(
        Buffer.get_activity(buffer_number) > 0 -- separator
            and opts.icon_separator_active
          or opts.icon_separator_inactive
      )
      + strwidth(buffer_name) -- name

    if has_numbers then
      width = width
        + len(tostring(i)) -- buffer-index
        + 1 -- space-after-buffer-index
    end

    local is_pinned = state.is_pinned(buffer_number)

    if is_pinned then
      local icon = opts.icon_pinned
      width = width + strwidth(icon) + 1 -- space-after-pinned-icon
    end
    sum = sum + width
    table.insert(widths, width)
  end

  return sum, widths
end

local function calculate_buffers_position_by_buffer_number(state, layout)
  local current_position = 0
  local positions = {}

  for i, buffer_number in ipairs(state.buffers) do
    positions[buffer_number] = current_position
    local width = layout.base_widths[i] + (2 * layout.padding_width)
    current_position = current_position + width
  end

  return positions
end

local function calculate(state)
  local opts = vim.g.bufferline

  local has_icons = (opts.icons == true) or (opts.icons == "both")

  -- [icon + space-after-icon] + space-after-name
  local base_width = (has_icons and (1 + 1) or 0) -- icon + space-after-icon
    + 1 -- space-after-name

  local available_width = vim.o.columns
  if state.offset then
    available_width = available_width - state.offset
  end

  local used_width, base_widths = calculate_buffers_width(state, base_width)
  local tabpages_display = get_tabpage_display()
  local tabpages_width = strwidth(tabpages_display) + 1

  local buffers_width = available_width - tabpages_width

  local buffers_length = len(state.buffers)
  local remaining_width = math.max(buffers_width - used_width, 0)
  local remaining_width_per_buffer = math.floor(remaining_width / buffers_length)
  local remaining_padding_per_buffer = math.floor(remaining_width_per_buffer / SIDES_OF_BUFFER)
  local padding_width = math.min(remaining_padding_per_buffer, opts.maximum_padding)
  local actual_width = used_width + (buffers_length * padding_width * SIDES_OF_BUFFER)

  return {
    actual_width = actual_width,
    available_width = available_width,
    base_width = base_width,
    base_widths = base_widths,
    buffers_width = buffers_width,
    padding_width = padding_width,
    tabpages_width = tabpages_width,
    tabpages_display = tabpages_display,
    used_width = used_width,
  }
end

local function calculate_width(buffer_name, base_width, padding_width)
  return strwidth(buffer_name) + base_width + padding_width * SIDES_OF_BUFFER
end

local exports = {
  calculate = calculate,
  calculate_buffers_width = calculate_buffers_width,
  calculate_buffers_position_by_buffer_number = calculate_buffers_position_by_buffer_number,
  calculate_width = calculate_width,
}

return exports
