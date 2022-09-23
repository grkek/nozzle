module Nozzle
  class Application
    Log = ::Log.for(self)

    @db : DB::Database?

    def initialize(@url : String, @handlers : Array(Handlers::Base))
      register_triggers()
      @listener = Listener.new(@url, Constants::CHANNEL)
    end

    def run
      dispatch(:start)
      @listener.on_action(->on_action(Events::Action))
      @listener.start ->{ dispatch(:connect) }
    end

    def close : Nil
      @listener.stop ->{ dispatch(:close) }
    ensure
      @db.try &.close
    end

    private def register_triggers
      return if is_registered?

      conn = DB.open(@url)

      conn.exec(change_data_capture)
      conn.exec(trigger)
      conn.exec("select public.create_cdc_for_all_tables()")
    rescue exception
      Log.error(exception: exception) { "Failed to register the triggers." }
    ensure
      conn.try &.close
    end

    private def is_registered?
      conn = DB.open(@url)
      conn.exec("select 'create_cdc_for_all_tables'::regproc;")
      conn.try &.close

      true
    rescue
      false
    end

    private def change_data_capture
      <<-SQL
      CREATE OR REPLACE FUNCTION public.notify_change() RETURNS TRIGGER AS $$

      DECLARE
          data record;
          notification json;
      BEGIN
          -- Convert the old or new row to JSON, based on the kind of action.
          -- Action = DELETE?             -> OLD row
          -- Action = INSERT or UPDATE?   -> NEW row
          IF (TG_OP = 'DELETE') THEN
              data =  OLD;
          ELSE
              data =  NEW;
          END IF;

        -- Construct json payload
        -- note that here can be done projection
          notification = json_build_object(
                              'timestamp',CURRENT_TIMESTAMP,
                              'schema',TG_TABLE_SCHEMA,
                              'table',TG_TABLE_NAME,
                              'action', LOWER(TG_OP),
                              'id', data.id);

          -- note that channel name MUST be lowercase, otherwise pg_notify() won't work
          -- Execute pg_notify(channel, notification)
          PERFORM pg_notify('cdc_events',notification::text);
          -- Result is ignored since we are invoking this in an AFTER trigger
          RETURN NULL;
      END;
      $$ LANGUAGE plpgsql;
      SQL
    end

    private def trigger
      <<-SQL
      -- Instead of manually creating triggers for each table, create CDC Trigger For All tables with id column
      CREATE OR REPLACE FUNCTION public.create_cdc_for_all_tables() RETURNS void AS $$

      DECLARE
        trigger_statement TEXT;
      BEGIN
        FOR trigger_statement IN SELECT
          'DROP TRIGGER IF EXISTS notify_change_event ON '
          || tab_name || ';'
          || 'CREATE TRIGGER notify_change_event AFTER INSERT OR UPDATE OR DELETE ON '
          || tab_name
          || ' FOR EACH ROW EXECUTE PROCEDURE public.notify_change();' AS trigger_creation_query
        FROM (
          SELECT
            quote_ident(t.table_schema) || '.' || quote_ident(t.table_name) as tab_name
          FROM
            information_schema.tables t, information_schema.columns c
          WHERE
            t.table_schema NOT IN ('pg_catalog', 'information_schema')
            AND t.table_schema NOT LIKE 'pg_toast%'
            AND c.table_name = t.table_name AND c.column_name='id'
        ) as TableNames
        LOOP
          EXECUTE  trigger_statement;
        END LOOP;
      END;
      $$ LANGUAGE plpgsql;
      SQL
    end

    private def dispatch(event : Events::Action)
      splash = enrich(event)

      @handlers.each do |h|
        spawn { h.on_splash(splash) }
      end
    end

    private def dispatch(evt : Events::LifeCycle)
      case evt
      in .start?   then @handlers.each { |h| spawn { h.on_start } }
      in .connect? then @handlers.each { |h| spawn { h.on_connect } }
      in .close?   then @handlers.each { |h| spawn { h.on_close } }
      end
    end

    private def enrich(action : Events::Action)
      Events::Splash.new(action.id.to_s, action.schema, action.table, action.timestamp, action.action, fetch(action))
    end

    private def on_action(action : Events::Action)
      dispatch(action)
    end

    private def connection
      (@db ||= DB.open(@url)).not_nil!
    end

    private def fetch(action : Events::Action) : String?
      return nil if action.action == Database::Action::DELETE

      return connection.query_one? "select to_json(t) from #{action.schema}.#{action.table} t where t.id = '#{action.id}'", &.read(JSON::Any).to_json if action.id.as_s?
      return connection.query_one? "select to_json(t) from #{action.schema}.#{action.table} t where t.id = #{action.id}", &.read(JSON::Any).to_json if action.id.as_i64?
    end
  end
end
