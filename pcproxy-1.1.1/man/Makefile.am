## Process this file with automake to produce Makefile.in
## $Id: Makefile.am,v 1.6 2004/03/11 09:14:34 kees Exp $

man_MANS = pcproxy.1

EXTRA_DIST = pcproxy.pod.in
CLEANFILES = pcproxy.1 pcproxy.pod
DISTCLEANFILES = $(CLEANFILES)

pcproxy.1: pcproxy.pod
	pod2man --release="$(PACKAGE) $(VERSION)" --center=pcproxy $< $@
