module Nozzle
  module Handlers
    abstract class Base
      # Method invoked whenever there is new `Splash` event received.
      abstract def on_splash(splash : Events::Splash) : Nil

      # Method invoked when Application is going to start.
      abstract def on_start : Nil

      # Method invoked when Listener is connected to PG.
      abstract def on_connect : Nil

      # Method invoked when Application is going to close.
      abstract def on_close : Nil
    end
  end
end
