# Домашнее задание к Лекции №13
## Работа с индексами


> Для развёртывания используется vagrant + ansible. Ansible отвечает за установку Postgres создание БД\таблиц, а также выполние восстанолениe БД dvdrental.

Запуск стенда:

```
git clone git@github.com:NickVG/otus-postgres.git
cd otus-postgres/Lecture14
vagrant up
```

Подготовка базы выполняется скриптом, который дёргает ansible. После `vagrunt up` автоматически выполняется ДЗ. Vagrant создаёт ВМ. Ansible устанавливает софт и запускает скрипты, которые поднимают малоизвестную базу dvdrental.


#### Создать индекс к какой-либо из таблиц вашей БД.

Первым делом удаляем существующие индексы на таблицы, чтобы не мешались. Например `alter table film drop constraint<INDEX NAME> ;` или `drop index <INDEX NAME>`

Создаём индекс по ID фильма.
```
dvdrental=# alter table film add constraint unique_film_id unique(film_id);
ALTER TABLE
dvdrental=# explain                                                        
select film from film order by film_id;
                                   QUERY PLAN                                    
---------------------------------------------------------------------------------
 Index Scan using unique_film_id on film  (cost=0.28..92.92 rows=1000 width=412)
(1 row)
```

Команда `explain` для данного индекса будет дана ниже.

#### Реализовать индекс для полнотекстового поиска
Создаём полнотекстовый поиск
```
dvdrental=# CREATE EXTENSION pg_trgm;
CREATE EXTENSION
dvdrental=# CREATE EXTENSION btree_gin;
CREATE EXTENSION
dvdrental=# CREATE INDEX films_description_idx ON film USING gin (to_tsvector('english', description));
CREATE INDEX
```

#### Прислать текстом результат команды explain, в которой используется данный индекс
Проверим как применяются созданные индексы:

```
dvdrental=# explain
select title from film order by film_id;
                                   QUERY PLAN                                   
--------------------------------------------------------------------------------
 Index Scan using unique_film_id on film  (cost=0.28..92.92 rows=1000 width=19)
(1 row)

dvdrental=# explain SELECT film_id,title,description FROM film WHERE to_tsvector('english', description) @@ to_tsquery('action');
                                             QUERY PLAN                                             
----------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on film  (cost=8.29..26.29 rows=5 width=113)
   Recheck Cond: (to_tsvector('english'::regconfig, description) @@ to_tsquery('action'::text))
   ->  Bitmap Index Scan on films_description_idx  (cost=0.00..8.29 rows=5 width=0)
         Index Cond: (to_tsvector('english'::regconfig, description) @@ to_tsquery('action'::text))
(4 rows)
```

#### Реализовать индекс на часть таблицы или индекс на поле с функцией

Создадим индекс на часть таблицы с актёрами.
```
dvdrental=# create unique index idx_actor_id on actor(actor_id);
CREATE INDEX
dvdrental=# explain analyze select last_name from actor where actor_id<100 order by actor_id;
                                               QUERY PLAN                                               
--------------------------------------------------------------------------------------------------------
 Sort  (cost=7.74..7.99 rows=98 width=11) (actual time=0.183..0.216 rows=99 loops=1)
   Sort Key: actor_id
   Sort Method: quicksort  Memory: 29kB
   ->  Seq Scan on actor  (cost=0.00..4.50 rows=98 width=11) (actual time=0.036..0.103 rows=99 loops=1)
         Filter: (actor_id < 100)
         Rows Removed by Filter: 101
 Planning Time: 0.569 ms
 Execution Time: 0.283 ms
(8 rows)

dvdrental=# explain analyze select last_name from actor where actor_id<100 AND actor_id>50 order by actor_id;
                                               QUERY PLAN                                               
--------------------------------------------------------------------------------------------------------
 Sort  (cost=6.38..6.50 rows=49 width=11) (actual time=0.095..0.104 rows=49 loops=1)
   Sort Key: actor_id
   Sort Method: quicksort  Memory: 27kB
   ->  Seq Scan on actor  (cost=0.00..5.00 rows=49 width=11) (actual time=0.033..0.066 rows=49 loops=1)
         Filter: ((actor_id < 100) AND (actor_id > 50))
         Rows Removed by Filter: 151
 Planning Time: 0.192 ms
 Execution Time: 0.147 ms
(8 rows)

dvdrental=# \d actor
                                            Table "public.actor"
   Column    |            Type             | Collation | Nullable |                 Default                 
-------------+-----------------------------+-----------+----------+-----------------------------------------
 actor_id    | integer                     |           | not null | nextval('actor_actor_id_seq'::regclass)
 first_name  | character varying(45)       |           | not null | 
 last_name   | character varying(45)       |           | not null | 
 last_update | timestamp without time zone |           | not null | now()
Indexes:
    "idx_actor_id" UNIQUE, btree (actor_id)
Triggers:
    last_updated BEFORE UPDATE ON actor FOR EACH ROW EXECUTE FUNCTION last_updated()
```

Несмотря на то, что индекс создан, планировщик похоже считает, что для такого запроса индекс не нужен. 

#### Создать индекс на несколько полей.

Созадим индекс таблицы film на имя фильма и год выхода и подберём запрос, который заставит планировщик использовать индекс.

```
CREATE INDEX  multi_field_index ON film(film_id, release_year);
CREATE INDEX
dvdrental=# explain select * from film where release_year>2006 and film_id>100 order by release_year ;
                                      QUERY PLAN                                       
---------------------------------------------------------------------------------------
 Sort  (cost=31.05..31.06 rows=1 width=384)
   Sort Key: release_year
   ->  Index Scan using multi_field_index on film  (cost=0.28..31.04 rows=1 width=384)
         Index Cond: ((film_id > 100) AND ((release_year)::integer > 2006))
(4 rows)

```
