-- Run as ADMIN.
-- &1 = TODO_APP schema password (reused as the workspace admin password)
-- &2 = notification email
--
-- On Autonomous Database the ADMIN database user is the APEX instance
-- administrator, so this call is allowed. If your database rejects it with
-- ORA-20001 or an insufficient-privilege error, create the same workspace in
-- APEX Administration Services (<APEX URL>/apex_admin) with:
--   workspace TODO_WORKSPACE / schema TODO_APP / admin TODO_ADMIN
SET DEFINE ON
WHENEVER SQLERROR EXIT FAILURE

DECLARE
  l_workspace_id NUMBER;
BEGIN
  SELECT workspace_id INTO l_workspace_id
    FROM apex_workspaces
   WHERE workspace = 'TODO_WORKSPACE';
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    apex_instance_admin.create_workspace(
      p_workspace          => 'TODO_WORKSPACE',
      p_primary_schema     => 'TODO_APP',
      p_workspace_username => 'TODO_ADMIN',
      p_workspace_password => '&1',
      p_email              => '&2'
    );
END;
/

EXIT
