require 'pathname'
require 'yaml'
require 'language_filter/error'
require 'language_filter/version'

module LanguageFilter
	class Filter
		attr_accessor :matchlist, :exceptionlist, :replacement

		DEFAULT_EXCEPTIONLIST = []
		DEFAULT_MATCHLIST = File.dirname(__FILE__) + "/../config/filters/profanity.txt"
		DEFAULT_REPLACEMENT = :stars

		def initialize(options={})
			@matchlist = if options[:matchlist] then
				validate_list_content(options[:matchlist])
				set_list_content(options[:matchlist])
			else set_list_content(DEFAULT_MATCHLIST) end
			@exceptionlist = if options[:exceptionlist] then
				validate_list_content(options[:exceptionlist])
				set_list_content(options[:exceptionlist]) 
			else set_list_content(DEFAULT_EXCEPTIONLIST) end
			@replacement = options[:replacement] || DEFAULT_REPLACEMENT
			validate_replacement
		end

		# SETTERS

		def matchlist=(content)
			validate_list_content(content)
			@matchlist = case content 
			when :default then set_list_content(DEFAULT_MATCHLIST)
			else @matchlist = set_list_content(content)
			end
		end

		def exceptionlist=(content)
			if content == :default then
				@exceptionlist = set_list_content(DEFAULT_EXCEPTIONLIST)
			else
				validate_list_content(content)
				@exceptionlist = set_list_content(content)
			end
		end

		def replacement=(value)
			@replacement = case value 
			when :default then :stars
			else value
			end
			validate_replacement
		end

		# LANGUAGE

		def match?(text)
			return false unless text.to_s.size >= 3
			@matchlist.each do |list_item|
				text.scan(/\b#{list_item}\b/i) {|match| return true unless protected_by_exceptionlist? match or match == [nil] }
			end
			false
		end

		def sanitize(text)
			return text unless text.to_s.size >= 3
			@matchlist.each do |list_item|
				text.gsub! /\b#{list_item}\b/i do |match| 
					if protected_by_exceptionlist? match then
						match
					else
						replace(match)
					end
				end
			end
			text
		end

		def matched(text)
			words = []
			return words unless text.to_s.size >= 3
			@matchlist.each do |list_item|
				text.scan(/\b#{list_item}\b/i) {|match| words << match unless protected_by_exceptionlist? match or match == [nil] }
			end
			words.uniq
		end

		private

		# VALIDATIONS

		def validate_list_content(content)
			case content
			when Array    then not content.empty?    || raise(LanguageFilter::EmptyContentList.new("List content array is empty."))
			when String   then File.exists?(content) || raise(LanguageFilter::UnkownContentFile.new("List content file \"#{content}\" can't be found."))
			when Pathname then content.exist?        || raise(LanguageFilter::UnkownContentFile.new("List content file \"#{content}\" can't be found."))
			when Symbol   then
				case content
				when :default, :hate, :profanity, :sex, :violence then true
				else raise(LanguageFilter::UnkownContent.new("The only accepted symbols are :default, :hate, :profanity, :sex, and :violence."))
				end
			else raise LanguageFilter::UnkownContent.new("The list content can be either an Array, Pathname, or String path to a file.")
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
			when :hate      then load_list File.dirname(__FILE__) + "/../config/filters/hate.txt"
			when :profanity then load_list File.dirname(__FILE__) + "/../config/filters/profanity.txt"
			when :sex       then load_list File.dirname(__FILE__) + "/../config/filters/sex.txt"
			when :violence  then load_list File.dirname(__FILE__) + "/../config/filters/violence.txt"
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

		def protected_by_exceptionlist?(text)
			@exceptionlist.each { |list_item| return true unless text.scan(/\b#{list_item}\b/i).empty? }
			return false
		end
	end
end