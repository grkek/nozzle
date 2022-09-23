require "../database/**"

module Nozzle
  module Events
    @[JSON::Serializable::Options(emit_nulls: true)]
    struct Splash
      include JSON::Serializable

      property id : String
      property schema : String
      property table : String
      property timestamp : Time
      property action : Database::Action
      property data : String?

      def initialize(@id : String, @schema : String, @table : String, @timestamp : Time, @action : Database::Action, @data : String?)
      end
    end
  end
end
