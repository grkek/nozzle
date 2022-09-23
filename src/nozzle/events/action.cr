require "../database/**"

module Nozzle
  module Events
    struct Action
      include JSON::Serializable

      property id : JSON::Any
      property schema : String
      property table : String
      property timestamp : Time
      property action : Database::Action
    end
  end
end
