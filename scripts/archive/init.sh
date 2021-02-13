#!/bin/bash

# run scripts in /app/cont-init.d
# execute any cont-init scripts
for i in /app/cont-init.d/*sh
do
	if [ -e "${i}" ]; then
		echo "[i] cont-init.d - processing $i"
		. "${i}"
	fi
done

# run cron in foreground for monitoring certs
service cron start
cron -f