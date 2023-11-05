# Домашнее задание к Лекции №18
## Партиционирование


> Для развёртывания используется vagrant + ansible. Ansible отвечает за установку Postgres создание БД\таблиц, а также выполние восстаноления БД demo (aka Download Big Database flights).

Запуск стенда:

```
git clone git@github.com:NickVG/otus-postgres.git
cd otus-postgres/Lecture18
vagrant up
```

Подготовка базы выполняется скриптом, который дёргает ansible. Vagrant создаёт ВМ. Ansible устанавливает софт и запускает скрипты, которые поднимают малоизвестную базу demo.


##### Секционировать большую таблицу из демо базы flights.

Выведем список таблиц БД:

```
demo=# \dt+
                                                List of relations
  Schema  |      Name       | Type  |  Owner   | Persistence | Access method |  Size  |        Description        
----------+-----------------+-------+----------+-------------+---------------+--------+---------------------------
 bookings | aircrafts_data  | table | postgres | permanent   | heap          | 16 kB  | Aircrafts (internal data)
 bookings | airports_data   | table | postgres | permanent   | heap          | 56 kB  | Airports (internal data)
 bookings | boarding_passes | table | postgres | permanent   | heap          | 455 MB | Boarding passes
 bookings | bookings        | table | postgres | permanent   | heap          | 105 MB | Bookings
 bookings | flights         | table | postgres | permanent   | heap          | 21 MB  | Flights
 bookings | seats           | table | postgres | permanent   | heap          | 96 kB  | Seats
 bookings | ticket_flights  | table | postgres | permanent   | heap          | 547 MB | Flight segment
 bookings | tickets         | table | postgres | permanent   | heap          | 386 MB | Tickets
(8 rows)
```

Посмотрим модержимое таблиц `bookings` и `tickets`.
```
demo=# \d bookings
                        Table "bookings.bookings"
    Column    |           Type           | Collation | Nullable | Default 
--------------+--------------------------+-----------+----------+---------
 book_ref     | character(6)             |           | not null | 
 book_date    | timestamp with time zone |           | not null | 
 total_amount | numeric(10,2)            |           | not null | 
Indexes:
    "bookings_pkey" PRIMARY KEY, btree (book_ref)
Referenced by:
    TABLE "tickets" CONSTRAINT "tickets_book_ref_fkey" FOREIGN KEY (book_ref) REFERENCES bookings(book_ref)
```

```
demo=# \d tickets
                        Table "bookings.tickets"
     Column     |         Type          | Collation | Nullable | Default 
----------------+-----------------------+-----------+----------+---------
 ticket_no      | character(13)         |           | not null | 
 book_ref       | character(6)          |           | not null | 
 passenger_id   | character varying(20) |           | not null | 
 passenger_name | text                  |           | not null | 
 contact_data   | jsonb                 |           |          | 
Indexes:
    "tickets_pkey" PRIMARY KEY, btree (ticket_no)
Foreign-key constraints:
    "tickets_book_ref_fkey" FOREIGN KEY (book_ref) REFERENCES bookings(book_ref)
Referenced by:
    TABLE "ticket_flights" CONSTRAINT "ticket_flights_ticket_no_fkey" FOREIGN KEY (ticket_no) REFERENCES tickets(ticket_no)
```


Так как эта таблица содержит данные о ежденвынх полётах, то заполняется она по датам  плюс-минус равномерно и разуменее всего её было бы разбить по датам. Сделаем это:

```
CREATE TABLE bookings_range (
       book_ref     character(6),
       book_date    timestamptz,
       total_amount numeric(10,2)
   ) PARTITION BY RANGE(book_date);
```

Создадим партиции на каждый месяц.

```
demo=# CREATE TABLE bookings_range_201706 PARTITION OF bookings_range FOR VALUES FROM ('2017-06-01'::timestamptz) TO ('2017-07-01'::timestamptz);
CREATE TABLE
demo=# CREATE TABLE bookings_range_201707 PARTITION OF bookings_range FOR VALUES FROM ('2017-07-01'::timestamptz) TO ('2017-08-01'::timestamptz);
CREATE TABLE
demo=# CREATE TABLE bookings_range_201606 PARTITION OF bookings_range FOR VALUES FROM ('2016-06-01'::timestamptz) TO ('2016-07-01'::timestamptz);
CREATE TABLE
demo=# CREATE TABLE bookings_range_201607 PARTITION OF bookings_range FOR VALUES FROM ('2016-07-01'::timestamptz) TO ('2016-08-01'::timestamptz);
CREATE TABLE
demo=# CREATE TABLE bookings_range_201608 PARTITION OF bookings_range FOR VALUES FROM ('2016-08-01'::timestamptz) TO ('2016-09-01'::timestamptz);
CREATE TABLE
demo=# CREATE TABLE bookings_range_201609 PARTITION OF bookings_range FOR VALUES FROM ('2016-09-01'::timestamptz) TO ('2016-10-01'::timestamptz);
CREATE TABLE
demo=# CREATE TABLE bookings_range_201610 PARTITION OF bookings_range FOR VALUES FROM ('2016-10-01'::timestamptz) TO ('2016-11-01'::timestamptz);
CREATE TABLE
CREATE TABLE bookings_range_201608 PARTITION OF bookings_range FOR VALUES FROM ('2016-08-01'::timestamptz) TO ('2016-09-01'::timestamptz);
CREATE TABLE
...
```

Для указания границ секции можно использовать не только константы, но и выражения, например вызов фун
кции. Значение выражения вычисляется в момент создания секции  и сохраняется в системном каталоге:

```
demo=# CREATE TABLE bookings_range_201708 PARTITION OF bookings_range 
demo-#        FOR VALUES FROM (to_timestamp('01.08.2017','DD.MM.YYYY')) 
demo-#                     TO (to_timestamp('01.09.2017','DD.MM.YYYY'));
CREATE TABLE
```

После добавления партиций для всего года (+небольшой задел на будущее) таблица `bookings_range` выглядит следующим образом:
```
demo=# \d+ bookings_range
                                          Partitioned table "bookings.bookings_range"
    Column    |           Type           | Collation | Nullable | Default | Storage  | Compression | Stats target | Description 
--------------+--------------------------+-----------+----------+---------+----------+-------------+--------------+-------------
 book_ref     | character(6)             |           |          |         | extended |             |              | 
 book_date    | timestamp with time zone |           |          |         | plain    |             |              | 
 total_amount | numeric(10,2)            |           |          |         | main     |             |              | 
Partition key: RANGE (book_date)
Partitions: bookings_range_201606 FOR VALUES FROM ('2016-06-01 00:00:00+00') TO ('2016-07-01 00:00:00+00'),
            bookings_range_201607 FOR VALUES FROM ('2016-07-01 00:00:00+00') TO ('2016-08-01 00:00:00+00'),
            bookings_range_201608 FOR VALUES FROM ('2016-08-01 00:00:00+00') TO ('2016-09-01 00:00:00+00'),
            bookings_range_201609 FOR VALUES FROM ('2016-09-01 00:00:00+00') TO ('2016-10-01 00:00:00+00'),
            bookings_range_201610 FOR VALUES FROM ('2016-10-01 00:00:00+00') TO ('2016-11-01 00:00:00+00'),
            bookings_range_201611 FOR VALUES FROM ('2016-11-01 00:00:00+00') TO ('2016-12-01 00:00:00+00'),
            bookings_range_201612 FOR VALUES FROM ('2016-12-01 00:00:00+00') TO ('2017-01-01 00:00:00+00'),
            bookings_range_201701 FOR VALUES FROM ('2017-01-01 00:00:00+00') TO ('2017-02-01 00:00:00+00'),
            bookings_range_201702 FOR VALUES FROM ('2017-02-01 00:00:00+00') TO ('2017-03-01 00:00:00+00'),
            bookings_range_201703 FOR VALUES FROM ('2017-03-01 00:00:00+00') TO ('2017-04-01 00:00:00+00'),
            bookings_range_201704 FOR VALUES FROM ('2017-04-01 00:00:00+00') TO ('2017-05-01 00:00:00+00'),
            bookings_range_201705 FOR VALUES FROM ('2017-05-01 00:00:00+00') TO ('2017-06-01 00:00:00+00'),
            bookings_range_201706 FOR VALUES FROM ('2017-06-01 00:00:00+00') TO ('2017-07-01 00:00:00+00'),
            bookings_range_201707 FOR VALUES FROM ('2017-07-01 00:00:00+00') TO ('2017-08-01 00:00:00+00'),
            bookings_range_201708 FOR VALUES FROM ('2017-08-01 00:00:00+00') TO ('2017-09-01 00:00:00+00')

```

Задаём 
```
demo=# SET constraint_exclusion = OFF;
SET
```

Заполняем таблицу с автоматической разбивкой по секциям:
```
demo=# INSERT INTO bookings_range SELECT * FROM bookings;
INSERT 0 2111110
```

За декларативным синтаксисом по-прежнему скрываются наследуемые таблицы, поэтому распределение строк по секциям можно посмотреть запросом:
```
demo=# sELECT tableoid::regclass, count(*) FROM bookings_range GROUP BY tableoid;
       tableoid        | count  
-----------------------+--------
 bookings_range_201706 | 165213
 bookings_range_201707 | 171671
 bookings_range_201607 |  11394
 bookings_range_201608 | 168470
 bookings_range_201609 | 165419
 bookings_range_201610 | 170925
 bookings_range_201708 |  87790
 bookings_range_201701 | 171206
 bookings_range_201702 | 154598
 bookings_range_201703 | 171260
 bookings_range_201704 | 165485
 bookings_range_201705 | 170952
 bookings_range_201611 | 165437
 bookings_range_201612 | 171290
(14 rows)
```

В родительской таблице этих данных нет:
```
demo=# SELECT * FROM ONLY bookings_range;
 book_ref | book_date | total_amount 
----------+-----------+--------------
(0 rows)

```

Проверим исключение секций в плане запроса:
```
demo=# EXPLAIN (COSTS OFF)  SELECT * FROM bookings_range WHERE book_date = '2016-07-01'::timestamptz;
                                 QUERY PLAN                                 
----------------------------------------------------------------------------
 Seq Scan on bookings_range_201607 bookings_range
   Filter: (book_date = '2016-07-01 00:00:00+00'::timestamp with time zone)
(2 rows)
```

В следующем запросе вместо константы используется функция to_timestamp с категорией изменчивости STABLE:
```
demo=# EXPLAIN (COSTS OFF) 
demo-#    SELECT * FROM bookings_range WHERE book_date = to_timestamp('01.07.2016','DD.MM.YYYY');
                                        QUERY PLAN                                        
------------------------------------------------------------------------------------------
 Gather
   Workers Planned: 2
   ->  Parallel Append
         Subplans Removed: 14
         ->  Parallel Seq Scan on bookings_range_201607 bookings_range_1
               Filter: (book_date = to_timestamp('01.07.2016'::text, 'DD.MM.YYYY'::text))

```

Значение функции вычисляется при инициализации плана запроса и часть секций исключается из просмотра (строка Subplans Removed). Но это работает только для SELECT. При изменении данных исключение секций на основе значений STABLE функций пока не реализовано:


```
demo=# EXPLAIN (COSTS OFF) DELETE FROM bookings_range WHERE book_date = to_timestamp('01.12.2016','DD.MM.YYYY');
                                        QUERY PLAN                                        
------------------------------------------------------------------------------------------
 Delete on bookings_range
   Delete on bookings_range_201606 bookings_range
   Delete on bookings_range_201607 bookings_range
   Delete on bookings_range_201608 bookings_range
   Delete on bookings_range_201609 bookings_range
   Delete on bookings_range_201610 bookings_range
   Delete on bookings_range_201611 bookings_range
   Delete on bookings_range_201612 bookings_range_1
   Delete on bookings_range_201701 bookings_range
   Delete on bookings_range_201702 bookings_range
   Delete on bookings_range_201703 bookings_range
   Delete on bookings_range_201704 bookings_range
   Delete on bookings_range_201705 bookings_range
   Delete on bookings_range_201706 bookings_range
   Delete on bookings_range_201707 bookings_range
   Delete on bookings_range_201708 bookings_range
   ->  Append
         Subplans Removed: 14
         ->  Seq Scan on bookings_range_201612 bookings_range_1
               Filter: (book_date = to_timestamp('01.12.2016'::text, 'DD.MM.YYYY'::text))
```

Поэтому следует использовать константы:
```
demo=# EXPLAIN (COSTS OFF) 
demo-#    DELETE FROM bookings_range WHERE book_date = '2016-12-01'::timestamptz;
                                    QUERY PLAN                                    
----------------------------------------------------------------------------------
 Delete on bookings_range
   Delete on bookings_range_201612 bookings_range_1
   ->  Seq Scan on bookings_range_201612 bookings_range_1
         Filter: (book_date = '2016-12-01 00:00:00+00'::timestamp with time zone)
(4 rows)
```

Для выполнения следующего запроса требуется сортировка результатов полученных из разных секций. Поэтому в плане запроса мы видим узел SORT и высокую начальную стоимость плана:

```
demo=# EXPLAIN SELECT * FROM bookings_range ORDER BY book_date;
                                                 QUERY PLAN                                                 
------------------------------------------------------------------------------------------------------------
 Sort  (cost=310344.03..315624.35 rows=2112130 width=21)
   Sort Key: bookings_range.book_date
   ->  Append  (cost=0.00..45145.95 rows=2112130 width=21)
         ->  Seq Scan on bookings_range_201606 bookings_range_1  (cost=0.00..20.20 rows=1020 width=52)
         ->  Seq Scan on bookings_range_201607 bookings_range_2  (cost=0.00..186.94 rows=11394 width=21)
         ->  Seq Scan on bookings_range_201608 bookings_range_3  (cost=0.00..2758.70 rows=168470 width=21)
         ->  Seq Scan on bookings_range_201609 bookings_range_4  (cost=0.00..2708.19 rows=165419 width=21)
         ->  Seq Scan on bookings_range_201610 bookings_range_5  (cost=0.00..2798.25 rows=170925 width=21)
         ->  Seq Scan on bookings_range_201611 bookings_range_6  (cost=0.00..2708.37 rows=165437 width=21)
         ->  Seq Scan on bookings_range_201612 bookings_range_7  (cost=0.00..2804.90 rows=171290 width=21)
         ->  Seq Scan on bookings_range_201701 bookings_range_8  (cost=0.00..2803.06 rows=171206 width=21)
         ->  Seq Scan on bookings_range_201702 bookings_range_9  (cost=0.00..2530.98 rows=154598 width=21)
         ->  Seq Scan on bookings_range_201703 bookings_range_10  (cost=0.00..2803.60 rows=171260 width=21)
         ->  Seq Scan on bookings_range_201704 bookings_range_11  (cost=0.00..2709.85 rows=165485 width=21)
         ->  Seq Scan on bookings_range_201705 bookings_range_12  (cost=0.00..2798.52 rows=170952 width=21)
         ->  Seq Scan on bookings_range_201706 bookings_range_13  (cost=0.00..2705.13 rows=165213 width=21)
         ->  Seq Scan on bookings_range_201707 bookings_range_14  (cost=0.00..2810.71 rows=171671 width=21)
         ->  Seq Scan on bookings_range_201708 bookings_range_15  (cost=0.00..1437.90 rows=87790 width=21)
(18 rows)
```

Создадим индекс по `book_date`. Вместо одного глобального индекса, создаются индексы в каждой секции:

```
demo=# CREATE INDEX book_date_idx ON bookings_range(book_date);
CREATE INDEX
demo=# \di bookings_range*
                                     List of relations
  Schema  |                Name                 | Type  |  Owner   |         Table         
----------+-------------------------------------+-------+----------+-----------------------
 bookings | bookings_range_201606_book_date_idx | index | postgres | bookings_range_201606
 bookings | bookings_range_201607_book_date_idx | index | postgres | bookings_range_201607
 bookings | bookings_range_201608_book_date_idx | index | postgres | bookings_range_201608
 bookings | bookings_range_201609_book_date_idx | index | postgres | bookings_range_201609
 bookings | bookings_range_201610_book_date_idx | index | postgres | bookings_range_201610
 bookings | bookings_range_201611_book_date_idx | index | postgres | bookings_range_201611
 bookings | bookings_range_201612_book_date_idx | index | postgres | bookings_range_201612
 bookings | bookings_range_201701_book_date_idx | index | postgres | bookings_range_201701
 bookings | bookings_range_201702_book_date_idx | index | postgres | bookings_range_201702
 bookings | bookings_range_201703_book_date_idx | index | postgres | bookings_range_201703
 bookings | bookings_range_201704_book_date_idx | index | postgres | bookings_range_201704
 bookings | bookings_range_201705_book_date_idx | index | postgres | bookings_range_201705
 bookings | bookings_range_201706_book_date_idx | index | postgres | bookings_range_201706
 bookings | bookings_range_201707_book_date_idx | index | postgres | bookings_range_201707
 bookings | bookings_range_201708_book_date_idx | index | postgres | bookings_range_201708
(15 rows)
```

Предыдущий запрос с сортировкой теперь может использовать индекс по ключу секционирования и выдавать результат из разных секций сразу в отсортированном виде. Узел SORT не нужен и для выдачи первой строки результата требуются минимальные затраты:

```
demo=# EXPLAIN SELECT * FROM bookings_range ORDER BY book_date;
                                                                    QUERY PLAN                                                                    
--------------------------------------------------------------------------------------------------------------------------------------------------
 Append  (cost=4.27..109766.54 rows=2112130 width=21)
   ->  Index Scan using bookings_range_201606_book_date_idx on bookings_range_201606 bookings_range_1  (cost=0.15..59.45 rows=1020 width=52)
   ->  Index Scan using bookings_range_201607_book_date_idx on bookings_range_201607 bookings_range_2  (cost=0.29..571.19 rows=11394 width=21)
   ->  Index Scan using bookings_range_201608_book_date_idx on bookings_range_201608 bookings_range_3  (cost=0.29..7919.30 rows=168470 width=21)
   ->  Index Scan using bookings_range_201609_book_date_idx on bookings_range_201609 bookings_range_4  (cost=0.29..7765.55 rows=165419 width=21)
   ->  Index Scan using bookings_range_201610_book_date_idx on bookings_range_201610 bookings_range_5  (cost=0.29..8024.08 rows=170925 width=21)
   ->  Index Scan using bookings_range_201611_book_date_idx on bookings_range_201611 bookings_range_6  (cost=0.29..7769.85 rows=165437 width=21)
   ->  Index Scan using bookings_range_201612_book_date_idx on bookings_range_201612 bookings_range_7  (cost=0.29..8041.64 rows=171290 width=21)
   ->  Index Scan using bookings_range_201701_book_date_idx on bookings_range_201701 bookings_range_8  (cost=0.29..8036.38 rows=171206 width=21)
   ->  Index Scan using bookings_range_201702_book_date_idx on bookings_range_201702 bookings_range_9  (cost=0.29..7259.26 rows=154598 width=21)
   ->  Index Scan using bookings_range_201703_book_date_idx on bookings_range_201703 bookings_range_10  (cost=0.29..8037.16 rows=171260 width=21)
   ->  Index Scan using bookings_range_201704_book_date_idx on bookings_range_201704 bookings_range_11  (cost=0.29..7770.56 rows=165485 width=21)
   ->  Index Scan using bookings_range_201705_book_date_idx on bookings_range_201705 bookings_range_12  (cost=0.29..8024.55 rows=170952 width=21)
   ->  Index Scan using bookings_range_201706_book_date_idx on bookings_range_201706 bookings_range_13  (cost=0.29..7758.43 rows=165213 width=21)
   ->  Index Scan using bookings_range_201707_book_date_idx on bookings_range_201707 bookings_range_14  (cost=0.29..8059.36 rows=171671 width=21)
   ->  Index Scan using bookings_range_201708_book_date_idx on bookings_range_201708 bookings_range_15  (cost=0.29..4109.14 rows=87790 width=21)
```


Созданные таким образом индексы на секциях поддерживаются централизованно. При добавлении новой секции на ней автоматически будет создан индекс. А удалить индекс только одной секции нельзя:
```
demo=# DROP INDEX bookings_range_201706_book_date_idx;
ERROR:  cannot drop index bookings_range_201706_book_date_idx because index book_date_idx requires it
HINT:  You can drop index book_date_idx instead.
```
Postgres подсказывает, что индекс можно удалить только целиком.
```
demo=# DROP INDEX book_date_idx;
DROP INDEX
```

При создании индекса на секционированной таблице нельзя указать CONCURRENTLY.

Но можно поступить следующим образом. Сначала создаем индекс только на основной таблице, он получит статус invalid:
```
demo=# CREATE INDEX book_date_idx ON ONLY bookings_range(book_date);
CREATE INDEX
demo=# SELECT indisvalid FROM pg_index WHERE indexrelid::regclass::text = 'book_date_idx';
 indisvalid 
------------
 f
(1 row)
```

Затем создаем индексы на всех секциях с опцией CONCURRENTLY:

```
demo=# CREATE INDEX CONCURRENTLY book_date_201706_idx ON bookings_range_201706 (book_date);
CREATE INDEX
demo=# CREATE INDEX CONCURRENTLY book_date_201707_idx ON bookings_range_201707 (book_date);
CREATE INDEX
demo=# CREATE INDEX CONCURRENTLY book_date_201708_idx ON bookings_range_201708 (book_date);
CREATE INDEX
demo=# CREATE INDEX CONCURRENTLY book_date_201708_idx ON bookings_range_201709 (book_date);
ERROR:  relation "bookings_range_201709" does not exist
demo=# CREATE INDEX CONCURRENTLY book_date_201709_idx ON bookings_range_201709 (book_date);
ERROR:  relation "bookings_range_201709" does not exist
demo=# CREATE INDEX CONCURRENTLY book_date_201606_idx ON bookings_range_201606 (book_date);
CREATE INDEX
demo=# CREATE INDEX CONCURRENTLY book_date_201607_idx ON bookings_range_201607 (book_date);
CREATE INDEX
demo=# CREATE INDEX CONCURRENTLY book_date_201608_idx ON bookings_range_201608 (book_date);
CREATE INDEX
demo=# CREATE INDEX CONCURRENTLY book_date_201609_idx ON bookings_range_201609 (book_date);
CREATE INDEX
demo=# CREATE INDEX CONCURRENTLY book_date_201610_idx ON bookings_range_201610 (book_date);
CREATE INDEX
demo=# CREATE INDEX CONCURRENTLY book_date_201611_idx ON bookings_range_201611 (book_date);
CREATE INDEX
demo=# CREATE INDEX CONCURRENTLY book_date_201612_idx ON bookings_range_201612 (book_date);
CREATE INDEX
demo=# CREATE INDEX CONCURRENTLY book_date_201701_idx ON bookings_range_201701 (book_date);
CREATE INDEX
demo=# CREATE INDEX CONCURRENTLY book_date_201702_idx ON bookings_range_201702 (book_date);
CREATE INDEX
demo=# CREATE INDEX CONCURRENTLY book_date_201703_idx ON bookings_range_201703 (book_date);
CREATE INDEX
demo=# CREATE INDEX CONCURRENTLY book_date_201704_idx ON bookings_range_201704 (book_date);
CREATE INDEX
demo=# CREATE INDEX CONCURRENTLY book_date_201705_idx ON bookings_range_201705 (book_date);
CREATE INDEX
```

Теперь подключаем локальные индексы к глобальному:
```
demo=# ALTER INDEX book_date_idx ATTACH PARTITION book_date_201606_idx;
ALTER INDEX
demo=# ALTER INDEX book_date_idx ATTACH PARTITION book_date_201607_idx;
ALTER INDEX
demo=# ALTER INDEX book_date_idx ATTACH PARTITION book_date_201608_idx;
ALTER INDEX
demo=# ALTER INDEX book_date_idx ATTACH PARTITION book_date_201609_idx;
ALTER INDEX
demo=# ALTER INDEX book_date_idx ATTACH PARTITION book_date_201610_idx;
ALTER INDEX
demo=# ALTER INDEX book_date_idx ATTACH PARTITION book_date_201611_idx;
ALTER INDEX
demo=# ALTER INDEX book_date_idx ATTACH PARTITION book_date_201612_idx;
ALTER INDEX
demo=# ALTER INDEX book_date_idx ATTACH PARTITION book_date_201701_idx;
ALTER INDEX
demo=# ALTER INDEX book_date_idx ATTACH PARTITION book_date_201702_idx;
ALTER INDEX
demo=# ALTER INDEX book_date_idx ATTACH PARTITION book_date_201703_idx;
ALTER INDEX
demo=# ALTER INDEX book_date_idx ATTACH PARTITION book_date_201704_idx;
ALTER INDEX
demo=# ALTER INDEX book_date_idx ATTACH PARTITION book_date_201705_idx;
ALTER INDEX
demo=# ALTER INDEX book_date_idx ATTACH PARTITION book_date_201706_idx;
ALTER INDEX
demo=# ALTER INDEX book_date_idx ATTACH PARTITION book_date_201708_idx;
ALTER INDEX
demo=# ALTER INDEX book_date_idx ATTACH PARTITION book_date_201709_idx;
```

Это похоже на подключение таблиц-секций, на которое мы посмотрим чуть позже. Как только все индексные секции будут подключены, основной индекс изменит свой статус:
```
SELECT indisvalid FROM pg_index WHERE indexrelid::regclass::text = 'book_date_idx';
 indisvalid 
------------
 f
(1 row)
```

##### Подключение и отключение секций
Автоматическое создание секций не предусмотрено. Поэтому их нужно создавать заранее, до того как в таблицу начнут добавляться записи с новыми значениями ключа секционирования.

Будем создавать новую секцию во время работы других транзакций с таблицей, заодно посмотрим на блокировки:
```
demo=# begin;
BEGIN
demo=*# SELECT count(*) FROM bookings_range
demo-*#     WHERE book_date = to_timestamp('01.07.2016','DD.MM.YYYY');
 count 
-------
     0
(1 row)

demo=*# SELECT count(*) FROM bookings_range
    WHERE book_date = to_timestamp('01.08.2016','DD.MM.YYYY');
 count 
-------
     2
(1 row)

demo=*# SELECT relation::regclass::text, mode FROM pg_locks 
demo-*#     WHERE pid = pg_backend_pid() AND relation::regclass::text LIKE 'bookings%';
       relation        |      mode       
-----------------------+-----------------
 bookings_range_201701 | AccessShareLock
 bookings_range_201612 | AccessShareLock
 bookings_range_201611 | AccessShareLock
 bookings_range_201610 | AccessShareLock
 bookings_range_201609 | AccessShareLock
 bookings_range_201608 | AccessShareLock
 bookings_range_201607 | AccessShareLock
 bookings_range_201606 | AccessShareLock
 bookings_range        | AccessShareLock
 bookings_range_201702 | AccessShareLock
 bookings_range_201705 | AccessShareLock
 bookings_range_201706 | AccessShareLock
 bookings_range_201707 | AccessShareLock
 bookings_range_201703 | AccessShareLock
 bookings_range_201704 | AccessShareLock
 bookings_range_201708 | AccessShareLock
(16 rows)
```

Блокировка AccessShareLock накладывается на основную таблицу, все секции и индексы в начале выполнения оператора. 
Вычисление функции to_timestamp и исключение секций происходит позже.
Если бы вместо функции использовалась константа, то блокировалась бы только основная таблица и секция bookings_range_201708.
Поэтому при возможности указывать в запросе константы — это следует делать, иначе количество строк в pg_locks будет увеличиваться 
пропорционально количеству секций, что может привести к необходимости увеличения max_locks_per_transaction.

Не завершая предыдущую транзакцию, создадим следующую секцию для сентября в новом сеансе:

```
postgres=# \c demo 
You are now connected to database "demo" as user "postgres".
demo=# CREATE TABLE bookings_range_201709 (LIKE bookings_range
demo(# );
CREATE TABLE
demo=# BEGIN ;
BEGIN
demo=*# ALTER TABLE bookings_range ATTACH PARTITION bookings_range_201709
demo-*#           FOR VALUES FROM ('2017-09-01'::timestamptz) TO ('2017-10-01'::timestamptz);
ALTER TABLE
demo=*# SELECT relation::regclass::text, mode FROM pg_locks 
demo-*#           WHERE pid = pg_backend_pid() AND relation::regclass::text LIKE 'bookings%';
              relation               |           mode           
-------------------------------------+--------------------------
 bookings_range_201709_book_date_idx | AccessExclusiveLock
 bookings_range_201709               | ShareLock
 bookings_range_201709               | AccessExclusiveLock
 bookings_range                      | ShareUpdateExclusiveLock
(4 rows)

```

При создании новой секции на основную таблицу накладывается блокировка ShareUpdateExclusiveLock, совместимая с AccessShareLock.
Поэтому операции добавления секций не конфликтуют с запросами к секционированной таблице.

далее выполняем коммит в обоих сеансах по принципу FIFO.

Отключение секций выполняется командой `ALTER TABLE… DETACH PARTITION`. Сама секция не удаляется, а становится самостоятельной таблицей. Из неё можно выгрузить данные, её можно удалить, а при необходимости подключить заново(ATTACH PARTITION).

Другой вариант отключения — удалить секцию командой `DROP TABLE`.

К сожалению оба варианта, DROP TABLE и DETACH PARTITION, используют блокировку AccessExclusiveLock на основную таблицу.
