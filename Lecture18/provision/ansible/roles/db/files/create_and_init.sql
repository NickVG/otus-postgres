-- SELECT current_database();

CREATE SCHEMA IF NOT EXISTS no_part;
CREATE SCHEMA IF NOT EXISTS by_hash;
CREATE SCHEMA IF NOT EXISTS by_list;
CREATE SCHEMA IF NOT EXISTS by_range;


DO
$main$
DECLARE
	clients	CONSTANT	varchar(63)[] = ARRAY['Иван Васильевич', 'Борис Фёдорович', 'Василий Иванович',  'Алексей Михайлович', 'Пётр Алексеевич', 'Александр Павлович', 'Николай Павлович.', 'Александр Николаевич'];
	query				text;
	wrk_date			date;
	client_theonly		varchar(63);
	client_mark			integer;

	range_fr1	text;
	range_to1	text;
	range_fr2	text;
	range_to2	text;
	range_fr3	text;
	range_to3	text;
	range_fr4	text;
	range_to4	text;	
BEGIN
	DROP TABLE IF EXISTS no_part.orders;
	DROP TABLE IF EXISTS by_hash.orders;
	DROP TABLE IF EXISTS by_list.orders;
	DROP TABLE IF EXISTS by_range.orders;
	
	-- no parts
	CREATE TABLE no_part.orders
	(
		order_id	bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
		client		varchar(63) NOT NULL,
		order_date	date NOT NULL,
		order_total	numeric(12, 2)
	);

	-- by range
	CREATE TABLE by_range.orders
	(
		order_id	bigint GENERATED ALWAYS AS IDENTITY,
		client		varchar(63) NOT NULL,
		order_date	date NOT NULL,
		order_total	numeric(12, 2),
		PRIMARY KEY (order_id, order_date)		-- !!!
	) PARTITION BY RANGE (order_date);

	/*
	CREATE TABLE by_range.orders_2020_1
	PARTITION OF by_range.orders
	FOR VALUES FROM ('2020-01-01') TO (2020-04-01');	
	*/

	FOR the_year IN 2010 .. 2022
	LOOP
		
		range_fr1 = the_year::text || '-01-01';
		range_to1 = the_year::text || '-04-01';
		range_fr2 = the_year::text || '-04-01';
		range_to2 = the_year::text || '-07-01';
		range_fr3 = the_year::text || '-07-01';
		range_to3 = the_year::text || '-10-01';
		range_fr4 = the_year::text || '-10-01';	
		range_to4 = (the_year+1)::text || '-01-01';	

		query = format	($fmt$
							CREATE TABLE by_range.orders_%s_1
							PARTITION OF by_range.orders
							FOR VALUES FROM ('%s') TO ('%s');
						$fmt$, the_year, range_fr1, range_to1);
		--RAISE NOTICE '%', query;
		EXECUTE query;
	
		query = format	($fmt$
							CREATE TABLE by_range.orders_%s_2
							PARTITION OF by_range.orders
							FOR VALUES FROM ('%s') TO ('%s');
						$fmt$, the_year, range_fr2, range_to2);
		--RAISE NOTICE '%', query;
		EXECUTE query;
	
		query = format	($fmt$
							CREATE TABLE by_range.orders_%s_3
							PARTITION OF by_range.orders
							FOR VALUES FROM ('%s') TO ('%s');
						$fmt$, the_year, range_fr3, range_to3);
		--RAISE NOTICE '%', query;
		EXECUTE query;

		query = format	($fmt$
							CREATE TABLE by_range.orders_%s_4
							PARTITION OF by_range.orders
							FOR VALUES FROM ('%s') TO ('%s');
						$fmt$, the_year, range_fr4, range_to4);
		--RAISE NOTICE '%', query;
		EXECUTE query;

	END LOOP;

	-- by list
	CREATE TABLE by_list.orders
	(
		order_id	bigint GENERATED ALWAYS AS IDENTITY,
		client		varchar(63) NOT NULL,
		order_date	date NOT NULL,
		order_total	numeric(12, 2),
		PRIMARY KEY (order_id, client)		-- !!!
	) PARTITION BY LIST (client);

	/*
	CREATE TABLE by_list.orders_2
	PARTITION OF by_list.orders
	FOR VALUES IN ('Борис Фёдорович');	
	*/

	client_mark = 0;

	FOREACH client_theonly IN ARRAY clients
	LOOP
		query = format	($fmt$
							CREATE TABLE by_list.orders_%s
							PARTITION OF by_list.orders
							FOR VALUES IN ('%s');
						$fmt$, client_mark, client_theonly);
		--RAISE NOTICE '%', query;
		EXECUTE query;
	
		client_mark = client_mark + 1;	
	END LOOP;


	-- by hash
	CREATE TABLE by_hash.orders
	(
		order_id	bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
		client		varchar(63) NOT NULL,
		order_date	date NOT NULL,
		order_total	numeric(12, 2)
	) PARTITION BY HASH (order_id);

	/*
		CREATE TABLE by_hash.orders_0
		PARTITION OF by_hash.orders
		FOR VALUES WITH (MODULUS 16, REMAINDER 0);
	*/

	FOR i IN 0 .. 15
	LOOP
		query = format	($fmt$
							CREATE TABLE by_hash.orders_%s
							PARTITION OF by_hash.orders
							FOR VALUES WITH (MODULUS 16, REMAINDER %s);
						$fmt$, i, i);
		--RAISE NOTICE '%', query;
		EXECUTE query;
	END LOOP;

	WITH src_data
	AS	(
		SELECT	clients[(random()*7)::integer+1] AS cl,
				'2010-01-01'::date + (random() * 365*12)::integer as dt,
				random()*25000 + 10. AS tl
		FROM generate_series (1, 10000000)
		), 
	ins_np
	AS	(
		INSERT INTO no_part.orders (client,  order_date, order_total)
		SELECT cl, dt, tl
		FROM src_data
		),
	ins_br
	AS	(
		INSERT INTO by_range.orders (client,  order_date, order_total)
		SELECT cl, dt, tl
		FROM src_data
		),
	ins_bl
	AS	(
		INSERT INTO by_list.orders (client,  order_date, order_total)
		SELECT cl, dt, tl
		FROM src_data
		)
	INSERT INTO by_hash.orders (client,  order_date, order_total)
	SELECT cl, dt, tl
	FROM src_data;
END;
$main$;





CREATE TABLE by_list.orders_default PARTITION OF by_list.orders DEFAULT;

INSERT INTO by_list.orders (client,  order_date, order_total)
VALUES ('new_client', '2020-10-10', 0.0);
-------------------------------------------------------------------------------




/*
SELECT * FROM no_part.orders ORDER BY order_id;
SELECT * FROM by_list.orders ORDER BY order_id;
SELECT * FROM by_range.orders ORDER BY order_id;
SELECT * FROM by_hash.orders ORDER BY order_id;

SELECT * FROM no_part.orders ORDER BY order_id LIMIT 10;
SELECT * FROM by_list.orders ORDER BY order_id LIMIT 10;
SELECT * FROM by_range.orders ORDER BY order_id LIMIT 10;
SELECT * FROM by_hash.orders ORDER BY order_id LIMIT 10;
*/
/*
SELECT count(*) FROM no_part.orders;
SELECT count(*) FROM by_range.orders;
SELECT count(*) FROM by_list.orders;
SELECT count(*) FROM by_hash.orders;
*/






