#!/bin/sh

dir=$(cd `dirname $0` && pwd)
$dir/oberon run $dir/a2.txt
