local clock = require("bufferline.userclock")
local utils = require("bufferline.utils")
local active_buffer = -1
local LAST_DECAY_TIME = "bufferline_last_decay_time"
local TIME_SCORE = "bufferline_time_score"
local TIME_ACTIVATED = "bufferline_time_activated"

local M = {}

local function get_last_decay_time(bufnr, now)
  local ok, val = pcall(vim.api.nvim_buf_get_var, bufnr, LAST_DECAY_TIME)
  return ok and val or now
end

local function get_time_activated(bufnr, now)
  local ok, val = pcall(vim.api.nvim_buf_get_var, bufnr, TIME_ACTIVATED)
  return ok and val or now
end

local function get_stored_score(bufnr)
  local ok, val = pcall(vim.api.nvim_buf_get_var, bufnr, TIME_SCORE)
  if ok then
    -- Floats get serialized as a table. See :help lua-special-tbl
    if type(val) == "table" then
      return val[vim.val_idx]
    else
      return val
    end
  else
    return 0
  end
end

local function apply_decay(bufnr, now)
  local last_time = get_last_decay_time(bufnr, now)
  local delta = now - last_time
  local score = get_stored_score(bufnr)

  score = score / 2 ^ (delta / vim.g.bufferline.time_decay_rate)
  vim.api.nvim_buf_set_var(bufnr, TIME_SCORE, score)
  vim.api.nvim_buf_set_var(bufnr, LAST_DECAY_TIME, now)
  return score
end

M.get_score = function(bufnr)
  local now = clock.time()
  if bufnr == active_buffer then
    local time_activated = get_time_activated(bufnr, now)
    return get_stored_score(bufnr) + (now - time_activated)
  else
    return apply_decay(bufnr, now)
  end
end

local function on_leave_buffer()
  if utils.is_displayed(vim.g.bufferline, active_buffer) then
    local now = clock.time()
    local score = get_stored_score(active_buffer)
    local time_activated = get_time_activated(active_buffer, now)
    local delta = now - time_activated
    vim.api.nvim_buf_set_var(active_buffer, TIME_SCORE, score + delta)
    vim.api.nvim_buf_set_var(active_buffer, LAST_DECAY_TIME, now)
  end
  active_buffer = -1
end

local function set_active_buffer(bufnr)
  if bufnr ~= active_buffer then
    on_leave_buffer()
  end

  local opts = vim.g.bufferline
  if bufnr == active_buffer or not utils.is_displayed(opts, bufnr) then
    return
  end
  local now = clock.time()
  apply_decay(bufnr, now)
  vim.api.nvim_buf_set_var(bufnr, TIME_ACTIVATED, now)
  active_buffer = bufnr
end

M.on_enter_buffer = function()
  set_active_buffer(vim.api.nvim_get_current_buf())
end

return M
