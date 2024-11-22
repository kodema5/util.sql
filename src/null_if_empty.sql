-- returns null if empty jsonb
-- @param {jsonb} value
-- @return {jsonb} null if empty
--
create function null_if_empty(jsonb)
    returns jsonb
    language sql
    set search_path from current
    immutable
as $$
    select case
    when is_empty($1) then null
    else $1
    end
$$;

-- returns null if empty json
-- @param {json} value
-- @return {json} null if empty
--
create function null_if_empty(json)
    returns json
    language sql
    set search_path from current
    immutable
as $$
    select case
    when is_empty($1) then null
    else $1
    end
$$;
