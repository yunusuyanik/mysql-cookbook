--mysql cookbook

###### performance schema ######

# waits
select thread_id, event_name, sum(number_of_bytes/1024) sum_kb 
from performance_schema.events_waits_history 
where number_of_bytes > 0 
group by thread_id, event_name 
order by sum_kb desc;

# slow queries in history - missing index - no index used - queries by table scan 
select THREAD_ID TID, SUBSTR(SQL_TEXT, 1, 50) SQL_TEXT, ROWS_SENT RS,ROWS_EXAMINED RE,CREATED_TMP_TABLES,NO_INDEX_USED,NO_GOOD_INDEX_USED 
from performance_schema.events_statements_history 
where NO_INDEX_USED=1 or NO_GOOD_INDEX_USED=1\G 




###### information schema - tables and columns ######

# foreing keys
select 
	concat('ALTER TABLE ', TABLE_NAME, ' DROP FOREIGN KEY ', CONSTRAINT_NAME, ';') 
from information_schema.key_column_usage 
where CONSTRAINT_SCHEMA = 'db_name' and referenced_table_name IS NOT NULL;

# table rows
select TABLE_NAME,TABLE_ROWS from information_schema.tables where TABLE_NAME IN ("discounts");

# track alter table events [current and history] -- https://dev.mysql.com/doc/refman/5.7/en/monitor-alter-table-performance-schema.html

select EVENT_NAME, WORK_COMPLETED, WORK_ESTIMATED, WORK_ESTIMATED-WORK_COMPLETED from performance_schema.events_stages_current;
select * from performance_schema.events_stages_history;




###### information schema - sessions, thread, client, lock throubleshoot ######

# transaction running
select * from information_schema.INNODB_TRX;

select trx_id,trx_state,trx_mysql_thread_id,trx_isolation_level,LEFT(trx_query,100) from information_schema.INNODB_TRX;



# locks
select * from information_schema.innodb_locks;
select * from performance_schema.data_lock;


SELECT r.trx_wait_started AS wait_started,
       TIMEDIFF(NOW(), r.trx_wait_started) AS wait_age,
       TIMESTAMPDIFF(SECOND, r.trx_wait_started, NOW()) AS wait_age_secs,
       rl.lock_table AS locked_table,
       rl.lock_index AS locked_index,
       rl.lock_type AS locked_type,
       r.trx_id AS waiting_trx_id,
       r.trx_started as waiting_trx_started,
       TIMEDIFF(NOW(), r.trx_started) AS waiting_trx_age,
       r.trx_rows_locked AS waiting_trx_rows_locked,
       r.trx_rows_modified AS waiting_trx_rows_modified,
       r.trx_mysql_thread_id AS waiting_pid,
       r.trx_query AS waiting_query,
       rl.lock_id AS waiting_lock_id,
       rl.lock_mode AS waiting_lock_mode,
       b.trx_id AS blocking_trx_id,
       b.trx_mysql_thread_id AS blocking_pid,
       b.trx_query AS blocking_query,
       bl.lock_id AS blocking_lock_id,
       bl.lock_mode AS blocking_lock_mode,
       b.trx_started AS blocking_trx_started,
       TIMEDIFF(NOW(), b.trx_started) AS blocking_trx_age,
       b.trx_rows_locked AS blocking_trx_rows_locked,
       b.trx_rows_modified AS blocking_trx_rows_modified,
       CONCAT("KILL QUERY ", b.trx_mysql_thread_id) AS sql_kill_blocking_query,
       CONCAT("KILL ", b.trx_mysql_thread_id) AS sql_kill_blocking_connection
  FROM information_schema.innodb_lock_waits w
       INNER JOIN information_schema.innodb_trx b    ON b.trx_id = w.blocking_trx_id
       INNER JOIN information_schema.innodb_trx r    ON r.trx_id = w.requesting_trx_id
       INNER JOIN information_schema.innodb_locks bl ON bl.lock_id = w.blocking_lock_id
       INNER JOIN information_schema.innodb_locks rl ON rl.lock_id = w.requested_lock_id
 ORDER BY r.trx_wait_started\G



# lock throubleshoot
select * from performance_schema.threads where PROCESSLIST_ID = blocking_thread;
select THREAD_ID, SQL_TEXT from performance_schema.events_statements_current where THREAD_ID = thread_id;
select trx_id,trx_state,trx_mysql_thread_id,trx_isolation_level,LEFT(trx_query,100) from information_schema.INNODB_TRX where trx_id =thread_id;



# lock waits
	# For MySQL 5.7 or earlier
	select * from information_schema.innodb_lock_waits; 

	# For MySQL 8.0
	select * from performance_schema.data_lock_waits;

	

# blocking related info
	# For MySQL 5.7 or earlier
	select
	  r.trx_id waiting_trx_id, r.trx_mysql_thread_id waiting_thread, r.trx_query waiting_query, b.trx_id blocking_trx_id, b.trx_mysql_thread_id blocking_thread, b.trx_query blocking_query
	from information_schema.innodb_lock_waits w
		join information_schema.innodb_trx b on b.trx_id = w.blocking_trx_id
		join information_schema.innodb_trx r on r.trx_id = w.requesting_trx_id;


	# For MySQL 8.0
	select
	  r.trx_id waiting_trx_id, r.trx_mysql_thread_id waiting_thread, r.trx_query waiting_query, b.trx_id blocking_trx_id, b.trx_mysql_thread_id blocking_thread, b.trx_query blocking_query
	from performance_schema.data_lock_waits w
		join information_schema.innodb_trx b on b.trx_id = w.blocking_engine_transaction_id
		join information_schema.innodb_trx r on r.trx_id = w.requesting_engine_transaction_id;



# current proccess check
select * from information_schema.processlist where Command!="Sleep";
	--for percona edition
select ID,USER,HOST,DB,COMMAND,STATE,LEFT(INFO,70),TIME,TIME_MS from information_schema.processlist where Command!="Sleep" order by TIME ASC;



# metadata locks
select processlist_id, object_type, lock_type, lock_status, source 
from metadata_locks 
	join threads on owner_thread_id=thread_id)
where object_schema=’sbtest’ and object_name=’sbtest1’; 



# events waits
select event_name, count(*) as c 
from performance_schema.events_waits_history_long 
where thread_id=42 
group by EVENT_NAME 
order by c desc;

select thread_id, event_name, sql_text from events_statements_history where event_name like ’statement/sp%’;
-- statement analysis • statements with full table scans • statements with runtimes in 95th percentile • statements with sorting • statements with temp tables • statements with errors or warnings • memory by thread by current bytes





## open source tools

#health check with perl
perl mysqltuner.pl --host hostname --user username --pass "password" --forcemem 5000 


##percona tools 

#online schema change
pt-online-schema-change --execute --alter="ADD COLUMN columnname VARCHAR(50)" D=databasename,t=taablename --check-replication-filters --user=username --ask-pass

