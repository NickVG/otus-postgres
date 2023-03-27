#!/bin/bash
sudo su postgres -c psql <<EOF 
\x 
create database testdb;
\c testdb;
create schema testnm;
create table t1(c1 int);
insert into t1 values('1');
create role readonly;
grant CONNECT ON DATABASE testdb TO readonly;
grant USAGE ON SCHEMA testnm TO readonly;
grant SELECT ON ALL TABLES IN SCHEMA testnm to readonly;
create user testread with password 'test123';
grant readonly to testread;
alter user postgres with password 'postgres';
create table rooms(room_num int, arendator text);
insert into rooms values ('1', 'Mendeleev');
insert into rooms values ('2', 'Lomonosov');
insert into rooms values ('3', 'Zvorykin');
EOF
