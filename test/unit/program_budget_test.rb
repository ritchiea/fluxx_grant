require 'test_helper'

class ProgramBudgetTest < ActiveSupport::TestCase
  def setup
    @program_budget = ProgramBudget.make
  end
  
  test "truth" do
    assert true
  end
end