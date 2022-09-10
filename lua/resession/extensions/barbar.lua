local M = {}

M.on_save = function()
  local state = require("bufferline.state")
  local data = { tabs = {}, bufdata = {} }
  for tabpage, buffers in pairs(state.buffers_by_tab) do
    if vim.api.nvim_tabpage_is_valid(tabpage) then
      local tab_buf_names = {}
      -- Using numeric index instead of tabpage because when we restore the
      -- session the tabpage numbers are lost
      table.insert(data.tabs, tab_buf_names)
      for _, bufnr in ipairs(buffers) do
        local name = vim.api.nvim_buf_get_name(bufnr)
        data.bufdata[name] = {
          name = state.buffers_by_id[bufnr].name,
        }
        table.insert(tab_buf_names, name)
      end
    end
  end
  return data
end

M.on_load = function(data)
  local state = require("bufferline.state")
  state.buffers_by_tab = {}
  for tabpage, buffers in ipairs(data.tabs) do
    local bufnrs = {}
    state.buffers_by_tab[tabpage] = bufnrs
    for _, name in ipairs(buffers) do
      local bufnr = vim.fn.bufadd(name)
      table.insert(bufnrs, bufnr)
    end
  end

  for name, bufdata in pairs(data.bufdata) do
    local bufnr = vim.fn.bufadd(name)
    if not state.buffers_by_id[bufnr] then
      state.buffers_by_id[bufnr] = state.new_buffer_data()
    end
    for k, v in pairs(bufdata) do
      state.buffers_by_id[bufnr][k] = v
    end
  end

  state.rerender()
end

return M
