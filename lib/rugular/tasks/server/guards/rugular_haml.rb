require 'guard/compat/plugin'
require 'action_view'
require 'haml'

module Guard
  class RugularHaml < Plugin
    include ActionView::Helpers::AssetTagHelper

    def initialize(opts = {})
      opts = {
        notifications:        true,
        default_ext:          'html',
        port:                 3111,
        auto_append_file_ext: false
      }.merge(opts)

      super(opts)

      if options[:input]
        watchers << ::Guard::Watcher.new(%r{^#{options[:input]}/([\w\-_]+(\.html)?\.haml)$})
      end
    end

    def start
      run_all
    end
    def stop; true end
    def reload; true end

    def run_all
    end

    def run_on_changes(paths)
      paths.each do |file|
        output_paths = _output_paths(file)
        compiled_haml = compile_haml(file)

        output_paths.each do |output_file|
          FileUtils.mkdir_p File.dirname(output_file)
          File.open(output_file, 'w') { |f| f.write(compiled_haml) }
        end

        message = "Successfully compiled haml to html!\n"
        message += "# #{file} -> #{output_paths.join(', ')}".gsub("#{::Bundler.root.to_s}/", '')
        ::Guard::UI.info message
      end
    end

    def run_on_removals(paths)

    end

    private

    def compile_haml(file)
      begin
        content = File.new(file).read
        engine  = ::Haml::Engine.new(content, (options[:haml_options] || {}))
        engine.render(get_binding)
      rescue StandardError => error
        message = "HAML compilation of #{file} failed!\nError: #{error.message}"
        ::Guard::UI.error message
        Notifier.notify(false, message) if options[:notifications]
        throw :task_has_failed
      end
    end

    # Get the file path to output the html based on the file being
    # built. The output path is relative to where guard is being run.
    #
    # @param file [String, Array<String>] path to file being built
    # @return [Array<String>] path(s) to file where output should be written
    #
    def _output_paths(file)
      input_file_dir = File.dirname(file)
      file_name = _output_filename(file)
      file_name = "#{file_name}.html" if _append_html_ext_to_output_path?(file_name)
      input_file_dir = input_file_dir.gsub(Regexp.new("#{options[:input]}(\/){0,1}"), '') if options[:input]

      if options[:output]
        Array(options[:output]).map do |output_dir|
          File.join(output_dir, input_file_dir, file_name)
        end
      else
        if input_file_dir == ''
          [file_name]
        else
          [File.join(input_file_dir, file_name)]
        end
      end
    end

    # Generate a file name based on the provided file path.
    # Provide a logical extension.
    #
    # Examples:
    #   "path/foo.haml"     -> "foo.html"
    #   "path/foo"          -> "foo.html"
    #   "path/foo.bar"      -> "foo.bar.html"
    #   "path/foo.bar.haml" -> "foo.bar"
    #
    # @param file String path to file
    # @return String file name including extension
    #
    def _output_filename(file)
      sub_strings           = File.basename(file).split('.')
      base_name, extensions = sub_strings.first, sub_strings[1..-1]

      if extensions.last == 'haml'
        extensions.pop
        if extensions.empty?
          [base_name, options[:default_ext]].join('.')
        else
          [base_name, extensions].flatten.join('.')
        end
      else
        [base_name, extensions, options[:default_ext]].flatten.join('.')
      end
    end

    def _append_html_ext_to_output_path?(filename)
      return unless options[:auto_append_file_ext]

      filename.match("\.html?").nil?
    end

    def get_binding
      @_binding ||= binding
    end

    # Override Action View to exclude the 'stylesheets' folder.
    def stylesheet_link_tag(*sources)
      options = sources.extract_options!.stringify_keys
      path_options = options.extract!('protocol').symbolize_keys
      copy_bower_files(
        sources.select { |source| source.match('bower_component') }
      )

      sources.uniq.map { |source|
        tag_options = {
          "rel" => "stylesheet",
          "media" => "screen",
          "href" => source.gsub('.tmp/', '')
        }.merge!(options)
        tag(:link, tag_options)
      }.join("\n").html_safe

    end

    # Override Action View to exclude the 'javascripts' folder.
    def javascript_include_tag(*sources)
      options = sources.extract_options!.stringify_keys
      path_options = options.extract!('protocol', 'extname').symbolize_keys
      copy_bower_files(
        sources.select { |source| source.match('bower_component') }
      )

      sources.uniq.map { |source|
        tag_options = {
          "src" => source.gsub('.tmp/', '')
        }.merge!(options)
        content_tag(:script, "", tag_options)
      }.join("\n").html_safe

    end

    def copy_bower_files(bower_components)
      bower_components.each do |bower_component|
        FileUtils.mkdir_p(File.dirname(bower_component.gsub('bow', '.tmp/bow')))
        FileUtils.cp_r(bower_component, bower_component.gsub('bow', '.tmp/bow'))
      end
    end

  end
end

