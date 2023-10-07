#!/bin/bash
sudo su postgres -c "pg_dump -d testdb --create -U postgres -Fc -Z 9 > /pg_backup/testdb.dump.gz"
sudo su postgres -c psql <<EOF 
\x 
\c testdb;
select * from copy_restore;
truncate table copy_restore;
EOF
sudo su postgres -c 'psql -d testdb -c "select * from copy_restore;" > /pg_backup/log.txt'
sudo su postgres -c "pg_restore -d testdb -t copy_restore --clean /pg_backup/testdb.dump.gz"
