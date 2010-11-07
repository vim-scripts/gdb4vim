# -*- encoding: utf-8 -*-
from subprocess import *

import gobject
import dbus
import dbus.service
import dbus.mainloop.glib
import os
import time

import gdb_helper
import parser


class GdbProcObject (dbus.service.Object):
	def __init__ (self, session_bus, path):
		self.GDB_CMDLINE = "LANG=en gdb -n -q"
		self.gdb_fo = os.path.join (os.path.abspath (os.path.dirname (__file__)), ".tmp.out")
		self.gdb_fo_p = open (self.gdb_fo, "w")
		self.gdb_fi_p = open (self.gdb_fo, "r")

		dbus.service.Object.__init__(self,session_bus, path)

	@dbus.service.method("com.gdbdbus.service",
			in_signature='', out_signature='')
	def start_gdb (self):
		self.proc = Popen (self.GDB_CMDLINE, 0, shell=True, stdout=self.gdb_fo_p, stdin=PIPE, stderr=STDOUT)
		text = gdb_helper.read_from_file (self.gdb_fi_p)
	
	@dbus.service.method("com.gdbdbus.service",
			in_signature='s', out_signature='s')
	def retrieve_output (self, cmdline):
		self.proc.stdin.write (cmdline.encode ('utf-8'))
		text = gdb_helper.read_from_file (self.gdb_fi_p)
		ret_list = parser.parse_display (text)
		return repr (ret_list)
	
	@dbus.service.method("comd.gdbdbus.service",
			in_signature='', out_signature='')
	def kill_gdb (self):
		self.proc.kill ()

	@dbus.service.method("com.gdbdbus.service",
			in_signature='', out_signature='')
	def exit (self):
		mainloop.quit ()

if __name__ == '__main__':
	dbus.mainloop.glib.DBusGMainLoop (set_as_default=True)
	session_bus = dbus.SessionBus ()
	name = dbus.service.BusName ("com.gdbdbus.service", session_bus)
	object = GdbProcObject (session_bus, '/GdbProcObject')
	mainloop = gobject.MainLoop ()
	mainloop.run ()
