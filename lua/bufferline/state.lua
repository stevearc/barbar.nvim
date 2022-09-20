local utils = require("bufferline.utils")
local timing = require("bufferline.timing")
local Buffer = require("bufferline.buffer")
local index_of = utils.index_of
local filter = vim.tbl_filter
local includes = vim.tbl_contains
local bufname = vim.fn.bufname
local bufwinnr = vim.fn.bufwinnr
local fnamemodify = vim.fn.fnamemodify

local PIN = "bufferline_pin"

--------------------------------
-- Section: Application state --
--------------------------------
local function get_tabpage()
  if vim.g.bufferline.tab_local_buffers then
    return vim.api.nvim_get_current_tabpage()
  else
    return 0
  end
end

local m = setmetatable({
  scroll = 0,
  buffers_by_tab = {},
  buffers_by_id = {},
  offset = 0,
  offset_text = "",
}, {
  __index = function(self, key)
    if key == "buffers" then
      local tabpage = get_tabpage()
      local buffers = self.buffers_by_tab[tabpage]
      if not buffers then
        buffers = {}
        self.buffers_by_tab[tabpage] = buffers
      end
      return buffers
    end
    return rawget(self, key)
  end,
  __newindex = function(self, key, value)
    if key == "buffers" then
      local tabpage = get_tabpage()
      self.buffers_by_tab[tabpage] = value
    else
      rawset(self, key, value)
    end
  end,
})

-- On startup, make sure all buffers are visible in the tab
m.buffers = filter(function(b)
  return utils.is_displayed(vim.g.bufferline, b)
end, vim.api.nvim_list_bufs())

function m.new_buffer_data()
  return {
    name = nil,
    width = nil,
    position = nil,
    real_width = nil,
  }
end

function m.get_buffer_data(id)
  local data = m.buffers_by_id[id]

  if data ~= nil then
    return data
  end

  m.buffers_by_id[id] = m.new_buffer_data()

  return m.buffers_by_id[id]
end

function m.rerender()
  vim.fn["bufferline#rerender"]()
end

-- Pinned buffers

local function is_pinned(bufnr)
  local ok, val = pcall(vim.api.nvim_buf_get_var, bufnr, PIN)
  return ok and val
end

local function sort_pins_to_left()
  local pinned = {}
  local unpinned = {}
  for _, bufnr in ipairs(m.buffers) do
    if is_pinned(bufnr) then
      table.insert(pinned, bufnr)
    else
      table.insert(unpinned, bufnr)
    end
  end
  m.buffers = vim.list_extend(pinned, unpinned)
end

local function toggle_pin(bufnr)
  bufnr = bufnr or 0
  vim.api.nvim_buf_set_var(bufnr, PIN, not is_pinned(bufnr))
  sort_pins_to_left()
  m.rerender()
end

-- Scrolling

local function set_scroll(target)
  m.scroll = target
end

-- Open buffers

local function open_buffers(new_buffers)
  local opts = vim.g.bufferline

  -- Open next to the currently opened tab
  -- Find the new index where the tab will be inserted
  local new_index = index_of(m.buffers, m.last_current_buffer)
  if new_index ~= nil then
    new_index = new_index + 1
  else
    new_index = #m.buffers + 1
  end

  -- Insert the buffers where they go
  for _, new_buffer in ipairs(new_buffers) do
    if index_of(m.buffers, new_buffer) == nil then
      local actual_index = new_index

      local should_insert_at_start = opts.insert_at_start
      local should_insert_at_end = opts.insert_at_end
        -- We add special buffers at the end
        or vim.api.nvim_buf_get_option(new_buffer, "buftype") ~= ""

      if should_insert_at_start then
        actual_index = 1
        new_index = new_index + 1
      elseif should_insert_at_end then
        actual_index = #m.buffers + 1
      else
        new_index = new_index + 1
      end

      table.insert(m.buffers, actual_index, new_buffer)
    end
  end

  sort_pins_to_left()
end

local function set_current_win_listed_buffer()
  local current = vim.fn.bufnr("%")
  local is_listed = vim.api.nvim_buf_get_option(current, "buflisted")

  -- Check previous window first
  if not is_listed then
    vim.api.nvim_command("wincmd p")
    current = vim.fn.bufnr("%")
    is_listed = vim.api.nvim_buf_get_option(current, "buflisted")
  end
  -- Check all windows now
  if not is_listed then
    local wins = vim.api.nvim_list_wins()
    for _, win in ipairs(wins) do
      current = vim.api.nvim_win_get_buf(win)
      is_listed = vim.api.nvim_buf_get_option(current, "buflisted")
      if is_listed then
        vim.api.nvim_set_current_win(win)
        break
      end
    end
  end

  return current
end

local function open_buffer_in_listed_window(buffer_number)
  set_current_win_listed_buffer()

  vim.api.nvim_command("buffer " .. buffer_number)
end

-- Close & cleanup buffers

local function close_buffer(buffer_number, should_update_names)
  m.buffers = filter(function(b)
    return b ~= buffer_number
  end, m.buffers)
  m.buffers_by_id[buffer_number] = nil
  if should_update_names then
    m.update_names()
  end
  m.rerender()
end

-- Update state

local function get_buffer_list()
  local opts = vim.g.bufferline
  local result = {}
  if opts.tab_local_buffers then
    local tabpage = vim.api.nvim_get_current_tabpage()
    for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
      local buffer = vim.api.nvim_win_get_buf(winid)
      if utils.is_displayed(opts, buffer) then
        result[buffer] = true
      end
    end

    for _, buffer in ipairs(m.buffers) do
      if not result[buffer] and utils.is_displayed(opts, buffer) then
        result[buffer] = true
      end
    end
    return vim.tbl_keys(result)
  else
    for _, buffer in pairs(vim.api.nvim_list_bufs()) do
      if utils.is_displayed(opts, buffer) then
        table.insert(result, buffer)
      end
    end
    return result
  end
end

function m.update_names()
  local opts = vim.g.bufferline
  local buffer_index_by_name = {}

  -- Compute names
  for i, buffer_n in ipairs(m.buffers) do
    local name = Buffer.get_name(opts, buffer_n)

    if buffer_index_by_name[name] == nil then
      buffer_index_by_name[name] = i
      m.get_buffer_data(buffer_n).name = name
    else
      local other_i = buffer_index_by_name[name]
      local other_n = m.buffers[other_i]
      local new_name, new_other_name =
        Buffer.get_unique_name(bufname(buffer_n), bufname(m.buffers[other_i]))

      m.get_buffer_data(buffer_n).name = new_name
      m.get_buffer_data(other_n).name = new_other_name
      buffer_index_by_name[new_name] = i
      buffer_index_by_name[new_other_name] = other_i
      buffer_index_by_name[name] = nil
    end
  end
end

function m.get_updated_buffers(update_names)
  local current_buffers = get_buffer_list()
  local new_buffers = filter(function(b)
    return not includes(m.buffers, b)
  end, current_buffers)

  -- To know if we need to update names
  local did_change = false

  -- Remove closed buffers
  local closed_buffers = filter(function(b)
    return not includes(current_buffers, b)
  end, m.buffers)

  for _, buffer_number in ipairs(closed_buffers) do
    did_change = true
    close_buffer(buffer_number)
  end

  -- Add new buffers
  if not vim.tbl_isempty(new_buffers) then
    did_change = true

    open_buffers(new_buffers)
  end

  local opts = vim.g.bufferline
  m.buffers = filter(function(b)
    return utils.is_displayed(opts, b)
  end, m.buffers)

  if did_change or update_names then
    m.update_names()
  end

  return m.buffers
end

local function set_offset(offset, offset_text)
  local offset_number = tonumber(offset)
  if offset_number then
    m.offset = offset_number
    m.offset_text = offset_text or ""
    m.rerender()
  end
end

-- Movement & tab manipulation

local function move_buffer_direct(from_idx, to_idx)
  local buffer_number = m.buffers[from_idx]
  table.remove(m.buffers, from_idx)
  table.insert(m.buffers, to_idx, buffer_number)
  sort_pins_to_left()

  m.rerender()
end

local function move_buffer(from_idx, to_idx)
  to_idx = math.max(1, math.min(#m.buffers, to_idx))
  if to_idx == from_idx then
    return
  end

  move_buffer_direct(from_idx, to_idx)
end

local function move_current_buffer_to(number)
  number = tonumber(number)
  m.get_updated_buffers()
  if number == -1 then
    number = #m.buffers
  end

  local currentnr = vim.api.nvim_get_current_buf()
  local idx = index_of(m.buffers, currentnr)
  move_buffer(idx, number)
end

local function move_current_buffer(steps)
  m.get_updated_buffers()

  local currentnr = vim.api.nvim_get_current_buf()
  local idx = index_of(m.buffers, currentnr)

  move_buffer(idx, idx + steps)
end

local function goto_buffer(number)
  m.get_updated_buffers()

  number = tonumber(number)

  local idx
  if number == -1 then
    idx = #m.buffers
  elseif number > #m.buffers then
    return
  else
    idx = number
  end

  vim.api.nvim_command("buffer " .. m.buffers[idx])
end

local function goto_buffer_relative(steps)
  m.get_updated_buffers()

  local current = set_current_win_listed_buffer()

  local idx = index_of(m.buffers, current)

  if idx == nil then
    print("Couldn't find buffer " .. current .. " in the list: " .. vim.inspect(m.buffers))
    return
  else
    idx = (idx + steps - 1) % #m.buffers + 1
  end

  vim.api.nvim_command("buffer " .. m.buffers[idx])
end

-- Close commands

local function bufnr_from_idx(bufidx)
  if not bufidx then
    return vim.api.nvim_get_current_buf()
  elseif bufidx > 0 and bufidx <= #m.buffers then
    return m.buffers[bufidx]
  end
end

local function get_fallback_buffer(bufnr)
  local tabpage = vim.api.nvim_get_current_tabpage()
  local opts = vim.g.bufferline
  for _, window in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
    local winbuf = vim.api.nvim_win_get_buf(window)
    if winbuf ~= bufnr and utils.is_displayed(opts, winbuf) then
      return winbuf
    end
  end

  local found = false
  for i, listed_buf in ipairs(m.buffers) do
    if listed_buf == bufnr then
      found = true
      for j = i - 1, 1, -1 do
        if vim.api.nvim_buf_is_valid(m.buffers[j]) then
          return m.buffers[j]
        end
      end
      for j = i + 1, #m.buffers do
        if vim.api.nvim_buf_is_valid(m.buffers[j]) then
          return m.buffers[j]
        end
      end
    end
  end

  if not found and not vim.tbl_isempty(m.buffers) then
    for _, buf in ipairs(m.buffers) do
      if vim.api.nvim_buf_is_valid(buf) then
        return buf
      end
    end
  end

  return nil
end

local function hide_buffer(bufnr)
  if bufnr == nil or bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  local new_buffer = get_fallback_buffer(bufnr) or vim.api.nvim_create_buf(true, false)

  local tabpage = vim.api.nvim_get_current_tabpage()
  for _, window in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
    local winbuf = vim.api.nvim_win_get_buf(window)
    if winbuf == bufnr then
      vim.api.nvim_win_set_buf(window, new_buffer)
    end
  end

  for i, buffer in ipairs(m.buffers) do
    if bufnr == buffer then
      table.remove(m.buffers, i)
      break
    end
  end
  m.rerender()
end

local function hide_buffer_idx(bufidx)
  local bufnr = bufnr_from_idx(bufidx)
  if bufnr then
    hide_buffer(bufnr)
  else
    vim.api.nvim_err_writeln(string.format("Could not find buffer at index %s", bufidx))
  end
end

local function hide_all_but_current()
  local curbuf = vim.api.nvim_get_current_buf()
  for _, bufnr in ipairs(m.buffers) do
    if bufnr ~= curbuf then
      hide_buffer(bufnr)
    end
  end
end

local function clone_tab()
  local visible_buffers = m.buffers
  vim.cmd("tab split")
  m.buffers = vim.deepcopy(visible_buffers)
  m.rerender()
end

local function delete_buffer(force, bufnr)
  if bufnr == nil or bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  if vim.api.nvim_buf_get_option(bufnr, "modified") then
    if not force and vim.o.confirm then
      vim.api.nvim_err_writeln(
        "E89: No write since last change for buffer " .. bufnr .. " (add ! to override)"
      )
      return
    end
    vim.api.nvim_buf_set_option(bufnr, "bufhidden", "hide")
  end

  local newbuf = get_fallback_buffer(bufnr)
  if newbuf then
    for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
      for _, window in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
        local winbuf = vim.api.nvim_win_get_buf(window)
        if winbuf == bufnr then
          vim.api.nvim_win_set_buf(window, newbuf)
        end
      end
    end
  end

  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.cmd("silent! bdelete! " .. bufnr)
  end
end

local function delete_buffer_idx(force, bufidx)
  local bufnr = bufnr_from_idx(bufidx)
  if bufnr then
    delete_buffer(force, bufnr)
  else
    vim.api.nvim_err_writeln(string.format("Could not find buffer at index %s", bufidx))
  end
end

local function close_all_but_current()
  local current = vim.api.nvim_get_current_buf()
  local buffers = m.buffers
  for _, number in ipairs(buffers) do
    if number ~= current then
      delete_buffer(false, number)
    end
  end
  m.rerender()
end

local function close_all_but_pinned()
  local buffers = m.buffers
  for _, number in ipairs(buffers) do
    if not is_pinned(number) then
      delete_buffer(false, number)
    end
  end
  m.rerender()
end

local function close_buffers_left()
  local idx = index_of(m.buffers, vim.api.nvim_get_current_buf()) - 1
  if idx == nil then
    return
  end
  for i = idx, 1, -1 do
    delete_buffer(false, m.buffers[i])
  end
  m.rerender()
end

local function close_buffers_right()
  local idx = index_of(m.buffers, vim.api.nvim_get_current_buf()) + 1
  if idx == nil then
    return
  end
  for i = idx, #m.buffers do
    delete_buffer(false, m.buffers[i])
  end
  m.rerender()
end

-- Ordering

local function with_pin_order(order_func)
  return function(a, b)
    local a_pinned = is_pinned(a)
    local b_pinned = is_pinned(b)
    if a_pinned and not b_pinned then
      return true
    elseif b_pinned and not a_pinned then
      return false
    else
      return order_func(a, b)
    end
  end
end

local function is_relative_path(path)
  return fnamemodify(path, ":p") ~= path
end

local function order_by_buffer_number()
  table.sort(m.buffers, function(a, b)
    return a < b
  end)
  m.rerender()
end

local function order_by_directory()
  table.sort(
    m.buffers,
    with_pin_order(function(a, b)
      local na = bufname(a)
      local nb = bufname(b)
      local ra = is_relative_path(na)
      local rb = is_relative_path(nb)
      if ra and not rb then
        return true
      end
      if not ra and rb then
        return false
      end
      return na < nb
    end)
  )
  m.rerender()
end

local function order_by_language()
  table.sort(
    m.buffers,
    with_pin_order(function(a, b)
      local na = fnamemodify(bufname(a), ":e")
      local nb = fnamemodify(bufname(b), ":e")
      return na < nb
    end)
  )
  m.rerender()
end

local function order_by_time()
  table.sort(
    m.buffers,
    with_pin_order(function(a, b)
      local a_score = timing.get_score(a)
      local b_score = timing.get_score(b)
      return a_score > b_score
    end)
  )
  m.rerender()
end

local function order_by_window_number()
  table.sort(
    m.buffers,
    with_pin_order(function(a, b)
      local na = bufwinnr(bufname(a))
      local nb = bufwinnr(bufname(b))
      return na < nb
    end)
  )
  m.rerender()
end

-- Exports

m.set_scroll = set_scroll
m.set_offset = set_offset

m.open_buffer_in_listed_window = open_buffer_in_listed_window

m.close_buffer = close_buffer
m.close_all_but_current = close_all_but_current
m.close_all_but_pinned = close_all_but_pinned
m.close_buffers_right = close_buffers_right
m.close_buffers_left = close_buffers_left

m.delete_buffer = delete_buffer
m.delete_buffer_idx = delete_buffer_idx
m.hide_buffer = hide_buffer
m.hide_buffer_idx = hide_buffer_idx
m.hide_all_but_current = hide_all_but_current

m.clone_tab = clone_tab

m.is_pinned = is_pinned
m.move_current_buffer_to = move_current_buffer_to
m.move_current_buffer = move_current_buffer
m.goto_buffer = goto_buffer
m.goto_buffer_relative = goto_buffer_relative

m.toggle_pin = toggle_pin
m.order_by_buffer_number = order_by_buffer_number
m.order_by_directory = order_by_directory
m.order_by_language = order_by_language
m.order_by_time = order_by_time
m.order_by_window_number = order_by_window_number

return m
