module Nozzle
  module Database
    enum Action
      INSERT
      UPDATE
      DELETE

      def to_s(io : IO) : Nil
        io << self.to_s.downcase
      end
    end
  end
end
