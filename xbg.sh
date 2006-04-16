#!/bin/sh
img=/tmp/xbg.ppm
w=1920
h=1200
gimp="gimp-console -i -d -f -c"
gimpcmd="(gimp-quit 1)"
while getopts 'ew:h:f:t:' opt ; do case $opt in
	e) gimp="gimp" ; gimpcmd="(gimp-display-new 1)" ; img=""; edit=1 ;;
	w) w=$OPTARG ;;
	h) h=$OPTARG ;;
	f) img=$OPTARG ;;
	t) time=$OPTARG ;;
	*) exit 1
esac ; done
sunpos=`sunpos -adm -f%s $time`

set -- $sunpos
$gimp $gimpargs --batch-interpreter 'plug_in_script_fu_eval' -b "(xbg \"$img\" $w $h $1 $3 $5)" "$gimpcmd" || exit 1
[[ $edit ]] && exit
[ -f $img ] || exit 1
xv -display :0.0 -root +noresetroot -quit $img
#rm -f $img
