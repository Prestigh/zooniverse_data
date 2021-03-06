module ZooniverseData
  module Projects
    class Orchid
      include Helpers

      def customize_subject
        if entry.location['standard'].is_a?(Array)
          thumbs = []
          entry.location['standard'].each do |image|
            original = convert_image(image).input_image
            thumbs << converter_for(original.path, type: 'thumbnail', max_size: 300, quality: 50)
          end
          entry.update :$set => {
            'location.thumb' => thumbs,
          }
        else
          original = convert_image(entry.location['standard']).input_image
          thumb = converter_for(original.path, type: 'thumbnail', max_size: 300, quality: 50)
          entry.update :$set => {
            'location.thumb' => thumb,
          }
        end
      end

      private

        def converter_for(path, type: nil, max_size: nil, quality: 80)
          convert_image(path, remove_original: false)
            .resize(width: max_size, height: max_size, force: false)
            .quality(quality)
            .write_to(prefix: type)
            .path
        end
    end
  end
end
