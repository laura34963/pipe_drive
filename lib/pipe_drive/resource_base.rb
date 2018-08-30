module PipeDrive
  class ResourceBase < Base

    protected

    def pagination(path, params, &block)
      self.class.send(:pagination, path, params, &block)
    end

    class << self do

      def resource_name
        name.split('::').last.downcase
      end

      def custom_field_keys
        PipeDrive.custom_field_keys[resource_name.to_sym]
      end

      def list(start_from=0, per_page=DEFAULT_PER_PAGE, options={}, &block)
        path = "/#{resource_name}s"
        params = {start: start_from, limit: per_page}
        params.merge!(options)
        pagination(path, params, &block)
      end

      def search(type, opts, strict=false)
        raise NotAllowSearchType.new(type) unless const_get('ALLOW_FOR_SEARCH_TERMS').include?(type)
        raise NotProvideAssignType.new(type) if opts[type].nil?
        params = {term: opts[type]}
        allow_search_opts = const_get('ALLOW_FOR_ADDITION_SEARCH_OPTS')
        params.merge!(opts.slice(*allow_search_opts))
        requester.http_get("/#{resource_name}s/find", params) do |result|
          result[:data].nil? ? nil : list_objects(result)
        end
      end

      def find_by(type, opts, strict=false)
        targets = search(type, opts, strict)
        return if targets.blank?
        if strict
          targets.find do |target|
            target.send(type) == opts[type]
          end
        else
          targets.first
        end
      end

      protected

      def pagination(path, params, &block)
        resources = []
        loop do
          next_start_from = requester.http_get(path, params) do |result|
            return resources if result[:data].nil?
            items = list_objects(result)
            resources += items
            items.each do |item|
              yield item
            end if block_given?
            result[:additional_data][:pagination][:next_start]
          end
          break if next_start_from.nil?
          params[:start] = next_start_from
        end
        resources
      end
    end

  end
end