#!/bin/bash
sudo su postgres -c psql <<EOF 
\x 
create database testdb;
\c testdb;
create table copy_test as
select
  generate_series(1,100) as id,
  md5(random()::text)::char(10) as fio;
create table copy_restore(id integer,fio text);
\copy copy_test to '/pg_backup/copy.sql';
\copy copy_restore from '/pg_backup/copy.sql';
EOF
