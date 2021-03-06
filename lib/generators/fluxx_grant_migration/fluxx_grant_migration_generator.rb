require 'rails/generators'
require 'rails/generators/migration'

class FluxxGrantMigrationGenerator < Rails::Generators::Base
  include Rails::Generators::Migration

  def self.source_root
    File.join(File.dirname(__FILE__), 'templates')
  end

  # Implement the required interface for Rails::Generators::Migration.
  # taken from http://github.com/rails/rails/blob/master/activerecord/lib/generators/active_record.rb
  def self.next_migration_number(dirname) #:nodoc:
    if ActiveRecord::Base.timestamped_migrations
      Time.now.utc.strftime("%Y%m%d%H%M%S")
    else
      "%.3d" % (current_migration_number(dirname) + 1)
    end
  end
  
  def create_geo_tables
    handle_migration 'create_programs.rb', 'db/migrate/fluxx_grant_create_programs.rb'
    handle_migration 'create_funding_sources.rb', 'db/migrate/fluxx_grant_create_funding_sources.rb'
    handle_migration 'create_initiatives.rb', 'db/migrate/fluxx_grant_create_initiatives.rb'
    handle_migration 'create_letter_templates.rb', 'db/migrate/fluxx_grant_create_letter_templates.rb'
    handle_migration 'create_requests.rb', 'db/migrate/fluxx_grant_create_requests.rb'
    handle_migration 'create_request_letters.rb', 'db/migrate/fluxx_grant_create_request_letters.rb'
    handle_migration 'create_request_organizations.rb', 'db/migrate/fluxx_grant_create_request_organizations.rb'
    handle_migration 'create_request_reports.rb', 'db/migrate/fluxx_grant_create_request_reports.rb'
    handle_migration 'create_request_transactions.rb', 'db/migrate/fluxx_grant_create_request_transactions.rb'
    handle_migration 'create_request_funding_sources.rb', 'db/migrate/fluxx_grant_create_request_funding_sources.rb'
    handle_migration 'create_request_users.rb', 'db/migrate/fluxx_grant_create_request_users.rb'
    handle_migration 'create_request_geo_states.rb', 'db/migrate/fluxx_grant_create_request_geo_states.rb'
    handle_migration 'add_grant_fields_to_organization.rb', 'db/migrate/fluxx_grant_add_grant_fields_to_organization.rb'
    handle_migration 'create_request_evaluation_metrics.rb', 'db/migrate/fluxx_grant_create_request_evaluation_metrics.rb'
    handle_migration 'create_project_requests.rb', 'db/migrate/fluxx_grant_create_project_requests.rb'
    handle_migration 'drop_request_letters.rb', 'db/migrate/fluxx_grant_drop_request_letters.rb'
    handle_migration 'add_description_to_project_relationships.rb', 'db/migrate/fluxx_grant_add_description_to_project_relationships.rb'
    handle_migration 'add_board_authority_to_request_funding_source.rb', 'db/migrate/fluxx_grant_add_board_authority_to_request_funding_source.rb'
    handle_migration 'create_sub_program.rb', 'db/migrate/fluxx_grant_create_sub_program.rb'
    handle_migration 'create_sub_initiative.rb', 'db/migrate/fluxx_grant_create_sub_initiative.rb'
    handle_migration 'add_sub_initiative_program_to_request_funding_source.rb', 'db/migrate/fluxx_grant_add_sub_initiative_program_to_request_funding_source.rb'
    handle_migration 'add_new_fields_to_funding_source.rb', 'db/migrate/fluxx_grant_add_new_fields_to_funding_source.rb'
    handle_migration 'switch_around_program_initiative_etc.rb', 'db/migrate/fluxx_grant_switch_around_program_initiative_etc.rb'
    handle_migration 'create_funding_source_allocation.rb', 'db/migrate/fluxx_grant_create_funding_source_allocation.rb'
    handle_migration 'switch_request_funding_source_authorities_to_allocation.rb', 'db/migrate/fluxx_grant_switch_request_funding_source_authorities_to_allocation.rb'
    handle_migration 'populate_funding_source_allocations.rb', 'db/migrate/fluxx_grant_populate_funding_source_allocations.rb'
    handle_migration 'add_program_geo_zone_meg.rb', 'db/migrate/fluxx_grant_add_program_geo_zone_meg.rb'
    handle_migration 'create_request_program.rb', 'db/migrate/fluxx_grant_create_request_program.rb'
    handle_migration 'add_retired_to_program_etc.rb', 'db/migrate/fluxx_grant_add_retired_to_program_etc.rb'
    handle_migration 'add_spending_year_to_funding_source_allocation.rb', 'db/migrate/fluxx_grant_add_spending_year_to_funding_source_allocation.rb'
    handle_migration 'limit_allocation_program_designation_to_one_field.rb', 'db/migrate/fluxx_grant_limit_allocation_program_designation_to_one_field.rb'
    handle_migration 'create_request_transaction_funding_source.rb', 'db/migrate/fluxx_grant_create_request_transaction_funding_source.rb'
    handle_migration 'add_payee_to_request_transaction.rb', 'db/migrate/fluxx_grant_add_payee_to_request_transaction.rb'
    handle_migration 'add_bank_account_to_transaction.rb', 'db/migrate/fluxx_grant_add_bank_account_to_transaction.rb'
    handle_migration 'make_eval_metrics_fields_text.rb', 'db/migrate/fluxx_grant_make_eval_metrics_fields_text.rb'
    handle_migration 'add_c3_field_to_organization.rb', 'db/migrate/fluxx_grant_add_c3_field_to_organization.rb'
    handle_migration 'add_prog_initiative_back_in_to_rfs.rb', 'db/migrate/fluxx_grant_add_prog_initiative_back_in_to_rfs.rb'
    handle_migration 'make_project_summary_a_text_field.rb', 'db/migrate/fluxx_grant_make_project_summary_a_text_field.rb'
    handle_migration 'create_funding_source_allocation_authority.rb', 'db/migrate/fluxx_grant_create_funding_source_allocation_authority.rb'
    handle_migration 'add_condition_to_request_transactions.rb', 'db/migrate/fluxx_grant_add_condition_to_request_transactions.rb'
    handle_migration 'add_grantee_user_profile_roles.rb', 'db/migrate/fluxx_grant_add_grantee_user_profile_roles.rb'
    handle_migration 'coalesce_grant_begins_at_ierf_start_at_fields.rb', 'db/migrate/fluxx_grant_coalesce_grant_begins_at_ierf_start_at_fields.rb'
    handle_migration 'add_reviewer_profile_and_role.rb', 'db/migrate/fluxx_grant_add_reviewer_profile_and_role.rb'
    handle_migration 'create_request_review.rb', 'db/migrate/fluxx_grant_create_request_review.rb'
    handle_migration 'add_initiative_id_to_requests.rb', 'db/migrate/fluxx_grant_add_initiative_id_to_requests.rb'
    handle_migration 'create_grantee_role_if_needed.rb', 'db/migrate/fluxx_grant_create_grantee_role_if_needed.rb'
    handle_migration 'add_po_number_extension_checkbox.rb', 'db/migrate/fluxx_grant_add_po_number_extension_checkbox.rb'
    handle_migration 'relax_authority_mev_constraint.rb', 'db/migrate/fluxx_grant_relax_authority_mev_constraint.rb'
    handle_migration 'create_budget_request.rb', 'db/migrate/fluxx_grant_create_budget_request.rb'
    handle_migration 'migrate_client_stores_to_program_hierarchy.rb', 'db/migrate/fluxx_grant_migrate_client_stores_to_program_hierarchy.rb'
    handle_migration 'add_hierarchy_marker_to_existing_dashboards.rb', 'db/migrate/fluxx_grant_add_hierarchy_marker_to_existing_dashboards.rb'
    handle_migration 'add_model_type_hierarchy_to_model_document_types.rb', 'db/migrate/fluxx_grant_add_model_type_hierarchy_to_model_document_types.rb'
    handle_migration 'use_class_names_for_modal_reports.rb', 'db/migrate/fluxx_grant_use_class_names_for_modal_reports.rb'
    handle_migration 'add_budget_request_profile_rules.rb', 'db/migrate/fluxx_grant_add_budget_request_profile_rules.rb'
    handle_migration 'create_loi.rb', 'db/migrate/fluxx_grant_create_loi.rb'
    handle_migration 'add_link_fields_to_loi.rb', 'db/migrate/fluxx_grant_add_link_fields_to_loi.rb'
    handle_migration 'rename_loi_organization_name.rb', 'db/migrate/fluxx_grant_rename_loi_organization_name.rb'
    handle_migration 'create_board_user_profile_rules.rb', 'db/migrate/fluxx_grant_create_board_user_profile_rules.rb'
    handle_migration 'add_grantee_roles_for_budget_requests.rb', 'db/migrate/fluxx_grant_add_grantee_roles_for_budget_requests.rb'
    handle_migration 'add_display_warnings_flag_to_grant_request.rb', 'db/migrate/fluxx_grant_add_display_warnings_flag_to_grant_request.rb'
    handle_migration 'add_request_grant_cycle.rb', 'db/migrate/fluxx_grant_add_request_grant_cycle.rb'
    handle_migration 'create_request_amendment.rb', 'db/migrate/fluxx_grant_create_request_amendment.rb'
    handle_migration 'populate_original_request_amendments.rb', 'db/migrate/fluxx_grant_populate_original_request_amendments.rb'
    handle_migration 'correct_project_request_constraint.rb', 'db/migrate/fluxx_grant_correct_project_request_constraint.rb'
    handle_migration 'convert_amounts_to_money.rb', 'db/migrate/fluxx_grant_convert_amounts_to_money.rb'
    handle_migration 'add_delta_column_to_loi.rb', 'db/migrate/fluxx_grant_add_delta_column_to_loi.rb'
    handle_migration 'add_timeframe_to_request_evaluation_metric.rb', 'db/migrate/fluxx_grant_add_timeframe_to_request_evaluation_metric.rb'
    handle_migration 'add_request_fields_to_loi.rb', 'db/migrate/fluxx_grant_add_request_fields_to_loi.rb'
    handle_migration 'make_amount_precision_larger.rb', 'db/migrate/fluxx_grant_make_amount_precision_larger.rb'
    handle_migration 'add_address_fields_to_lois.rb', 'db/migrate/fluxx_grant_add_address_fields_to_lois.rb'
    handle_migration 'add_view_model_document_to_grantee_profile.rb', 'db/migrate/fluxx_grant_add_view_model_document_to_grantee_profile.rb'
    handle_migration 'alter_grantee_profile_rule_for_model_document.rb', 'db/migrate/fluxx_grant_alter_grantee_profile_rule_for_model_document.rb'
    handle_migration 'add_migrate_id_to_tables.rb', 'db/migrate/fluxx_grant_add_migrate_id_to_tables.rb'
    handle_migration 'add_hgrant_omit_flag.rb', 'db/migrate/fluxx_grant_add_hgrant_omit_flag.rb'
    handle_migration 'add_notes_to_funding_source_allocation_authority.rb', 'db/migrate/fluxx_grant_add_notes_to_funding_source_allocation_authority.rb'
    handle_migration 'add_funding_source_fields_for_ef.rb', 'db/migrate/fluxx_grant_add_funding_source_fields_for_ef.rb'
    handle_migration 'add_state_to_request_amendments_table.rb', 'db/migrate/fluxx_grant_add_state_to_request_amendments_table.rb'
    handle_migration 'add_note_to_request_migrations_table.rb', 'db/migrate/fluxx_grant_add_note_to_request_migrations_table.rb'
    handle_migration 'add_delta_field_to_request_amendments.rb', 'db/migrate/fluxx_grant_add_delta_field_to_request_amendments.rb'
    handle_migration 'add_created_by_to_request_amendments.rb', 'db/migrate/fluxx_grant_add_created_by_to_request_amendments.rb'
    handle_migration 'add_program_listview_perms_for_grantee.rb', 'db/migrate/fluxx_grant_add_program_listview_perms_for_grantee.rb'
    handle_migration 'make_a_default_state_for_funding_sources.rb', 'db/migrate/fluxx_grant_make_a_default_state_for_funding_sources.rb'
    handle_migration 'update_state_of_funding_sources.rb', 'db/migrate/fluxx_grant_update_state_of_funding_sources.rb'
    handle_migration 'add_organization_foreign_name_to_loi.rb', 'db/migrate/fluxx_grant_add_organization_foreign_name_to_loi.rb'
    handle_migration 'add_old_value_fields_to_request_amendments_table.rb', 'db/migrate/fluxx_grant_add_old_value_fields_to_request_amendments_table.rb'
    handle_migration 'add_doc_view_privs_for_board_members.rb', 'db/migrate/fluxx_grant_add_doc_view_privs_for_board_members.rb'
    handle_migration 'delete_off_childless_funding_source_allocations.rb', 'db/migrate/fluxx_grant_delete_off_childless_funding_source_allocations.rb'
    handle_migration 'add_two_new_funding_source_amount_fields.rb', 'db/migrate/fluxx_grant_add_two_new_funding_source_amount_fields.rb'
    handle_migration 'create_program_budget.rb', 'db/migrate/fluxx_grant_create_program_budget.rb'
    handle_migration 'add_budget_allocation_amount_to_fsa.rb', 'db/migrate/fluxx_grant_add_budget_allocation_amount_to_fsa.rb'
    handle_migration 'add_actual_budget_amount_to_fsa.rb', 'db/migrate/fluxx_grant_add_actual_budget_amount_to_fsa.rb'
    handle_migration 'add_state_to_lois.rb', 'db/migrate/fluxx_grant_add_state_to_lois.rb'
    handle_migration 'add_conflict_field_to_request_reviews_table.rb', 'db/migrate/fluxx_grant_add_conflict_field_to_request_reviews_table.rb'
    handle_migration 'create_request_reviewer_assignment.rb', 'db/migrate/fluxx_grant_create_request_reviewer_assignment.rb'
    handle_migration 'add_reviewer_group_to_request.rb', 'db/migrate/fluxx_grant_add_reviewer_group_to_request.rb'
    handle_migration 'add_delta_to_request_reviews.rb', 'db/migrate/fluxx_grant_add_delta_to_request_reviews.rb'
  end
  
  private
  def handle_migration name, filename
    begin
      migration_template name, filename
      sleep 1
    rescue Exception => e
      p e.to_s
    end
  end
end
