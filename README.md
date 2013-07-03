# LanguageFilter

LanguageFilter is a Ruby gem to detect and optionally filter multiple categories of language. It was adapted from Thiago Jackiw's Obscenity gem to create a simple, intuitive way to detect and optionally filter multiple categories of language, originally for FractalWriting.org's diverse community.

With multiple language categories and 

## Installation

Add this line to your application's Gemfile:

``` ruby
gem 'language_filter'
```

And then execute:

``` bash
$ bundle
```

Or install it yourself as:

``` bash
$ gem install language_filter
```

## Usage

Need a new language filter? Here's a quick usage example:

``` ruby
sex_filter = LanguageFilter::Filter.new matchlist: :sex, replacement: :stars

# returns true if any content matched the filter's matchlist, else false
sex_filter.match?('This is some sexual content.')
=> true

# returns a "cleaned up" version of the text, based on the replacement rule
sex_filter.sanitize('This is some sexual content.')
=> "This is some ****** content."

# returns an array of the words and phrases that matched an item in the matchlist
sex_filter.matched('This is some sexual content.')
=> ["sexual"]
```

Now let's go over this a little more methodically. When you create a new LanguageFilter, you simply call LanguageFilter::Filter.new, with any of the following optional parameters. Below, you can see their defaults.

``` ruby
LanguageFilter::Filter.new(
                            matchlist: :profanity,
                            exceptionlist: [],
                            replacement: :stars
                          )
```

Now let's dive a little deeper into each parameter.

### `:matchlist` and `:exceptionlist`

Both of these lists can take four different kinds of inputs.

#### Symbol signifying a pre-packaged list

By default, LanguageFilter comes with four different matchlists, each screening for a different category of language. These filters are accessible via:

- `matchlist: :hate` (for hateful language, like `f**k you`, `b***h`, or *fag* itself)
- `matchlist: :profanity` (for swear/cuss words and phrases)
- `matchlist: :sex` (for content of a sexual nature)
- `matchlist: :violence` (for language indicating violence, such as `stab`, `gun`, or `murder`)

There's quite a bit of overlap between these lists, but they can be useful for communities that may want to self-monitor, giving them an idea of the kind of content in a story or article before clicking through. This is how it's used on FractalWriting.org.

#### An array of words and phrases to screen for

- `matchlist: ['giraffes?','rhino\w*','elephants?'] # a non-exhaustive list of African animals`

As you may have noticed, you can include regex! However, if you do, keep in mind that the more complicated regex you include, the slow the matching will be. Also, if you're assigning an array directly to matchlist and want to use regex, be sure to use single quotes (`'text'`), rather than double quotes (`"text"`). Otherwise, Ruby will think your backslashes are to help it interpolate the string, rather than to be intrepreted literally. 

In the actual matching, each item you enter in the list is dumped into the middle of the following regex for matching, through the `list_item` variable.

``` ruby
/\b#{list_item}\b/i
```

There's not a whole lot going on there, but I'll quickly parse it for any who aren't very familiar with regex.

- `#{list_item}` just dumps in our an item from our list that we want to check.
- The two `\b` on either side ensures that only text surrounded by non-word characters (anything other letters, numbers, and the underscore) or the beginning or end of a string, are matched.
- The two `/` wrapping (almost) the whole statement lets Ruby know that this is a regex statement.
- The `i` right after the regex tells it to match case-insensitive, so that whether someone writes `giraffe`, `GIRAFFE`, or `gIrAffE`, the match won't fail.

If you'd like to master some regex Rubyfu, I highly recommend stopping at [Rubular.com](http://rubular.com/).

#### A filepath or string pointing to a filepath

If you want to use your own lists, there are two ways to do it.

Pass in a dynamically generated filepath (which is my preferred method):

``` ruby ```
matchlist: File.join(Rails.root,"/config/language_filters/my_custom_list.yml")
```

Pass in a string with a filepath, which may look something like this:

``` ruby ```
matchlist: "/home/username/webapps/rails/my_app/config/filters/violence.yml"
```

If you haven't already guessed why I prefer the first method, it's because it won't break if you move your Rails app to a different folder.

##### Formatting your lists

Now when you're actually writing these lists, they both use the same, relatively simple format, which looks something like this:

``` regex
giraffes?
rhino\w*
elephants?
```

It's a pretty simple pattern. Each word, phrase, or regex is on its own line - and that's it.

### `:replacement`

If you're not using this gem to filter out potentially offensive content, then you don't have to worry about this part. For the rest of you the `:replacement` parameter specifies what to replace matches with, when sanitizing text.

Here are the options:

`replacement: :stars` (this is the default replacement method)
Example: This is some ****** up ****.

`replacement: :garbled`
Example: This is some $@!#% up $@!#%.

`replacement: :vowels`
Example: This is some f*ck*d up sh*t.

`replacement: :nonconsonants` (useful where letters might be replaced with numbers, for example in L3375P34|< - i.e. leetspeak)
Example: 7|-|1$ 1$ $0/\/\3 PhU****D UP ******.

### Methods to modify filters after creation

If you ever want to change the matchlist, exceptionlist, or replacement type, each parameter is accessible via an assignment method.

For example:

``` ruby
my_filter = LanguageFilter::Filter.new(
                                        matchlist: ['dog(s)?'], 
                                        exceptionlist: ['dogs drool'],
                                        replacement: :garbled
                                      )

my_filter.sanitize('Dogs rule, cats drool!')
=> "$@!#% rule, cats drool!"
my_filter.sanitize('Cats rule, dogs drool!')
=> "Cats rule, dogs drool!"

my_filter.matchlist = ['dog(s)?','cats drool']
my_filter.exceptionlist = ['dogs drool','dogs are cruel']
my_filter.replacement = :stars

my_filter.sanitize('Dogs rule, cats drool!')
=> "**** rule, **********!"
my_filter.sanitize('Cats rule, dogs drool!')
=> "Cats rule, dogs drool!"
```

In the above case though, we just wanted to add items to the existing lists, so there's actually a better solution. They're stored as arrays, so treat them as such. Any array methods are fair game.

For example:

``` ruby
my_filter.matchlist.delete "dogs drool"
my_filter.matchlist << "dogs are mean"
my_filter.matchlist.uniq!
# etc...
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
