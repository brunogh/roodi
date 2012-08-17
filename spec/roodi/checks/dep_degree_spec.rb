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
  
    it "has the right dependency degree" do
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

    it "has the right dependency degree" do
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

end