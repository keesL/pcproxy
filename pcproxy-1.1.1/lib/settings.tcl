# Configurable settings reader/writer for the ProController Proxy
#
# $Id: settings.tcl,v 1.9 2004/04/10 09:36:39 kees Exp $
#
##########################################################################
#    Copyright (C) 2001-2003  Kees Leune
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

global SETTINGS

## 
# find the directory to save to
proc findSaveFile {} {
    global SETTINGS env
    
    set execdir [file dirname [info nameofexecutable]]
    catch { set homedir $env(HOME) }

    set dirs [list $execdir/etc $execdir ./etc /etc/pcproxy]

    # when wrapped, the save file is in the same directory as the .exe
    # file and it will be called pcproxy.ini
    if {[info exists tcl_platform(isWrapped)]} {
        return $execdir/pcproxy.ini
    } 

    # on unix, look in a user's homedir for .pcproxyrc first
    if {[info exists homedir]} {
        if {[file exists $homedir/.pcproxyrc]} { return $homedir/.pcproxyrc }
    }
   
    # else look in the ususal locations
    foreach d $dirs {
       if {[file exists $d/pcproxy.ini]} { 
           if {[catch {
               set f [open $d/pcproxy.ini a]
               close $f
           }]} { 
               # we do  not have write access to this file. Skip it.
               continue 
           }
           return $d/pcproxy.ini 
       }
    }

    return pcproxy.ini
}

##
# initialise the SETTINGS array with default values
#
proc initSettings {} {
    global SETTINGS COMMENTS tcl_platform

    set SETTINGS(remote_port) 6809
    set SETTINGS(remote_ip)   EUROPE-C.vatsim.net
    set SETTINGS(my_port)     6809
    set SETTINGS(debug)       0
    set SETTINGS(chat)        0
    set SETTINGS(wwwport)     8000
    set SETTINGS(connected)   0
    set SETTINGS(wwwserver)   0
    set SETTINGS(modec)       0
    set SETTINGS(fpport)      2688
    set SETTINGS(fpserver)    0
    set SETTINGS(fpinterval)  5000

    set COMMENTS(remote_port) "portnumber on remote server (usually 6809)"
    set COMMENTS(remote_ip) "internet address of remote server"
    set COMMENTS(my_port) "portnumber on which PCProxy lives (usually 6809)"
    set COMMENTS(debug) "show debug output. 1 = yes, 0 = no"
    set COMMENTS(chat) "private messages to secondaries 1 = yes, 0 = no"
    set COMMENTS(wwwport) "port for web server (default is 8000)"
    set COMMENTS(connected) "show connection status every 150 sec (1=yes, 0=no)"
    set COMMENTS(wwwserver) "run flightplan webserver (1=yes, 0=no)"
    set COMMENTS(modec) "force transponder mode C below this alt in feet"
    set COMMENTS(fpport) "port for flight plan server (default is 2688)"
    set COMMENTS(fpserver) "run flight plan server. 1 = yes, 0 = no"
    set COMMENTS(fpinterval) "interval between subsequent flightplan feeds"
} ;# end proc initSettings

###
# Save the current settings to the ini-file. The ini-file is located in the
# top level directory. The format of the file is easy. All lines starting
# with ; or # are ignore as comments. All empty lines are ignored. All
# lines that are not in the format 'key = value' are ignored. Each key of
# the SETTINGS array is a key.
#
proc saveSettings {} {
    global SETTINGS COMMENTS

    if {[catch {
        set f [open [findSaveFile] w]
    }]} {
        cprint "Could not open save file ([findSaveFile])."
        return
    }

    foreach {key value} [array get SETTINGS] {
        catch {
            puts $f "; $COMMENTS($key)"
        }
        puts $f "$key = $value\n"
    }

    close $f
} ;# end proc saveSettings
    

##
# Attempt to load the settings from the ini-file. If the file does not
# exist, simply return from this procedure. The format of the ini-file is
# described in saveSettings. Each valid key-value line is read into the
# SETTINGS array.
#
proc loadSettings {} {
    global SETTINGS

    if {[catch {
        set f [open [findSaveFile] r]
    }]} {
        saveSettings
        return 
    }

    while {![eof $f]} {
        # abort on read error
        if {[catch {
            gets $f line
        }]} {
            break
        }

        # ignore empty lines
        if {$line == ""} {
            continue
        }

        # ignore comments (lines starting with ; or #)
        if {[regexp {^[;#]} $line x]} {
            continue
        }

        # ignore malformed lines (not key = value)
        if {![regexp {^([^=]+)=(.+)$} $line x key value]} {
            continue
        }

        # set config entry
        set SETTINGS([string tolower [string trim $key]]) [string trim $value]
    }
    close $f
} ;# end proc loadSettings    


# EOF
