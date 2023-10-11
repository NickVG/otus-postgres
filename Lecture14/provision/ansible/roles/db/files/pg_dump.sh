#!/bin/bash
sudo su postgres -c psql<<EOF
CREATE DATABASE dvdrental;
EOF
sudo su postgres -c "pg_restore -d dvdrental /pg_backup/dvdrental.tar"
