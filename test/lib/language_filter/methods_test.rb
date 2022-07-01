require_relative '../../test_helper'

describe LanguageFilter do

  it "must be successfully created with correct defaults" do
    filter = LanguageFilter::Filter.new
    _(filter).must_be_kind_of LanguageFilter::Filter
    valid_non_empty_list? filter.matchlist
    _(filter.exceptionlist).must_be_kind_of Array
    _(filter.exceptionlist).must_be_empty
    filter.exceptionlist.each {|list_item| list_item.must_be_kind_of String}
    _(filter.creative_letters).must_be :==, false
    valid_non_empty_list? filter.creative_matchlist
  end

  it "must work with custom params and assignments" do
    # MATCHLIST
    # pre-packaged lists
    [:hate,:profanity,:sex,:violence].each do |list|
      filter = LanguageFilter::Filter.new matchlist: list
      _(filter).must_be_kind_of LanguageFilter::Filter
      valid_non_empty_list? filter.matchlist
    end
    # array of strings
    list = ['blah\\w*','test']
    filter = LanguageFilter::Filter.new matchlist: list
    valid_non_empty_list? filter.matchlist
    _(filter.matchlist).must_be :==, list
    # filepath
    list = File.dirname(__FILE__) + '/../../../config/matchlists/profanity.txt'
    filter = LanguageFilter::Filter.new matchlist: list
    valid_non_empty_list? filter.matchlist

    # EXCEPTIONLIST
    # pre-packaged lists
    [:hate,:profanity,:sex,:violence].each do |list|
      filter = LanguageFilter::Filter.new exceptionlist: list
      _(filter).must_be_kind_of LanguageFilter::Filter
      valid_non_empty_list? filter.exceptionlist
    end
    # array of strings
    list = ['blah\\w*','test']
    filter = LanguageFilter::Filter.new exceptionlist: list
    _(filter.exceptionlist).must_be_kind_of Array
    valid_non_empty_list? filter.exceptionlist
    # filepath
    list = File.dirname(__FILE__) + '/../../../config/matchlists/profanity.txt'
    filter = LanguageFilter::Filter.new exceptionlist: list
    valid_non_empty_list? filter.exceptionlist

    # CREATIVE_LETTERS
    [true,false].each do |creative_boolean|
      filter = LanguageFilter::Filter.new creative_letters: creative_boolean
      _(filter.creative_letters).must_be :==, creative_boolean
      valid_non_empty_list? filter.creative_matchlist
      _(filter.creative_matchlist).must_be :!=, filter.matchlist
      _(filter.creative_matchlist.size).must_be :==, filter.matchlist.size
      _(filter.creative_matchlist.join("").size).must_be :>, filter.matchlist.join("").size
    end
  end

  it "must correctly detect bad words without false positives" do
    test_against_word_lists
  end

end