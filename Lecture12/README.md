# Домашнее задание к Лекции №12
## Репликация

> Для развёртывания используется vagrant + ansible. Ansible отвечает за установку Postgres и создание схемы\таблицы.

Запуск стенда:

```
git clone git@github.com:NickVG/otus-postgres.git
cd otus-postgres/Lecture09
vagrant up
```

Подготовка базы выполняется скриптом, который дёргает ansible. После `vagrunt up` получаем три сервера с таблицами test и test2. Все серверы подготовлены к настройке логической репликации. Досконально автоматизироват лень, поэтому Все базу создаются одинаковыми. В дальнейшем лишние данные удаляются.

### Реализовать свой миникластер на 3 ВМ.


##### Подписка на таблицу test


Создаём публикацию на Server01.

```
testdb=# delete from test2 *;
DELETE 1
testdb=# CREATE PUBLICATION test_pub FOR TABLE test;
CREATE PUBLICATION
```

Создаём подписку на Server02.

```
testdb=# create subscription test_sub connection 'host=192.168.56.101 dbname=testdb user=postgres password=postgres' publication test_pub;
NOTICE:  created replication slot "test_sub" on publisher
CREATE SUBSCRIPTION
testdb=# select * fro

testdb=# select * from test;
 c1 
----
  1
(1 row)
```

##### Подписка на таблицу test2

Создаём публикацию на Server02.

```
testdb=# CREATE PUBLICATION test2_pub FOR TABLE test2;
CREATE PUBLICATION
```

Создаём подписку на Server01, теперь уже с опцией не копировать существующие данные.

```
testdb=# create subscription test2_sub connection 'host=192.168.56.102 dbname=testdb user=postgres password=postgres' publication test2_pub with ( copy_data = false);
NOTICE:  created replication slot "test2_sub" on publisher
CREATE SUBSCRIPTION
testdb=# select * from test2;
 c2 
----
(0 rows)
```

Server02

```
testdb=# insert into test2 values ( 3);
INSERT 0 1
testdb=# select * from test2;
 c2 
----
  2
  3
(2 rows)
```

Server01

```
testdb=# select * from test2;
 c2 
----
  3
(1 row)
```

##### Настройка Сервера №3

Создаём подписки на таблицы test и test2 на Server03

```
testdb=# create subscription server03_test2_sub connection 'host=192.168.56.102 dbname=testdb user=postgres password=postgres' publication test2_pub;
NOTICE:  created replication slot "server03_test2_sub" on publisher
CREATE SUBSCRIPTION
testdb=# create subscription server03_test_sub connection 'host=192.168.56.101 dbname=testdb user=postgres password=postgres' publication test_pub;
NOTICE:  created replication slot "server03_test_sub" on publisher
CREATE SUBSCRIPTION
testdb=# select * from test*;
 c1 
----
  1
(1 row)

testdb=# select * from test2;
 c2 
----
  2
  3
(2 rows)
```

### Настройка Сервера №4

Помятуя о том, что wal_level отвечает за то, насколько подробными будут wal, решил попробовать оставить на Server03 wal_level=logical. И всё отлично заработало.

Настройка на Server04.

```
root@server04:~# pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
14  main    5432 online postgres /var/lib/postgresql/14/main /var/log/postgresql/postgresql-14-main.log
root@server04:~# pg_ctlcluster 14 main stop
root@server04:~# rm -rf /var/lib/postgresql/14/main/
postgres@server04:~$ pg_basebackup -p 5432 -R -D /var/lib/postgresql/14/main/ -h 192.168.56.103 -U postgres
Password:
postgres@server04:~$ pg_ctlcluster 14 main start
Warning: the cluster will not be running as a systemd service. Consider using systemctl:
  sudo systemctl start postgresql@14-main

postgres@server04:~$ 
postgres@server04:~$ pg_lsclusters 
Ver Cluster Port Status          Owner    Data directory              Log file
14  main    5432 online,recovery postgres /var/lib/postgresql/14/main /var/log/postgresql/postgresql-14-main.log
postgres@server04:~$ psql
psql (14.7 (Ubuntu 14.7-1.pgdg20.04+1))
Type "help" for help.

postgres=# \c testdb 
You are now connected to database "testdb" as user "postgres".
testdb=# select * from test2;
 c2 
----
  2
  3
(2 rows)
```

