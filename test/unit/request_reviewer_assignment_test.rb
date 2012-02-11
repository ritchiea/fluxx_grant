require 'test_helper'

class RequestReviewerAssignmentTest < ActiveSupport::TestCase
  def setup
    @request_reviewer_assignment = RequestReviewerAssignment.make
  end
  
  test "truth" do
    assert true
  end
end