" File: bufferline.vim
" Author: romgrk
" Description: Buffer line
" Date: Fri 22 May 2020 02:22:36 AM EDT
" !::exe [So]

function! bufferline#enable()
   set showtabline=2

   augroup bufferline
      au!
      au VimEnter       * call bufferline#highlight#setup()
      au ColorScheme    * call bufferline#highlight#setup()
   augroup END

   augroup bufferline_update
      au!
      au BufNew                 * lua require('bufferline.render').update_names()
      au OptionSet      buflisted call bufferline#rerender()
      au TermOpen               * lua require('bufferline.render').update_names()
   augroup END

   augroup bufferline_time
      au!
      au BufEnter               * lua require'bufferline.timing'.on_enter_buffer()
      au CursorMoved            * lua require'bufferline.userclock'.report_activity()
      au CursorMovedI           * lua require'bufferline.userclock'.report_activity()
   augroup END

   call bufferline#highlight#setup()
   let &tabline = "%{%v:lua.require'bufferline.render'.render()%}"
endfunc

function! bufferline#disable()
   set showtabline=1
   augroup bufferline | au! | augroup END
   augroup bufferline_time | au! | augroup END
   let &tabline = ''
endfunc

function! bufferline#rerender() abort
   if &tabline != ''
      let &tabline = "%{%v:lua.require'bufferline.render'.render()%}"
   endif
endfunc

"=================
" Section: Commands
"=================

command!                BarbarEnable           call bufferline#enable()
command!                BarbarDisable          call bufferline#disable()

command! -count   -bang BufferNext             call s:goto_buffer_relative(v:count1)
command! -count   -bang BufferPrevious         call s:goto_buffer_relative(-v:count1)

command! -nargs=1 -bang BufferGoto             call s:goto_buffer(<f-args>)
command!          -bang BufferLast             call s:goto_buffer(-1)

command! -count   -bang BufferMoveNext         call s:move_current_buffer(v:count1)
command! -count   -bang BufferMovePrevious     call s:move_current_buffer(-v:count1)
command! -nargs=1 -bang BufferMove             call s:move_current_buffer_to(<f-args>)

command!                BufferPin              lua require'bufferline.state'.toggle_pin()

command!          -bang BufferOrderByBufferNumber  call bufferline#order_by_buffer_number()
command!          -bang BufferOrderByDirectory     call bufferline#order_by_directory()
command!          -bang BufferOrderByLanguage      call bufferline#order_by_language()
command!          -bang BufferOrderByTime          call bufferline#order_by_time()
command!          -bang BufferOrderByWindowNumber  call bufferline#order_by_window_number()

command! -nargs=? -bang BufferClose                call s:delete_buffer(<q-bang>, <q-args>)
command! -nargs=? -bang BufferDelete               call s:delete_buffer(<q-bang>, <q-args>)
command!                BufferCloseAllButCurrent   lua require'bufferline.state'.close_all_but_current()
command!                BufferCloseAllButPinned    lua require'bufferline.state'.close_all_but_pinned()
command!                BufferCloseBuffersLeft     lua require'bufferline.state'.close_buffers_left()
command!                BufferCloseBuffersRight    lua require'bufferline.state'.close_buffers_right()
command! -nargs=?       BufferHide                 call s:hide_buffer(<q-args>)
command!                BufferHideAllButCurrent    lua require'bufferline.state'.hide_all_but_current()

command!                TabClone                   lua require'bufferline.state'.clone_tab()

"=================
" Section: Options
"=================

let s:DEFAULT_OPTIONS = {
\ 'auto_hide': v:false,
\ 'exclude_ft': v:null,
\ 'exclude_name': v:null,
\ 'icon_pinned': '車',
\ 'icon_separator_active':   '▎',
\ 'icon_separator_inactive': '▎',
\ 'icons': v:true,
\ 'icon_custom_colors': v:false,
\ 'idle_timeout': 5,
\ 'insert_at_start': v:false,
\ 'insert_at_end': v:false,
\ 'letters': 'asdfjkl;ghnmxcvbziowerutyqpASDFJKLGHNMXCVBZIOWERUTYQP',
\ 'maximum_padding': 4,
\ 'maximum_length': 30,
\ 'no_name_title': v:null,
\ 'semantic_letters': v:true,
\ 'time_decay_rate': 30,
\ 'tabpages': v:true,
\}

let bufferline = extend(s:DEFAULT_OPTIONS, get(g:, 'bufferline', {}))

call dictwatcheradd(g:bufferline, '*', 'BufferlineOnOptionChanged')

"========================
" Section: Main functions
"========================

function! bufferline#order_by_buffer_number()
   call luaeval("require'bufferline.state'.order_by_buffer_number()")
endfunc

function! bufferline#order_by_directory()
   call luaeval("require'bufferline.state'.order_by_directory()")
endfunc

function! bufferline#order_by_language()
   call luaeval("require'bufferline.state'.order_by_language()")
endfunc


function! bufferline#order_by_time()
   call luaeval("require'bufferline.state'.order_by_time()")
endfunc

function! bufferline#order_by_window_number()
   call luaeval("require'bufferline.state'.order_by_window_number()")
endfunc

function! bufferline#close(abuf)
   call luaeval("require'bufferline.state'.close_buffer(_A)", a:abuf)
endfunc

"========================
" Section: Event handlers
"========================

" Needs to be global -_-
function! BufferlineOnOptionChanged(d, k, z)
   let g:bufferline = extend(s:DEFAULT_OPTIONS, get(g:, 'bufferline', {}))
endfunc

" Buffer operations

function! s:delete_buffer(bang, ...)
   let force = empty(a:bang) ? v:false : v:true
   call luaeval("require'bufferline.state'.delete_buffer_idx(_A[1], _A[2] and tonumber(_A[2]))", [force, a:0 ? a:1 : v:null])
endfunc

function! s:hide_buffer(...)
   call luaeval("require'bufferline.state'.hide_buffer_idx(_A and tonumber(_A))", a:0 ? a:1 : v:null)
endfunc

function! s:move_current_buffer(steps)
   call luaeval("require'bufferline.state'.move_current_buffer(_A)", a:steps)
endfunc

function! s:move_current_buffer_to(number)
   call luaeval("require'bufferline.state'.move_current_buffer_to(_A)", a:number)
endfunc

function! s:goto_buffer(number)
   call luaeval("require'bufferline.state'.goto_buffer(_A)", a:number)
endfunc

function! s:goto_buffer_relative(steps)
   call luaeval("require'bufferline.state'.goto_buffer_relative(_A)", a:steps)
endfunc

" Final setup

if !g:barbar_disable
  call bufferline#enable()
end

let g:bufferline# = s:
