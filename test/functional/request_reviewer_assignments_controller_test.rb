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
  
  test "should get CSV index" do
    get :index, :format => 'csv'
    assert_response :success
    assert_not_nil assigns(:request_reviewer_assignments)
  end
  
  test "autocomplete" do
    lookup_instance = RequestReviewerAssignment.make
    get :index, :name => lookup_instance.name, :format => :autocomplete
    a = @response.body.de_json # try to deserialize the JSON to an array
    assert a.map{|elem| elem['value']}.include?(lookup_instance.id)
  end

  test "should confirm that name_exists" do
    get :index, :name => @request_reviewer_assignment.name, :format => :autocomplete
    a = @response.body.de_json # try to deserialize the JSON to an array
    assert a.map{|elem| elem['value']}.include?(@request_reviewer_assignment.id)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create request_reviewer_assignment" do
    assert_difference('RequestReviewerAssignment.count') do
      post :create, :request_reviewer_assignment => { :name => 'some random name for you' }
    end

    assert 201, @response.status
    assert @response.header["Location"] =~ /#{request_reviewer_assignment_path(assigns(:request_reviewer_assignment))}$/
  end

  test "should show request_reviewer_assignment" do
    get :show, :id => @request_reviewer_assignment.to_param
    assert_response :success
  end

  test "should show request_reviewer_assignment with documents" do
    model_doc1 = ModelDocument.make(:documentable => @request_reviewer_assignment)
    model_doc2 = ModelDocument.make(:documentable => @request_reviewer_assignment)
    get :show, :id => @request_reviewer_assignment.to_param
    assert_response :success
  end
  
  test "should show request_reviewer_assignment with groups" do
    group = Group.make
    group_member1 = GroupMember.make :groupable => @request_reviewer_assignment, :group => group
    group_member2 = GroupMember.make :groupable => @request_reviewer_assignment, :group => group
    get :show, :id => @request_reviewer_assignment.to_param
    assert_response :success
  end
  
  test "should show request_reviewer_assignment with audits" do
    Audit.make :auditable_id => @request_reviewer_assignment.to_param, :auditable_type => @request_reviewer_assignment.class.name
    get :show, :id => @request_reviewer_assignment.to_param
    assert_response :success
  end
  
  test "should show request_reviewer_assignment audit" do
    get :show, :id => @request_reviewer_assignment.to_param, :audit_id => @request_reviewer_assignment.audits.first.to_param
    assert_response :success
  end
  
  test "should get edit" do
    get :edit, :id => @request_reviewer_assignment.to_param
    assert_response :success
  end

  test "should not be allowed to edit if somebody else is editing" do
    @request_reviewer_assignment.update_attributes :locked_until => (Time.now + 5.minutes), :locked_by_id => User.make.id
    get :edit, :id => @request_reviewer_assignment.to_param
    assert assigns(:not_editable)
  end

  test "should not be allowed to update if somebody else is editing" do
    @request_reviewer_assignment.update_attributes :locked_until => (Time.now + 5.minutes), :locked_by_id => User.make.id
    put :update, :id => @request_reviewer_assignment.to_param, :request_reviewer_assignment => {}
    assert assigns(:not_editable)
  end

  test "should update request_reviewer_assignment" do
    put :update, :id => @request_reviewer_assignment.to_param, :request_reviewer_assignment => {}
    assert flash[:info]
    
    assert 201, @response.status
    assert @response.header["Location"] =~ /#{request_reviewer_assignment_path(assigns(:request_reviewer_assignment))}$/
  end

  test "should destroy request_reviewer_assignment" do
    delete :destroy, :id => @request_reviewer_assignment.to_param
    assert_not_nil @request_reviewer_assignment.reload().deleted_at 
  end
end
