
INSERT INTO grape.notification_function (description, function_name, function_schema, active)
	VALUES ('Maintenance Mode', 'notify_maintenance_mode', 'public', true);

CREATE OR REPLACE FUNCTION public.notify_maintenance_mode() RETURNS JSONB AS $$
	SELECT jsonb_build_object('maintenance_mode', true);
$$ LANGUAGE sql;

