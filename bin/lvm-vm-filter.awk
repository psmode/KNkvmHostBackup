#
# usage: lvs --units=m  --noheadings --nosuffix | awk [-v filterlv="lv1[ lv2 ...]"] -f lvm-vm-filter.awk
#
(substr($1, 1, 2) == "uv") || (substr($1, 1, 2) == "wv") || (substr($1, 1, 2) == "ws") {
	if (match(" "filterlv" ", " "$1" "))
	   next;
	sGuest = substr($1, 1, index($1, "-")-1);
	printf("%12s %08d %8s %24s\n",
		sGuest, $4, $1, $2); 
}
