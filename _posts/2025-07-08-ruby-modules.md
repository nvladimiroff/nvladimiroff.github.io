---
layout: post
title: Mixins--an underappreciated feature
---

Mixins are a great language feature that's often underappreciated. Much like a function lets you name and group lines of code, mixins let you name and group _functions_. This is a simple, but very handy feature!

## What problems do mixins solve?

Imagine you work for a video streaming company. The core of your business might be a big class called `Video`, and that big class does a lot of different things:

```ruby
class Video
  def upload(video_file)
    # ...
  end

  def optimize
    # ...
  end

  def stream_from_s3(quality)
    # ...
  end

  def sync_ratings
    # ...
  end

  def appropriate_for_user?(user)
    # ...
  end

  # Many more methods omitted.
end
```

A big class gives you a powerful interface for code it but can be easy to get lost in when modifying the class itself. Luckily, this is a perfect problem for mixins! We can split up the class into parts and then mix them into the Video class instead of writing them in there directly:

```ruby
# src/video/uploadable.rb
module Uploadable
  def upload(video_file)
    # ...
  end
end

# src/video/reencodable.rb
module Reencodable
  def optimize
    # ...
  end

  def stream_from_s3(quality)
    # ...
  end
end

# src/video/ratable.rb
module Ratable
  def sync_ratings
    # ...
  end

  def appropriate_for_user?(user)
    # ...
  end
end

# src/video.rb
class Video
  include Uploadable, Reencodable, Ratable
end
```

We've ended up with a Video class with an identical interface, but with individual concerns moved out,  named, and put into their own files.

You should only be mildly impressed right now; we haven't done anything too spectacular. But that's the beauty of mixins! They're a very simple solution to let you move some code in a class into its own file, and sometimes that's all you need.
