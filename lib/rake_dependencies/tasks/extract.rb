require 'rake_factory'
require 'zip'

require_relative '../template'
require_relative '../extractors'

module RakeDependencies
  module Tasks
    class Extract < RakeFactory::Task
      default_name :extract
      default_description RakeFactory::DynamicValue.new { |t|
        "Extract #{t.dependency} archive"
      }

      parameter :type, default: :zip
      parameter :os_ids, default: {
          mac: 'mac',
          linux: 'linux'
      }
      parameter :extractors, default: {
          zip: Extractors::ZipExtractor,
          tar_gz: Extractors::TarGzExtractor,
          tgz: Extractors::TarGzExtractor,
          uncompressed: Extractors::UncompressedExtractor
      }

      parameter :distribution_directory, default: 'dist'
      parameter :binary_directory, default: 'bin'

      parameter :dependency, required: true
      parameter :version
      parameter :path, required: true
      parameter :file_name_template, required: true
      parameter :source_binary_name_template
      parameter :target_binary_name_template
      parameter :strip_path_template

      action do
        parameters = {
            version: version,
            platform: platform,
            os_id: os_id,
            ext: ext
        }

        distribution_file_name = Template.new(file_name_template)
            .with_parameters(parameters)
            .render
        distribution_file_directory = File.join(path, distribution_directory)
        distribution_file_path = File.join(
            distribution_file_directory, distribution_file_name)

        extraction_path = File.join(path, binary_directory)

        options = {}
        if strip_path_template
          options[:strip_path] = Template.new(strip_path_template)
              .with_parameters(parameters)
              .render
        end

        if source_binary_name_template && target_binary_name_template
          options[:rename_from] = Template.new(source_binary_name_template)
              .with_parameters(parameters)
              .render
          options[:rename_to] = Template.new(target_binary_name_template)
              .with_parameters(parameters)
              .render
        end

        extractor = extractor_for_extension.new(
            distribution_file_path,
            extraction_path,
            options)
        extractor.extract
      end

      private

      def extractor_for_extension
        extractors[resolved_type]
      end

      def os_id
        os_ids[platform]
      end

      def platform
        RUBY_PLATFORM =~ /darwin/ ? :mac : :linux
      end

      def resolved_type
        type.is_a?(Hash) ? type[platform].to_sym : type.to_sym
      end

      def ext
        case resolved_type
        when :tar_gz then
          '.tar.gz'
        when :tgz then
          '.tgz'
        when :zip then
          '.zip'
        when :uncompressed then
          ''
        else
          raise "Unknown type: #{type}"
        end
      end
    end
  end
end
