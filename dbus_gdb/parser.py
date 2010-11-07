# -*- encoding: utf-8 -*-
import re

def parse_display (string):
	filist = re.findall ('at .*:[0-9]+', string)
	for i in range (len (filist)):
		filist[i] = re.sub ('at ', '', filist[i])
		filist[i] = re.sub (':[0-9]*', '', filist[i])

	linelist = re.findall ('[0-9]*\t.*', string)
	for i in range (len (linelist)):
		linelist[i] = re.findall ('[0-9]+', linelist[i])
		linelist[i] = linelist[i][0]
	
	varlist = re.findall ('\n\d+:.*|^\d+:.*',string)
	for i in range (len (varlist)):
		varlist[i] = re.sub ('\n', '', varlist[i])

	#print varlist

	breaklist = re.findall ('Breakpoint [0-9]+ at.*line [0-9]+', string)
	for i in range (len (breaklist)):
		pos = re.search ('Breakpoint [0-9]+ at', breaklist[i]).span ()
		breakid = breaklist[i][pos[0]:pos[1]]
		breakid = re.sub ('Breakpoint ', '', breakid)
		breakid = re.sub (' at', '', breakid)

		pos = re.search ('file .*,', breaklist[i]).span ()
		breakfile = breaklist[i][pos[0]:pos[1]]
		breakfile = re.sub ('file ', '', breakfile)
		breakfile = re.sub (',', '', breakfile)

		pos = re.search ('line [0-9]+', breaklist[i]).span ()
		breakline = breaklist[i][pos[0]:pos[1]]
		breakline = re.sub ('line ', '', breakline)

		breaklist[i] = {'breakid': breakid, 'breakfile': breakfile, 'breakline':breakline}

	breakdelete = re.findall ('Deleted breakpoint.? [0-9]+.*', string)
	res = []
	for i in range (len (breakdelete)):
		blist = re.findall ('[0-9]+', breakdelete[i])
		res += blist
	breakdelete = res

	return {
			'filelist': filist, 
			'linelist' : linelist, 
			'varlist' : varlist, 
			'orgtext' : string, 
			'breakpoints' : breaklist,
			'breakdelete' : breakdelete,
			}

