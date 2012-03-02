require 'test_helper'

class OrganizationTest < ActiveSupport::TestCase
  def setup
    @org = Organization.make
  end
  
  test "test creating organization" do
    assert @org.id
  end
  
  test "geocoding sets latitude and longitude post validation" do
    @org.postal_code = '96734'
    assert_nil @org.latitude
    assert_nil @org.longitude
    @org.valid?
    assert_equal 1.0, @org.latitude  # values from stubbed geocoder
    assert_equal 2.0, @org.longitude
  end
  
end