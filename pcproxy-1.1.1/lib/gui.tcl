# GUI Procedure for the ProController Proxy
#
# $Id: gui.tcl,v 1.17 2004/03/11 09:30:03 kees Exp $
#
############################################################################
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
# Change the IP address and the TCP portnumber of the server to which we
# connect. This procedure should be called by the GUI
#
# param $server   IP address of server to connect to
# param $port     TCP port on server to which the connection is made
#
proc updateProperties {server port} {
    global SETTINGS
    global HTTPSOCKET
    global TIMEOUTS
    global FPLISTENER

    set SETTINGS(remote_ip)   [$server get]
    set SETTINGS(remote_port)  [$port get]
    saveSettings
    cprint "Properties updated."

    if {$SETTINGS(debug)} { 
        .topcanvas.logText configure -state normal 
    } else { 
        .topcanvas.logText configure -state disabled 
    }
    destroy .prop

    if {[expr $SETTINGS(wwwserver) == 0] && [info exists HTTPSOCKET]} {
        stopHttpServer
    }
    if {[expr $SETTINGS(wwwserver) == 1] && ![info exists HTTPSOCKET]} {
        startHttpServer
    }
    if {[expr $SETTINGS(fpserver) == 0] && [info exists FPLISTENER]} {
        stopFPserver
    }
    if {[expr $SETTINGS(fpserver) == 1] && ![info exists FPLISTENER]} {
        startFPserver
    }
    
    if {$SETTINGS(connected) == 0} {
        after cancel showStatus
    }
    if {$SETTINGS(connected) == 1} {
        after cancel showStatus
        after $TIMEOUTS(status) showStatus
    }
}

##
# Set up the properties window. Lots of code for a simple dialogue :-(
#
# +------------------------------------------------------------------+
# |                              1                                   |
# +------------------------------------------------------------------+
# |                              2                                   |
# |        +---------------------+---------------------+             |
# |        |                     |                     |             |
# |        |                     |                     |             |
# |        |      2.1            |      2.2            |             |
# |        |                     |                     |             |
# |        |                     |                     |             |
# |        +---------------------+---------------------+             |
# +------------------------------------------------------------------+
# |                              3                                   |
# +------------------------------------------------------------------+
# |                              5                                   |
# +------------------------------------------------------------------+
#
proc setProperties {} {
    global SETTINGS
    toplevel .prop
    wm title .prop "PCProxy properties"

    frame .prop.1                ;# title 
    frame .prop.2 -border 3 -relief groove     ;# input
    frame .prop.3 -border 3 -relief groove     ;# checkboxes
    frame .prop.4 -border 3 -relief groove     ;# max xpdr C altitude
    frame .prop.2.1
    frame .prop.2.2
    frame .prop.5                ;# OK/Cancel

    # frame 1
    label .prop.1.name -text Properties
    pack  .prop.1.name -side left

    # frame 2 (server info)
    set lserver [label  .prop.2.1.lServer -text "Server "]
    set lport   [label  .prop.2.1.lPort   -text "Port "]
    set tserver [entry  .prop.2.2.tServer -width 20 ]
    set tport   [entry  .prop.2.2.tPort   -width 20 ]
    $tserver delete 0 end
    $tport   delete 0 end
    $tserver insert @0 $SETTINGS(remote_ip)
    $tport   insert @0 $SETTINGS(remote_port)
    focus $tserver
    
    pack $lserver $lport -side top -anchor e
    pack $tserver $tport -side top

    pack .prop.2.1 -anchor e -side left
    pack .prop.2.2 -fill x -expand 1 -anchor w -side left

    pack $tserver -side top -anchor w
    pack $tport   -side top -anchor w

    # frame 3 (checkbuttons)
    checkbutton .prop.3.connect -onvalue 1 -offvalue 0 \
        -variable SETTINGS(connected) \
        -text "Status reporting connected clients"
    checkbutton .prop.3.webserver -onvalue 1 -offvalue 0 \
        -variable SETTINGS(wwwserver) \
        -text "Run flightplan webserver"
    checkbutton .prop.3.fpserver -onvalue 1 -offvalue 0 \
        -variable SETTINGS(fpserver) \
        -text "Run flightplan server"
    checkbutton .prop.3.debug -onvalue 1 -offvalue 0 \
        -variable SETTINGS(debug) \
        -text "Debug output" 
    checkbutton .prop.3.chat -onvalue 1 -offvalue 0 \
        -variable SETTINGS(chat)\
        -text "Chat messages to secondary clients"

    pack .prop.3.debug      -side top -anchor w
    pack .prop.3.chat       -side top -anchor w
    pack .prop.3.webserver  -side top -anchor w
    pack .prop.3.fpserver   -side top -anchor w
    pack .prop.3.connect    -side top -anchor w

    # frame 4 (maximum transponder mode C forcing altitude)
    pack [label .prop.4.l1 -text "Mode C below"] -side left
    pack [entry .prop.4.e -width 5 -textvariable SETTINGS(modec)] -side left
    pack [label .prop.4.l2 -text "feet"] -side left
    
    # frame 5 (ok/cancel)
    button .prop.5.ok     -text Ok -command "updateProperties $tserver $tport"
    button .prop.5.cancel -text Cancel -command {destroy .prop}
    pack .prop.5.ok .prop.5.cancel -side left -fill x -expand 1

    # toplevel
    pack .prop.1 -side top -expand 1 -fill x -padx 5 -pady 5 \
        -ipadx 5 -ipady 5
    pack .prop.2 -side top -expand 1 -fill both -padx 5 -pady 5 \
        -ipadx 5 -ipady 5
    pack .prop.3 -side top -expand 1 -fill x -padx 5 -pady 5 \
        -ipadx 5 -ipady 5
    pack .prop.4 -side top -expand 1 -fill x -padx 5 -pady 5 \
        -ipadx 5 -ipady 5
    pack .prop.5 -side top -expand 1 -fill x -padx 5 -pady 5 \
        -ipadx 5 -ipady 5

} ;# end setProperties

# Create the main GUI. Consists of a menu bar with a File menu and a Help
# menu, and a log window (text).
#
proc createGUI {} {
    global STOP SETTINGS

    menu .topmenu -type menubar -tearoff false

    # File Menu
    menu .topmenu.file \
        -type normal \
        -tearoff false
    .topmenu.file add command \
        -label Properties \
        -accelerator Control-p \
        -underline 0 \
        -state normal \
        -command setProperties
    .topmenu.file add separator
    .topmenu.file add command \
        -label Disconnect \
        -underline 0 \
        -accelerator Control-d \
        -command disconnectAll
    .topmenu.file add command \
        -label Quit \
        -accelerator Control-c \
        -underline 0 \
        -command shutdown

    # Help menu
    menu .topmenu.help \
        -type normal \
        -tearoff false
    .topmenu.help add command \
        -label "About proxy" \
        -underline 0 \
        -command aboutProxy
    .topmenu.help add command \
        -label "Homepage" \
        -underline 7 \
        -command {tk_messageBox -title homepage \
            -message {Please visit http://www.leune.org/pcproxy} -type ok}

    # Main menu
    .topmenu add cascade \
        -label File \
        -menu .topmenu.file
    .topmenu add cascade \
        -label Help \
        -menu .topmenu.help

    # setup main log window
    canvas .topcanvas -relief sunken
    label  .topcanvas.logLabel -text Status 
    text   .topcanvas.logText  -height 10 -width 80 -wrap word

    pack   .topcanvas.logLabel -anchor w -padx 5 -pady 5
    pack   .topcanvas.logText .topcanvas -padx 5 -pady 5

    . configure -menu .topmenu
    wm protocol . WM_DELETE_WINDOW shutdown
    wm title . PCProxy
    bind all <Control-p> setProperties
    bind all <Control-c> shutdown
    bind all <Control-d> disconnectAll
    if {!$SETTINGS(debug)} { .topcanvas.logText configure -state disabled }
} ;# end createGUI

##
# The About window.
#
proc aboutProxy {} {
    tk_messageBox -title {About PCProxy} -message {

    This software is (C) 2003 by Kees Leune <kees@leune.org>.  
    All rights reserved.  
     
    Copying of this software is permitted, providing the program  
    is not changed in any form and appropriates credites are given.  
     
    Use is free for all personal, non-commercial use. No warantee of any  
    kind is given. Use at your own risk.  
     
    Please visit http://www.leune.org/pcproxy for more information.
   
    $Id: gui.tcl,v 1.17 2004/03/11 09:30:03 kees Exp $
    } -type ok

} ;# end of aboutProxy

#### EOF ####
