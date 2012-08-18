require 'roodi/checks/check'

module Roodi
  module Checks
    class DepDegreeMethodCheck < Check
      class Factory
        def initialize(counter)
          @counter = counter
        end

        def arg_initialization(*args)
          args.push @counter
          Initialization.new *args
        end          

        def assignment(*args)
          args.push @counter
          Assignment.new *args
        end

        def call(*args)
          args.push @counter
          Call.new *args
        end

        def inline_reference(*args)
          args.push @counter
          InlineReference.new *args
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

        def next_id(klass)
          @ids ||= Hash.new{ |h,k| h[k] = 0 }
          @ids[klass] += 1
        end
      end

      class Operation
        attr_accessor :dependencies

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
          @id = counter.next_id(self.class)
          counter.add self
        end

        def dependency_paths
          @dependencies.map do |dep|
            "#{short}-#{dep.short}" if !dep.is_a?(Reference)
          end.compact
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

      class Initialization < Operation
        self.code = "I"
      end

      class Call < Operation
        self.code = "C"
      end

      class InlineReference < Operation
        self.code = "IR"
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
        @calls = []
        @threshold = 10
        @counter = Counter.new
        @factory = Factory.new(@counter)
        super
      end

      def __evaluate(node, options={})
        node.visitable_children.map do |sexp|

          case sexp[0]
          when :args
            operations = []
            sexp[1..-1].each do |arg|
              assignment = @factory.arg_initialization(sexp[0], [], {:name => arg, :line => sexp.line})
              @assignments[arg] << assignment
            end

          when :scope, :block
            __evaluate(sexp).flatten.compact

          when :arglist
            __evaluate(sexp, :within_arglist => true).flatten.compact

          when :lasgn
            arg = sexp[1]
            dependencies = __evaluate(sexp).compact.flatten
            @factory.assignment(arg, dependencies, {:name => arg, :line => sexp.line}).tap do |assignment|
              @assignments[arg] << assignment
              if options[:within_arglist]
                @factory.inline_reference(arg, [assignment], {:name => arg, :line => sexp.line})
              end
            end

          when :call
            if !options[:within_call]
              chain = collect_method_chain(sexp)
              @calls << chain.flatten
            end
            __evaluate(sexp, :within_call => true).flatten.compact

          when :lvar            
            arg = sexp[1]
            reference = @factory.reference(arg, [@assignments[arg].last].compact, {:name => arg, :line => sexp.line})
          end
        end
      end

      def collect_method_chain(node)
        chain = []
        sexp = node.visitable_children.first
        while sexp.is_a?(Sexp)
 #         if sexp.last.is_a?(Sexp) && sexp.last.last.first != :lit   # uncomment if you want to start ignoring literals in chained method calls
            chain << @factory.call("call", [], {:line => sexp.line})
 #         end
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
#            push_paths.call d
          end
        }

        @counter.operations.each do |operation|
          push_paths.call operation
        end

        paths = paths.uniq
        @score += paths.length

        @calls.each do |chain| 
          @score += chain.length - 1 if chain.any?
        end

        if @score > @threshold
          add_error "Method name \"#{@method_name}\" has a dependency degree of #{@score}. It should be #{@threshold} or less."
        end

      end
    end
  end
end
