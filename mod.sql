--
-- PostgreSQL database dump
--

-- Dumped from database version 16.3 (Debian 16.3-1.pgdg120+1)
-- Dumped by pg_dump version 16.0

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: util; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA util;


--
-- Name: util_; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA util_;


--
-- Name: console_log_context_t; Type: TYPE; Schema: util; Owner: -
--

CREATE TYPE util.console_log_context_t AS (
	context_offset integer,
	length integer,
	root text,
	current text
);


--
-- Name: console_log_it; Type: TYPE; Schema: util; Owner: -
--

CREATE TYPE util.console_log_it AS (
	current text,
	format regproc,
	context_offset integer,
	is_table_log boolean,
	is_console_log boolean,
	channel_log text
);


--
-- Name: clean(json, boolean); Type: FUNCTION; Schema: util; Owner: -
--

CREATE FUNCTION util.clean(json, deep_ boolean DEFAULT false) RETURNS json
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'util', 'util_', 'public'
    AS $_$
    select case
    when json_typeof($1)='object'
        then (
            select null_if_empty(
                json_object_agg(key, value)
            )
            from json_each($1)
            where not is_empty(
                case
                when deep_ then clean(value, deep_)
                else value
                end
            ))

    when json_typeof($1)='array'
        then (
            select null_if_empty(
                json_agg(value)
            )
            from json_array_elements($1)
            where not is_empty(
                case
                when deep_ then clean(value, deep_)
                else value
                end
            ))

    else null_if_empty($1)
    end
$_$;


--
-- Name: clean(jsonb, boolean); Type: FUNCTION; Schema: util; Owner: -
--

CREATE FUNCTION util.clean(jsonb, deep_ boolean DEFAULT false) RETURNS jsonb
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'util', 'util_', 'public'
    AS $_$
    select case
    when jsonb_typeof($1)='object'
        then (
            select null_if_empty(
                jsonb_object_agg(key, value)
            )
            from jsonb_each($1)
            where not is_empty(
                case
                when deep_ then clean(value, deep_)
                else value
                end
            ))

    when jsonb_typeof($1)='array'
        then (
            select null_if_empty(
                jsonb_agg(value)
            )
            from jsonb_array_elements($1)
            where not is_empty(
                case
                when deep_ then clean(value, deep_)
                else value
                end
            ))

    else null_if_empty($1)
    end
$_$;


--
-- Name: console_log(anyelement, text); Type: FUNCTION; Schema: util; Owner: -
--

CREATE FUNCTION util.console_log(val anyelement, curr text) RETURNS anyelement
    LANGUAGE sql
    SET search_path TO 'util', 'util_', 'public'
    AS $$
    select case
    when setting('console_log.enabled')::boolean
        then console_log_( val, console_log_it(current := curr))
    else
        val
    end;
$$;


--
-- Name: console_log(anyelement, util.console_log_it); Type: FUNCTION; Schema: util; Owner: -
--

CREATE FUNCTION util.console_log(val anyelement, it util.console_log_it DEFAULT NULL::util.console_log_it) RETURNS anyelement
    LANGUAGE sql
    SET search_path TO 'util', 'util_', 'public'
    AS $$
    select case
    when setting('console_log.enabled')::boolean
        then console_log_( val, coalesce(it, console_log_it()))
    else
        val
    end;
$$;


--
-- Name: console_log_it(text, regproc, integer, boolean, boolean, text); Type: FUNCTION; Schema: util; Owner: -
--

CREATE FUNCTION util.console_log_it(current text DEFAULT NULL::text, format regproc DEFAULT NULL::regproc, context_offset integer DEFAULT NULL::integer, is_table_log boolean DEFAULT NULL::boolean, is_console_log boolean DEFAULT NULL::boolean, channel_log text DEFAULT NULL::text) RETURNS util.console_log_it
    LANGUAGE sql STABLE
    SET search_path TO 'util', 'util_', 'public'
    AS $$
    select (
        current,
        format,
        coalesce(
            context_offset,
            setting('console_log.context_offset')::int,
            5),
        coalesce(
            is_table_log,
            setting('console_log.is_table_log')::boolean,
            false),
        coalesce(
            is_console_log,
            setting('console_log.is_console_log')::boolean,
            true),
        coalesce(
            channel_log,
            setting('console_log.channel_log'))
    )::console_log_it
$$;


--
-- Name: console_log_(anyelement, util.console_log_it); Type: FUNCTION; Schema: util; Owner: -
--

CREATE FUNCTION util.console_log_(val anyelement, it util.console_log_it DEFAULT util.console_log_it()) RETURNS anyelement
    LANGUAGE plpgsql
    SET search_path TO 'util', 'util_', 'public'
    AS $$
declare
    ctx_ console_log_context_t = console_log_context_t(it.context_offset);
    root_id_ text;
    js_ jsonb;
begin

    -- check if root has changed or null root_id
    --
    root_id_ = setting('console_log.root_id');

    if ctx_.root <> setting('console_log.root')
    or root_id_ is null
    then
        root_id_ = gen_random_uuid()::text;
        perform setting('console_log.root', ctx_.root);
        perform setting('console_log.root_id', root_id_);
    end if;

    -- optional fmt_ formats/traps  data
    --
    if it.format is not null
    then
        execute format('select %s (%L) ',
            fmt_::text,
            val)
            into js_;
    else
        js_ = to_jsonb(val);
    end if;

    -- if store to table
    --
    if it.is_table_log
    then
        insert into console_log (
            root_id,
            root,
            current,
            type,
            data
        ) values (
            root_id_,
            ctx_.root,
            coalesce(it.current, ctx_.current),
            pg_typeof(val),
            js_
        );
    end if;

    -- if warn to console
    --
    if it.is_console_log
    then
        raise warning 'console_log> % [%] %',
            coalesce(it.current, ctx_.current, '-'),
            pg_typeof(val),
            jsonb_pretty(js_);
    end if;


    -- if publish to a channel
    --
    if it.channel_log is not null
    then
        perform pg_notify(
            it.channel_log,
            (jsonb_build_object(
                'root', ctx_.root,
                'root_id', root_id_,
                'current', coalesce(it.current, ctx_.current),
                'type', pg_typeof(val),
                'data', js_
            ))::text
        );
    end if;

    return val;
end;
$$;


--
-- Name: console_log_context_t(integer, integer); Type: FUNCTION; Schema: util; Owner: -
--

CREATE FUNCTION util.console_log_context_t(integer DEFAULT 4, integer DEFAULT 0) RETURNS util.console_log_context_t
    LANGUAGE plpgsql STABLE
    SET search_path TO 'util', 'util_', 'public'
    AS $_$
declare
    ctx_ console_log_context_t;
    s_ text;
    arr_ text[];
begin
    get diagnostics s_ = pg_context;
    arr_ = regexp_split_to_array ( s_, E'\n');

    ctx_.context_offset = $1;
    ctx_.length = array_length(arr_, 1);

    -- get root signature.
    -- use 'function (.*?)\('  for function name only
    ctx_.root = substring(
        arr_[ctx_.length - $2]
        from 'function (.*) (line|statement)');

    -- get current function location
    ctx_.current = substring(
        arr_[ctx_.context_offset]
        from 'function (.*?) at');

    return ctx_;
end;
$_$;


--
-- Name: iif(boolean, anyelement, anyelement); Type: FUNCTION; Schema: util; Owner: -
--

CREATE FUNCTION util.iif(boolean, anyelement, anyelement) RETURNS anyelement
    LANGUAGE sql STABLE
    SET search_path TO 'util', 'util_', 'public'
    AS $_$
    select case
        when $1 then $2
        else $3
        end;
$_$;


--
-- Name: is_empty(json); Type: FUNCTION; Schema: util; Owner: -
--

CREATE FUNCTION util.is_empty(json) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'util', 'util_', 'public'
    AS $_$
    select case
    when $1 is null then true
    when json_typeof($1)='null' then true
    when json_typeof($1)='string' then $1::text = '""'
    when json_typeof($1)='array' then json_array_length($1)=0
    when json_typeof($1)='object' then (select count(1)=0 from json_object_keys($1))
    else false
    end;
$_$;


--
-- Name: is_empty(jsonb); Type: FUNCTION; Schema: util; Owner: -
--

CREATE FUNCTION util.is_empty(jsonb) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'util', 'util_', 'public'
    AS $_$
    select case
    when $1 is null then true
    when jsonb_typeof($1)='null' then true
    when jsonb_typeof($1)='string' then $1::text = '""'
    when jsonb_typeof($1)='array' then jsonb_array_length($1)=0
    when jsonb_typeof($1)='object' then (select count(1)=0 from jsonb_object_keys($1))
    else false
    end;
$_$;


--
-- Name: null_if_empty(json); Type: FUNCTION; Schema: util; Owner: -
--

CREATE FUNCTION util.null_if_empty(json) RETURNS json
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'util', 'util_', 'public'
    AS $_$
    select case
    when is_empty($1) then null
    else $1
    end
$_$;


--
-- Name: null_if_empty(jsonb); Type: FUNCTION; Schema: util; Owner: -
--

CREATE FUNCTION util.null_if_empty(jsonb) RETURNS jsonb
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'util', 'util_', 'public'
    AS $_$
    select case
    when is_empty($1) then null
    else $1
    end
$_$;


--
-- Name: setting(text); Type: FUNCTION; Schema: util; Owner: -
--

CREATE FUNCTION util.setting(text) RETURNS text
    LANGUAGE sql STABLE
    SET search_path TO 'util', 'util_', 'public'
    AS $_$
    select current_setting($1, true)
$_$;


--
-- Name: setting(text, text); Type: FUNCTION; Schema: util; Owner: -
--

CREATE FUNCTION util.setting(text, text) RETURNS text
    LANGUAGE sql STABLE
    SET search_path TO 'util', 'util_', 'public'
    AS $_$
    select set_config($1, $2, false)
$_$;


--
-- Name: to_camel(text); Type: FUNCTION; Schema: util; Owner: -
--

CREATE FUNCTION util.to_camel(text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    SET search_path TO 'util', 'util_', 'public'
    AS $_$
    select lower(left(a,1)) || right(a, -1)
    from to_pascal($1) a;
$_$;


--
-- Name: to_pascal(text); Type: FUNCTION; Schema: util; Owner: -
--

CREATE FUNCTION util.to_pascal(text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    SET search_path TO 'util', 'util_', 'public'
    AS $_$
    select replace(initcap(replace($1, '_', ' ')), ' ', '');
$_$;


--
-- Name: to_snake(text); Type: FUNCTION; Schema: util; Owner: -
--

CREATE FUNCTION util.to_snake(text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    SET search_path TO 'util', 'util_', 'public'
    AS $_$
    select lower(trim(
        both '_' from regexp_replace($1, '([A-Z])','_\1','g')
    ))
$_$;


--
-- Name: to_ts(timestamp with time zone); Type: FUNCTION; Schema: util; Owner: -
--

CREATE FUNCTION util.to_ts(tz timestamp with time zone) RETURNS numeric
    LANGUAGE sql STABLE
    SET search_path TO 'util', 'util_', 'public'
    AS $$
    select extract(epoch from tz)
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: console_log; Type: TABLE; Schema: util_; Owner: -
--

CREATE TABLE util_.console_log (
    log_id integer NOT NULL,
    log_tz timestamp with time zone DEFAULT clock_timestamp(),
    root text,
    root_id text,
    current text,
    type text,
    data jsonb
);


--
-- Name: console_log_log_id_seq; Type: SEQUENCE; Schema: util_; Owner: -
--

CREATE SEQUENCE util_.console_log_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: console_log_log_id_seq; Type: SEQUENCE OWNED BY; Schema: util_; Owner: -
--

ALTER SEQUENCE util_.console_log_log_id_seq OWNED BY util_.console_log.log_id;


--
-- Name: console_log log_id; Type: DEFAULT; Schema: util_; Owner: -
--

ALTER TABLE ONLY util_.console_log ALTER COLUMN log_id SET DEFAULT nextval('util_.console_log_log_id_seq'::regclass);


--
-- PostgreSQL database dump complete
--

