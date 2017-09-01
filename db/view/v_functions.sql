
CREATE OR REPLACE VIEW grape.v_pg_functions AS 
	SELECT 
		r.routine_schema, 
		r.routine_name, 
		array_agg((p.udt_name)::TEXT ORDER BY ordinal_position) AS parameters
		FROM information_schema.routines r 
			JOIN information_schema.parameters p ON 
				r.specific_schema=p.specific_schema 
				AND r.specific_name=p.specific_name 
			WHERE r.routine_schema != 'pg_catalog' 
			GROUP BY 
				r.routine_schema, 
				r.routine_name
			ORDER BY 
				r.routine_schema,
				r.routine_name;

