#!/bin/bash

/bin/mkdir -p /usr/local
/usr/sbin/chown root:wheel /usr/local

/bin/chmod u+rwx /usr/local/bin
/bin/chmod g+rwx /usr/local/bin
/bin/chmod 755 /usr/local/bin
/usr/sbin/chown ${USER} /usr/local/bin
/usr/bin/chgrp admin /usr/local/bin
