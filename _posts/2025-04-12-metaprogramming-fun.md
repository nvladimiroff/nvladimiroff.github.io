---
layout: post
title: Metaprogramming meandering
subtitle: Talking to Objective-C from Ruby
state: hidden
---

_Metaprogramming_ is what makes Ruby unique as a programming language. Metaprogramming means many different things for many different programming languages, but for Ruby, metaprogramming is a set of special APIs to directly talk to and interact with Ruby's runtime. You can think of those APIs as a second more powerful (and potentially more confusing) Ruby syntax for when ordinary Ruby isn't expressive enough.

We're going to use metaprogramming to implement a magic `ObjC` module that lets us call Objective-C code from Ruby without directly wrapping any specific Objective-C code.

Our goal is to be able to run some Objective-C code like this:
```objective-c
// This code just displays a "Hello world" alert box with an "Ok" button to dismiss it.
NSAlert *alert = [[NSAlert alloc] init];
[alert setMessageText:@"Hello world!"];
[alert addButtonWithTitle:@"Ok"];
[alert runModal];
```
in Ruby like this:
```ruby
alert = ObjC::NSAlert.alloc.init
alert.set_message_text("Hello world!")
alert.add_button_with_title("ok")
alert.run_modal
```

I'll explain everything, so don't worry if you're not familiar with Objective-C!

## Dissecting Objective-C

Let's take a look at that first line: `[[NSAlert alloc] init]`. In Objective-C, method calls are wrapped in square brackets, so this example is calling `alloc` on the class `NSAlert` and then calls `init` on that result.

So if we want to do the same in Ruby, we need a way to:
 * Turn the string `'NSAlert'` into an Objective-C class.
 * Call the `alloc` and `init` methods on Objective-C objects.

Luckily, Objective-C gives us ways to call into its runtime to do both of these things.

## Calling into Objective-C's runtime

Under the hood, much of Objective-C is just some fancy syntax over C that desugars into function calls to `libobjc`, the underlying C library that makes up Objective-C's runtime, and we can use [ffi](https://github.com/ffi/ffi) to call into that C library in Ruby.

I won't go into the details here, but we can use `ffi` to make an `ObjC::Internal` module and bind the two `libobjc` methods we want:
 * `objc_getClass`: this one turns a name into a Objective-C class.
 * `objc_msgSend`: this one calls methods on Objective-C objects.

Objective-C, like Ruby, uses _message passing_ as a core part of its object system, and `objc_msgSend` works a lot like Ruby's [`send`](https://ruby-doc.org/3.4.1/Object.html#method-i-send) method. But unlike Ruby, Objective-C sends _selectors_ to objects, not symbols, so we'll need one final C function to make those selectors: `sel_registerName`.

With all of that, we can now write `[[NSAlert alloc] init]` in Ruby:
```ruby
nsalert_class = ObjC::Internal.objc_getClass('NSAlert')
alloc_selector = ObjC::Internal.sel_registerName('alloc')
init_selector = ObjC::Internal.sel_registerName('init')
my_nsalert = ObjC::Internal.objc_msgSend(ObjC::Internal.objc_msgSend(nsalert_class, alloc_selector), init_selector)
```

It works, but it's pretty ugly. Let's use metaprogramming to make it nicer!

## const_missing

If we wanted `NSAlert` to look like a Ruby class, we could do something like this:
```ruby
module ObjC
  NSAlert = Internal.objc_getClass('NSAlert')
end
```
and then `ObjC::NSAlert` would work! This works for a single class, but it would get tedious to define every single Objective-C class like this. Instead, we'd like something that looks like we defined an `NSAlert` constant, but actually just passes the constant name to `objc_getClass`. we can use Ruby's `const_missing` to do exactly that!

```ruby
module ObjC
  def self.const_missing(const)
    Internal.objc_getClass(const.to_s)
  end
end
```

Ruby's runtime calls `const_missing` every time a constant that doesn't exist is accessed in a module. We can just send that missing constant symbol to `objc_getClass`, and now `ObjC::NSAlert` works out of the box along with every single other Objective-C class!

## method_missing

Next we'd like method calls to work just as seamlessly. We could write a class like this:
```ruby
class ObjC::NSAlert
  def initialize(objc_value)
    @objc_value = objc_value
  end

  def init
    init_selector = ObjC::Internal.sel_registerName('init')
    ObjC::Internal.objc_msgSend(@objc_value, init_selector)
  end
end
```
and now `my_nsalert.init` would work, but again, this could get pretty tedious if we wanted it to work for every Objective-C class. Instead, we're going to do two things:
 * Make an Objective-C wrapper class.
 * Implement `method_missing` on that wrapper class.

Here's what the wrapper class looks like:
```ruby
class ObjC::Object
  def initalize(objc_value)
    @objc_value = objc_value
  end

  def method_missing(name)
    selector = ObjC::Internal.sel_registerName(name.to_s)
    self.class.new(ObjC::Internal.objc_msgSend(@objc_value, selector))
  end
end
```
And then we modify `const_missing` to return the wrapper class too:
```ruby
module ObjC
  def self.const_missing(const)
    # Classes are objects too!
    Object.new(Internal.objc_getClass(const.to_s))
  end
end
```
And now `ObjC::NSAlert.alloc.init` works out of the box! `method_missing`, like `const_missing`, is called by Ruby's runtime when a method that doesn't exist is called on an object. We just take that method name, turn it into an Objective-C selector, and then forward that to Objective-C's runtime.

## Making the initial example work!
We're just missing two final things: parameters, and a way to turn Objective-C's camel case method names into more Ruby-friendly snake case.

### Parameters

### Method names

## Closing
TODO: some decent closing paragraph.
