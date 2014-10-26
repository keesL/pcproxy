# Access control procedures for PCProxy
#
# $Id: access.tcl,v 1.5 2004/03/11 09:30:03 kees Exp $
#
########################################################################
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

proc initACL {} {
    global ACL SETTINGS

    if {[info exists SETTINGS(access)] && 
        ![string match $SETTINGS(access) ""]} {

        set count 0
        cprint "Loading access control list from $SETTINGS(access)"
        if {[catch {
            set f [open $SETTINGS(access) r]
        }]} {
            cprint "Unable to load access control list."
            return
        }

        while {![eof $f]} {
            if {[catch {
                gets $f line
            }]} {
                break
            }
            
            if {$line == ""} { continue }

            if {[regexp {^[;#]} $line x]} { continue }

            if {[regexp {^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+} $line x]} {
                incr count
                lappend ACL $line
            } else {
                cprint "Ignoring ACL entry $line (invalid format)"
            }
        }
        cprint "Allowing $count hosts to connect"

        close $f
        return
    }
}

proc checkACL {ip ch} {
    global ACL SETTINGS

    if {![info exists SETTINGS(access)]} {
        return 0
    }

    if {[info exists ACL] && \
        [lsearch -exact $ACL $ip] != -1} {
        # if there is no ACL, or if there is one and we are on it, allow
        # access.
        return 0
    } 

    catch {
        uprint $ch "You are not allowed to connect to this port. Goodbye."
        flush $ch
        disconnect $ch
    }
    debug "Refusing $ip"
    return 1
}
