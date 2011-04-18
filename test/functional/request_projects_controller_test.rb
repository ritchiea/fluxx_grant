require 'test_helper'

class RequestProjectsControllerTest < ActionController::TestCase
  def setup
    @org = Organization.make
    @program = Program.make
    @grant_request = GrantRequest.make :program => @program, :program_organization => @org, :base_request_id => nil
    @project = Project.make
    @project_request1 = ProjectRequest.make :request_id => @grant_request.id, :project_id => @project.id, :granted => false

    @user1 = User.make
    @user1.has_role! Program.program_officer_role_name, @program
    login_as @user1
  end

  test "should get new for granted request" do
    get :new, :request_project => { :granted => true, :request_id => @grant_request.id }
    assert_response :success
  end

  test "should get new for not granted request" do
    get :new, :request_project => { :granted => false, :request_id => @grant_request.id }
    assert_response :success
  end

  test "should create project_request" do
    assert_difference('ProjectRequest.count') do
      post :create, :project_request => { :request_id => @grant_request.id, :project_id => @project.id}
    end

    assert 201, @response.status
    assert_match /#{request_project_path(assigns(:project_request))}$/, @response.header["Location"]
  end

  test "should show project_request" do
    get :show, :id => @project_request1.to_param
    assert_response :success
  end

  test "should destroy project_request" do
    assert_difference('ProjectRequest.count', -1) do
      delete :destroy, :id => @project_request1.to_param
    end
  end
end
