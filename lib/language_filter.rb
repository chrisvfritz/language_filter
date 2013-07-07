# encoding: utf-8

require 'pathname'
require 'yaml'
require 'language_filter/error'
require 'language_filter/version'

module LanguageFilter
	class Filter
		attr_accessor :matchlist, :exceptionlist, :replacement, :creative_letters
		attr_reader :creative_matchlist, :creative_exceptionlist

		BEG_REGEX = '(?<=\\s|\\A|_|\\-|\\.])'
		END_REGEX = '(?=\\b|\\s|\\z|_|\\-|\\.)'

		DEFAULT_EXCEPTIONLIST = []
		DEFAULT_MATCHLIST = File.dirname(__FILE__) + "/../config/filters/profanity.txt"
		DEFAULT_REPLACEMENT = :stars
		DEFAULT_CREATIVE_LETTERS = false

		def initialize(options={})
			@creative_letters = if options[:creative_letters] then
				options[:creative_letters]
			else DEFAULT_CREATIVE_LETTERS end

			@matchlist = if options[:matchlist] then
				validate_list_content(options[:matchlist])
				set_list_content(options[:matchlist])
			else set_list_content(DEFAULT_MATCHLIST) end
			@creative_matchlist = @matchlist.map {|list_item| use_creative_letters(list_item)}

			@exceptionlist = if options[:exceptionlist] then
				validate_list_content(options[:exceptionlist])
				set_list_content(options[:exceptionlist])
			else set_list_content(DEFAULT_EXCEPTIONLIST) end
			@creative_exceptionlist = @exceptionlist.map {|list_item| use_creative_letters(list_item)}

			@replacement = options[:replacement] || DEFAULT_REPLACEMENT
			validate_replacement
		end

		# SETTERS

		def matchlist=(content)
			validate_list_content(content)
			@matchlist = case content 
			when :default then set_list_content(DEFAULT_MATCHLIST)
			else set_list_content(content)
			end
			@creative_matchlist = @matchlist.map {|list_item| use_creative_letters(list_item)}
		end

		def exceptionlist=(content)
			validate_list_content(content)
			@exceptionlist = case content 
			when :default then set_list_content(DEFAULT_EXCEPTIONLIST)
			else set_list_content(content)
			end
			@creative_exceptionlist = @exceptionlist.map {|list_item| use_creative_letters(list_item)}
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
			chosen_matchlist = case @creative_letters
			when true then @creative_matchlist
			else @matchlist
			end
			chosen_matchlist.each do |list_item|
				start_at = 0
				text.scan(%r"#{BEG_REGEX}#{list_item}#{END_REGEX}"i) do |match|
					match_start = text[start_at,text.size].index(%r"#{BEG_REGEX}#{list_item}#{END_REGEX}"i) unless @exceptionlist.empty?
					match_end = match_start + match.size unless @exceptionlist.empty?
					unless match == [nil] then
						return true if @exceptionlist.empty? or not protected_by_exceptionlist?(match_start,match_end,text,start_at)
					end
					start_at = match_end + 1 unless @exceptionlist.empty?
				end
			end
			false
		end

		def matched(text)
			words = []
			return words unless text.to_s.size >= 3
			chosen_matchlist = case @creative_letters
			when true then @creative_matchlist
			else @matchlist
			end
			chosen_matchlist.each do |list_item|
				start_at = 0
				text.scan(%r"#{BEG_REGEX}#{list_item}#{END_REGEX}"i) do |match|
					match = match.compact.join("") if match.class == Array
					next if match.empty?
					match_start = text[start_at,text.size].index(%r"#{BEG_REGEX}#{list_item}#{END_REGEX}"i) unless @exceptionlist.empty?
					match_end = match_start + match.size unless @exceptionlist.empty?
					unless match == [nil] then
						words << match if @exceptionlist.empty? or not protected_by_exceptionlist?(match_start,match_end,text,start_at)
					end
					start_at = match_end + 1 unless @exceptionlist.empty?
				end
			end
			words.uniq
		end

		def sanitize(text)
			return text unless text.to_s.size >= 3
			chosen_matchlist = case @creative_letters
			when true then @creative_matchlist
			else @matchlist
			end
			chosen_matchlist.each do |list_item|
				start_at = 0
				text.gsub! %r"#{BEG_REGEX}#{list_item}#{END_REGEX}"i do |match|
					match_start = text[start_at,text.size].index(%r"#{BEG_REGEX}#{list_item}#{END_REGEX}"i) unless @exceptionlist.empty?
					match_end = match_start + match.size unless @exceptionlist.empty?
					unless @exceptionlist.empty? or not protected_by_exceptionlist?(match_start,match_end,text,start_at) then
						start_at = match_end + 1 unless @exceptionlist.empty?
						match
					else
						start_at = match_end + 1 unless @exceptionlist.empty?
						replace(match)
					end
				end
			end
			text
		end

		private

		# VALIDATIONS

		def validate_list_content(content)
			case content
			when Array    then content.all? {|c| c.class == String} || raise(LanguageFilter::EmptyContentList.new("List content array is empty."))
			when String   then File.exists?(content)                || raise(LanguageFilter::UnkownContentFile.new("List content file \"#{content}\" can't be found."))
			when Pathname then content.exist?                       || raise(LanguageFilter::UnkownContentFile.new("List content file \"#{content}\" can't be found."))
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

		def use_creative_letters(text)
			new_text = ""
			last_char = ""
			text.each_char do |char|
				if last_char != '\\'
					# new_text += '[\\W_]*' if last_char != "" and char =~ /[A-Za-z]/
					new_text += case char.downcase
					when 'a' then '(?:(?:a|@|4|\\^|/\\\\|/\\-\\\\|aye?)+)'
					when 'b' then '(?:(?:b|i3|l3|13|\\|3|/3|\\\\3|3|8|6|\\u00df|p\\>|\\|\\:|bee+)+)'
					when 'c','k' then '(?:(?:c|\\u00a9|\\u00a2|\\(|\\[|cee+|see+|k|x|[\\|\\[\\]\\)\\(li1\\!\\u00a1][\\<\\{\\(]|[ck]ay)+)'
					when 'd' then '(?:(?:d|\\)|\\|\\)|\\[\\)|\\?|\\|\\>|\\|o|dee+)+)'
					when 'e' then '(?:(?:e|3|\\&|\\u20ac|\\u00eb|\\[\\-)+)'
					when 'f' then '(?:(?:f|ph|\\u0192|[\\|/\\\\][\\=\\#]|ef+)+)'
					when 'g' then '(?:(?:g|6|9|\\&|c\\-|\\(_\\+|gee+)+)'
					when 'h' then '(?:(?:h|\\#|[\\|\\}\\{\\\\/\\(\\)\\[\\]]\\-?[\\|\\}\\{\\\\/\\(\\)\\[\\]])+)'
					when 'i','l' then '(?:(?:i|l|1|\\!|\\u00a1|\\||\\]|\\[|\\\\|/|eye|\\u00a3|[\\|li1\\!\\u00a1\\[\\]\\(\\)\\{\\}]_|\\u00ac|el+)+)'
					when 'j' then '(?:(?:j|\\]|\\u00bf|_\\||_/|\\</|\\(/|jay+)+)'
					when 'm' then '(?:(?:m|[\\|\\(\\)/](?:\\\\/|v|\\|)[\\|\\(\\)\\\\]|\\^\\^|em+)+)'
					when 'n' then '(?:(?:n|[\\|/\\[\\]\\<\\>]\\\\[\\|/\\[\\]\\<\\>]|/v|\\^/|en+)+)'
					when 'o' then '(?:(?:o|0|\\(\\)|\\[\\]|\\u00b0|oh+)+)'
					when 'p' then '(?:(?:p|\\u00b6|[\\|li1\\[\\]\\!\\u00a1/\\\\][\\*o\\u00b0\\"\\>7\\^]|pee+)+)'
					when 'q' then '(?:(?:q|9|(?:0|\\(\\)|\\[\\])_|\\(_\\,\\)|\\<\\||[ck]ue*|qu?eue*)+)'
					when 'r' then '(?:(?:r|[/1\\|li]?[2\\^\\?z]|\\u00ae|ar+)+)'
					when 's','z' then '(?:(?:s|\\$|5|\\u00a7|es+|z|2|7_|\\~/_|\\>_|\\%|zee+)+)'
					when 't' then '(?:(?:t|7|\\+|\\u2020|\\-\\|\\-|\\\'\\]\\[\\\')+)'
					when 'u','v' then '(?:(?:u|v|\\u00b5|[\\|\\(\\)\\[\\]]_[\\|\\(\\)\\[\\]]|\\L\\||\\/|you|yoo+|vee+)+)'
					when 'w' then '(?:(?:w|vv|\\\\/\\\\/|\\\\\\|/|\\\\\\\\\\\'|\\\'//|\\\\\\^/|\\(n\\)|double ?(?:u+|you|yoo+))+)'
					when 'x' then '(?:(?:x|\\>\\<|\\%|\\*|\\}\\{|\\)\\(|e[ck]+s+|ex+)+)'
					when 'y' then '(?:(?:y|\\u00a5|j|\\\'/|wh?(?:y+|ie+))+)'
					else char
					end
				else
					new_text += char
				end
				last_char = char
			end
			new_text
		end

		def protected_by_exceptionlist?(match_start,match_end,text,start_at)
			@exceptionlist.each do |list_item|
				exception_start = text[start_at,text.size].index(%r"#{BEG_REGEX}#{list_item}#{END_REGEX}"i)
				if exception_start and exception_start <= match_start then
					return true if exception_start + text[start_at,text.size][%r"#{BEG_REGEX}#{list_item}#{END_REGEX}"i].size >= match_end
				end
			end
			return false
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