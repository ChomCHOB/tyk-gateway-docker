#!/bin/bash

TYK_CONF=/opt/tyk-gateway/tyk.conf

sed -i 's/TYKLISTENPORT/'${TYK_LISTEN_PORT}'/g' ${TYK_CONF}
sed -i 's/TYKSECRET/'${TYK_SECRET}'/g' ${TYK_CONF}

/opt/tyk-gateway/tyk$TYK_LANG --conf=${TYK_CONF}