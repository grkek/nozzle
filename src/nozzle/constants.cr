module Nozzle
  module Constants
    VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify.downcase }}

    CHANNEL = "cdc_events"
  end
end
