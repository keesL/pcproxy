# Flightplan stream for the ProController Proxy
#
# $Id: fpserver.tcl,v 1.2 2004/03/11 09:30:03 kees Exp $
#
#####################################################################
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

##
# start the flightplan server. Report an error when not possible
#
proc startFPserver {} {
    global SETTINGS
    global FPSOCKETS
    global FPLISTENER
    global errorInfo

    if {[info exists FPLISTENER]} {
        cprint "Flight plan server already running on port $SETTINGS(fpport)"
        return
    }

    if {[catch {
        set FPLISTENER [socket -server handleFPconnection $SETTINGS(fpport)]
    }]} {
        cprint "Unable to start flight plan server on port $SETTINGS(fpport)"
        cprint $errorInfo
        return
    }
    pushFP
    cprint "Flight plan server listening on http://[info hostname]:$SETTINGS(fpport)"
    fconfigure $FPLISTENER -buffering line
} ;# end startFPserver


##
# stop the flight plan server.
#
proc stopFPserver {} {
    global FPSOCKETS
    global FPLISTENER
    global errorInfo

    if {[info exists FPLISTENER]} {
        foreach s [array names FPSOCKETS] {
            catch {
                unset FPSOCKETS($s)
                close $s
            }
        }
        catch {
            close $FPLISTENER
            unset FPSOCKETS
            unset FPLISTENER
        }
        after cancel pushFP
        cprint "Flight plan server stopped"
    }
} ;# end stop FP Server


##
# Setup an event handler for incoming connections and switch to line
# buffering
#
proc handleFPconnection {ch address port} {
    global FPSOCKETS
    fconfigure $ch -buffering line

    if {[catch {
        puts $ch "% Welcome $address"
        set FPSOCKETS($ch) $address
    }]} {
        debug "Error writing to FP Client"
    }
    debug "fpserver: Incoming connection from $address"
} ;# end startHttpServer


##
# push a flightplan to the socket
#
proc pushFP {} {
    global FPSOCKETS
    global SETTINGS
    global FLIGHTPLANS


    if {$SETTINGS(fpserver)==0} { return }

    set size [llength [array names FLIGHTPLANS]]
    foreach s [array names FPSOCKETS] {
        if {[catch {
            puts $s "% Will push $size flightplans"
        }]} {
            debug "fpserver: Connection with $FPSOCKETS($s) lost."
            close $s
            unset FPSOCKETS($s)
            continue
        }
        foreach call [array names FLIGHTPLANS] {
            set out ""
            foreach field $FLIGHTPLANS($call) {
                set out "$out:$field"
            }

            if {[catch {
                puts $s "$call:$out"
            }]} {
                catch { 
                    debug "fpserver: Connection with $FPSOCKETS($s) lost."
                    close $s
                    unset FPSOCKETS($s)
                }
            }
        } ;# end FPSOCKETS loop
    } ;# end FLIGHTPLANS loop

    after $SETTINGS(fpinterval) pushFP
} ; # end pushFP

# EOF
