module FluxxRequestReviewerAssignmentsController
  extend FluxxModuleHelper

  ICON_STYLE = 'style-request-reviewer-assignments'

  when_included do
    insta_index RequestReviewerAssignment do |insta|
      insta.template = 'request_reviewer_assignment_list'
      insta.filter_title = "RequestReviewerAssignments Filter"
      insta.filter_template = 'request_reviewer_assignments/request_reviewer_assignment_filter'
      insta.order_clause = 'updated_at desc'
      insta.icon_style = ICON_STYLE
    end
    insta_show RequestReviewerAssignment do |insta|
      insta.template = 'request_reviewer_assignment_show'
      insta.icon_style = ICON_STYLE
      insta.add_workflow
    end
    insta_new RequestReviewerAssignment do |insta|
      insta.template = 'request_reviewer_assignment_form'
      insta.icon_style = ICON_STYLE
    end
    insta_edit RequestReviewerAssignment do |insta|
      insta.template = 'request_reviewer_assignment_form'
      insta.icon_style = ICON_STYLE
    end
    insta_post RequestReviewerAssignment do |insta|
      insta.template = 'request_reviewer_assignment_form'
      insta.icon_style = ICON_STYLE
    end
    insta_put RequestReviewerAssignment do |insta|
      insta.template = 'request_reviewer_assignment_form'
      insta.icon_style = ICON_STYLE
      insta.add_workflow
    end
    insta_delete RequestReviewerAssignment do |insta|
      insta.template = 'request_reviewer_assignment_form'
      insta.icon_style = ICON_STYLE
    end
    insta_related RequestReviewerAssignment do |insta|
      insta.add_related do |related|
      end
    end
  end
end