#!/usr/bin/env bash

## Usage:
# export CREDENTIALS=$( echo -n "username:password" | md5sum | cut -d ' ' -f 1 )
# eval $(./export_auth_token.bash -c {CREDENTIALS_HASH} -a {ACCOUNT_NAME}), or
# eval $(./export_auth_token.bash -c {CREDENTIALS_HASH} -r {REALM}), or
# eval $(./export_auth_token.bash -c {CREDENTIALS_HASH} -p {PHONE_NUMBER}).

## to access 2600hz hosted, signal the api hostname and the insecure flag for curl to work
## use `-i` for curl --insecure compatability with 2600hz https api certificate:
# eval $(./export_auth_token.bash -k ui.zswitch.net -i -c {CREDENTIALS_HASH} -r {REALM})


usage()
{
	echo 'Usage: eval $('"$0"' -k {KAZOO_API_HOSTNAME} [-i] [-c {CREDENTIALS_HASH}] [[-a {ACCOUNT_NAME}] || [-p {PHONE_NUMBER}] || [-r {ACCOUNT_REALM}]] )' 1>&2;
}

function authenticate()
{
    local C="$1"
    local TYPE="$2"
    local ID="$3"
    local API="$4"

    AUTH_RESP=$( curl ${INSECURE_COMPAT} -s -X PUT ${SCHEME}://${API}:${APIPORT}/v2/user_auth \
	-d "{\"data\":{\"credentials\":\"$C\", \"$TYPE\":\"$ID\"}}" )

    STATUS=$( echo $AUTH_RESP | jq -r '.status' )

    if [[ "$STATUS" == "success" ]]
    then
        echo "export ACCOUNT_ID=$(echo $AUTH_RESP | jq -r '.data.account_id')"
        echo "export AUTH_TOKEN=$(echo $AUTH_RESP | jq -r '.auth_token')"
    else
        echo $AUTH_RESP
    fi
}

ACCOUNT_IDENTIFIER=
CREDS=
IDENTIFIER_VALUE=
# pre-define APIHOST as SERVER environment variable, if exists; null default
# otherwise.
APIHOST=
[[ -z ${SERVER} ]] && APIHOST=${SERVER}
SCHEME=http
APIPORT=8000
INSECURE_COMPAT=

while getopts ":a:c:k:p:r:i" opt; do
    case $opt in
        c)
            CREDS=${OPTARG}
            ;;
        p)
            IDENTIFIER_VALUE=${OPTARG}
            ACCOUNT_IDENTIFIER="phone_number"
            ;;
        a)
            IDENTIFIER_VALUE=${OPTARG}
            ACCOUNT_IDENTIFIER="account_name"
            ;;
        r)
            IDENTIFIER_VALUE=${OPTARG}
            ACCOUNT_IDENTIFIER="account_realm"
            ;;
        k)
	    APIHOST=${OPTARG}
	    SCHEME=https
	    APIPORT=8443
            ;;
        i)
	    INSECURE_COMPAT='--insecure'
	    ;;
        *)
            usage
            ;;
    esac
done

# if creds not specified on cli, set from environment
[[ -z "${CREDS}" ]] && CREDS="$CREDENTIALS"

# if apihost undefined default to localhost and non https config
[[ -z "${APIHOST}" ]] && APIHOST=localhost

if [[ -z "${ACCOUNT_IDENTIFIER}" ]]
then
    usage
else
    authenticate $CREDS $ACCOUNT_IDENTIFIER $IDENTIFIER_VALUE $APIHOST
fi
