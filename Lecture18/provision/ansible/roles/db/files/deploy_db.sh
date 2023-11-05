#!/bin/bash
sudo su postgres -c "psql -f /pg_backup/$(ls /pg_backup/)"
