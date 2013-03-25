#!/bin/bash
for item in $(find -L logs -name "*.log" -size +10M)
do
	head -n 1000 $item > $item.tmp
	tail -n 1000 $item >> $item.tmp
	mv $item.tmp $item
	echo "Truncated $item to the first and last 1000 line"
done

