# Flightplan database for the ProController Proxy
#
# $Id: flightplans.tcl,v 1.23 2004/03/11 09:30:03 kees Exp $
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
# start the WWW server. Report an error when not possible
#
proc startHttpServer {} {
    global SETTINGS
    global HTTPSOCKET
    global errorInfo

    if {[info exists HTTPSOCKET]} {
        cprint "Web server already running on port $SETTINGS(wwwport)"
        return
    }

    if {[catch {
        set HTTPSOCKET [socket -server handleWWWRequest $SETTINGS(wwwport)]
    }]} {
        cprint "Unable to start web server on port $SETTINGS(wwwport)"
        cprint $errorInfo
        return
    }
    cprint "Web server listening on http://[info hostname]:$SETTINGS(wwwport)"
    fconfigure $HTTPSOCKET -buffering line
} ;# end startHttpServer


##
# stop the HTTP server.
#
proc stopHttpServer {} {
    global HTTPSOCKET
    global errorInfo

    if {[info exists HTTPSOCKET]} {
        if {[catch {
            disconnect $HTTPSOCKET
        }]} {
            cprint "Unable to stop web server"
            cprint $errorInfo
        }
        unset HTTPSOCKET
        cprint "Web server stopped"
    }
} ;# end stopHttpServer


##
# Setup an event handler for incoming connections and switch to line
# buffering
#
proc handleWWWRequest {ch address port} {
    #if {[checkACL $address $ch]} {
    #    cprint "CONNECTION REFUSED on WWW port"
    #    return
    #}

    fconfigure $ch -buffering line
    fileevent $ch readable "wwwRequestHandler $ch $address"
    debug "Incoming connection on www server from $address"
} ;# end startHttpServer


##
# handles WWW request from clients
#
proc wwwRequestHandler {ch address} {
    set header 1
    set file  ""
    set param ""

    while {![eof $ch]} {
        if {[catch {
            gets $ch line
        }]} {
            debug "Error reading from www client"
            break;
        }

        # read until empty line
        if {[string trim $line] == ""} {
            break;
        }

        if {$header} {
            set input [split $line :]
            set field [string trim [lindex $input 0]]
            set data  [string trim [join [lrange $input 1 end]]]
            set HEADER($field) $data
        } 
        if {[regexp {^GET (.+)} $line x uri]} {
            set get $uri
        }
    } ;# end while not eof

    # parse the request
    if {![info exists get]} {
        httpError $ch "Invalid request from $address"
        return
    } else {
        if {![regexp {^(/[^ ]*) (.*)$} $get x request protocol]} {
            httpError $ch "Unknown format from $address"
            return
        }
        set file $request
        regexp {^(/[^?]*)\??(.*)$} $request x file param

        if {[string match $file "/"]} {
            cprint "$address \"GET $file\" 200 Ok"
            httpRoot $ch
            return
        } elseif {[string match $file "/flightplan.html"]} {
            cprint "$address \"GET $file\" 200 Ok"
            httpFlightplan $ch $param
            return
        } elseif {[string match $file "/details.html"]} {
            if {[regexp {callsign=([a-zA-Z,-_]+)} $param x callsign]} {
                cprint "$address \"GET $file\" 200 Ok"
                httpDetailedFlightplan $ch $callsign
                return
            } else {
                cprint "$address \"GET $request\" 404 Not Found"
                httpNotFound $ch "Invalid callsign"
            }
        }

        cprint "$address \"GET $file\" 404 Not Found"
        httpNotFound $ch $file
        return
    }

} ;# end wwwRequestHandler


##
# print output to web client. 
#
proc httpRoot ch {
    puts $ch "HTTP/1.0 200 OK
Server: PCProxy Kees Leune/kees@leune.org
Content-Type: text/html
Connection: close\n"
 puts $ch "
 <HTML><HEAD><TITLE>Flight plan Settings</TITLE></HEAD>
 <BODY>
 <H1>PCProxy</H1>
 <FORM action=\"flightplan.html\" method=\"GET\">
 <TABLE>
 <TR>
    <TD>Filter type</TD>
    <TD><SELECT name=\"filter\">
        <OPTION value=\"none\" SELECTED>No filtering
        <OPTION value=\"origin\">Departure aerodrome
        <OPTION value=\"destination\">Destination aerodrome
        <OPTION value=\"both\">Destination or departure aerodrome
        </SELECT>
    </TD>
 </TR>
 <TR>
    <TD>Filter value</TD>
    <TD><INPUT name=\"filtervalue\" type=\"text\" size=\"10\"></TD>  
    <TD>(optional)</TD>
 <TR>
     <TD>Refresh every</TD>
     <TD><input type=\"text\" size=\"3\" name=\"refresh\">&nbsp;seconds.</TD>
     <TD>(leave empty for no auto-refresh)</TD>
 </TR>
 <TR>
     <TD>Order flightplans by</TD>
     <TD><select name=\"orderby\">
         <option value=\"callsign\" SELECTED>Callsign
         <option value=\"dest\">Destination
         <option value=\"from\">Origin
         </select></td>
 </TR>
 <TR VALIGN=\"top\">
     <TD>Display format</TD>
     <TD>
        <input checked type=\"radio\" value=\"normal\" name=\"format\">
        Normal<BR>
        <input type=\"radio\" value=\"plain\" name=\"format\">
        Simple
    </TD>
 </TR>
 </TABLE>
 <input type=\"submit\" value=\"Show flightplans\"></FORM>
 </BODY>
 </HTML>"
    flush $ch
    printHttpFooter $ch
}


##
# support procedure for sorting flightplans by destination
#
proc originSort {arg1 arg2} {
    global FLIGHTPLANS

    set origin1 [lindex [split $FLIGHTPLANS($arg1) :] 5]
    set origin2 [lindex [split $FLIGHTPLANS($arg2) :] 5]

    return [string compare $origin1 $origin2]
} ;# end originSort


##
# support procedure for sorting flightplans by origin
proc destinationSort {arg1 arg2} {
    global FLIGHTPLANS

    set destination1 [lindex [split $FLIGHTPLANS($arg1) :] 9]
    set destination2 [lindex [split $FLIGHTPLANS($arg2) :] 9]

    return [string compare $destination1 $destination2]
} ;# end destinationSort


##
# helpers
#
proc fpheader {colspan msg} {
    return "
<TD colspan=\"$colspan\" bgcolor=\"#008080\" ALIGN=\"center\">
<FONT color=\"white\" size=\"-1\">$msg</FONT>
</TD>"
}

proc fpbody {colspan msg} {
    return "
<TD colspan=\"$colspan\" ALIGN=\"left\">
<FONT color=\"black\" size=\"-1\">$msg</FONT>
</TD>"
}


##
# print a detailed flightplan
#
proc httpDetailedFlightplan {ch callsign} {
    global FLIGHTPLANS
    global POSITIONS

    puts $ch "HTTP/1.0 200 OK"
    puts $ch "Server: PCProxy Kees Leune/kees@leune.org"
    puts $ch "Content-Type: text/html"
    puts $ch "Pragma: no-cache"
    puts $ch "Connection: close"
    puts $ch ""

    if {[catch {
        set data     [split $FLIGHTPLANS($callsign) :]
    }]} {
        puts $ch "Flightplan not available."
        printHttpFooter
        return
    }
    set ifr      [lindex $data 2]
    set type     [string toupper [lindex $data 3]]
    set tas      [lindex $data 4]  
    set from     [lindex $data 5]
    set etd      [lindex $data 6]
    set atd      [lindex $data 7]
    set fl       [lindex $data 8]
    set dest     [lindex $data 9]
    set hrs      [lindex $data 10]
    set mins     [lindex $data 11]
    set fuelhrs  [lindex $data 12]
    set fuelmins [lindex $data 13]
    set alt      [lindex $data 14]
    set remarks  [lindex $data 15]
    set route    [lindex $data 16]
   
    #  Transponder check
    if {[catch {
        set xpdr [lindex $POSITIONS($callsign) 1]
    }]} {
        set xpdr "Unknown"
        set show 0
    } else {
        # add leading zero's if necesarry
        if {[string length $xpdr] == 3} {
            set xpdr "0$xpdr"
        } elseif {[string length $xpdr] == 2} {
            set xpdr "00$xpdr"
        } elseif {[string length $xpdr] == 1} {
            set xpdr "000$xpdr"
        }
    }

    if {[string match $ifr "I"]} {
        set ifrstring "IFR"
    } elseif {[string match $ifr "V"]} {
        set ifrstring "VFR"
    } else {
        set ifrstring "Unknown"
    }
    puts $ch "
<HTML><HEAD><TITLE>Flight Plan of $callsign</TITLE></HEAD>
<BODY>
<small><a href=\"/\">Settings</a></small><BR>
<TABLE WIDTH=\"100%\" BORDER=\"1\"> 
<TR>
    "
    puts $ch "<TR><TD colspan=\"4\" bgColor=\"000080\" align=\"center\">
    <STRONG><font color=\"white\">Flightplan of $callsign</font></STRONG>
    </TD></TR>"
    puts $ch "
</TR>
<TR>"
    puts $ch [fpheader 1 "Aircraft Identification"]
    puts $ch [fpheader 1 "Flight Rules"]
    puts $ch [fpheader 2 "Remarks"]
    puts $ch "
</TR>
<TR>"
    puts $ch [fpbody 1 "<font size=\"+1\" color=\"red\"><B>$callsign</B></FONT>"]
    puts $ch [fpbody 1 "$ifrstring"]
    puts $ch [fpbody 2 "$remarks"]
    puts $ch "
</TR>
<TR>"
    puts $ch [fpheader 1 "Departure aerodrome"]
    puts $ch [fpheader 1 "Cruise speed"]
    puts $ch [fpheader 1 "Requested altitude"]
    puts $ch [fpheader 1 "Destination aerodrome"]
    puts $ch "
</TR>
<TR>"
    puts $ch [fpbody 1 "<font size=\"+1\" color=\"red\"><B>$from</B></font>"]
    puts $ch [fpbody 1 "$tas knots (TAS)"]
    puts $ch [fpbody 1 "<font size=\"+1\" color=\"red\"><B>$fl</B></font>"]
    puts $ch [fpbody 1 "<font size=\"+1\" color=\"red\"><B>$dest</B></font>"]
    puts $ch "
</TR>
<TR>
    "
    puts $ch [fpheader 1 "Estimated time of departure"]
    puts $ch [fpheader 1 "Actual time of departure"]
    puts $ch [fpheader 1 "Estimated flight time"]
    puts $ch [fpheader 1 "Fuel on board"]
    puts $ch "
</TR>
<TR>
    "
    puts $ch [fpbody 1 "$etd"]
    puts $ch [fpbody 1 "$atd"]
    puts $ch [fpbody 1 "$hrs:$mins<BR>(hours:minutes)"]
    puts $ch [fpbody 1 "$fuelhrs:$fuelmins<BR>(hours:minutes)"]
    puts $ch [fpbody 1 ""]
    puts $ch "
</TR>
<TR>"
    puts $ch [fpheader 1 "Alternate Aerodrome"]
    puts $ch [fpbody 3 "$alt"]
    puts $ch "
</TR>
<TR>"
    puts $ch [fpheader 1 "Route"]
    puts $ch [fpbody 3 "$route"]
    puts $ch "
</TR>
<TR>"
    puts $ch [fpheader 1 "Aircraft type"]
    puts $ch [fpbody 3 "$type"]
    puts $ch "
</TR>
<TR>"
    puts $ch [fpheader 1 "Squawk"]
    puts $ch [fpbody 3 "$xpdr"]
    puts $ch "
</TR>
<TR>
    <TD colspan=\"4\" bgColor=\"000080\">&nbsp;</TD>
</TR>
</TABLE>
</FONT>
</BODY>
</HTML>
"
    printHttpFooter $ch
} ; # end httpDetailedFlightplan


##
# print output to web client. 
#
proc httpFlightplan {ch param} {
    global FLIGHTPLANS
    global POSITIONS

    puts $ch "HTTP/1.0 200 OK"
    puts $ch "Server: PCProxy Kees Leune/kees@leune.org"
    puts $ch "Content-Type: text/html"
    puts $ch "Pragma: no-cache"
    puts $ch "Connection: close"
    puts $ch ""

    # scan for refresh parameter
    puts $ch "<HEAD>"
    if {[regexp {refresh=([0-9]+)} $param x refresh]} {
        puts $ch "<META HTTP-EQUIV=\"refresh\" content=\"$refresh\">"
    }
    puts $ch "<TITLE>Flight routes</TITLE>"
    puts $ch "</HEAD><BODY>"

    # scan for filters
    set filtertype NONE
    set filtervalue NONE
    set displayformat NONE

    if {[regexp {filter=([a-zA-Z]+)} $param x filtertype]} {
        set filtertype [string toupper $filtertype]
        debug "Filter active: $filtertype"
    }
    if {[regexp {filtervalue=([a-zA-Z+-]+)} $param x filtervalue]} {
        set filtervalue [string toupper $filtervalue]
        debug "Filtering on: $filtervalue"
    }
    if {[regexp {orderby=([a-zA-Z]+)} $param x orderby]} {
        set orderby [string toupper $orderby]
    }
    if {[regexp -nocase {format=plain} $param x ]} {
        debug "Display format: plain"
        set displayformat plain
    }

    # report if we do not have any flight plans
    if {![info exists FLIGHTPLANS]} {
        puts $ch "No flightplans available."
        puts $ch "<P>"
        printHttpFooter $ch
        return
    }
        
    # check if we have to sort
    if {[string match $orderby DEST]} {
        debug "Order by: destination"
        set callsigns [lsort -command destinationSort [array names FLIGHTPLANS]]
    } elseif {[string match $orderby FROM]} {
        debug "Order by: origin"
        set callsigns [lsort -command originSort [array names FLIGHTPLANS]]
    } else {
        set callsigns [lsort -dictionary [array names FLIGHTPLANS]]
    }

    if {[string match $displayformat plain]} {
        puts $ch "<table width=\"100%\" border=\"0\"><TR><TD>"
    } else {
        puts $ch "<small><a href=\"/\">Settings</a></small><BR>"
        puts $ch "<table width=\"100%\" cellpadding=\"3\" border=\"1\"><TR><TD>"
    }
    set count 0
    foreach callsign $callsigns {

        set data     [split $FLIGHTPLANS($callsign) :]
        set ifr      [lindex $data 2]
        set type     [lindex $data 3]
        set tas      [lindex $data 4]  
        set from     [lindex $data 5]
        set etd      [lindex $data 6]
        set atd      [lindex $data 7]
        set fl       [lindex $data 8]
        set dest     [lindex $data 9]
        set hrs      [lindex $data 10]
        set mins     [lindex $data 11]
        set fuelhrs  [lindex $data 12]
        set fuelmins [lindex $data 13]
        set alt      [lindex $data 14]
        set remarks  [lindex $data 15]
        set route    [lindex $data 16]
        set show 1

        # destination filter
        if {[string match $filtertype DESTINATION] && \
            ![regexp -nocase "^$filtervalue" $dest]} {
            
            set show 0
        } elseif {[string match $filtertype ORIGIN] && \
            ![regexp -nocase "^$filtervalue" $from]} {

            set show 0
        } elseif {[string match $filtertype BOTH] && \
            ![regexp -nocase "^$filtervalue" $dest] && \
            ![regexp -nocase "^$filtervalue" $from]} {

            set show 0
        }

        #  Transponder check
        if {[catch {
            set xpdr [lindex $POSITIONS($callsign) 1]
        }]} {
            set xpdr "Unknown"
            set show 0
        } else {
            # add leading zero's if necesarry
            if {[string length $xpdr] == 3} {
                set xpdr "0$xpdr"
            } elseif {[string length $xpdr] == 2} {
                set xpdr "00$xpdr"
            } elseif {[string length $xpdr] == 1} {
                set xpdr "000$xpdr"
            }
        }

        # show flightstrip
        if {$show} {
            incr count
            puts $ch "<TR>"
            if {[string match $displayformat plain]} {
              puts $ch "<td>$callsign</td>"
              # Get type of plane.
              set type [lindex [split $FLIGHTPLANS($callsign) :] 3]
              # Throw away stuff before and after the slashes.
              regexp {[^/]*/([^/]+)/[^/]*} $type dummy type
              regexp {([^/]+)/[^/]+} $type dummy type
              puts $ch "<td>$type</td>"
            } else {
              puts $ch "
    <TD valign=\"top\" align=\"left\" NOWRAP>
        <FONT SIZE=\"+2\" COLOR=\"RED\">
        <a href=\"details.html?callsign=$callsign\">$callsign</a>
        </FONT>
    </TD>"
            }
            puts $ch "
    <TD valign=\"top\" NOWRAP><FONT SIZE=\"+2\">$from-$dest</FONT></TD>
    <TD valign=\"top\" ALIGN=\"RIGHT\" NOWRAP><font size=\"+2\">$fl</font></TD>"

    # Throw away unnessesary characters that tend to clog up flight plans.
    regsub -all {[\.\-,/]} $route " " route
    # Shorten really long flight plans.
    if {[string length $route] > 100} {
      set part1 [string range $route 0 45]
      set start [expr [string length $route]-45]
      set part2 [string range $route $start end]
      puts $ch "<TD valign=\"top\">$part1 ... $part2</TD>"
    } else {
      puts $ch "<TD valign=\"top\">$route</TD>"
    }
    puts $ch "</TR>"
         } ;# end show
    } ;# end foreach
    puts $ch "</table><P>"

    # no results because filtering rules active
    if {$count == 0}  {
        puts $ch "No flightplans available.<P>"
    }

    # announce time and (possibly) next update
    if {![string match $displayformat plain]} {
        set now [clock format [clock seconds] -format {%d-%m-%Y %H:%M:%S} -gmt 1]
        puts $ch "Last update $now Z"

        if {[info exists refresh]} {
            set next [clock format [expr [clock seconds] + $refresh] \
                -format {%H:%M:%S} -gmt 1]
            puts $ch "(next at $next Z)"
        }
    } ;# end if not plain
    puts $ch "<P>"
    printHttpFooter $ch
} ;# end httpOk


##
# HTTP 500 Bad request
#
proc httpError {ch message} {
    puts $ch "HTTP/1.0 500 Bad Request"
    puts $ch "Server: PCProxy Kees Leune/kees@leune.org"
    puts $ch "Connection: close"
    puts $ch "Content-Type: text/html\n"
    puts $ch "<H1>HTTP/1.0 500 Bad Request</H1>"
    puts $ch $message
    cprint "HTTP/1.0 500 Bad Request $message"

    printHttpFooter $ch
}


##
# HTTP 404 Not Found
#
proc httpNotFound {ch message} {
    puts $ch "HTTP/1.0 404 Not Found"
    puts $ch "Connection: close"
    puts $ch "Content-type: text/html\n"
    puts $ch "<H1>HTTP/1.0 404 Not Found</H1>"
    puts $ch "The requested file $message could not be found on this server"
    cprint "HTTP/1.0 404 Not Found $message"

    printHttpFooter $ch
}

##
# print a HTML footer to channel 
#
proc printHttpFooter ch {
    puts $ch "<P><HR><SMALL><a href=\"http://www.leune.org/pcproxy/\">PCProxy</a> &copy; 2001-2003 Kees Leune"
    puts $ch "<a href=\"mailto:kees@leune.org\">kees@leune.org</a></SMALL>"
    puts $ch "</BODY></HTML>"
    close $ch
}

# EOF
