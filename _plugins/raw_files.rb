# frozen_string_literal: true

# Raw file hosting.
#
# `raw/` is deliberately listed in _config.yml's `exclude:`, so Jekyll's reader
# never touches it. This generator walks the tree itself and registers a plain
# Jekyll::StaticFile for every file it finds, which Jekyll writes with a bare
# FileUtils.copy_file.
#
# That indirection is the whole point. Jekyll decides "page or static file" by
# sniffing whether a file starts with `---`, which means an ordinary YAML config
# would be swallowed as front matter, run through Liquid, and served corrupted.
# On a site whose job is hosting configs and shell scripts people pipe into
# `sh`, that is not a hypothetical. Bypassing the reader makes byte-identity a
# property of the design rather than something to remember.
#
# On top of that it builds, for each file, a syntax-highlighted preview page at
# /files/<path>.html, plus /files/SHA256SUMS.txt and /files/manifest.json.

require "digest"
require "fileutils"
require "json"
require "rouge"
require "time"

module RawFiles
  RAW_DIR     = "raw"
  RAW_URL     = "/raw"
  PREVIEW_DIR = "files"
  PREVIEW_URL = "/files"

  # Read the whole file only up to here; above it we report metadata only.
  READ_CAP            = 8 * 1024 * 1024
  # Above either of these, highlight just the head and link out to the raw file.
  MAX_HIGHLIGHT_BYTES = 256 * 1024
  MAX_HIGHLIGHT_LINES = 3_000
  HEAD_LINES          = 500
  BINARY_SNIFF_BYTES  = 8 * 1024

  # Editor and OS detritus. Note that .gitignore is *not* here — a .gitignore
  # template is a perfectly reasonable thing to want to host.
  SKIP_NAMES = %w[.DS_Store .gitkeep Thumbs.db desktop.ini].freeze
  SKIP_RE    = [/\.swp\z/, /\.swo\z/, /~\z/].freeze

  module_function

  def human_size(bytes)
    return "#{bytes} B" if bytes < 1024

    value = bytes.to_f
    %w[KiB MiB GiB TiB].each do |unit|
      value /= 1024
      return format("%.1f %s", value, unit) if value < 1024
    end
    format("%.1f TiB", value)
  end

  def count_lines(text)
    return 0 if text.empty?

    text.count("\n") + (text.end_with?("\n") ? 0 : 1)
  end

  # Returns a Rouge lexer *class*. Passing `source:` lets Rouge fall back to
  # shebang sniffing, so `raw/scripts/bootstrap` with no extension at all still
  # highlights as bash.
  def lexer_for(name, source)
    Rouge::Lexer.guess(filename: name, source: source) || Rouge::Lexers::PlainText
  rescue Rouge::Guesser::Ambiguous => e
    e.alternatives.first
  rescue StandardError
    Rouge::Lexers::PlainText
  end

  def formatter
    @formatter ||= Rouge::Formatters::HTMLTable.new(
      Rouge::Formatters::HTML.new,
      table_class:  "rouge-table",
      gutter_class: "rouge-gutter",
      code_class:   "rouge-code"
    )
  end

  # The rendered HTML is handed to the template through page.data, never
  # page.content. Liquid does not parse data values, so a hosted file
  # containing `{{ ... }}` or `{% ... %}` — a Jinja template, a Helm chart, a
  # GitHub Actions workflow — renders as text instead of executing or blowing
  # up the build. Rouge's HTML formatter escapes < > &, so hosted content
  # cannot inject markup either.
  def highlight(text, lexer_class)
    inner = formatter.format(lexer_class.new.lex(text))
    %(<div class="highlighter-rouge language-#{lexer_class.tag}">) +
      %(<div class="highlight">#{inner}</div></div>)
  end

  class Generator < Jekyll::Generator
    safe false
    priority :normal

    def generate(site)
      root = File.join(site.source, RawFiles::RAW_DIR)

      unless Dir.exist?(root)
        Jekyll.logger.warn "raw:", "#{RawFiles::RAW_DIR}/ not found — nothing to host"
        site.data["raw_files"] = empty_aggregate
        return
      end

      entries = collect(site, root)

      entries.each do |entry|
        register_static_file(site, entry)
        site.pages << preview_page(site, entry)
      end

      site.data["raw_files"] = aggregate(entries)
      Jekyll.logger.info "raw:", "hosting #{entries.size} files from #{RawFiles::RAW_DIR}/"
    end

    private

    def collect(site, root)
      Dir.glob("**/*", File::FNM_DOTMATCH, base: root).sort.filter_map do |rel|
        abs  = File.join(root, rel)
        name = File.basename(rel)

        next if name == "." || name == ".."
        next if File.directory?(abs)
        next if RawFiles::SKIP_NAMES.include?(name)
        next if RawFiles::SKIP_RE.any? { |re| name.match?(re) }

        # upload-pages-artifact does not preserve symlink semantics; a symlink
        # here would silently publish something from outside raw/.
        if File.symlink?(abs)
          Jekyll.logger.warn "raw:", "skipping symlink #{rel}"
          next
        end

        if name.match?(/\s/) || rel.include?("{{") || rel.include?("{%")
          Jekyll.logger.warn "raw:", "#{rel} has an awkward filename (whitespace or Liquid delimiters)"
        end

        build_entry(site, rel, abs)
      end
    end

    def build_entry(_site, rel, abs)
      stat   = File.stat(abs)
      size   = stat.size
      subdir = File.dirname(rel)
      subdir = "" if subdir == "."
      name   = File.basename(rel)

      head   = File.binread(abs, RawFiles::BINARY_SNIFF_BYTES).to_s
      binary = head.include?("\x00")
      oversize = size > RawFiles::READ_CAP

      text = nil
      unless binary || oversize
        raw = File.binread(abs).force_encoding(Encoding::UTF_8)
        if raw.valid_encoding?
          text = raw
        else
          binary = true
        end
      end

      lines       = text && RawFiles.count_lines(text)
      lexer_class = RawFiles.lexer_for(name, text)

      truncated   = false
      highlighted = nil
      if text
        if size > RawFiles::MAX_HIGHLIGHT_BYTES || lines > RawFiles::MAX_HIGHLIGHT_LINES
          truncated = true
          text = text.lines.first(RawFiles::HEAD_LINES).join
        end
        highlighted = RawFiles.highlight(text, lexer_class)
      end

      {
        "name"       => name,
        "path"       => rel,
        "dir"        => subdir,
        "ext"        => File.extname(name).delete_prefix("."),
        "url"        => "#{RawFiles::RAW_URL}/#{rel}",
        "page_url"   => "#{RawFiles::PREVIEW_URL}/#{rel}.html",
        "size"       => size,
        "size_human" => RawFiles.human_size(size),
        "lines"      => lines,
        "language"   => lexer_class.title,
        "lexer_tag"  => lexer_class.tag,
        "mtime"      => stat.mtime,
        "sha256"     => Digest::SHA256.file(abs).hexdigest,
        "binary"     => binary,
        "oversize"   => oversize,
        "truncated"  => truncated,
        # Not part of the public entry shape; consumed by preview_page below.
        :highlighted => highlighted,
      }
    end

    # The byte-identity guarantee, in four lines. StaticFile#write is a bare
    # FileUtils.copy_file — no read, no parse, no render.
    def register_static_file(site, entry)
      dir = entry["dir"].empty? ? "/#{RawFiles::RAW_DIR}" : "/#{RawFiles::RAW_DIR}/#{entry['dir']}"
      site.static_files << Jekyll::StaticFile.new(site, site.source, dir, entry["name"])
    end

    # A real .html file rather than <name>/index.html: the directory form would
    # depend on the Pages server redirecting a directory literally named
    # "install.sh", and the suffix keeps "preview page" visually distinct from
    # "the actual bytes".
    def preview_page(site, entry)
      dir = entry["dir"].empty? ? RawFiles::PREVIEW_DIR : File.join(RawFiles::PREVIEW_DIR, entry["dir"])
      page = Jekyll::PageWithoutAFile.new(site, site.source, dir, "#{entry['name']}.html")

      page.data.merge!(
        "layout"      => "file",
        "title"       => entry["name"],
        "description" => "#{entry['name']} — #{entry['size_human']}, #{entry['language']}",
        "permalink"   => entry["page_url"],
        "file"        => entry.reject { |k, _| k.is_a?(Symbol) },
        "highlighted" => entry[:highlighted]
      )
      page.content = ""
      page
    end

    def empty_aggregate
      { "count" => 0, "total_bytes" => 0, "total_human" => "0 B", "groups" => [], "all" => [] }
    end

    # An array of groups rather than a hash, so Liquid iterates in a defined
    # order without destructuring [key, value] pairs.
    def aggregate(entries)
      public_entries = entries.map { |e| e.reject { |k, _| k.is_a?(Symbol) } }
      total = public_entries.sum { |e| e["size"] }

      groups = public_entries
               .group_by { |e| e["dir"] }
               .sort_by { |dir, _| [dir.empty? ? 0 : 1, dir] }
               .map do |dir, files|
        {
          "dir"   => dir,
          "label" => dir.empty? ? "#{RawFiles::RAW_DIR}/" : "#{RawFiles::RAW_DIR}/#{dir}/",
          "count" => files.size,
          "files" => files.sort_by { |e| e["name"] },
        }
      end

      {
        "count"       => public_entries.size,
        "total_bytes" => total,
        "total_human" => RawFiles.human_size(total),
        "groups"      => groups,
        "all"         => public_entries,
      }
    end
  end
end

# SHA256SUMS.txt and manifest.json are written directly rather than as Jekyll
# pages, because page content goes through Liquid and a hosted filename
# containing `{{` would break the build. Writing post_write sidesteps that
# entirely — and these are machine-readable artifacts with no layout anyway.
Jekyll::Hooks.register :site, :post_write do |site|
  data = site.data["raw_files"]
  next if data.nil? || data["all"].empty?

  dir = File.join(site.dest, RawFiles::PREVIEW_DIR)
  FileUtils.mkdir_p(dir)

  # `sha256sum -c` format: digest, two spaces, path.
  sums = data["all"].map { |e| "#{e['sha256']}  #{e['path']}" }.join("\n")
  File.write(File.join(dir, "SHA256SUMS.txt"), "#{sums}\n")

  manifest = {
    "generated" => site.time.utc.iso8601,
    "base_url"  => "#{site.config['url']}#{RawFiles::RAW_URL}",
    "count"     => data["count"],
    "files"     => data["all"].map { |e| e.merge("mtime" => e["mtime"].utc.iso8601) },
  }
  File.write(File.join(dir, "manifest.json"), "#{JSON.pretty_generate(manifest)}\n")
end
