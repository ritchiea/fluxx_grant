require 'test_helper'

class RequestReviewerAssignmentsControllerTest < ActionController::TestCase

  def setup
    @user1 = User.make
    login_as @user1
    @request_reviewer_assignment = RequestReviewerAssignment.make
  end
  
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:request_reviewer_assignments)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create request_reviewer_assignment" do
    assert_difference('RequestReviewerAssignment.count') do
      post :create, :request_reviewer_assignment => { :user_id => @user1.id }
    end

    assert 201, @response.status
    assert @response.header["Location"] =~ /#{request_reviewer_assignment_path(assigns(:request_reviewer_assignment))}$/
  end

  test "should show request_reviewer_assignment" do
    get :show, :id => @request_reviewer_assignment.to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => @request_reviewer_assignment.to_param
    assert_response :success
  end

  test "should update request_reviewer_assignment" do
    put :update, :id => @request_reviewer_assignment.to_param, :request_reviewer_assignment => {}
    assert flash[:info]
    
    assert 201, @response.status
    assert @response.header["Location"] =~ /#{request_reviewer_assignment_path(assigns(:request_reviewer_assignment))}$/
  end

  test "should destroy request_reviewer_assignment" do
    assert_difference('RequestReviewerAssignment.count', -1) do
      delete :destroy, :id => @request_reviewer_assignment.to_param
    end
  end
end
