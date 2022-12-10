#!/bin/bash

EXPORT_DIR="/root/migr/data/vcards"
MIN_SIZE=1

while read line
do
	user=$(echo -n $line | tr -d "\n")
	vcard_file="${user}.vcf"
	code=$(curl -sSL -w '%{http_code}' -u "${user}:xxx" -o "${EXPORT_DIR}/${vcard_file}" "https://dav.xxx.at/export/addressbooks/${user}/personal?export")
	if [[ "$code" =~ ^200 ]]; then
		if [[ -f "${EXPORT_DIR}/$vcard_file" ]]; then
			filesize=$(stat -c%s "${EXPORT_DIR}/${vcard_file}")
			if [[ $filesize -lt $MIN_SIZE ]]; then
		        rm -f "${EXPORT_DIR}/${vcard_file}"
				echo "$0: ERROR: $user - no vcard entries"
				continue
			fi
		else
			echo "$0: ERROR: user: $user - file ${vcard_file} not found"
			continue
		fi
	else
		echo "$0: ERROR: user: $user - server returned HTTP code: ${code}"
		rm -f "${EXPORT_DIR}/${vcard_file}"
		continue
	fi
done < "${1:-/dev/stdin}"
