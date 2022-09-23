module Nozzle
  module Handlers
    class Redis < Base
      Log = ::Log.for(self)

      def initialize(redis_url : String)
        @redis = ::Redis.new(url: redis_url)
      end

      def on_splash(splash : Events::Splash) : Nil
        channel = "#{splash.schema}.#{splash.table}.cdc_events"
        Log.info { "Publishing splash events to redis channel: #{channel}" }
        @redis.publish(channel, splash.to_json)
      end

      def on_connect : Nil
      end

      def on_start : Nil
      end

      def on_close : Nil
        @redis.close
      end
    end
  end
end
