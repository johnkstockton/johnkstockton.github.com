module Jekyll
  module PhotoList
    def make_photo_list(photos)
      photos = photos.map do |url|
        "'/assets/images/#{url}'"
      end
      '[' + photos.join(',') + ']'
    end
  end
end

Liquid::Template.register_filter(Jekyll::PhotoList)
