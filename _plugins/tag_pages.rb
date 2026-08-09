# frozen_string_literal: true

# One page per tag, generated from whatever tags actually exist. Worth doing
# because the generator machinery is already here for raw_files.rb — it removes
# the whole class of "added a tag, forgot to create its page" bugs.
#
# Runs at :low priority, after articles.rb has withheld drafts.

module TagPages
  class Generator < Jekyll::Generator
    safe false
    priority :low

    def generate(site)
      collection = site.collections["articles"]
      return if collection.nil?

      index = Hash.new { |hash, key| hash[key] = [] }
      collection.docs.each do |doc|
        Array(doc.data["tags"]).each { |tag| index[tag.to_s] << doc }
      end

      index.each do |tag, docs|
        site.pages << build_page(site, tag, docs)
      end

      Jekyll.logger.info "tags:", "generated #{index.size} tag page(s)" unless index.empty?
    end

    private

    def build_page(site, tag, docs)
      slug = Jekyll::Utils.slugify(tag)
      page = Jekyll::PageWithoutAFile.new(site, site.source, File.join("tags", slug), "index.html")

      page.data.merge!(
        "layout"      => "tag",
        "title"       => "##{tag}",
        "description" => "Articles tagged #{tag}.",
        "permalink"   => "/tags/#{slug}/",
        "tag"         => tag,
        "tag_docs"    => docs.sort_by { |doc| doc.data["date"] }.reverse,
        # Thin aggregation pages; they only dilute the index.
        "sitemap"     => false
      )
      page
    end
  end
end
