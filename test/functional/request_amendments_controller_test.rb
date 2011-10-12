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
  
  test "should get CSV index" do
    get :index, :format => 'csv'
    assert_response :success
    assert_not_nil assigns(:request_amendments)
  end
  
  test "autocomplete" do
    lookup_instance = RequestAmendment.make
    get :index, :name => lookup_instance.name, :format => :autocomplete
    a = @response.body.de_json # try to deserialize the JSON to an array
    assert a.map{|elem| elem['value']}.include?(lookup_instance.id)
  end

  test "should confirm that name_exists" do
    get :index, :name => @request_amendment.name, :format => :autocomplete
    a = @response.body.de_json # try to deserialize the JSON to an array
    assert a.map{|elem| elem['value']}.include?(@request_amendment.id)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create request_amendment" do
    assert_difference('RequestAmendment.count') do
      post :create, :request_amendment => { :name => 'some random name for you' }
    end

    assert 201, @response.status
    assert @response.header["Location"] =~ /#{request_amendment_path(assigns(:request_amendment))}$/
  end

  test "should show request_amendment" do
    get :show, :id => @request_amendment.to_param
    assert_response :success
  end

  test "should show request_amendment with documents" do
    model_doc1 = ModelDocument.make(:documentable => @request_amendment)
    model_doc2 = ModelDocument.make(:documentable => @request_amendment)
    get :show, :id => @request_amendment.to_param
    assert_response :success
  end
  
  test "should show request_amendment with groups" do
    group = Group.make
    group_member1 = GroupMember.make :groupable => @request_amendment, :group => group
    group_member2 = GroupMember.make :groupable => @request_amendment, :group => group
    get :show, :id => @request_amendment.to_param
    assert_response :success
  end
  
  test "should show request_amendment with audits" do
    Audit.make :auditable_id => @request_amendment.to_param, :auditable_type => @request_amendment.class.name
    get :show, :id => @request_amendment.to_param
    assert_response :success
  end
  
  test "should show request_amendment audit" do
    get :show, :id => @request_amendment.to_param, :audit_id => @request_amendment.audits.first.to_param
    assert_response :success
  end
  
  test "should get edit" do
    get :edit, :id => @request_amendment.to_param
    assert_response :success
  end

  test "should not be allowed to edit if somebody else is editing" do
    @request_amendment.update_attributes :locked_until => (Time.now + 5.minutes), :locked_by_id => User.make.id
    get :edit, :id => @request_amendment.to_param
    assert assigns(:not_editable)
  end

  test "should not be allowed to update if somebody else is editing" do
    @request_amendment.update_attributes :locked_until => (Time.now + 5.minutes), :locked_by_id => User.make.id
    put :update, :id => @request_amendment.to_param, :request_amendment => {}
    assert assigns(:not_editable)
  end

  test "should update request_amendment" do
    put :update, :id => @request_amendment.to_param, :request_amendment => {}
    assert flash[:info]
    
    assert 201, @response.status
    assert @response.header["Location"] =~ /#{request_amendment_path(assigns(:request_amendment))}$/
  end

  test "should destroy request_amendment" do
    delete :destroy, :id => @request_amendment.to_param
    assert_not_nil @request_amendment.reload().deleted_at 
  end
end
