# stub to avoid actual geocoding calls
# to test hitting api query limits, use this:
# Geocoder::Lookup::Google.any_instance.stubs(:fetch_raw_data).returns(Geocoder::GOOGLE_OVER_QUERY_LIMIT)
module Geocoder
  GOOGLE_JSON= <<-JSON
  {
    "status": "OK",
    "results": [ 
      {
        "address_components":[{
            "long_name":"301", "short_name":"301", "types":["street_number"]
          }, {
            "long_name":"Battery St", "short_name":"Battery St", "types":["route"]
          }, {
            "long_name":"Financial District", "short_name":"Financial District", "types":["neighborhood", "political"]
          }, {
            "long_name":"San Francisco", "short_name":"SF", "types":["locality", "political"]
          }, {
            "long_name":"San Francisco", "short_name":"San Francisco", "types":["administrative_area_level_2", "political"]
          }, {
            "long_name":"California", "short_name":"CA", "types":["administrative_area_level_1", "political"]
          }, {
            "long_name":"United States", "short_name":"US", "types":["country", "political"]
          }, {
            "long_name":"94111", "short_name":"94111", "types":["postal_code"]
        }], 
        "formatted_address":"301 Battery St, San Francisco, CA 94111, USA", 
        "geometry":{
          "location":{
            "lat":37.794353, 
            "lng":-122.4002
          }, 
          "location_type":"ROOFTOP", 
          "viewport":{
            "northeast":{
              "lat":37.7957019802915, 
              "lng":-122.3988510197085
              }, 
            "southwest":{
              "lat":37.7930040197085, 
              "lng":-122.4015489802915
            }
          }
        }, 
        "types":["street_address"]
      }
    ]
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
