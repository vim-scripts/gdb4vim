import time
import re

GDB_PATTERN = '^\(gdb\)\s*'
GDB_PATTERN_N = '\n\(gdb\)\s*'
def read_from_file (fi):
	time.sleep (0.05)
	buf = fi.read ()
	buf = re.sub (GDB_PATTERN, '', buf)
	buf = re.sub (GDB_PATTERN_N, '\n', buf)

	return buf

