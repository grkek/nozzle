module Nozzle
  module Handlers
    class Redis < Base
      Log = ::Log.for(self)

      def initialize(url : String)
        @redis = ::Redis.new(url: url)
      end

      # Method invoked whenever there is new `Splash` event received.
      def on_splash(splash : Events::Splash) : Nil
        channel = "#{splash.schema}.#{splash.table}.cdc_events"
        Log.info { "Publishing splash events to redis channel: #{channel}" }
        @redis.publish(channel, splash.to_json)
      end

      # Method invoked when Application is going to start.
      def on_connect : Nil
      end

      # Method invoked when Listener is connected to PG.
      def on_start : Nil
      end

      # Method invoked when Application is going to close.
      def on_close : Nil
        @redis.close
      end
    end
  end
end
