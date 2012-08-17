require 'roodi/checks/check'

module Roodi
  module Checks
    class DepDegreeMethodCheck < Check
      class Factory
        def initialize(counter)
          @counter = counter
        end

        def assignment(*args)
          args.push @counter
          Assignment.new *args
        end

        def call(*args)
          args.push @counter
          Call.new *args
        end

        def reference(*args)
          args.push @counter
          Reference.new *args
        end
      end

      class Counter
        def add(operation)
           self.operations << operation
        end

        def operations
          @operations ||= []
        end

        def next_id
          @next_id ||= 0
          @next_id += 1
        end
      end

      class Operation
        attr_reader :dependencies

        def self.code=(code)
          @code = code
        end

        def self.code
          @code
        end

        def code
          self.class.code
        end

        def initialize(type, dependencies, metadata, counter)
          @dependencies = [dependencies].flatten
          @metadata = metadata
          @type = type
          @id = counter.next_id
          counter.add self
        end

        def dependency_paths
          @dependencies.map do |dep|
            "#{short}-#{dep.short}" if dep
          end
        end

        def to_s
          if @dependencies
            "#{code}(#{@id}, #{@type} #{@metadata}, #{@dependencies.map{ |d| d.short}})"
          else
            "#{code}(#{@id}, #{@type} #{@metadata})"
          end
        end

        def short
          "#{code}#{@id}"
        end        
      end

      class Assignment < Operation
        self.code = "A"
      end

      class Call < Operation
        self.code = "C"
      end

      class Reference < Operation
        self.code = "R"
      end

      attr_reader :data, :score
      attr_accessor :threshold

      def interesting_nodes
        [ 
          :args,    # args is used for declaring method arguments, ie: the b in "def foo(b) ; end"
          :lvar,    # lvar is used to reference variables, ie: the b in "c = b"
          :lasgn    # lasgn is used to assign variables, ie: the b in "b = 1"
        ]
        [:defn]
      end

      def initialize(*)
        @assignments = Hash.new{ |h,k| h[k] = [] }
        @calls = Hash.new{ |h,k| h[k] = [] }
        @threshold = 10
        @counter = Counter.new
        @factory = Factory.new(@counter)
        super
      end

      def __evaluate(node)
        node.visitable_children.map do |sexp|
          case sexp[0]
          when :args
            operations = []
            sexp[1..-1].each do |arg|
              assignment = @factory.assignment(sexp[0], [], {:name => arg, :line => sexp.line})
              @assignments[arg] << assignment
            end

          when :scope, :block, :arglist
            __evaluate(sexp).flatten.compact

          when :lasgn
            arg = sexp[1]
            dependencies = __evaluate(sexp).compact
            assignment = @factory.assignment(arg, dependencies, {:name => arg, :line => sexp.line})
            @assignments[arg] << assignment

          when :call
            chain = collect_method_chain(sexp)
            binding.pry
            __evaluate(sexp).flatten.compact

          when :lvar            
            arg = sexp[1]
            reference = @factory.reference(arg, [@assignments[arg]].compact, {:name => arg, :line => sexp.line})
          end
        end
      end

      def collect_method_chain(node)
        chain = []
        sexp = node.visitable_children.first
        while sexp.is_a?(Sexp)
          chain << @factory.call("call", [], {})
          sexp = sexp.visitable_children.first
        end
        chain
      end

      def evaluate_start(node)
        @method_name = node[1]
        __evaluate node
      end

      def evaluate_end(node)
        @score = 0

        paths = []

        push_paths = lambda { |operation|
          paths.push *operation.dependency_paths
          operation.dependencies.each do |d|
            paths.push *d.dependency_paths
            push_paths.call d
          end
        }

        @counter.operations.each do |operation|
          push_paths.call operation
        end

        paths = paths.uniq
        @score = paths.length
puts node.inspect
binding.pry
        if @score > @threshold
          add_error "Method name \"#{@method_name}\" has a dependency degree of #{@score}. It should be #{@threshold} or less."
        end

      end
    end
  end
end
