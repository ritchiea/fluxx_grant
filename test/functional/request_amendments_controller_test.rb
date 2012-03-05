require 'test_helper'

class RequestAmendmentsControllerTest < ActionController::TestCase

  def setup
    @user1 = User.make
    login_as @user1
    @request_amendment = RequestAmendment.make
  end
  
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:request_amendments)
  end
  
  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create request_amendment" do
    assert_difference('RequestAmendment.count') do
      post :create, :request_amendment => { :amount_recommended => 1000 }
    end

    assert 201, @response.status
    assert @response.header["Location"] =~ /#{request_amendment_path(assigns(:request_amendment))}$/
  end

  test "should show request_amendment" do
    get :show, :id => @request_amendment.to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => @request_amendment.to_param
    assert_response :success
  end

  test "should update request_amendment" do
    put :update, :id => @request_amendment.to_param, :request_amendment => {}
    assert flash[:info]
    
    assert 201, @response.status
    assert @response.header["Location"] =~ /#{request_amendment_path(assigns(:request_amendment))}$/
  end

  test "should destroy request_amendment" do
    assert_difference('RequestAmendment.count', -1) do
      delete :destroy, :id => @request_amendment.to_param
    end
  end
end
