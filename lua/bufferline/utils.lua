local M = {}

---@param value any
---@return boolean
M.is_nil = function(value)
  return value == nil or value == vim.NIL
end

---@param tbl any[]
---@param n integer
---@return integer|nil
M.index_of = function(tbl, n)
  for i, value in ipairs(tbl) do
    if value == n then
      return i
    end
  end
  return nil
end

M.slice = function(tbl, first, last)
  if type(tbl) == "string" then
    if last == nil then
      local start = first - 1
      return vim.fn.strcharpart(tbl, start)
    else
      local start = first - 1
      local length = last - first + 1
      return vim.fn.strcharpart(tbl, start, length)
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
    sliced[#sliced + 1] = tbl[i]
  end

  return sliced
end

---@generic T: any
---@param tbl T[]
---@return T[]
M.reverse = function(tbl)
  local result = {}
  for i = #tbl, 1, -1 do
    table.insert(result, tbl[i])
  end
  return result
end

---@param path string
---@return string
M.basename = function(path)
  return vim.fn.fnamemodify(path, ":t")
end

M.is_displayed = function(opts, buffer)
  local exclude_ft = opts.exclude_ft
  local exclude_name = opts.exclude_name

  if not vim.api.nvim_buf_is_valid(buffer) then
    return false
  elseif not vim.api.nvim_buf_get_option(buffer, "buflisted") then
    return false
  end

  if not M.is_nil(exclude_ft) then
    local ft = vim.api.nvim_buf_get_option(buffer, "filetype")
    if vim.tbl_contains(exclude_ft, ft) then
      return false
    end
  end

  if not M.is_nil(exclude_name) then
    local fullname = vim.api.nvim_buf_get_name(buffer)
    local name = M.basename(fullname)
    if vim.tbl_contains(exclude_name, name) then
      return false
    end
  end
  return true
end

return M
