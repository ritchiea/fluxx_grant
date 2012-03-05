# stub to avoid actual geocoding calls
# to test hitting api query limits, use this:
# Geocoder::Lookup::Google.any_instance.stubs(:fetch_raw_data).returns(Geocoder::GOOGLE_OVER_QUERY_LIMIT)
module Geocoder
  GOOGLE_JSON= <<-JSON
  {
    "status": "OK",
    "results": [ {
      "geometry": {
        "location": {
          "lat": 1.0,
          "lng": 2.0
        }
      }
    } ]
  }
  JSON

  GOOGLE_OVER_QUERY_LIMIT= <<-JSON
  {
    "status": "OVER_QUERY_LIMIT",
    "results": [ ]
  }
  JSON

  module Lookup
    class Base
    end
    class Google < Base
      private
      def fetch_raw_data(query, reverse = false)
        GOOGLE_JSON
      end
    end
  end

end
