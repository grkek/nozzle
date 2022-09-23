module Nozzle
  class Application
    Log = ::Log.for(self)

    @db : DB::Database?

    def initialize(@database_url : String, @database_channel : String, @handlers : Array(Handlers::Base))
      if needs_registration?
        conn = DB.open(@database_url)

        change_data_capture = ECR.render("#{__DIR__}/fixtures/change_data_capture.ecr")
        trigger = ECR.render("#{__DIR__}/fixtures/trigger.ecr")

        conn.exec(change_data_capture)
        conn.exec(trigger)

        conn.exec("select public.create_cdc_for_all_tables()")

        conn.try &.close
      end

      @listener = Listener.new(@database_url, @database_channel)
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

    private def needs_registration?
      conn = DB.open(@database_url)
      conn.exec("select 'create_cdc_for_all_tables'::regproc;")
      conn.try &.close

      false
    rescue
      true
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
      (@db ||= DB.open(@database_url)).not_nil!
    end

    private def fetch(action : Events::Action) : String?
      return nil if action.action == Database::Action::DELETE

      return connection.query_one? "select to_json(t) from #{action.schema}.#{action.table} t where t.id = '#{action.id}'", &.read(JSON::Any).to_json if action.id.as_s?
      return connection.query_one? "select to_json(t) from #{action.schema}.#{action.table} t where t.id = #{action.id}", &.read(JSON::Any).to_json if action.id.as_i64?
    end
  end
end
