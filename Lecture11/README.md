# Домашнее задание к Лекции №11 
### Нагрузочное тестирование и тюнинг PostgreSQL

> Для развёртывания используется vagrant + ansible. Ansible отвечает за установку Postgres и создание схемы\таблицы.

Запуск стенда:

```
git clone git@github.com:NickVG/otus-postgres.git
cd otus-postgres/Lecture09
vagrant up
```

Подготовка базы выполняется скриптом, который дёргает ansible

> Подключаемся к VM `vagrant ssh server`

####  Настроить кластер PostgreSQL 15 на максимальную производительность не обращая внимание на возможные проблемы с надежностью в случае аварийной перезагрузки виртуальной машины

> Порогон тестов с параметрами по-умолчанию

```
postgres@server:~$ pgbench -c50 -P 60 -T 600 -U postgres postgres
pgbench (15.2 (Ubuntu 15.2-1.pgdg20.04+1))
starting vacuum...end.
progress: 60.0 s, 949.2 tps, lat 52.278 ms stddev 55.437, 0 failed
progress: 120.0 s, 714.8 tps, lat 69.969 ms stddev 66.424, 0 failed
progress: 180.0 s, 747.1 tps, lat 66.939 ms stddev 64.486, 0 failed
progress: 240.0 s, 736.1 tps, lat 67.928 ms stddev 64.176, 0 failed
progress: 300.0 s, 789.3 tps, lat 63.360 ms stddev 62.547, 0 failed
progress: 360.0 s, 744.0 tps, lat 67.216 ms stddev 66.147, 0 failed
progress: 420.0 s, 777.3 tps, lat 64.310 ms stddev 64.372, 0 failed
progress: 480.0 s, 806.2 tps, lat 62.043 ms stddev 61.774, 0 failed
progress: 540.0 s, 822.4 tps, lat 60.800 ms stddev 63.021, 0 failed
^[[Dprogress: 600.0 s, 855.0 tps, lat 58.464 ms stddev 59.263, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 50
number of threads: 1
maximum number of tries: 1
duration: 600 s
number of transactions actually processed: 476524
number of failed transactions: 0 (0.000%)
latency average = 62.929 ms
latency stddev = 62.820 ms
initial connection time = 338.717 ms
```


> Настроим автовакуум:

```
log_autovacuum_min_duration = 0
autovacuum_max_workers = 1
autovacuum_naptime = 15s
autovacuum_vacuum_threshold = 25
autovacuum_vacuum_scale_factor = 0.05
autovacuum_vacuum_cost_delay = 10
autovacuum_vacuum_cost_limit = 1000
checkpoint_timeout = 30s
```

> И прогоним тесты ещё разок

```
postgres@server:~$ pgbench -c50 -P 60 -T 600 -U postgres postgres
pgbench (15.2 (Ubuntu 15.2-1.pgdg20.04+1))
starting vacuum...end.
progress: 60.0 s, 1788.7 tps, lat 27.796 ms stddev 31.590, 0 failed
progress: 120.0 s, 1794.7 tps, lat 27.861 ms stddev 31.098, 0 failed
progress: 180.0 s, 1278.5 tps, lat 39.089 ms stddev 48.268, 0 failed
progress: 240.0 s, 1159.0 tps, lat 43.154 ms stddev 50.322, 0 failed
progress: 300.0 s, 2014.7 tps, lat 24.818 ms stddev 27.348, 0 failed
progress: 360.0 s, 1965.3 tps, lat 25.442 ms stddev 25.449, 0 failed
progress: 420.0 s, 2180.7 tps, lat 22.929 ms stddev 21.898, 0 failed
progress: 480.0 s, 2043.5 tps, lat 24.465 ms stddev 24.674, 0 failed
progress: 540.0 s, 2093.5 tps, lat 23.883 ms stddev 24.410, 0 failed
progress: 600.0 s, 2116.0 tps, lat 23.625 ms stddev 24.144, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 50
number of threads: 1
maximum number of tries: 1
duration: 600 s
number of transactions actually processed: 1106118
number of failed transactions: 0 (0.000%)
latency average = 27.108 ms
latency stddev = 30.886 ms
initial connection time = 311.076 ms
tps = 1844.308120 (without initial connection time)
```

> Затем выставим параметры, которые подходят в нашем случае

```
shared_buffers = '1024 MB'	|| Выставляется в 1/4 от объёма RAM
work_mem = '32 MB'		|| Настройка используется для сложной сортировки.  Если много пользователей, пытающихся выполнить операции сортировки, тогда система выделит: _work_mem * total sort operations_
maintenance_work_mem = '320 MB'	|| параметр памяти, используемый для задач обслуживания. Используется в таких задачах, как VACUUM, RESTORE, CREATE INDEX, ADD FOREIGN KEY и ALTER TABLE.
huge_pages = off		|| Использование больших страниц памяти. Вряд ли для нас актуально, т.к. памяти всего 4 GB
effective_cache_size = '3 GB'	|| оценка памяти, доступной для кэширования диска. При маленьком значении планировщик запросов может принять решение не использоват ьнекоторые индексы, даже если они полезны. Задётся с запасом.
effective_io_concurrency = 200	|| Задаёт допустимое число параллельных операций ввода/вывода. Для SSD актуальны несколько 100. У Меня не было особой разницы между 100 и 1000.
random_page_cost = 0.1		|| Вес запроса при случайном доступе. Для SSD актуальны значения ~ 1. Или же ещё меньше, при большом объёме RAM. В моём случае 0.1 и 1 почти не показывали разницы

bgwriter_delay = 200ms		|| Задаёт задержку между раундами активности процесса фоновой записи. Для уменьшения IO
bgwriter_lru_maxpages = 100	|| Задаёт максимальное число буферов, которое сможет записать процесс фоновой записи за раунд активности. Подбирать, наверное, стоит опытным путём.

wal_level = minimal		|| Меньше данных в wal -> меньше требований к IO
synchronous_commit = off	|| Снижение потребности в IO.
```

> Результат тестирования

```
postgres@server:~$ pgbench -c50 -P 60 -T 600 -U postgres postgres
pgbench (15.2 (Ubuntu 15.2-1.pgdg20.04+1))
starting vacuum...end.
progress: 60.0 s, 4923.5 tps, lat 10.100 ms stddev 8.175, 0 failed
progress: 120.0 s, 4892.1 tps, lat 10.221 ms stddev 9.048, 0 failed
progress: 180.0 s, 4967.2 tps, lat 10.065 ms stddev 7.813, 0 failed
progress: 240.0 s, 4913.1 tps, lat 10.177 ms stddev 8.065, 0 failed
progress: 300.0 s, 4771.0 tps, lat 10.479 ms stddev 8.767, 0 failed
progress: 360.0 s, 4801.6 tps, lat 10.413 ms stddev 7.858, 0 failed
progress: 420.0 s, 4735.4 tps, lat 10.556 ms stddev 7.958, 0 failed
progress: 480.0 s, 4863.0 tps, lat 10.283 ms stddev 8.039, 0 failed
progress: 540.0 s, 4838.1 tps, lat 10.334 ms stddev 8.274, 0 failed
progress: 600.0 s, 4387.5 tps, lat 11.396 ms stddev 9.266, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 50
number of threads: 1
maximum number of tries: 1
duration: 600 s
number of transactions actually processed: 2885594
number of failed transactions: 0 (0.000%)
latency average = 10.391 ms
latency stddev = 8.339 ms
initial connection time = 308.686 ms
tps = 4811.378498 (without initial connection time)
```

#### Аналогично протестировать через утилиту https://github.com/Percona-Lab/sysbench-tpcc

> Результаты прогона sysbench с параметрами postgresql.conf по-умолчанию.

```
SQL statistics:
    queries performed:
        read:                            2398343
        write:                           2489259
        other:                           369588
        total:                           5257190
    transactions:                        184738 (614.94 per sec.)
    queries:                             5257190 (17499.63 per sec.)
    ignored errors:                      825    (2.75 per sec.)
    reconnects:                          0      (0.00 per sec.)

General statistics:
    total time:                          300.4162s
    total number of events:              184738

Latency (ms):
         min:                                    0.21
         avg:                                   90.98
         max:                                12798.30
         95th percentile:                      235.74
         sum:                             16807429.46

Threads fairness:
    events (avg/stddev):           3298.8929/51.33
    execution time (avg/stddev):   300.1327/0.12
```


> Результаты прогона sysbench с дефолтовым параметрами postgresql.conf

```
SQL statistics:
    queries performed:
        read:                            3268053
        write:                           3392388
        other:                           503172
        total:                           7163613
    transactions:                        251530 (837.07 per sec.)
    queries:                             7163613 (23840.00 per sec.)
    ignored errors:                      1091   (3.63 per sec.)
    reconnects:                          0      (0.00 per sec.)

General statistics:
    total time:                          300.4863s
    total number of events:              251530

Latency (ms):
         min:                                    0.18
         avg:                                   66.82
         max:                                 4731.62
         95th percentile:                      173.58
         sum:                             16807750.51

Threads fairness:
    events (avg/stddev):           4491.6071/62.95
    execution time (avg/stddev):   300.1384/0.12
```

> Результаты прогона sysbench с новыми параметрами postgresql.conf
```
SQL statistics:
    queries performed:
        read:                            3481016
        write:                           3613621
        other:                           537874
        total:                           7632511
    transactions:                        268881 (894.96 per sec.)
    queries:                             7632511 (25404.59 per sec.)
    ignored errors:                      1159   (3.86 per sec.)
    reconnects:                          0      (0.00 per sec.)

General statistics:
    total time:                          300.4374s
    total number of events:              268881

Latency (ms):
         min:                                    0.19
         avg:                                   62.51
         max:                                  674.40
         95th percentile:                      164.45
         sum:                             16806428.87

Threads fairness:
    events (avg/stddev):           4801.4464/64.95
    execution time (avg/stddev):   300.1148/0.10
```

P.S В этой [статье](https://www.percona.com/blog/tuning-postgresql-for-sysbench-tpcc/) сказано, что включение компрессии уменьшает нагрузку т.к. уменьшает количество и частоту записи WAL, но мой опыт говорит о том, что это такое себе, либо я чего-то не понимаю. Даже если учесть, что в статье упомминается избыток CPU. Я уверен, что если нагрузка реально высока, то такая настройка приведёт к "тормозам".
