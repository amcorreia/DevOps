#!/bin/bash

FTP_HOST=""
FTP_USER=""
FTP_PASS=""

DAY_TO_DELETE=$(date --date="3 days ago" +"%Y-%m-%d")

TMPBACKUPDIR=$(mktemp --tmpdir=/opt/backup-zimbra --directory)
BKP_DATE_FILE=$(date +"%Y-%m-%d")

# go to temp directory
cd $TMPBACKUPDIR || exit 1

DOMAINS=$(zmprov getAllDomains)
DOMAINS_N=$(echo $DOMAINS | wc -w)
DOMAINS_I=1
for DOMAIN in $DOMAINS; do
    mkdir $DOMAIN
    ACCOUNTS=$(zmprov -l getAllAccounts $DOMAIN)
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
ncftp -u ${FTP_USER} -p ${FTP_PASS} ${FTP_HOST} <<EOF
ls /zimbra-backup/*${DAY_TO_DELETE}*
EOF

cd -
rmdir $TMPBACKUPDIR

