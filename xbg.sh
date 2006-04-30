#!/bin/sh
w=1920
h=1200
displays=":0.0"

img=/tmp/xbg.ppm
dir=`dirname $0`
[ "$dir" ] && dir=$dir/
gimp="gimp-console -i -d -c --batch-interpreter plug_in_script_fu_eval"
while getopts 'ew:h:d:f:S:W:' opt ; do case $opt in
	e) img= ; edit=1 ;;
	w) w=$OPTARG ;;
	h) h=$OPTARG ;;
	d) displays=$OPTARG ;; 
	f) img=$OPTARG ;;
	S) sunpos=$OPTARG ;;
	W) weather=$OPTARG ;;
	*) exit 1
esac ; done
nd=0 ; for d in $displays ; do nd=$((nd+1)) ; done
[ "$sunpos" ] || sunpos=`${dir}sunpos -adm -f%s $time`
[ "$weather" ] || weather=`${dir}weather.pl`
args="\"$img\" '($((w*nd)) . $h) '($sunpos) '($weather)"
cmd="(set! xbg-dir \"$dir\") (load \"${dir}xbg.scm\") (xbg $args)"

if [ "$edit" ] ; then
	echo $args
	exec gimp -b "(begin $cmd)" "(gimp-display-new 1)"
fi
$gimp -b "(begin $cmd (gimp-quit 1))" "(gimp-quit 1)" || exit 1
[ -f "$img" ] || exit 1
x=0
for d in $displays ; do
	xv -display "$d" -crop $x 0 $w $h -root +noresetroot -quit $img
	x=$((x+w))
done
