module Jekyll
  class CssEmbed < Liquid::Tag

    def initialize(tag_name, text, tokens)
      super
      @path = text.strip
    end

    def render(context)
      full_path = context.registers[:site].in_source_dir(@path)

      "<style>#{File.read(full_path)}</style>"
    end
  end
end

Liquid::Template.register_tag('css_embed', Jekyll::CssEmbed)
