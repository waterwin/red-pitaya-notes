#! /bin/sh

JOBS=4
NICE=10

DIR=`readlink -f $0`
DIR=`dirname $DIR`

RECORDER=$DIR/write-c2-files
CONFIG=write-c2-files.cfg

DECODER=/media/mmcblk0p1/apps/ft8d/ft8d
ALLMEPT=ALL_FT8.TXT

SLEEP=/media/mmcblk0p1/apps/common_tools/sleep-to-59

date

test $DIR/$CONFIG -ot $CONFIG || cp $DIR/$CONFIG $CONFIG

echo "Sleeping ..."

$SLEEP

sleep 1

date
TIMESTAMP=`date --utc +'%y%m%d_%H%M'`

echo "Recording ..."

killall -q $RECORDER
$RECORDER $CONFIG

echo "Decoding from IN1 ..."

for file in ft8_*_1_$TIMESTAMP.c2
do
  while [ `pgrep $DECODER | wc -l` -ge $JOBS ]
  do
    sleep 1
  done
  nice -n $NICE $DECODER $file &
done > decodes_1_$TIMESTAMP.txt

echo "Decoding from IN2 ..."

for file in ft8_*_2_$TIMESTAMP.c2
do
  while [ `pgrep $DECODER | wc -l` -ge $JOBS ]
  do
    sleep 1
  done
  nice -n $NICE $DECODER $file &
done > decodes_2_$TIMESTAMP.txt

wait

rm -f ft8_*_$TIMESTAMP.c2
