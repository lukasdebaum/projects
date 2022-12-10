#!/bin/bash

EXPORT_DIR="/root/migr/data/vcards"

while read line
do
	user=$(echo -n $line | tr -d "\n")
	vcard_file="${user}.vcf"
	if [[ ! -f "${EXPORT_DIR}/$vcard_file" ]]; then
        continue
    fi

    php import_vcard.php "${user}" "${EXPORT_DIR}/${vcard_file}"

done < "${1:-/dev/stdin}"
