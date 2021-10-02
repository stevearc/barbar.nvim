--
-- utils.lua
--

local vim = vim
local nvim = require'bufferline.nvim'
local fnamemodify = vim.fn.fnamemodify
local strcharpart = vim.fn.strcharpart

local function len(value)
  return #value
end

local function is_nil(value)
  return value == nil or value == vim.NIL
end

local function index_of(tbl, n)
  for i, value in ipairs(tbl) do
    if value == n then
      return i
    end
  end
  return nil
end

local function has(tbl, n)
  return index_of(tbl, n) ~= nil
end

local function slice(tbl, first, last)
  if type(tbl) == 'string' then
    if last == nil then
      local start = first - 1
      return strcharpart(tbl, start)
    else
      local start = first - 1
      local length = last - first + 1
      return strcharpart(tbl, start, length)
    end
  end

  if first < 0 then
    first = #tbl + 1 + first
  end

  if last ~= nil and last < 0 then
    last = #tbl + 1 + last
  end

  local sliced = {}

  for i = first or 1, last or #tbl do
    sliced[#sliced+1] = tbl[i]
  end

  return sliced
end

local function reverse(tbl)
  local result = {}
  for i = #tbl, 1, -1 do
    table.insert(result, tbl[i])
  end
  return result
end

local function collect(iterator)
  local result = {}
  for it, v in iterator do
    table.insert(result, v)
  end
  return result
end

local function basename(path)
   return fnamemodify(path, ':t')
end

local function is_displayed(opts, buffer)
  local exclude_ft   = opts.exclude_ft
  local exclude_name = opts.exclude_name

  if not nvim.buf_is_valid(buffer) then
    return false
  elseif not nvim.buf_get_option(buffer, 'buflisted') then
    return false
  end

  if not is_nil(exclude_ft) then
    local ft = nvim.buf_get_option(buffer, 'filetype')
    if has(exclude_ft, ft) then
      return false
    end
  end

  if not is_nil(exclude_name) then
    local fullname = nvim.buf_get_name(buffer)
    local name = basename(fullname)
    if has(exclude_name, name) then
      return false
    end
  end
  return true
end

return {
  len = len,
  is_nil = is_nil,
  index_of = index_of,
  has = has,
  slice = slice,
  reverse = reverse,
  collect = collect,
  basename = basename,
  is_displayed = is_displayed,
}
