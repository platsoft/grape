CREATE OR REPLACE VIEW grape.v_pg_table_stats AS
	SELECT 
		oid,
		table_schema,
		table_name,
		row_estimate,
		pg_size_pretty(total_bytes) AS total_size,
		pg_size_pretty(index_bytes) AS index_size,
		pg_size_pretty(toast_bytes) AS toast_size,
		pg_size_pretty(table_bytes) AS table_size,
		pg_stat_get_last_vacuum_time(oid) AS last_vacuum,
		pg_stat_get_last_autovacuum_time(oid) AS last_autovacuum,
		pg_stat_get_last_analyze_time(oid) AS last_analyze,
		pg_stat_get_last_autoanalyze_time(oid) AS last_autoanalyze,
		pg_stat_get_vacuum_count(oid) AS vacuum_count,
		pg_stat_get_autovacuum_count(oid) AS autovacuum_count,
		pg_stat_get_analyze_count(oid) AS analyze_count,
		pg_stat_get_autoanalyze_count(oid) AS autoanalyze_count

		FROM (
			SELECT oid,
				table_schema,
				table_name,
				row_estimate,
				total_bytes,
				index_bytes,
				toast_bytes,
				total_bytes-index_bytes-COALESCE(toast_bytes,0) AS table_bytes 
			FROM (
				SELECT 
					c.oid,
					nspname AS table_schema,
					relname AS TABLE_NAME, 
					c.reltuples AS row_estimate,
					pg_total_relation_size(c.oid) AS total_bytes,
					pg_indexes_size(c.oid) AS index_bytes, 
					pg_total_relation_size(reltoastrelid) AS toast_bytes
				FROM pg_class c
				LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
				WHERE relkind = 'r'
				) a
		) a
	WHERE
		(table_schema <> ALL (ARRAY['pg_catalog'::name, 'information_schema'::name])) 
		AND table_schema !~ '^pg_toast'::text;
