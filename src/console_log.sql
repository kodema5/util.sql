-- how to debug a value without changing/adding structure?
--

-- parses pg_context to find location and caller
--
-- it is usually shown when an exception as below:
-- # Subtest: tests.test_web_register()
--      # Test died: 42703: column "web" does not exist                                                                  +
--      #         CONTEXT:                                                                                               +
--      #             PL/pgSQL function web_t(jsonb) line 6 at RETURN                                                    +
--      #             PL/pgSQL function web_register(jsonb) line 3 during statement block local variable initialization  +
--      #             PL/pgSQL function tests.test_web_register() line 5 at assignment                                   +
--      #             PL/pgSQL function _runner(text[],text[],text[],text[],text[]) line 62 at FOR over EXECUTE statement+
--      #             SQL function "runtests" statement 1


-- @typedef console_log_context_t
-- @property {int} offset of current function
-- @property {int} length of pg_context
-- @property {text} root caller for function
-- @property {text} current caller function
--
create type console_log_context_t as (
    context_offset int,
    length int,
    root text,
    current text
);

-- generates context from pg_context
-- @param {int} offset of current function, use 2x of each level, default 4
-- @param {int} offset of root function, usually last line, default 0
-- @return {console_log_context_t}
--
create function console_log_context_t (
    int default 4,
    int default 0
)
    returns console_log_context_t
    language plpgsql
    set search_path from current
    stable
as $$
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
$$;

-- set env setting
-- @param {text} name of setting
-- @param {text} value of setting
-- @returns {text}
--
create function setting(text, text)
    returns text
    language sql
    set search_path from current
    stable
as $$
    select set_config($1, $2, false)
$$;

-- get env setting
-- @param {text} name of setting
-- @returns {text} value of setting
--
create function setting(text)
    returns text
    language sql
    set search_path from current
    stable
as $$
    select current_setting($1, true)
$$;


-- @typedef console_log_it
-- @property {text} a text tag for current location
-- @property {regproc} formatter of message
-- @property {int} offset for funcition in pg_context
-- @property {boolean} is_table_log if to store to console_log table
-- @property {boolean} is_console_log if to print to console
-- @property {text} channel_log if to notify to channel
--
create type console_log_it as (
    current text,
    format regproc,
    context_offset int,
    is_table_log boolean,
    is_console_log boolean,
    channel_log text
);


-- creates inspec input type
-- @param {text} a text tag for current location
-- @param {regproc} formatter of message
-- @param {int} offset for funcition in pg_context
-- @param {boolean} is_table_log if to store to console_log table (default false)
-- @param {boolean} is_console_log if to print to console (default true)
-- @param {text} channel_log if to notify to channel (default null)
-- @return {console_log_it}
--
create function console_log_it(
    current text default null,
    format regproc default null,
    context_offset int default null,
    is_table_log boolean default null,
    is_console_log boolean default null,
    channel_log text default null
)
    returns console_log_it
    language sql
    set search_path from current
    stable
as $$
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

-- console_log any data and information of its location
-- @param {anyelement} data to be emited
-- @param {console_log_it} configuration
-- @return {anyelement} returns data back
--
create function console_log_ (
    val anyelement,
    it console_log_it default console_log_it()
)
    returns anyelement
    language plpgsql
    set search_path from current
as $$
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


-- checks console_log.enabled env variable
-- @param {anyelement} value to be emited
-- @param {console_log_it} configuration
-- @return {anayelement} value
--
create function console_log (
    val anyelement,
    it console_log_it default null
)
    returns anyelement
    language sql
    set search_path from current
as $$
    select case
    when setting('console_log.enabled')::boolean
        then console_log_( val, coalesce(it, console_log_it()))
    else
        val
    end;
$$;

create function console_log (
    val anyelement,
    curr text
)
    returns anyelement
    language sql
    set search_path from current
as $$
    select case
    when setting('console_log.enabled')::boolean
        then console_log_( val, console_log_it(current := curr))
    else
        val
    end;
$$;


\if :{?test}
\if :test

    create function tests.test_util_console_log()
        returns setof text
        language plpgsql
        set search_path from current
    as $$
    begin
        perform setting('console_log.enabled', 'true');
        perform setting('console_log.is_table_log', 'true');
        perform console_log(json_object('a':123));
        return next ok(
            (
                select count(1)>0
                from console_log u
                where current like '%test_util_console_log()%')
            , 'able to log to table');
    end;
    $$;
\endif
\endif