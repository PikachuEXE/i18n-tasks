module I18n::Tasks
  module MissingKeys
    # @param [:missing_from_base, :missing_from_locale, :eq_base] type (default nil)
    # @return [KeyGroup]
    def missing_keys(opts = {})
      locales = Array(opts[:locales]).presence || self.locales
      type    = opts[:type]
      unless type
        types = opts[:types].presence || missing_keys_types
        opts  = opts.except(:types).merge(locales: locales)
        return types.map { |t| missing_keys(opts.merge(type: t)) }.reduce(:+)
      end

      if type.to_s == 'missing_from_base'
        keys = keys_missing_from_base if locales.include?(base_locale)
      else
        keys = non_base_locales(locales).map { |locale|
          send("keys_#{type}", locale)
        }.reduce(:+)
      end
      keys || KeyGroup.new([])
    end

    def missing_keys_types
      @missing_keys_types ||= [:missing_from_base, :eq_base, :missing_from_locale]
    end

    def untranslated_keys(locales = nil)
      I18n::Tasks.warn_deprecated("#untranslated_keys. Please use #missing_keys instead")
      missing_keys(locales: locales)
    end

    # @return [KeyGroup] missing keys, i.e. key that are in the code but are not in the base locale data
    def keys_missing_from_base
      @keys_missing_from_base ||= begin
        KeyGroup.new(
            used_keys.keys.reject { |k|
              key = k.key
              k.expr? || key_value?(key, base_locale) || ignore_key?(key, :missing)
            }.map(&:clone_orphan), type: :missing_from_base, locale: base_locale)
      end
    end

    # @return [KeyGroup] keys missing (nil or blank?) in locale but present in base
    def keys_missing_from_locale(locale)
      return keys_missing_from_base if locale == base_locale
      @keys_missing_from_locale         ||= {}
      @keys_missing_from_locale[locale] ||= KeyGroup.new(
          traverse_map_if(data[base_locale]) { |key, base_value|
            key if !ignore_key?(key, :missing) && !key_value?(key, locale) && !key_value?(depluralize_key(key), locale)
          }, type: :missing_from_locale, locale: locale)

    end

    # @return [KeyGroup] keys missing value (but present in base)
    def keys_eq_base(locale)
      @keys_eq_base ||= KeyGroup.new(
          traverse_map_if(data[base_locale]) { |key, base_value|
            key if base_value == t(key, locale) && !ignore_key?(key, :eq_base, locale)
          }, type: :eq_base, locale: locale)
    end
  end
end
