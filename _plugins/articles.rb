# frozen_string_literal: true

# Article collection housekeeping.
#
# Runs at :high priority so it lands before tag_pages.rb builds its index —
# otherwise a withheld draft would still contribute its tags.

require "date"
require "time"

module Articles
  class Prepare < Jekyll::Generator
    safe false
    priority :high

    def generate(site)
      collection = site.collections["articles"]
      return if collection.nil?

      collection.docs.each { |doc| normalise_date!(doc) }
      # Ascending, matching Jekyll's own convention; templates reverse it.
      collection.docs.sort_by! { |doc| doc.data["date"] }

      withhold_drafts!(collection) if Jekyll.env == "production"
    end

    private

    # A collection has no filename date to fall back on, and mtime is not an
    # option: actions/checkout resets it, so ordering would silently reshuffle
    # on every deploy. Better a loud build failure than a scrambled index.
    def normalise_date!(doc)
      value = doc.data["date"]

      normalised =
        case value
        when Time     then value
        when DateTime then value.to_time
        when Date     then value.to_time
        when String   then (Time.parse(value) rescue nil)
        end

      if normalised.nil?
        raise Jekyll::Errors::FatalException,
              "#{doc.relative_path}: articles need a valid `date:` in their front matter " \
              "(got #{value.inspect})"
      end

      doc.data["date"] = normalised
    end

    # Removing drafts from the collection rather than filtering them in
    # templates means no page is ever *written*, so there is no orphan sitting
    # at a guessable URL in the deployed artifact.
    def withhold_drafts!(collection)
      drafts, published = collection.docs.partition { |doc| doc.data["draft"] }
      return if drafts.empty?

      collection.docs.replace(published)
      Jekyll.logger.info "articles:", "withheld #{drafts.size} draft(s) from the production build"
    end
  end
end
