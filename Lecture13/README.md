# Домашнее задание к Лекции №13
## Резервное копирование

> Для развёртывания используется vagrant + ansible. Ansible отвечает за установку Postgres создание БД\таблиц, а также выполние бэкапа и восстаноления.

Запуск стенда:

```
git clone git@github.com:NickVG/otus-postgres.git
cd otus-postgres/Lecture13
vagrant up
```

Подготовка базы выполняется скриптом, который дёргает ansible. После `vagrunt up` автоматически выпролняется ДЗ. Vagrant создаёт ВМ. Ansible устанавливает софт и запускает скрипты выполняющие ДЗ.
ДЗ выполняется с помощью скрптов `` ``.

#### Бэкап и восстановление с помощью copy.

Данное задание выолняет скрипт `script.sql`. Скрпит создаёт БД testdb,  таблицу `copy_test`, которую забивает данными и таблицу `copy_restore` в которую выполняется восстановление.
```
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
```

#### Бэкап и восстановление с помощью утилит pg_dump и pg_restore

Данное задание выполняется с помощью скрипта `pg_dump.sh` Для того, чтобы уудостовреиться, что данных в таблице `copy_restore` нет выполняется выгрузка из таблицы в файл `/pg_backup/log.txt`. Выгрузка показывает, что таблица перед восстановлнием является пустой.
```
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
```
