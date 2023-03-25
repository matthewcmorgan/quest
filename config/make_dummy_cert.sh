#!/bin/sh
umask 077

answers() {
        echo --
        echo US
        echo Longview
        echo "Matthew C Morgan Consulting"
        echo AWSCloudDevOps
        echo hexfury@gmail.com
        echo hexfury@hotmail.com
}

if [ $# -lt 2 ] ; then
        echo "Usage: (basename $0) filename1 filename2 filename3"
        echo "Usage: filename1 ~= server.crt"
        echo "Usage: filename2 ~= server.key"
        echo "Usage: filename3 ~= dhparams.pem"
        exit 0
fi

PEM1=$(/bin/mktemp /tmp/openssl.XXXXXX)
PEM2=$(/bin/mktemp /tmp/openssl.XXXXXX)
trap 'rm -f ${PEM1} ${PEM2}' INT
answers | /usr/bin/openssl req -newkey rsa:2048 -keyout "${PEM1}" -nodes -x509 -days 365 -out "${PEM2}" 2> /dev/null
cat "${PEM1}" > "${1}"
cat "${PEM2}" >> "${2}"
rm -f "${PEM1}" "${PEM2}"
/usr/bin/openssl dhparam -out "${3}" 4096
