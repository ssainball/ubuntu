

#!/bin/bash
shopt -s expand_aliases
RESTAPI_PORT=3301
MY_POOL_ID="b71a8a9f42914b96de8a057c29f789004e5d96bdab8e97ec70be8c380bc4e380"
MY_USER_ID="5484ab13-9b2f-404d-bdbc-446f2633dc9f" # on pooltool website get this from your account profile page
THIS_GENESIS="8e4d2a343f3dcf93"   # We only actually look at the first 7 characters


if [ ! $JORMUNGANDR_RESTAPI_URL ]; then export JORMUNGANDR_RESTAPI_URL=http://127.0.0.1:${RESTAPI_PORT}/api; fi
alias cli="$(which jcli) rest v0"
nodestats=$(/root/jcli rest v0 node stats get --output-format json > stats.json);

lastBlockHeight=$(cat stats.json | jq -r .lastBlockHeight)
lastBlockHash=$(cat stats.json | jq -r .lastBlockHash)
lastPoolID=$(/root/jcli rest v0 block ${lastBlockHash} get | cut -c169-232)

echo   "https://api.pooltool.io/v0/sharemytip?poolid=${MY_POOL_ID}&userid=${MY_USER_ID}&genesispref=${THIS_GENESIS}&mytip=${lastBlockHeight}&lasthash=${lastBlockHash}&lastpool=${lastPoolID}"
if [ "$lastBlockHeight" != "" ]; then
/usr/bin/curl -G "https://api.pooltool.io/v0/sharemytip?poolid=${MY_POOL_ID}&userid=${MY_USER_ID}&genesispref=${THIS_GENESIS}&mytip=${lastBlockHeight}&lasthash=${lastBlockHash}&lastpool=${lastPoolID}"
fi
