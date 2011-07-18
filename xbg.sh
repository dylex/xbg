#!/bin/bash
w=1920
h=1200
displays=":0.0"
setroot="fvwm-root -r"
#setroot="xv -root +noresetroot -quit"

img=/tmp/xbg.xpm
dir=`dirname $0`
[[ $dir ]] && dir=$dir/
gimp="gimp-console -i -c --batch-interpreter plug-in-script-fu-eval"
while getopts 'ew:h:d:f:S:W:n' opt ; do case $opt in
	e) img= ; edit=1 ;;
	w) w=$OPTARG ;;
	h) h=$OPTARG ;;
	d) displays=$OPTARG ;; 
	f) img=$OPTARG ;;
	S) sunpos=$OPTARG ;;
	W) weather=$OPTARG ;;
	n) gimp="echo $gimp" ;;
	*) exit 1
esac ; done
nd=0 ; for d in $displays ; do nd=$(($nd+1)) ; done
[[ $sunpos ]] || sunpos=`${dir}sunpos -adm -f%s $time`
[[ $weather ]] || weather=`${dir}weather.pl`
args="\"$img\" $nd '($(($w*$nd)) . $h) '(${sunpos//
/ }) '((${weather//
/) (}))"
cmd="(define xbg-dir \"$dir\") (load \"${dir}xbg.scm\") (xbg $args)"

if [[ $edit ]] ; then
	echo $args
	echo $cmd
	exec gimp -b "$cmd" -b "(gimp-display-new 1)"
fi
lockfile -r0 $img.lock || exit $?
rm -f $img.0
trap "rm -f $img.lock" EXIT
$gimp -b "$cmd (gimp-quit 1)" -b "(gimp-quit 1)" || exit 1
[[ -f $img.0 ]] || exit 1
i=0
for d in $displays ; do
	DISPLAY=$d $setroot $img.$i
	i=$(($i+1))
done
