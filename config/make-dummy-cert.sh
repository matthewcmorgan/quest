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
        echo "Usage: filename1 ~= key.pem"
        echo "Usage: filename2 ~= cert.pem"
        echo "Usage: filename3 ~= dhparams.pem"
        exit 0
fi

PEM1=$(/bin/mktemp /tmp/openssl.XXXXXX)
PEM2=$(/bin/mktemp /tmp/openssl.XXXXXX)
PEM3=$(/bin/mktemp /tmp/openssl.XXXXXX)
trap 'rm -f ${PEM1} ${PEM2}' INT
answers | /usr/bin/openssl req -nodes -x509 -days 365 -newkey -sha512 -outform PEM -keyout "${PEM1}"  -out "${PEM2}" 2> /dev/null
/usr/bin/openssl dhparam -out "${PEM3}" 4096
install -Dv "${PEM1}" "${1}"
install -Dv "${PEM2}" "${2}"
install -Dv "${PEM3}" "${3}"
rm -f "${PEM1}" "${PEM2}" "${PEM3}"
