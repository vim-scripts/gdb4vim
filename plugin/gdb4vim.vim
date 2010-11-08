command! -nargs=? Gs call StartGdb ()
command! -nargs=1 Gt call Gdbtest (<q-args>)


if !exists ('g:gdb_var_active_highlight')
	highlight gdbVarActive term=bold ctermbg=grey guibg=grey
else
	exe 'highlight gdbVarActive ' . g:gdb_var_active_highlight
endif

if !exists ('g:gdb_break_highlight')
	highlight gdbBreak term=bold ctermbg=red guibg=red
else
	exe 'highlight gdbBreak ' . g:gdb_break_highlight
endif

if !exists ('g:gdb_highlight')
	highlight gdbLine term=bold ctermbg=darkblue guibg=darkgrey
else
	exe 'highlight gdbLine ' . g:gdb_highlight
endif

" Pre-check for environment
if !exists ('g:gdb_dbus_server_path')
	echoerr "GDB Server path not specified"
	echoerr "Please set g:gdb_dbus_server_path"
	finish
endif

if !has ('python')
	echoerr "Need python support!"
	finish
endif

python << endpython
# -*- encoding: utf-8 -*-
import os
import vim
import thread
import time
import threading
import dbus
import dbus.mainloop.glib


# python global variables
gVarList = {}
gBreakList = {}
endpython

function! s:Create_Gdb_Window (name)
	let cur_buf = bufname ('%')
	
	if (a:name) == 'gdbcmd'
		exe 'silent! botright 15split gdbcmd'	
	endif

	if (a:name) == 'gdbvar'
		exe 'silent! 25vsplit gdbvar'
		nnoremap <buffer> <silent> <CR> 
			\ :call Edit_Variable_Value() <CR>
	endif

	let index = bufwinnr (cur_buf)
	exe index . ' wincmd w'

	call clearmatches ()
endfunction

function! s:Check_Window_Exists (name)
	if bufwinnr(a:name) == -1
		call s:Create_Gdb_Window (a:name)
	endif
endfunction

function! s:Key_Mapping ()
	nnoremap <F7> :Gt step<CR>
	nnoremap <F8> :Gt next<CR>
	nnoremap <F9> :Gt run<CR>
	nnoremap <C-B> :exe 'Gt' . ' break ' . expand('%:p') . ':' . line('.')<CR>
	nnoremap <C-D> :exe 'Gt' . ' clear ' . expand('%:p') . ':' . line('.')<CR>
endfunction


python << endpython

def thread_func (data):
	path = vim.eval ("g:gdb_dbus_server_path")
	os.system ("python " + path)

def start_gdb ():
	b_suceed = False
	bus = dbus.SessionBus ()


	try:
		remote_object = bus.get_object ("com.gdbdbus.service", "/GdbProcObject")
		b_suceed = True
	except dbus.DBusException:
		thread.start_new (thread_func, (None,))
		time.sleep (0.2)
		try:
			remote_object = bus.get_object ("com.gdbdbus.service", "/GdbProcObject")
			b_suceed = True
		except dbus.DBusException:
			vim.command ('echoerr "Problem connecting to remote server"')

	if (b_suceed):
		remote_object.start_gdb ()
		vim.command ("call s:Check_Window_Exists ('gdbcmd')")
		vim.command ("call s:Check_Window_Exists ('gdbvar')")

		vim.command ("call s:Key_Mapping()")

endpython



function! StartGdb ()
python<<endpython
global gVarList, gBreakList

gVarList = {}
gBreakList = {}

start_gdb ()
endpython
endfunction





python << endpython


# Update variable list
def update_variable_list (varlist):
	global gVarList
	var_buf = int (vim.eval ("bufnr('gdbvar')"))
	present_list = []
	for line in vim.buffers[var_buf-1]:
		tmp = line.split (':')
		tmp = tmp[0]
		present_list.append (tmp)

	key_dellist = []
	for key in gVarList:
		if (not key in present_list):
			key_dellist.append (key)
			continue
		gVarList[key]['active'] = False

	for key in key_dellist:
		gVarList.pop (key)

	for line in varlist:
		key  = line.split(':')
		key = key[0]
		gVarList[key] = {'value':line, 'active':True}


# Display variables
def display_variables ():
	cur_buf = vim.eval ("bufname('%')")
	index = int (vim.eval ("bufwinnr('gdbvar')"))

	vim.command ("%s wincmd w" % index)
	vim.eval ("clearmatches()")

	vim.windows[index-1].buffer[:] = None
	for key in gVarList:
		line = gVarList[key]['value']

		vim.windows[index-1].buffer.append (line)
		if (gVarList[key]['active']):
			last_line = vim.eval ("line('$')")
			vim.eval ("matchadd('%s', '.\%%%sl')" % \
						('gdbVarActive', last_line))
	cur_win = vim.eval ("bufwinnr('%s')" % cur_buf)
	vim.command ("%s wincmd w" % cur_win)


# Display command line objects
def display_command_line (orgtext):
	cur_buf = vim.eval ("bufname('%')")
	index = int (vim.eval ("bufwinnr('gdbcmd')"))
	vim.command ('%s wincmd w' % index)

	lines = orgtext.split ("\n")
	for line in lines:
		vim.windows[index-1].buffer.append (line)
	vim.command ("%s" % vim.eval ("line('$')"))
	vim.eval ("winline()")

	cur_win = vim.eval ("bufwinnr('%s')" % cur_buf)
	vim.command ('%s wincmd w' % cur_win)


# Switch to file current program is in
def switch_to_file (filist):
	for fi in filist:
		tarPathAbs = vim.eval ("g:target_abspath")
		fi_abs = os.path.join (tarPathAbs, fi)
		base = os.path.basename (fi)
		index = int (vim.eval ("bufnr('%s')" % base))
			
		if (index == -1):
			vim.command ("edit %s" % fi_abs)
			vim.command ("call s:Check_Window_Exists ('gdbcmd')")
			vim.command ("call s:Check_Window_Exists ('gdbvar')")
		else:
			index = int (vim.eval ("bufwinnr('%s')" % base))
			if (index == -1):
				vim.command ("edit %s" % fi_abs)
			else:
				vim.command ("%s wincmd w" % index)


# Update breakpoints list
def update_break_point_list (breaklist, breakdelete):
	global gBreakList
	for item in breaklist:
		item['breakfile'] = os.path.basename (item['breakfile'])
		gBreakList[item['breakid']] = {'breakfile':item['breakfile'], 'breakline': item['breakline'], 'marked': False}
	# Delete those breakpoints that are not in need
	for item in breakdelete:
		gBreakList.pop (item)


# Update breakpoints highlight:
def update_break_high_light ():
	vim.eval ("clearmatches ()")
	for breakid in gBreakList:
		fi = gBreakList[breakid]['breakfile']
		index = vim.eval ("bufwinnr ('%s')" % fi)
		if (index == '-1'):
			continue

		vim.command ("%s wincmd w" % index)
			
		line = gBreakList[breakid]['breakline']
		matchid = int (breakid) + 5
		expr = ".\%%%sl" % line
		vim.eval ("matchadd ('gdbBreak', '%s', '%s')" % \
					(expr, matchid))
		gBreakList[breakid]['marked'] = True

# Hightlight current line to be displayed
def highlight_cur_line (lilist):
	for line in lilist:
		vim.eval ("matchadd ('gdbLine', '.\%%%sl')" % line)
		vim.command ('%s' % line)


# Actual function to communicate with dbus server
def retrieve_msg_from_gdb (cmdline):
	bus = dbus.SessionBus ()

	try:
		remote_object = bus.get_object ("com.gdbdbus.service", "/GdbProcObject")
	except dbus.DBusException:
		vim.command ('echoerr "Problem connecting to remote server"')
		return


	if (cmdline == "clc"):
		index = int (vim.eval ("bufwinnr('gdbcmd')"))
		if (index == -1):
			vim.command ("echo 'Window is closed!'")
			return
		vim.windows[index-1].buffer[:] = None
		return
		 
	if (cmdline == "die"):
		remote_object.kill_gdb ()
		remote_object.exit ()
		
		index = vim.eval ("bufwinnr ('gdbcmd')")
		vim.command ("%s wincmd w" % index)
		vim.command ("silent! %s wincmd q" % index)

		index = vim.eval ("bufnr ('gdbcmd')")
		vim.command ("%s bd!" % index)

		index = vim.eval ("bufwinnr ('gdbvar')")
		vim.command ("%s wincmd w" % index)
		vim.command ("silent! %s wincmd q" % index)

		index = vim.eval ("bufnr ('gdbvar')")
		vim.command ("%s bd!" % index)

		vim.eval ("clearmatches ()")

		return

	if (cmdline == "exit"):
		remote_object.kill_gdb ()
		return

	# Process a "file" command and determine the root
	if (cmdline.find ("file") != -1):
		tmp = cmdline.split ()
		if (len (tmp) >= 2):
			tmp = os.path.dirname (tmp[1])
			tmp = os.path.abspath (tmp)
			vim.command ("let g:target_abspath='%s'" % tmp)

 	cmdline += ' \n'
	reply = remote_object.retrieve_output (cmdline)
	reply = eval (reply)
	filist = reply['filelist']
	lilist = reply['linelist']
	varlist = reply['varlist']
	orgtext = reply['orgtext']
	breaklist = reply['breakpoints']
	breakdelete = reply['breakdelete']

	# Update variable list
	update_variable_list (varlist)

	# Display variables
	display_variables ()
		
	# Display command line objects
	display_command_line (orgtext)

	# Switch to file current program is in
	switch_to_file (filist)

	# Update breakpoints list
	update_break_point_list (breaklist, breakdelete)

	# Update breakpoints highlight:
	update_break_high_light ()

	# Hightlight current line to be displayed
	highlight_cur_line (lilist)


def edit_variable_value ():
	line = vim.eval ("getline ('.')")
	line = line.split (':')
	if (line[0] == ""):
		return

	if (len (line) < 2):
		return
	
	eqpos = line[1].find ('=')
	if (eqpos == -1):
		return

	variable = line[1][:eqpos]

	value = vim.eval ("input('Please input value for %s :')" % variable)
	vim.eval ("s:Check_Window_Exists ('gdbcmd')")
	vim.eval ("s:Check_Window_Exists ('gdbvar')")
	cmdline = "set var %s = %s " % (variable, value)
	retrieve_msg_from_gdb (cmdline)

endpython

function! Edit_Variable_Value ()
python << endpython
edit_variable_value ()
endpython
endfunction

function! Gdbtest (c)
	call s:Check_Window_Exists ('gdbcmd')
	call s:Check_Window_Exists ('gdbvar')
python << endpython
cmdline = vim.eval ("a:c")
retrieve_msg_from_gdb (cmdline)
endpython

endfunction


