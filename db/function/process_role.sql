
CREATE OR REPLACE FUNCTION grape.process_role_update(_process_id INTEGER, _role_name TEXT, _view BOOLEAN, _execute BOOLEAN, _edit BOOLEAN) RETURNS INTEGER AS $$
DECLARE
	_process_role_id INTEGER;
BEGIN
	-- Check that current user can edit
	DELETE FROM grape.process_role WHERE process_id=_process_id::INTEGER AND role_name=_role_name::TEXT;

	INSERT INTO grape.process_role (process_id, role_name, can_view, can_execute, can_edit)
		VALUES (_process_id, _role_name, _view, _execute, _edit) 
		RETURNING process_role_id INTO _process_role_id;
	
	RETURN _process_role_id;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grape.process_role_update(_process_name TEXT, _role_name TEXT, _view BOOLEAN, _execute BOOLEAN, _edit BOOLEAN) RETURNS INTEGER AS $$
DECLARE
	_process_role_id INTEGER;
BEGIN
	RETURN grape.process_role_update(grape.process_id_by_name(_process_name), _role_name, _view, _execute, _edit);
END; $$ LANGUAGE plpgsql;

/** 
 * Checks if the current user has access to view a process
 */
CREATE OR REPLACE FUNCTION grape.check_process_view_permission(_process_id INTEGER) RETURNS BOOLEAN AS $$
DECLARE
	_process_role_id INTEGER;
BEGIN
	SELECT process_role_id INTO _process_role_id 
		FROM grape.process_role 
		WHERE 
			role_name IN (SELECT * FROM grape.current_user_roles()) 
			AND process_id=_process_id::INTEGER 
			AND can_view=TRUE;
	IF FOUND THEN
		RETURN TRUE;
	END IF;
	
	RETURN FALSE;
END; $$ LANGUAGE plpgsql;

