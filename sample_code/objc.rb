require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'ffi'
  gem 'activesupport', require: 'active_support/all'
end

module ObjC
end

module ObjC::Internal

  extend FFI::Library

  ffi_lib(
    'objc',
    '/System/Library/Frameworks/Foundation.framework/Foundation',
    '/System/Library/Frameworks/Cocoa.framework/Cocoa'
  )

  attach_function(:objc_getClass, [:string], :pointer)
  attach_function(:class_getName, [:pointer], :string)
  attach_function(:sel_registerName, [:string], :pointer)
  attach_function(:objc_allocateClassPair, %i[pointer string int], :pointer)
  attach_function(:objc_registerClassPair, %i[pointer], :void)
  attach_function(:class_addIvar, %i[pointer string int int string], :int)


  class << self

    def msg_send(target, selector_name, *args)
      # TODO: some sanity checking probably

      selector = sel_registerName(selector_name)

      c_args = ruby_to_c_args(args)
      arg_types = [:pointer, :pointer] + c_args.collect(&:first)
      arg_values = [target, selector] + c_args.collect(&:second)

      func = FFI::Function.new(:pointer, arg_types, objc_msgSend)
      func.call(*arg_values)
    end


    def define_objc_method(klass, selector_name, ret, *args, &block)
      selector = sel_registerName(selector_name)
      cb = FFI::CallbackInfo.new(ret, args)
      objc_types = c_types_to_objc_types([ret, :pointer, :selector] + args)
      arg_values = [klass, selector, block, objc_types]

      func = FFI::Function.new(:void, [:pointer, :pointer, cb, :string], class_addMethod)
      func.call(*arg_values)
    end


      private

        def objc_msgSend
          @msg_send_func ||= (
            lib_objc = ffi_libraries.detect { |lib| lib.name == 'libobjc.dylib' }
            lib_objc.find_function('objc_msgSend')
          )
        end


        def class_addMethod
          @class_addMethod ||= (
            lib_objc = ffi_libraries.detect { |lib| lib.name == 'libobjc.dylib' }
            lib_objc.find_function('class_addMethod')
          )
        end


        def ruby_to_c_args(args)
          args.collect { |arg|
            case arg
            in Array if arg == []
              next
            in Integer
              [:int, arg]
            in Float
              [:double, arg]
            in String
              [:pointer, ns_string(arg)]
            in Symbol
              [:string, arg.to_s]
            in FalseClass
              [:int, 0]
            in TrueClass
              [:int, 1]
            in FFI::Struct
              [arg.class.by_value, arg]
            else # More checking would probably be a good idea
              [:pointer, arg]
            end
          }.compact
        end


        def c_types_to_objc_types(args)
          # https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html#//apple_ref/doc/uid/TP40008048-CH100
          args.collect { |arg|
            case arg
            when :pointer
              '@'
            when :int
              'i'
            when :string
              '*'
            when :selector
              ':'
            when :void
              'v'
            else
              raise 'Unknown arg!'
            end
          }.join
        end


        def ns_string(str)
          klass = objc_getClass('NSString')
          selector = sel_registerName('stringWithCString:')
          types = %i[pointer pointer string]
          func = FFI::Function.new(:pointer, types, objc_msgSend)

          values = [klass, selector, str]
          # [NSString stringWithUTF8String:str]
          func.call(*values)
        end

  end
end

module ObjC
  class NSRect < FFI::Struct

    layout :x, :double,
           :y, :double,
           :width, :double,
           :height, :double

    def self.create(x, y, width, height)
      new.tap do |r|
        r[:x] = x
        r[:y] = x
        r[:width] = width
        r[:height] = height
      end
    end

  end


  class Object

    def initialize(objc_obj)
      @objc_obj = objc_obj
    end


    def method_missing(name, *args, **opts)
      super(name, *args, **opts) if args.length > 1

      objc_send(name, *args, **opts)
    end


    def objc_send(name, *args, **opts)
      # E.g., turn `window.is_visible = true` into `[window setIsVisible:true]`
      name = "set_#{name[0..-2]}" if name.to_s.end_with?('=')

      sel = format_selector(name, args, opts)

      method_args = []

      method_args << args[0] if args.any?
      method_args += opts.values if opts.any?
      method_args.collect! do |arg|
        if arg.respond_to?(:to_objc)
          arg.to_objc
        else
          arg
        end
      end

      result = Internal.msg_send(to_objc, sel, *method_args)
      if result.null?
        nil
      else
        self.class.new(result)
      end
    end


    def to_objc
      @objc_obj
    end


    def inspect
      "#<#{objc_class}>"
    end


    def objc_class
      klass = Internal.msg_send(@objc_obj, 'class')
      Internal.class_getName(klass)
    end


    def selector(name)
      Internal.sel_registerName(name.to_s)
    end


    private

    def format_selector(name, args, opts)
      selector = "#{name.to_s.camelize(:lower)}"

      selector << ':' if args.any?

      opts.keys.each do |key|
        selector << "#{key.to_s.camelize(:lower)}:"
      end

      selector
    end

  end


  class Class < Object

    def new(**opts)
      instance = Object.new(Internal.msg_send(@objc_obj, 'alloc'))

      # Call an initializer if passed.
      if opts.any?
        name, first_arg = opts.first
        rest = opts.drop(1).to_h

        instance.objc_send(name, first_arg, **rest)
      end

      instance
    end


    def self.define(name, &block)
      ns_object = Internal.objc_getClass('NSObject')
      @internal_obj = Internal.objc_allocateClassPair(ns_object, name.to_s, 0)
      klass = new(@internal_obj)
      instance_eval(&block) if block_given?
      ObjC::Internal.objc_registerClassPair(@internal_obj)

      @internal_obj = nil
      klass
    end


    def self.def_method(name, args, ret, &block)
      ObjC::Internal.define_objc_method(@internal_obj, name.to_s, ret, *args, &block)
    end

  end


  def self.const_missing(const)
    klass = Internal.objc_getClass(const.to_s)
    return Class.new(klass) unless klass.null?

    super
  end


  # NSApp is actually a global variable. I dunno how to actually bind to it. Most
  # of the third party Cocoa bindings seem to just do this, so 🤷.
  # NSApp = NSApplication.shared_application

  NSWindowStyleMaskBorderless = 0
  NSWindowStyleMaskTitled = 1 << 0
  NSWindowStyleMaskClosable = 1 << 1
  NSWindowStyleMaskMiniaturizable = 1 << 2
  NSWindowStyleMaskResizable = 1 << 3

  NSBackingStoreBuffered = 2

  NSApplicationActivationPolicyRegular = 0
end

# NSAlert *alert = [[NSAlert alloc] init];
# [alert setMessageText:@"Message text."];
# [alert setInformativeText:@"Informative text."];
# [alert addButtonWithTitle:@"Cancel"];
# [alert addButtonWithTitle:@"Ok"];
# [alert runModal];
# alert = ObjC::NSAlert.alloc.init
# alert.message_text = "Hello world!"
# alert.add_button_with_title("ok")
# alert.run_modal
