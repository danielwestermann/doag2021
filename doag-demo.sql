-- 1. tables, types and arrays
select 'Part 1: tables, types and arrays' as chapter;
\timing on
create type type1 as ( a int
                     , b text
                     , c timestamptz
                     );
\dT
create schema s1;
create schema s2;
create table s1.t1 of type1 ( primary key (a)
                            , b with options default 'a very interesting text'
                            , c with options check ( c > now () )
                            );
create table s2.t1 of type1 ( primary key (a)
                            , b with options default 'a very interesting text'
                            , c with options check ( c > now () )
                            );
\d s1.t1
\d s2.t1
insert into s1.t1 select i, i::text, now() + interval '1 day' 
                    from generate_series(1,1000000) i;
insert into s2.t1 select i, i::text, now() + interval '1 day' 
                    from generate_series(1,1000000) i;
alter type type1 add attribute d jsonb[] cascade;
\d s1.t1
\d s2.t1
create schema s3;
create table s3.t1 ( like s1.t1 including all );
\d s3.t1
update s1.t1 set d = array['{"string": "value"}'::jsonb,'{"string": "value"}'::jsonb];
select * from s1.t1 limit 2;
create table s1.t2 ( a int
                   , b int[]
                   , c text[][]
                   , d type1
                   , e type1[]
                   , f type1[][][][][][]
                   );
drop table s1.t1,s1.t2,s2.t1,s3.t1;
drop schema s1,s2,s3;
drop type type1;

-----------------------------------------------------------------======================================================

-- 2. exlusion constraints and (multi-)ranges
select 'Part 2: Exlusion constraints and (mult-)ranges ' as chapter;
create extension if not exists btree_gist;
create table meeting_rooms ( id int primary key
                           , mname varchar(20)
                           , location varchar(10)
                           );
create table meeting_rooms_booked ( mid int references meeting_rooms(id)
                                  , booking_range tsrange
                                  , exclude using gist (mid with =,booking_range with &&)
                                  );
insert into meeting_rooms ( id, mname, location)
       values ( 1, 'meetingsouth', 'south' )
            , ( 2, 'meetingnorth', 'north' )
            , ( 3, 'meetingwest', 'west' )
            , ( 4, 'meetingeast', 'east' );
insert into meeting_rooms_booked ( mid, booking_range )
       values ( 1, '[2022-01-01 15:00, 2022-01-01 18:30]' )
            , ( 1, '[2022-01-01 08:00, 2022-01-01 08:30]' )
            , ( 2, '[2022-03-01 17:00, 2022-03-01 18:30]' )
            , ( 1, '[2022-03-01 05:00, 2022-03-01 08:30]' )
            , ( 3, '[2022-02-01 15:00, 2022-02-01 18:30]' )
            , ( 4, '[2022-02-01 19:00, 2022-02-01 20:30]' )
            , ( 4, '[2022-03-01 15:00, 2022-03-01 18:30]' );
select * from meeting_rooms_booked where mid = 3;
select booking_range && '[2022-02-01 16:00,2022-02-01 16:30)'::tsrange from meeting_rooms_booked where mid = 3;
select booking_range && '[2022-02-01 18:45,2022-02-01 19:15)'::tsrange from meeting_rooms_booked where mid = 3;
insert into meeting_rooms_booked ( mid, booking_range )
       values ( 1, '[2022-01-01 08:00, 2022-01-01 10:30]' );
drop table meeting_rooms_booked;
drop table meeting_rooms;
drop extension btree_gist;

-----------------------------------------------------------------======================================================

-- 3. full text searching
select 'Part 3: Full text search' as chapter;
create table t_full_text ( sentence text );
insert into t_full_text values ('I am a nobody. Nobody is perfect. Therefore, I am perfect.');
insert into t_full_text values ('I will buy you 11 Roses; 10 real and 1 fake. And I will love you until the last rose dies.');
insert into t_full_text values ('I stepped on a Cornflake, and now I am a cereal killer.');
insert into t_full_text values (E'Isn\'t having a smoking section in a restaurant like having a peeing section in a swimming pool?');
insert into t_full_text values ('What happens if you get scared half to death twice?');
insert into t_full_text values ('Nobody dies a virgin, because life fucks us all.');
insert into t_full_text values ('Future depends on your dreams. So go to sleep.');
insert into t_full_text values (E'You all laugh because I\'m different - I laugh because you\'re all the same.');
insert into t_full_text values ('The more you learn, the more you know, the more you know, and the more you forget. The more you forget, the less you know. So why bother to learn.');
insert into t_full_text values ('You are the light of my life. Before I met you, I walked in the dark.');
insert into t_full_text select 'a simple dummy sentence' from generate_series(1,1000000);
explain select * from t_full_text where sentence like '%What happens if%';
create index i_t_full_text on t_full_text(sentence);
explain select * from t_full_text where sentence like '%What happens if%';
create extension pg_trgm;
\dx
create index i2_t_full_text on t_full_text using gin ( sentence gin_trgm_ops);
explain select * from t_full_text where sentence like '%What happens if%';
select sentence, to_tsvector(sentence) from t_full_text limit 10;
select sentence, to_tsvector('German',sentence) from t_full_text limit 10;
select * from pg_ts_config;
alter table t_full_text add tokens tsvector;
update t_full_text set tokens = to_tsvector(sentence);
select * from t_full_text where tokens @@ to_tsquery('what & happens');
drop table t_full_text;

-----------------------------------------------------------------======================================================


-- 4. Conversions and casting
select 'Part 6: Converting units' as chapter;
create table t_units as select * from generate_series(1,1000000) x;
select relpages as "8kBlocks" from pg_class where relname = 't_units';
select 4425*8 as KB;
select pg_relation_size('t_units');
select pg_relation_size('t_units')/1024;
select pg_size_pretty(pg_relation_size('t_units'));
select pg_database_size('postgres');
select pg_size_pretty(pg_database_size('postgres'));
select pg_size_bytes('1MB');
select pg_size_bytes('1TB');
select pg_size_pretty(pg_size_bytes('1TB'));
select 1::int::boolean::text::boolean::char(5);
drop table t_units;


-----------------------------------------------------------------======================================================


-- 5. partial and brin indexes
select 'Part 4: Partial and BRIN indexes' as chapter;
create table t_partial ( id int, status boolean );
insert into t_partial (id,status) values (1,'true'),(2,'true'),(3,'true'),(4,1::boolean),(5,2::boolean);
insert into t_partial select id, 'true' from generate_series(1,1000000) id;
insert into t_partial select id, 'false' from generate_series(1,100) id;
create index i_partial_1 on t_partial(status) where true;
create index i_partial_2 on t_partial(status) where false;
select pg_size_pretty(pg_relation_size('i_partial_1'));
select pg_size_pretty(pg_relation_size('i_partial_2'));
create index i_brin on t_partial using brin (id) with (pages_per_range=256);
select pg_size_pretty(pg_relation_size('i_brin'));
drop table t_partial;

-----------------------------------------------------------------======================================================

-- 6. reading and writing files
select 'Part 5: Reading and writing files' as chapter;
select pg_ls_dir('/var/tmp');
create table t_dummy as select x as id, md5(x::text) as dummy from generate_series(1,1000000) x;
select * from t_dummy limit 5;
copy t_dummy to '/var/tmp/t_dummy';
 \! head -10 /var/tmp/t_dummy
create table t_dummy2 ( like t_dummy );
copy t_dummy2 from '/var/tmp/t_dummy';
select * from t_dummy2 limit 5;
select pg_read_file('/var/tmp/t_dummy');
create table t_dummy3 as select pg_read_file('/var/tmp/t_dummy');
select * from t_dummy3 limit 5;
select pg_stat_file('/var/tmp/t_dummy');
\set my_content `cat /var/tmp/t_dummy`
select :'my_content';
create table lottery ( draw_date date, winning_numbers text, mega_ball integer, multiplier integer );
copy lottery from program 'curl https://data.ny.gov/api/views/5xaw-6ayf/rows.csv?accessType=DOWNLOAD' with (header true, delimiter ',', format csv);
select * from lottery limit 5;
drop table lottery,t_dummy3,t_dummy2,t_dummy;



-----------------------------------------------------------------======================================================

-- 7. changing data types of columns
select 'Part 7: Changing data types of columns' as chapter;

create table t1 ( a int, b int );
insert into t1 select x, 20211117 from generate_series(1,1000000) x;
alter table t1 alter b type date using to_date(b::text,'YYYYMMDD');
\d t1
create type mytype as ( a int, b date );
create or replace function to_my_type ( source_date in date ) returns mytype
as
$$
  select (1,source_date)::mytype;
$$ language sql;
alter table t1 alter column b type mytype using to_my_type(b);
\d t1
drop table t1;
drop type mytype cascade;

-----------------------------------------------------------------======================================================

-- 8. on the fly sorting by collation
select 'Part 8: On-the-fly sorting with different collations' as chapter;

create table numbers ( lang text, number text );
insert into numbers values ('swedish','noll')
                         , ('swedish','ett/en')
                         , ('swedish','två')
                         , ('swedish','tre')
                         , ('swedish','fyra')
                         , ('swedish','fem')
                         , ('swedish','sex')
                         , ('swedish','sju')
                         , ('swedish','åtta')
                         , ('swedish','nio')
                         , ('swedish','tio');
insert into numbers values ('german','eins')
                         , ('german','zwei')
                         , ('german','drei')
                         , ('german','vier')
                         , ('german','fünf')
                         , ('german','sechs')
                         , ('german','sieben')
                         , ('german','acht')
                         , ('german','neun')
                         , ('german','zehn');
insert into numbers values ('arabic','وَاحِد')
                         , ('arabic','اِثْنَان')
                         , ('arabic','ثَلَاثَة')
                         , ('arabic','أَرْبَعَة')
                         , ('arabic','خَمْسَة')
                         , ('arabic','سِتَّة')
                         , ('arabic','سَبْعَة')
                         , ('arabic','ثَمَانِيَة')
                         , ('arabic','تِسْعَة')
                         , ('arabic','عَشَرَة');
select * from numbers;
select * from numbers order by 2;
select * from numbers order by number  collate "en_US";
select * from numbers order by number  collate "C";
select * from numbers order by number  collate "de_DE";
\q
sudo vi /etc/locale.gen
sudo locale-gen
sudo systemctl restart postgresql-PG1.service
psql
select pg_import_system_collations('pg_catalog');
select * from numbers order by number  collate "de-CH";
drop table numbers;


-----------------------------------------------------------------======================================================


-- 9. template databases
select 'Part 9: Template databases' as chapter;
-- this needs two sessions
-- session 1 
\c template1
drop database postgres;
create database postgres;
create database postgres1 with template = template1;
drop database postgres;
drop database postgres1;
alter database template1 is_template false;
\c template0
alter database template0 allow_connections = true;
\c template0
drop database template1;
\l
create database template1;
create database template1 with template = template0;
alter database template1 is_template = true;
\c template1
alter database template0 allow_connections = false;
create database postgres;
\l
\c postgres postgres
create table t1 as select x as id, now() as datum from generate_series(1,1000000) x;
create database my_new_db with template = postgres;
 \c my_new_db
select count(*) from t1;
alter database my_new_db is_template = true;
alter database my_new_db allow_connections = false;
 \c postgres
alter database my_new_db allow_connections = false;
drop table t1;
rop database my_new_db;
alter database my_new_db is_template = false;
drop database my_new_db;
\l


-----------------------------------------------------------------======================================================


-- 10. default privleges 
select 'Part 10: Default privileges' as chapter;
-- this needs two sessions
-- session 1
create user u with password 'u' login;
create user v with password 'v' login;
grant all on database postgres to u;
\c postgres u
create schema a;
create table a.t1 ( a int );
-- session 2
\c postgres v
select count(*) from a.t1;
-- session 1
grant usage on schema a to v;
-- session 2
select count(*) from a.t1;
-- session 1
grant select on a.t1 to v;
-- session 2
select count(*) from a.t1;
-- session 1
alter default privileges in schema a grant select on tables to v;
create table a.t2 ( a int );
select count(*) from a.t2;
-- session 1 and 2
 \c postgres postgres
-- session 1
drop schema a cascade;
drop user v;
revoke all on database postgres from u;
drop user u;


-----------------------------------------------------------------======================================================


-- 11. Listen and notify
select 'Part 11: Listen and notify' as chapter;
-- this needs two sessions
-- session 1
listen doag2021;
-- session 2
notify doag2021, 'this is an asynchronous message';
notify doag2021, 'this is an asynchronous message AND THE END OF THIS TALK';
-- session 1
listen doag2021;
