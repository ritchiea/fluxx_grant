module FluxxProgramBudgetsController
  extend FluxxModuleHelper

  ICON_STYLE = 'style-program-budgets'

  when_included do
    insta_index ProgramBudget do |insta|
      insta.template = 'program_budget_list'
      insta.filter_title = "ProgramBudgets Filter"
      insta.filter_template = 'program_budgets/program_budget_filter'
      insta.order_clause = 'updated_at desc'
      insta.icon_style = ICON_STYLE
    end
    insta_show ProgramBudget do |insta|
      insta.template = 'program_budget_show'
      insta.icon_style = ICON_STYLE
      insta.add_workflow
    end
    insta_new ProgramBudget do |insta|
      insta.template = 'program_budget_form'
      insta.icon_style = ICON_STYLE
    end
    insta_edit ProgramBudget do |insta|
      insta.template = 'program_budget_form'
      insta.icon_style = ICON_STYLE
    end
    insta_post ProgramBudget do |insta|
      insta.template = 'program_budget_form'
      insta.icon_style = ICON_STYLE
    end
    insta_put ProgramBudget do |insta|
      insta.template = 'program_budget_form'
      insta.icon_style = ICON_STYLE
      insta.add_workflow
    end
    insta_delete ProgramBudget do |insta|
      insta.template = 'program_budget_form'
      insta.icon_style = ICON_STYLE
    end
    insta_related ProgramBudget do |insta|
      insta.add_related do |related|
      end
    end
  end
end