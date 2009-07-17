require File.dirname(__FILE__) + '/test_helper.rb'
include JqGridHelper

class JqGridHelperTest < Test::Unit::TestCase
  def test_tweet
    assert_equal "Tweet! Hello", tweet("Hello")
  end
end
