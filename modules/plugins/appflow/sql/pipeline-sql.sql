-- HTTP POST
-- One read-only query, answered as an array of row objects. `q` is the whole
-- statement: `task apps:query` posts it here first, and falls back to psql or
-- ssh only on a deployment that predates this route. The statement is checked
-- in `appflow_pipeline_sql` (schema.sql) before it runs.
select * from appflow_pipeline_sql(:q);
