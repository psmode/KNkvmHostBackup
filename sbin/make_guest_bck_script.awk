BEGIN {
	if (substr(ExtTarget, length(ExtTarget),1) != "/")
	   ExtTarget = ExtTarget "/";
	if (ZipCmd == "")
	   ZipCmd = "gzip --fast"
	sLastGuest = "";
	iLvIndex = 0;
	iBiggie = 50000;

	print "#!/bin/sh";
	print "# this dynamic script was made by make_guest_bck_script.awk";
	print "#";
	print "#";
}



($1 != sLastGuest) {
	if (sLastGuest != "")
	   iLvIndex = NewGuest();
}


 {
	sLastGuest = $1;
	aLV_size[iLvIndex] = $2;
	aLV_name[iLvIndex] = $3;
	aLV_vg[iLvIndex] = $4
	++iLvIndex;
}



END {
	iLvIndex = NewGuest();
}



function NewGuest()
{
	print "echo \"**\"";
	printf("echo \"** `date +%%x\\ %%T`: Backup LVMs for guest %s\"\n", sLastGuest);
	for (i = 0; i < iLvIndex; i++)
	   printf("/sbin/lvcreate -L2G -s -n bu-%s /dev/%s/%s\n",
		aLV_name[i], aLV_vg[i], aLV_name[i]);
	print "#";
	for (i = 0; i < iLvIndex; i++) {
	   printf("echo \"* `date +%%x\\ %%T`: dd if=/dev/%s/bu-%s\"\n",
		aLV_vg[i], aLV_name[i]);
	   if (aLV_size[i] > iBiggie)
	      printf("dd if=/dev/%s/bu-%s ibs=64k obs=64k | %s > %sbu-%s.dd.gz\n",
		aLV_vg[i], aLV_name[i], ZipCmd, ExtTarget, aLV_name[i])
	   else
              printf("dd if=/dev/%s/bu-%s ibs=64k obs=64k of=%sbu-%s.dd\n",
                aLV_vg[i], aLV_name[i], ExtTarget, aLV_name[i]);
	   printf("/sbin/lvremove --force /dev/%s/bu-%s\n", aLV_vg[i], aLV_name[i]);
	}
	print "#";
	print "#";
	return 0;
}
