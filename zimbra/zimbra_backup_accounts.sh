#!/bin/bash

FTP_HOST=""
FTP_USER=""
FTP_PASS=""
DAYS_TO_KEEP_BKP=3
FTP_PATH="/zimbra-backup/"

TMPBACKUPDIR=$(mktemp --tmpdir=/opt/backup-zimbra --directory)
BKP_DATE_FILE=$(date +"%Y-%m-%d")
DAY_TO_DELETE=$(date --date="$DAYS_TO_KEEP_BKP days ago" +"%Y-%m-%d")

function datediff() {
    d1=$(date -d "$1" +%s)
    d2=$(date -d "$2" +%s)
    # only diff doesn't matter order
    echo $(( (((d1-d2) > 0 ? (d1-d2) : (d2-d1)) + 43200) / 86400 ))
}

function ftp_delete_old_copy() {
    FILES=$(ncftpls -u ${FTP_USER} -p ${FTP_PASS} ftp://${FTP_HOST}/$FTP_PATH/)

    for file in $FILES; do
        date=$(echo $file | grep -Eo '[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}')
        num_days=$(datediff $date $BKP_DATE_FILE)
        if [ $num_days -gt $DAYS_TO_KEEP_BKP ]; then
            echo "Delete: $file"
            ncftp -u ${FTP_USER} -p ${FTP_PASS} ${FTP_HOST} <<EOF
rm $FTP_PATH/$file
EOF
        fi
    done
}


# go to temp directory
cd $TMPBACKUPDIR || exit 1


DOMAINS=$(/opt/zimbra/bin/zmprov getAllDomains)
DOMAINS_N=$(echo $DOMAINS | wc -w)
DOMAINS_I=1
for DOMAIN in $DOMAINS; do
    mkdir $DOMAIN
    ACCOUNTS=$(/opt/zimbra/bin/zmprov -l getAllAccounts $DOMAIN)
    ACCOUNTS_N=$(echo $ACCOUNTS | wc -w)
    ACCOUNTS_I=1
    for ACCOUNT in $ACCOUNTS; do
        /opt/zimbra/bin/zmmailbox -z -m $ACCOUNT -t 0 getRestURL "//?fmt=tgz" > $DOMAIN/${ACCOUNT}-${BKP_DATE_FILE}.tgz
    done

    # send backup
    ncftpput -u ${FTP_USER} -p ${FTP_PASS} -m -V -DD ${FTP_HOST} /zimbra-backup/ $DOMAIN/*.tgz

    rmdir $DOMAIN
done

# Delete old backups
ftp_delete_old_copy
#ncftp -u ${FTP_USER} -p ${FTP_PASS} ${FTP_HOST} <<EOF
#ls /zimbra-backup/*${DAY_TO_DELETE}*
#EOF

cd -
rmdir $TMPBACKUPDIR

