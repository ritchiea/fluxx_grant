module LiquidLoader
  # Ideally we would have this loaded automatically by discovering the helper classes required
  def self.include_libraries
    LiquidFilters.send :include, ::ApplicationGrantHelper
    LiquidRenderer.send :include, ::ApplicationGrantHelper
    LiquidFilters.send :include, ::ApplicationHelper
    LiquidRenderer.send :include, ::ApplicationHelper
    LiquidFilters.send :include, ::ApplicationEngineHelper
    LiquidRenderer.send :include, ::ApplicationEngineHelper
    LiquidRenderer.send :include, Rails.application.routes.url_helpers
  end
end