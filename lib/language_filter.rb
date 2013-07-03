require 'pathname'
require 'yaml'
require 'language_filter/error'
require 'language_filter/version'

module LanguageFilter
	class Test
		attr_accessor :matchlist, :exceptionlist, :replacement

		DEFAULT_EXCEPTIONLIST = []
		DEFAULT_MATCHLIST = File.dirname(__FILE__) + "/../config/filters/profanity.txt"
		DEFAULT_REPLACEMENT = :stars

		def initialize(options={})
			@matchlist = if options[:matchlist] then
				set_list_content(options[:matchlist])
			else set_list_content(DEFAULT_MATCHLIST) end
			@exceptionlist = if options[:exceptionlist] then
				set_list_content(options[:exceptionlist]) 
			else set_list_content(DEFAULT_EXCEPTIONLIST) end
			@replacement = options[:replacement] || DEFAULT_REPLACEMENT
			validate_options
		end

		# SETTERS

		def matchlist=(content)
			if content == :default then
				@matchlist = DEFAULT_MATCHLIST
			else
				validate_list_content(content)
				@matchlist = set_list_content(content) || DEFAULT_MATCHLIST
			end
		end

		def exceptionlist=(content)
			if content == :default then
				@exceptionlist = DEFAULT_EXCEPTIONLIST
			else
				validate_list_content(content)
				@matchlist = set_list_content(content) || DEFAULT_EXCEPTIONLIST
			end
		end

		def replacement=(value)
			if value == :default then
				@replacement = :stars
			else
				@replacement = value
				validate_replacement
			end
		end

		# LANGUAGE

		def match?(word)
			return false unless text.to_s.size >= 3
			@matchlist.each do |list_item|
				return true if text =~ /\b#{list_item}\b/i and not @exceptionlist.include? list_item
			end
			false
		end

		def sanitize(text)
			return text unless text.to_s.size >= 3
			@matchlist.each do |list_item|
				text.gsub! /\b#{list_item}\b/i, replace(list_item) unless @exceptionlist.include? list_item
			end
			text
		end

		def matched(text)
			words = []
			return words unless text.to_s.size >= 3
			@matchlist.each do |list_item|
				words << list_item if text =~ /\b#{list_item}\b/i and not @exceptionlist.include?(list_item)
			end
			words.uniq
		end

		private

		# VALIDATIONS

		def validate_options
			[@matchlist, @exceptionlist].each{ |content| validate_list_content(content) if content }
			validate_replacement
		end

		def validate_list_content(content)
			case content
			when Array    then not content.empty?    || raise(LanguageFilter::EmptyContentList.new("List content array is empty."))
			when String   then File.exists?(content) || raise(LanguageFilter::UnkownContentFile.new("List content file \"#{content}\" can't be found."))
			when Pathname then content.exist?        || raise(LanguageFilter::UnkownContentFile.new("List content file \"#{content}\" can't be found."))
			when Symbol   then content == :default   || raise(LanguageFilter::UnkownContent.new("The only accepted symbol is :default."))
			else raise LanguageFilter::UnkownContent.new("The list content can be either an Array, Pathname, or String path to a .yml file.")
			end
		end

		def validate_replacement
			case @replacement
			when :default, :garbled, :vowels, :stars, :nonconsonants
			else raise LanguageFilter::UnknownReplacement.new("This is not a known replacement type.")
			end
		end

		# HELPERS

		def set_list_content(list)
			case list
			when :hate      then load_list File.dirname(__FILE__) + "/../config/filters/hate.yml"
			when :profanity then load_list File.dirname(__FILE__) + "/../config/filters/profanity.txt"
			when :sex       then load_list File.dirname(__FILE__) + "/../config/filters/sex.yml"
			when :violence  then load_list File.dirname(__FILE__) + "/../config/filters/violence.yml"
			when Array then list
			when String, Pathname then load_list list.to_s
			else []
			end
		end

		def load_list(filepath)
			IO.readlines(filepath).each {|line| line.gsub!(/\n/,'')}
		end

		# This was moved to private because users should just use sanitize for any content
		def replace(word)
			case @replacement
			when :vowels then word.gsub(/[aeiou]/i, '*')
			when :stars  then '*' * word.size
			when :nonconsonants then word.gsub(/[^bcdfghjklmnpqrstvwxyz]/i, '*')
			when :default, :garbled then '$@!#%'
			else raise LanguageFilter::UnknownReplacement.new("#{@replacement} is not a known replacement type.")
			end
		end
	end
end