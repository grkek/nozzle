module Nozzle
  class Listener
    @listener : PG::ListenConnection?
    @handler : (Events::Action ->)?
    @channels : Enumerable(String)

    def initialize(@url : String, *channel : String)
      @channels = channel
      @shutdown = Channel(Nil).new
    end

    def on_action(handler : Events::Action ->)
      @handler = handler
    end

    def start(h : Proc? = nil)
      @listener ||= PG.connect_listen(@url, @channels, &->event_handler(PQ::Notification))
      h.try &.call
      @shutdown.receive
    end

    def stop(h : Proc? = nil)
      @listener.try &.close
      h.try &.call
      @shutdown.send(nil)
    end

    private def event_handler(event : PQ::Notification)
      @handler.try &.call(Events::Action.from_json(event.payload))
    end
  end
end
