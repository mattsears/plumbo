# frozen_string_literal: true

module Plumbo
  # Finds the Stimulus controllers referenced by a page and nests each one under
  # the template/partial whose source declares it. Controllers are discovered by
  # scanning a file's source for data-controller attributes, then mapping each
  # identifier to its source file via Stimulus's naming convention. No asset
  # pipeline or digest guessing is involved: the mapping is deterministic.
  #
  #   data-controller="hello"            -> app/javascript/controllers/hello_controller.js
  #   data-controller="date-picker"      -> app/javascript/controllers/date_picker_controller.js
  #   data-controller="users--list-item" -> app/javascript/controllers/users/list_item_controller.js
  #
  # (A "--" in an identifier is a directory separator; a "-" is a word separator.)
  module Stimulus
    ATTRIBUTE = /data-controller\s*=\s*["']([^"']*)["']/i

    module_function

    # Given the ordered [path, depth] file list, returns a new list with each
    # template/partial's Stimulus controllers inserted right after it, nested one
    # level deeper — so a controller appears under the view/partial that
    # references it. Files whose source can't be read (or non-.erb files)
    # contribute no children.
    def nest(files, config)
      return files unless config.include_stimulus

      files.flat_map { |path, depth| [[path, depth]] + children(path, depth, config) }
    end

    def children(path, depth, config)
      source = source_for(path, config)
      return [] unless source

      controllers(source, config).map { |controller| [controller, depth + 1] }
    end

    # Reads the on-disk source of a rendered template/partial (only .erb files),
    # reconstructing the absolute path from the prefixed path and the root.
    def source_for(path, config)
      return unless path.end_with?(".erb")

      absolute = File.join(config.root, path.delete_prefix(config.path_prefix))
      File.file?(absolute) ? File.read(absolute) : nil
    end

    # Source paths for every Stimulus controller referenced in +markup+, prefixed
    # and deduped (first occurrence wins). Empty when disabled or none are found.
    def controllers(markup, config)
      return [] unless config.include_stimulus

      identifiers(markup).map { |id| path_for(id, config) }.uniq
    end

    # Each whitespace-separated identifier across all data-controller attributes.
    def identifiers(markup)
      markup.scan(ATTRIBUTE).flatten.flat_map(&:split)
    end

    def path_for(identifier, config)
      file = "#{identifier.gsub('--', '/').gsub('-', '_')}_controller.js"
      "#{config.path_prefix}#{config.javascript_root}/controllers/#{file}"
    end
  end
end
