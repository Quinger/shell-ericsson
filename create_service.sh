#!/bin/bash

name="$1"

if [ -e $name ]
then
	exit 1
fi

if [ -n $name ]
then
	echo $name
	cat << EOF > /etc/init.d/$name
case "\$1" in
	start)
		systemctl start $name.service
	;;
	stop)
		systemctl stop $name.service
	;;
	restart)
		systemctl restart $name.service
	;;
	status)
		systemctl status $name.service
esac
EOF
	chmod +x /etc/init.d/$name
fi
