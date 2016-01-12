#!/bin/bash

# TODO: migrate mailing lists

get_info() {
    account=$1
    property=$2
    n=$(zmprov getAccount $account $property | wc -l )

    if [ $n -gt 2 ]; then
        zmprov getAccount $account $property | tail -2 | head -1 | cut -d: -f2 | sed -e 's/^[[:space:]]*//'
    else
        echo ""
    fi
}

get_alias() {
    account=$1
    zmprov -l getAccount $account | grep zimbraMailAlias | awk '{print $2}'
}

DOMAINS=$(zmprov getAllDomains)
DOMAINS_N=$(echo $DOMAINS | wc -w)
DOMAINS_I=1

for DOMAIN in $DOMAINS; do
    echo "Exporting domain [$DOMAINS_I/$DOMAINS_N]: $DOMAIN"
    TMP_FILE=$(tempfile -p zmb)

    echo "createDomain $DOMAIN" >> $TMP_FILE
    ACCOUNTS=$(zmprov -l getAllAccounts $DOMAIN)
    ACCOUNTS_N=$(echo $ACCOUNTS | wc -w)
    ACCOUNTS_I=1
    for ACCOUNT in $ACCOUNTS; do
        DISPLAY_NAME=$(get_info $ACCOUNT displayName)
        GIVEN_NAME=$(get_info $ACCOUNT givenName )
        SN_NAME=$(get_info  $ACCOUNT sn) 
        PASS=$(echo $ACCOUNT | md5sum | cut -d ' ' -f1) 
        echo -n "Exporting account [$ACCOUNTS_I/$ACCOUNTS_N]\\r"

        # zmprov  createAccount andy@domain.com password displayName 'Andy Anderson' givenName Andy sn Anderson
        LINE0=$(printf "createAccount %s %s displayName '%s' givenName '%s' sn '%s'" "$ACCOUNT" "$PASS" "$DISPLAY_NAME" "$GIVEN_NAME" "$SN_NAME")

        echo $LINE0 >> $TMP_FILE
        ACCOUNTS_I=$(( $ACCOUNTS_I + 1))
    done

    # Get all alias
    for ACCOUNT in $ACCOUNTS; do
        aliases=$(get_alias $ACCOUNT)
        if [ -n "$aliases" ]; then
            for ALIAS in $aliases;do
                echo "addAccountAlias $ACCOUNT $ALIAS" >> $TMP_FILE
            done
        fi
    done

    mv $TMP_FILE $DOMAIN.zimbra.zmp
    DOMAINS_I=$(($DOMAINS_I+1))
done


DOMAINS_N=$(echo $DOMAINS | wc -w)
DOMAINS_I=1
for DOMAIN in $DOMAINS; do
    ACCOUNTS=$(zmprov -l getAllAccounts $DOMAIN)
    ACCOUNTS_N=$(echo $ACCOUNTS | wc -w)
    ACCOUNTS_I=1
    mkdir $DOMAIN
    for ACCOUNT in $ACCOUNTS; do
        echo -n "Exporting account data [$ACCOUNTS_I/$ACCOUNTS_N]\\r"
        # /opt/zimbra/bin/zmmailbox -z -m email@example.com -t 0 getRestURL "//?fmt=tgz" > email@example.com.tgz
        /opt/zimbra/bin/zmmailbox -z -m $ACCOUNT -t 0 getRestURL "//?fmt=tgz" > $DOMAIN/${ACCOUNT}.tgz
        ACCOUNTS_I=$(( $ACCOUNTS_I + 1))
    done
    DOMAINS_I=$(($DOMAINS_I+1))
done
# export

# provisioninng das listas de email
# myPath=$(pwd)
#/opt/zimbra/bin/zmprov gadl | while read listname;
#do
#   echo "/opt/zimbra/bin/zmprov cdl $listname" > $myPath/$listname
#   /opt/zimbra/bin/zmprov gdl $listname | grep zimbraMailForwardingAddress >  $myPath/$listname.tmp
#   cat $myPath/$listname.tmp | sed 's/zimbraMailForwardingAddress: //g' |
#   while read member; do
#     echo "/opt/zimbra/bin/zmprov adlm $listname $member" >> $myPath/$listname
#   done
#   /bin/rm $myPath/$listname.tmp
#done
