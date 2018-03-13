
CREATE OR REPLACE VIEW grape.v_pg_functions AS 
	SELECT 
		r.routine_schema, 
		r.routine_name, 
		array_remove(array_agg((p.udt_name)::TEXT ORDER BY ordinal_position), NULL) AS parameters,
		r.type_udt_name AS return_type

		FROM information_schema.routines r 
			LEFT JOIN information_schema.parameters p ON 
				r.specific_schema=p.specific_schema 
				AND r.specific_name=p.specific_name 
			WHERE r.routine_schema != 'pg_catalog' 
			GROUP BY 
				r.routine_schema, 
				r.routine_name,
				r.type_udt_name
			ORDER BY 
				r.routine_schema,
				r.routine_name;

