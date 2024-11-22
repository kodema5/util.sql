------------------------------------------------------------------------------
-- if true returns first else second
-- @param {boolean} expr of condition
-- @param {anyelement} first element
-- @param {anyelement} second element
-- @return {anyelement} first/second element
--
create function iif(boolean, anyelement, anyelement)
    returns anyelement
    language sql
    set search_path from current
    stable
as $$
    select case
        when $1 then $2
        else $3
        end;
$$;
