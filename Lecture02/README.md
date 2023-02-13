#Домашнее задание к Лекции №2 Работа с уровнями изоляции транзакции в PostgreSQL

ДЗ Выполняем в `psql`

> Выключаем автокоммит
`\set AUTOCOMMIT off`

> Создаём таблицу
```
create table persons(id serial, first_name text, second_name text);
CREATE TABLE
postgres=*# insert into persons(first_name, second_name) values('ivan', 'ivanov');
INSERT 0 1
postgres=*# insert into persons(first_name, second_name) values('petr', 'petrov');
INSERT 0 1
postgres=*# commit;
COMMIT
```
> Проверяем уровень транзакци
```
show transaction isolation level;
 transaction_isolation 
-----------------------
 read committed
(1 row)
```
> Выполняем INSERT в таблицу в первой сессии 
```
postgres=# begin;
BEGIN
postgres=*# insert into persons(first_name, second_name) values('sergey', 'sergeev');
INSERT 0 1
```
> Проверяем видимость изменений во второй сессии
```
begin;
BEGIN
postgres=*# select * from persons;
 id | first_name | second_name 
----+------------+-------------
  1 | ivan       | ivanov
  2 | petr       | petrov
(2 rows)
```
> Не видим записи во второй сессии т.к. транзакция не завершена, а уровень изоляции не позволяет выполнять грязное чтение(в постгресе грязное чтение вообще запрезено)
> После выполнения комита в первой сессии мы можем видеть новую запись во второй сессии:
```
id | first_name | second_name 
----+------------+-------------
  1 | ivan       | ivanov
  2 | petr       | petrov
  3 | sergey     | sergeev
(3 rows)
```

> Выполняем транзакции с уровень изоляции repeatable read:
```
begin transaction isolation level repeatable read;
BEGIN
insert into persons(first_name, second_name) values('sveta', 'svetova');
```
> Не видим изменений во второй сессии по тем же самым причинам, что и в первый раз
```
select * from persons;
 id | first_name | second_name 
----+------------+-------------
  1 | ivan       | ivanov
  2 | petr       | petrov
  3 | sergey     | sergeev
(3 rows)
```

> После прмиенения комита в первой сессии во второй сессии по-прежнему не видно изменений. Это связано с тем, что транзакции выполнялись с уровнем repeatable read. Repeatable read фиксирует состояние таблицы на начало чтения для того, чтобы обеспечить консистентность читаемых данных. Но возможно вставить новую строку между заблокированными или изменять новые строки, котороые не охвачены блокировкой.
> После применения commit новая строка ожидаемо доступна для чтения т.к. после коммита снята блокировка со всех строк охваченных транзакцией
```
select * from persons;
 id | first_name | second_name 
----+------------+-------------
  1 | ivan       | ivanov
  2 | petr       | petrov
  3 | sergey     | sergeev
  5 | sveta      | svetova
(4 rows)
```
