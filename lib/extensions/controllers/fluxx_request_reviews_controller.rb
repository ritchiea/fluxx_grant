module FluxxRequestReviewsController
  ICON_STYLE = 'style-request-reviews'
  def self.included(base)
    base.insta_index RequestReview do |insta|
      insta.template = 'request_review_list'
      insta.filter_title = "RequestReviews Filter"
      insta.filter_template = 'request_reviews/request_review_filter'
      insta.order_clause = 'updated_at desc'
      insta.icon_style = ICON_STYLE
    end
    base.insta_show RequestReview do |insta|
      insta.template = 'request_review_show'
      insta.icon_style = ICON_STYLE
#      insta.add_workflow
    end
    base.insta_new RequestReview do |insta|
      insta.template = 'request_review_form'
      insta.icon_style = ICON_STYLE
      insta.layout = lambda {|user| user.is_external_user? ? 'reviewer_portal' : 'application'}
      insta.skip_card_footer = true
      insta.format do |format|
        format.html do |triple|
          controller_dsl, outcome, default_block = triple
          # Don't create a new review if there is already one from this user
          review = @model.request.request_reviews.where(:created_by_id => current_user.id).first
          if (review)
            redirect_to edit_request_review_path(review)
          else
            default_block.call
          end
        end
      end
    end
    base.insta_edit RequestReview do |insta|
      insta.template = 'request_review_form'
      insta.icon_style = ICON_STYLE
      insta.layout = lambda {|user| user.is_external_user? ? 'reviewer_portal' : 'application'}
      insta.skip_card_footer = true
    end
    base.insta_post RequestReview do |insta|
      insta.template = 'request_review_form'
      insta.icon_style = ICON_STYLE
      insta.pre do |conf|
        self.pre_model = conf.load_new_model params, self.pre_model, fluxx_current_user
        if params[:report_conflict]
          self.pre_model.conflict_reported = true
        end
      end
      insta.format do |format|
        format.html do |triple|
          controller_dsl, outcome, default_block = triple
          if (outcome != :error) && current_user.is_external_user?
            redirect_to reviewer_portal_index_path
          else
            default_block.call
          end
        end
      end
    end
    base.insta_put RequestReview do |insta|
      insta.template = 'request_review_form'
      insta.icon_style = ICON_STYLE
      insta.pre do |conf|
        self.pre_model = conf.load_existing_model params
        if params[:report_conflict]
          self.pre_model.conflict_reported = true
        end
      end
      insta.format do |format|
        format.html do |triple|
          controller_dsl, outcome, default_block = triple
          if (outcome != :error) && current_user.is_external_user?
            redirect_to reviewer_portal_index_path
          else
            default_block.call
          end
        end
      end
    end
    base.insta_delete RequestReview do |insta|
      insta.template = 'request_review_form'
      insta.icon_style = ICON_STYLE
    end
    base.insta_related RequestReview do |insta|
      insta.add_related do |related|
      end
    end
    
    base.extend(ModelClassMethods)
    base.class_eval do
      include ModelInstanceMethods
    end
  end

  module ModelClassMethods
  end

  module ModelInstanceMethods
  end
end