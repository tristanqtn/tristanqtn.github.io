source "https://rubygems.org"

gem "jekyll", "~> 4.3"

group :jekyll_plugins do
  gem "jekyll-seo-tag", "~> 2.8"
  gem "jekyll-sitemap", "~> 1.4"
end

# Required explicitly, not transitively: _plugins/raw_files.rb `require`s Rouge
# directly to highlight hosted files outside of kramdown.
gem "rouge", "~> 4.2"

# Ruby >= 3.0 no longer bundles webrick, and `jekyll serve` needs it.
gem "webrick", "~> 1.8"

platforms :mingw, :x64_mingw, :mswin, :jruby do
  gem "tzinfo", ">= 1", "< 3"
  gem "tzinfo-data"
end
