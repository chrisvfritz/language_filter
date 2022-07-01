require_relative '../../test_helper'

describe LanguageFilter do

  it "must be defined" do
    _(LanguageFilter::VERSION).wont_be_nil
  end

end