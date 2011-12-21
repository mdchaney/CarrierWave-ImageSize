module CarrierWave
  module ImageSize

    # Requirements:
    # imagemagick - in particular the "identify" command
    #
    # Include CarrierWave::ImageSize in your CarrierWave uploader
    # to have image sizes and content type automatically stored
    # along with the image.  For this to work, you must create a
    # second column in your database named:
    #
    #   "#{image_name}_information"
    #
    # For instance, if your image is named "pic", you need to create
    # a string or text column named "pic_information".
    #
    #   t.string :pic, :limit => 250
    #   t.string :pic_information, :limit => 250
    #
    # In your model, you mount the uploader
    #
    #   mount_uploader :pic, PicUploader
    #
    # And in the uploader, you include CarrierWave::ImageSize:
    # 
    #   class LogoUploader < CarrierWave::Uploader::Base
    #
    #     ...
    #     include CarrierWave::ImageSize
    #
    # Note that you might also need to "require" it at the top
    # of the file:
    #
    #   require 'carrier_wave/image_size'
    #
    # You now have three new methods on your uploaded pictures:
    #
    #   image_width, image_height - returns height and width of images
    #       as integers
    #
    #   content_type - returns the original content type of the image
    #
    # Note that nested versions are fully supported and you can use
    # these methods with any of your versions:
    #
    #   version :thumb do
    #     process :resize_to_fit => [50, 50]
    #     version :tiny do
    #       process :resize_to_fit => [10, 10]
    #     end
    #   end
    #
    # In your code:
    #
    #   artist.pic.thumb.tiny.image_width
    #
    # Additionally, your form should propogate the _information field
    # along with the cache, otherwise the content type will be lost.
    #
    #   <%= f.file_field :pic %>
    #   <%= f.hidden_field :pic_cache %>
    #   <%= f.hidden_field :pic_information unless f.object.pic_cache.blank? %>
    #
    # The only limitation is that you cannot create a version of your
    # picture called "base", as I use that for storing the size of the
    # base image.  If you really badly need to use "base", search for "base"
    # below and change it to something else.
    #
    # Internally, the _information field is simply a string:
    #
    #   "image/png\nbase:200x150\nthumb:20x15\nthumb_tiny:10x7\n"
    #
    # Where the sizes are simply width x height.  The content_type
    # is saved across "recreate_versions!".
    #
    # Improvements (TODO):
    #
    #   1. This should be turned into a gem
    #   2. Could probably better use the image processor (i.e. minimagick)
    #      to get size information
    #   3. Needs some tests

    def image_width
      info_field(my_version_name).first rescue nil
    end

    def image_height
      info_field(my_version_name).last rescue nil
    end

    def content_type
      info_field('content_type')
    end

    CarrierWave::Uploader::Base::after :cache, :capture_size_before_cache

    protected

    def my_version_name
      (self.version_name || 'base').to_s
    end

    private

    def capture_size_before_cache(new_file) 
      if has_info_field?
        if has_info?
          prev_content_type = info_field('content_type')
        end
        set_info((new_file.content_type.blank? ? prev_content_type : new_file.content_type) + "\n" + drill_for_info(model.send(mounted_as)).collect { |k,v| sprintf("%s:%dx%d\n",k,v[0],v[1]) }.join() )
      end
    end 

    def drill_for_info(obj, hash = {})
      hash[obj.my_version_name] = do_identify(obj.current_path)
      obj.versions.keys.each { |v| drill_for_info(obj.send(v), hash) }
      hash
    end

    def info_field_name
      "#{mounted_as}_information"
    end

    def raw_info_field
      model[info_field_name]
    end

    def info_field(datum)
      if datum == 'content_type'
        raw_info_field.split(/\n/).first
      else
        md = /^#{datum}:(\d+)x(\d+)$/.match(raw_info_field)
        if md
          md[1..2]
        else
          nil
        end
      end
    end

    def has_info_field?
      model.respond_to?(info_field_name)
    end

    def has_info?
      has_info_field? && raw_info_field.is_a?(String)
    end

    def set_info(new_info)
      model.send("#{info_field_name}=", new_info)
    end

    def do_identify(filename)
      ret = nil
      IO.popen(['identify', '-format', '%wx%h', filename]) { |f| ret = f.gets.chomp }
      !ret.blank? ? ret.split(/x/).collect { |x| x.to_i } : nil
    end

  end
end
