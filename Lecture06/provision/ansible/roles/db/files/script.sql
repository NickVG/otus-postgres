#!/bin/bash
sudo su postgres -c psql <<EOF 
\x 
create table test(c1 text);
insert into test values('1');
EOF
