Delayed::Paperclip [![Build Status](https://travis-ci.org/jrgifford/delayed_paperclip.svg?branch=master)](https://travis-ci.org/jrgifford/delayed_paperclip) [![Code Climate](https://codeclimate.com/github/jrgifford/delayed_paperclip.png)](https://codeclimate.com/github/jrgifford/delayed_paperclip)
======================================================================================


DelayedPaperclip lets you process your [Paperclip](http://github.com/thoughtbot/paperclip)
attachments in a background task with [ActiveJob](https://github.com/rails/rails/tree/master/activejob)

Why?
----

The most common use case for Paperclip is to easily attach image files
to ActiveRecord models. Most of the time these image files will have
multiple styles and will need to be resized when they are created. This
is usually a pretty slow operation and should be handled in a background task.

I’m sure that everyone knows this, this gem just makes it easy to do.

Installation
------------

Install the gem:

```
gem install delayed_paperclip
```

Or even better, add it to your Gemfile.

```
source "https://rubygems.org"
gem "delayed_paperclip"
```

Usage
-----

In your model:

```ruby
class User < ActiveRecord::Base
  has_attached_file :avatar, styles: {
                                       medium: "300x300>",
                                       thumb: "100x100>"
                                     }

  process_in_background :avatar
end
```

Use your Paperclip attachment just like always in controllers and views.

### Displaying images during processing

In the default setup, when you upload an image for the first time and
try to display it before the job has been completed, Paperclip will be
none the wiser and output the url of the image which is yet to be
processed, which will result in a broken image link being displayed on
the page.

To have the missing image url be outputted by paperclip while the image is being processed, all you need to do is add a
`#{attachment_name}_processing` column to the specific model you want
to enable this feature for. This feature gracefully degrades and will not affect models which do not have the column added to them.

```ruby
class AddAvatarProcessingToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :avatar_processing, :boolean
  end

  def self.down
    remove_column :users, :avatar_processing
  end
end

@user = User.new(avatar: File.new(...))
@user.save
@user.avatar.url #=> "/images/original/missing.png"

# Process job

@user.reload
@user.avatar.url #=> "/system/images/3/original/IMG_2772.JPG?1267562148"
```

#### Custom image for processing

This is useful if you have a difference between missing images and
images currently being processed.

```ruby
class User < ActiveRecord::Base
  has_attached_file :avatar

  process_in_background :avatar, processing_image_url: "/images/:style/processing.jpg"
end

@user = User.new(avatar: File.new(...))
@user.save
@user.avatar.url #=> "/images/original/processing.png"

# Process job

@user.reload
@user.avatar.url #=> "/system/images/3/original/IMG_2772.JPG?1267562148"
```

You can also define a custom logic for `processing_image_url`, for
example to display the original picture while specific formats are being processed.

```ruby
class Item < ActiveRecord::Base
  has_attached_file :photo

  process_in_background :photo, processing_image_url: :processing_image_fallback

  def processing_image_fallback
    options = photo.options
    options[:interpolator].interpolate(options[:url], photo, :original)
  end
end
```

Another option is to provide an object which responds to `call` to `processing_image_url` and returns the image url. The method will be called with the attachment as the argument. 

```ruby
class Item < ActiveRecord::Base
  has_attached_file :photo

  process_in_background :photo, processing_image_url: ->(attachment) {
    ActionController::Base.helpers.image_path("processing.gif")
  }
end
```

#### Have processing? status available, but construct image URLs as if delayed_paperclip wasn’t present

If you define the `#{attachment_name}_processing` column, but set the
`url_with_processing` option to false, this opens up other options (other than modifying the url that paperclip returns) for giving feedback to the user while the image is processing. This is useful for advanced situations, for example when dealing with caching systems.

Note especially the method #processing? which passes through the value
of the boolean created via migration.

```ruby
class User < ActiveRecord::Base
  has_attached_file :avatar

  process_in_background :avatar, url_with_processing: false
end

@user = User.new(avatar: File.new(...))
@user.save
@user.avatar.url #=> "/system/images/3/original/IMG_2772.JPG?1267562148"
@user.avatar.processing? #=> true

# Process job

@user.reload
@user.avatar.url #=> "/system/images/3/original/IMG_2772.JPG?1267562148"
@user.avatar.processing? #=> false
```

#### Only process certain styles

This is useful if you don’t want the background job to reprocess all
styles.

```ruby
class User < ActiveRecord::Base
  has_attached_file :avatar, styles: { small: "25x25#", medium: "50x50#" }

  process_in_background :avatar, only_process: [:small]
end
```

Like paperclip, you could also supply a lambda function to define
`only_process` dynamically.

```ruby
class User < ActiveRecord::Base
  has_attached_file :avatar, styles: { small: "25x25#", medium: "50x50#" }

  process_in_background :avatar, only_process: lambda { |a| a.instance.small_supported? ? [:small, :large] : [:large] }
end
```

#### Split processing

You can process some styles in the foreground and some in the background
by setting `only_process` on both `has_attached_file` and
`process_in_background`.

```ruby
class User < ActiveRecord::Base
  has_attached_file :avatar, styles: { small: "25x25#", medium: "50x50#" }, only_process: [:small]

  process_in_background :avatar, only_process: [:medium]
end
```

#### Reprocess Without Delay

This is useful if you don’t want the background job. It accepts
individual styles too. Take note, normal `reprocess!` does not accept styles as arguments anymore. It will delegate to DelayedPaperclip and
reprocess all styles.

```ruby
class User < ActiveRecord::Base
  has_attached_file :avatar, styles: { small: "25x25#", medium: "50x50#" }

  process_in_background :avatar
end

@user.avatar.url #=> "/system/images/3/original/IMG_2772.JPG?1267562148"
@user.avatar.reprocess_without_delay!(:medium)
```

#### Set queue name

You can set queue name for background job. By default it's called "paperclip".
You can set it by changing global default options or by:

```ruby
class User < ActiveRecord::Base
  has_attached_file :avatar

  process_in_background :avatar, queue: "default"
end
```

Defaults
--------

Global defaults for all delayed_paperclip instances in your app can be
defined by changing the DelayedPaperclip.options Hash, this can be useful for setting a default ‘processing image,’ so you won’t have to define it in every `process_in_background` definition.

If you’re using Rails you can define a Hash with default options in
config/application.rb or in any of the config/environments/\*.rb files on `config.delayed_paperclip_defaults`, these will get merged into DelayedPaperclip.options as your Rails app boots. An example:

```ruby
module YourApp
  class Application < Rails::Application
    # Other code...

    config.delayed_paperclip_defaults = {
        url_with_processing: true,
        processing_image_url: 'custom_processing.png'
    }
  end
end
```

What if I’m not using images?
-----------------------------

This library works no matter what kind of post-processing you are doing
with Paperclip.

Paperclip Post-processors are not working
-----------------------------------------

If you are using custom [post-processing processors](https://github.com/thoughtbot/paperclip#post-processing)
like this:

```ruby
# ...

has_attached_file :avatar, styles: { thumb: '100x100>' },  processors: [:rotator]
process_in_background :avatar

def rotate!
  # ...
  avatar.reprocess!
  # ...
end

# ...
```

...you may encounter an issue where your post-processors are ignored
([more info](https://github.com/jrgifford/delayed_paperclip/issues/171)).
In order to avoid this use `reprocess_without_delay!`

```ruby
# ...

def rotate!
  # ...
  avatar.reprocess_without_delay!
  # ...
end

# ...
```

Does it work with s3?
---------------------

Yes.

Contributing
------------

Checkout out [CONTRIBUTING](https://github.com/jrgifford/delayed_paperclip/blob/master/CONTRIBUTING). Run specs with:

```
# Rspec on all versions
bundle exec appraisal install
bundle exec appraisal rake

# Rspec on latest stable gems
bundle exec rake

# Rspec on specific rails version
bundle exec appraisal 5.0 rake
```
