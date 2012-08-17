module Roodi
  module Core
    class Error
      attr_reader :filename, :line_number, :message
      
      def initialize(filename, line_number, message)
        @filename = filename
        @line_number = line_number
        @message = message
      end
      
      def to_s
        "#{@filename}:#{@line_number} - #{@message}"
      end

      def ==(other)
        other.is_a?(self.class) && other.to_s == self.to_s
      end
    end
  end
end
