require 'test_helper'

class ProgramBudgetsControllerTest < ActionController::TestCase

  def setup
    @user1 = User.make
    login_as @user1
    @program = Program.make
    @program_budget = ProgramBudget.make
  end
  
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:program_budgets)
  end
  
  test "should get CSV index" do
    get :index, :format => 'csv'
    assert_response :success
    assert_not_nil assigns(:program_budgets)
  end
  
  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create program_budget" do
    assert_difference('ProgramBudget.count') do
      post :create, :program_budget => { :program_id => @program.id }
    end

    assert 201, @response.status
    assert @response.header["Location"] =~ /#{program_budget_path(assigns(:program_budget))}$/
  end

  test "should show program_budget" do
    get :show, :id => @program_budget.to_param
    assert_response :success
  end

  test "should show program_budget audit" do
    get :show, :id => @program_budget.to_param, :audit_id => @program_budget.audits.first.to_param
    assert_response :success
  end
  
  test "should get edit" do
    get :edit, :id => @program_budget.to_param
    assert_response :success
  end

  test "should not be allowed to edit if somebody else is editing" do
    @program_budget.update_attributes :locked_until => (Time.now + 5.minutes), :locked_by_id => User.make.id
    get :edit, :id => @program_budget.to_param
    assert assigns(:not_editable)
  end

  test "should not be allowed to update if somebody else is editing" do
    @program_budget.update_attributes :locked_until => (Time.now + 5.minutes), :locked_by_id => User.make.id
    put :update, :id => @program_budget.to_param, :program_budget => {}
    assert assigns(:not_editable)
  end

  test "should update program_budget" do
    put :update, :id => @program_budget.to_param, :program_budget => {}
    assert flash[:info]
    
    assert 201, @response.status
    assert @response.header["Location"] =~ /#{program_budget_path(assigns(:program_budget))}$/
  end

  test "should destroy program_budget" do
    delete :destroy, :id => @program_budget.to_param
    assert_not_nil @program_budget.reload().deleted_at 
  end
end
