require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

# http://www.sosy-lab.org/~dbeyer/Publications/2010-ICPC.A_Simple_and_Effective_Measure_for_Complex_Low-Level_Dependencies.pdf
describe Roodi::Checks::DepDegreeMethodCheck do
  let(:threshold){ 1 }
  let(:check){ Roodi::Checks::DepDegreeMethodCheck.make :threshold => threshold }
  let(:roodi){ Roodi::Core::Runner.new(check) }

  describe "method arguments" do
    let(:threshold){ 1 }    
  
    it "doesn't add an error when they don't go over the threshold" do
      content = <<-END
        def foo_bar(a)
        end
      END
      roodi.check_content(content)
      roodi.errors.should eq([])
    end

    it "adds an error when it goes over the threshold" do
      content = <<-END
        def foo_bar(a, b)
          a = a + b
        end
      END
      roodi.check_content(content)
      expected_error = Roodi::Core::Error.new("dummy-file.rb", "1", %|Method name "foo_bar" has a dependency degree of 2. It should be #{threshold} or less.|)
      roodi.errors.should include(expected_error)
    end
  end

  describe "method body with assignments (swap)" do
    let(:threshold){ 1 }    
  
    it "has the right dependency degree for simple swap" do
      content = <<-END
        def swap(a, b)
          temp = b
          b = a
          a = temp
        end
      END
      checks = roodi.check_content(content)
      checks.first.score.should eq(3)
    end

    it "has the right dependency degree for complex swap" do
      content = <<-END
        def swap(a, b)
          a += b
          b = a - b
          a -= b
        end
      END
      checks = roodi.check_content(content)
      checks.first.score.should eq(6)
    end
  end

  describe "method body with simple expressions" do
    let(:threshold){ 1 }    
  
    it "has the right dependency degree with simple expressions that reference variables only" do
      content = <<-END
        def add_ten(a, b)
          a + b
        end
      END
      checks = roodi.check_content(content)
      checks.first.score.should eq(2)
    end

    it "has the right dependency degree with simple expressions that refer to literals by ignoring literals in dependency score" do
      content = <<-END
        def add_ten(a, b)
          a + 1 + b + :b + "asfs"
        end
      END
      checks = roodi.check_content(content)
      checks.first.score.should eq(2)
    end

    it "has the right dependency degree with expressions that contain nested assignment" do
      content = <<-END
        def add_ten(a, b)
          a + b += 5
        end
      END
      checks = roodi.check_content(content)
      checks.first.score.should eq(3)
    end
  end

  describe "method body with method chaining " do
    let(:threshold){ 1 }    
  
    it "has the right dependency degree with expressions that make chained method calls" do
      content = <<-END
        def add_ten(foo)
          foo.bar.baz
        end
      END
      checks = roodi.check_content(content)
      # 1 point for 'foo' reference to 'foo' initialization
      # 0 points for call to foo.bar
      # 1 point for (foo.bar).baz call
      checks.first.score.should eq(2)
    end

    it "has the right dependency degree with expressions that make chained method calls" do
      content = <<-END
        def add_ten(foo)
          foo.bar(5).baz(6).x.y.z
        end
      END
      checks = roodi.check_content(content)
      checks.first.score.should eq(5)
    end

  end  

end