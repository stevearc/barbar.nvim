local has_devicons, web_devicons = pcall(require, "nvim-web-devicons")

local M = {}

local function get_attr(group, attr)
  local rgb_val = (vim.api.nvim_get_hl_by_name(group, true) or {})[attr]
  return rgb_val and string.format("#%06x", rgb_val) or "NONE"
end

-- List of icon HL groups
local hl_groups = {}

-- It's not possible to purely delete an HL group when the colorscheme
-- changes, therefore we need to re-define colors for all groups we have
-- already highlighted.
M.set_highlights = function()
  for _, hl_group in ipairs(hl_groups) do
    local icon_hl = hl_group[1]
    local buffer_status = hl_group[2]
    vim.cmd(
      "hi! "
        .. icon_hl
        .. buffer_status
        .. " guifg="
        .. get_attr(icon_hl, "foreground")
        .. " guibg="
        .. get_attr("Buffer" .. buffer_status, "background")
    )
  end
end

---@param bufnr integer
---@param buffer_status string
M.get_icon = function(bufnr, buffer_status)
  local buffer_name = vim.api.nvim_buf_get_name(bufnr)
  local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
  if not has_devicons then
    vim.cmd("echohl WarningMsg")
    vim.cmd(
      'echom "barbar: bufferline.icons is set to v:true but \\"nvim-dev-icons\\" was not found."'
    )
    vim.cmd(
      'echom "barbar: icons have been disabled. Set bufferline.icons to v:false to disable this message."'
    )
    vim.cmd("echohl None")
    vim.cmd("let g:bufferline.icons = v:false")
    return " "
  end

  local basename
  local extension
  local icon_char
  local icon_hl

  -- nvim-web-devicon only handles filetype icons, not other types (eg directory)
  -- thus we need to do some work here
  if filetype == "netrw" or filetype == "LuaTree" or filetype == "defx" then
    icon_char = ""
    icon_hl = "Directory"
  else
    if filetype == "fugitive" or filetype == "gitcommit" then
      basename = "git"
      extension = "git"
    else
      basename = vim.fn.fnamemodify(buffer_name, ":t")
      extension = vim.fn.fnamemodify(buffer_name, ":e")
    end

    icon_char, icon_hl = web_devicons.get_icon(basename, extension, { default = true })
  end

  if icon_hl and vim.fn.hlexists(icon_hl .. buffer_status) < 1 then
    local hl_group = icon_hl .. buffer_status
    vim.cmd(
      "hi! "
        .. hl_group
        .. " guifg="
        .. get_attr(icon_hl, "foreground")
        .. " guibg="
        .. get_attr("Buffer" .. buffer_status, "background")
    )
    table.insert(hl_groups, { icon_hl, buffer_status })
  end

  return icon_char, icon_hl .. buffer_status
end

return M
