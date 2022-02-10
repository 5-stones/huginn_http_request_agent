module Agents
  class HttpRequestAgent < Agent
    include EventHeadersConcern
    include WebRequestConcern
    include FileHandling

    consumes_file_pointer!

    MIME_RE = /\A\w+\/.+\z/

    can_dry_run!
    no_bulk_receive!
    default_schedule "never"

    description do
      <<-MD
        A HTTP Request Agent receives events from other agents (or runs periodically), merges those events with the [Liquid-interpolated](https://github.com/huginn/huginn/wiki/Formatting-Events-using-Liquid) contents of `payload`, and sends the request to a specified url.

        ### Options

        **Primary:**

          - `endpoint` - The URL you would like to send request. Please include the URI scheme (`http` or `https`).
          - `method` - The lowercase HTTP verb you would like to use (i.e. `get`, `post`, `put`, `patch`, and `delete`).
          - `content_type` - The content type of the request (see below for more detail).
          - `payload` - For `get` requests this will be converted to URL params. For `post`, `put`, and `patch` this will be the request `body`. When `payload` is a string `no_merge` has to be set to `true`.

        **Other:**

          - `headers` - When present, it should be a hash of headers to send with the request (e.g. an  `Authorization` header).
          - `basic_auth` - Specify HTTP basic auth parameters: `"username:password"`, or `["username", "password"]`.
          - `disable_ssl_verification` - Set to `true` to disable ssl verification.
          - `user_agent` - A custom User-Agent name (default: "Faraday v#{Faraday::VERSION}").
          - `no_merge` - Setting this value to `true` will result in the incoming event, but still send the interpolated payload
          - `output_mode` - Setting this value to `merge` will result in the emitted Event being merged into the original contents of the received Event. Setting it to `clean` will result in no merge.
          - `emit_events` - Setting this to `true` will result in the server response being emitted as an Event which can be subsequently consumed by another agent (ex. to a WebsiteAgent for parsing of the response body)
          - `log_requests` - Setting this to `true` will log the contents of the interpolated request object sent by this event.

        ### Content Type's:

        **Supported `content_type`'s:**

          - `json` to send JSON instead
          - `xml` to send XML, where the name of the root element may be specified using `xml_root`
          - All other `content_type`'s will be serialized as a string

        By default, non-GETs will be sent with form encoding (`application/json`).

        The `content_type` field will default the `Content-Type` header if it is not explicitly set in the following manner:

          - if `Content-Type` is set use value
          - else if `content_type==json` then `Content-Type=application/json`
          - else if `content_type==xml` then `Content-Type=application/xml`
          - else `Content-Type=content_type`

        This allows you fine grained control over the mime type being used.

        ### Response

        `emit_events` must be set to `true` to use the response. The emitted Event will have a "headers" hash and a "status" integer value. No data processing will be attempted by this Agent, so the resopnse Event's "body" value will always be raw text.

        ### Misc

        Set `event_headers` to a list of header names, either in an array of string or in a comma-separated string, to include only some of the header values.
        Set `event_headers_style` to one of the following values to normalize the keys of "headers" for downstream agents' convenience:

          - `capitalized` (default) - Header names are capitalized; e.g. "Content-Type"
          - `downcased` - Header names are downcased; e.g. "content-type"
          - `snakecased` - Header names are snakecased; e.g. "content_type"
          - `raw` - Backward compatibility option to leave them unmodified from what the underlying HTTP library returns.

        #{receiving_file_handling_agent_description}
        When receiving a `file_pointer` the request will be sent with multipart encoding (`multipart/form-data`) and `content_type` is ignored. `upload_key` can be used to specify the parameter in which the file will be sent, it defaults to `file`.
        When a `payload` is passed with a `get` method then the payload is converted into URL query params.
      MD
    end

    event_description <<-MD
      Events look like this:
        {
          "status": 200,
          "headers": {
            "Content-Type": "text/html",
            ...
          },
          "body": "<html>Some data...</html>"
        }
      Original event contents will be merged when `output_mode` is set to `merge`.
    MD

    def default_options
      {
        'endpoint' => "http://www.example.com",
        'expected_receive_period_in_days' => '1',
        'content_type' => 'json',
        'method' => 'get',
        'payload' => {
          'key' => 'value',
          'something' => 'the event contained {{ somekey }}'
        },
        'headers' => {},
        'emit_events' => 'true',
        'no_merge' => 'false',
        'output_mode' => 'clean',
        'log_requests' => 'false'
      }
    end

    def working?
      return false if recent_error_logs?

      if interpolated['expected_receive_period_in_days'].present?
        return false unless last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago
      end

      true
    end

    def method
      (interpolated['method'].presence || 'post').to_s.downcase
    end

    def validate_options
      unless options['endpoint'].present?
        errors.add(:base, "endpoint is a required field")
      end

      if options['payload'].present? && %w[get delete].include?(method) && !(options['payload'].is_a?(Hash) || options['payload'].is_a?(Array))
        errors.add(:base, "if provided, payload must be a hash or an array")
      end

      if options['payload'].present? && %w[post put patch].include?(method)
        if !(options['payload'].is_a?(Hash) || options['payload'].is_a?(Array)) && options['content_type'] !~ MIME_RE
          errors.add(:base, "if provided, payload must be a hash or an array")
        end
      end

      if options['content_type'] =~ MIME_RE && options['payload'].is_a?(String) && boolify(options['no_merge']) != true
        errors.add(:base, "when the payload is a string, `no_merge` has to be set to `true`")
      end

      if options['content_type'] == 'form' && options['payload'].present? && options['payload'].is_a?(Array)
        errors.add(:base, "when content_type is a form, if provided, payload must be a hash")
      end

      if options.has_key?('emit_events') && boolify(options['emit_events']).nil?
        errors.add(:base, "if provided, emit_events must be true or false")
      end

      if options.has_key?('log_requests') && boolify(options['log_requests']).nil?
        errors.add(:base, "If provided, log_requests must be true or false")
      end

      validate_event_headers_options!

      unless %w[post get put delete patch].include?(method)
        errors.add(:base, "method must be 'post', 'get', 'put', 'delete', or 'patch'")
      end

      if options['no_merge'].present? && !%[true false].include?(options['no_merge'].to_s)
        errors.add(:base, "if provided, no_merge must be 'true' or 'false'")
      end

      if options['output_mode'].present? && !options['output_mode'].to_s.include?('{') && !%[clean merge].include?(options['output_mode'].to_s)
        errors.add(:base, "if provided, output_mode must be 'clean' or 'merge'")
      end

      unless headers.is_a?(Hash)
        errors.add(:base, "if provided, headers must be a hash")
      end

      validate_web_request_options!
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          outgoing = interpolated['payload'].presence || {}

          if boolify(interpolated['no_merge'])
            handle outgoing, event, headers(interpolated[:headers])
          else
            handle outgoing.merge(event.payload), event, headers(interpolated[:headers])
          end
        end
      end
    end

    def check
      handle interpolated['payload'].presence || {}, headers
    end

    private

    def handle(data, event = Event.new, headers)
      url = interpolated(event.payload)[:endpoint]

      case method
      when 'get'
        content_type = interpolated(event.payload)['content_type']

        case content_type
        when 'json'
          headers['Content-Type'] ||= 'application/json; charset=utf-8'
          url = faraday.build_url(url, data.compact)
        else
          params = data
          body = nil
        end

      when 'delete'
        params = data
        body = nil
      when 'post', 'put', 'patch'
        params = nil
        content_type = nil

        if has_file_pointer?(event)
          data[interpolated(event.payload)['upload_key'].presence || 'file'] = get_upload_io(event)
        else
          content_type = interpolated(event.payload)['content_type']
        end

        case content_type
        when 'json'
          headers['Content-Type'] ||= 'application/json; charset=utf-8'
          body = data.to_json
        when 'xml'
          headers['Content-Type'] ||= 'text/xml; charset=utf-8'
          body = data.to_xml(root: (interpolated(event.payload)[:xml_root] || 'post'))
        when MIME_RE
          headers['Content-Type'] ||= content_type
          body = data.to_s
        else
          body = data
        end
      else
        error "Invalid method '#{method}'"
      end

      if boolify(interpolated['log_requests'])
        log({ method: method, url: url, body: body, headers: headers })
      end

      output_event = interpolated['output_mode'].to_s == 'merge' ? event.payload.dup : {}

      begin

        response = faraday.run_request(method.to_sym, url, body, headers) { |request|

          # open/read timeout in seconds
          if interpolated['timeout'].to_i
              request.options.timeout = interpolated['timeout'].to_i
          end

          # connection open timeout in seconds
          if interpolated['open_timeout'].to_i
              request.options.open_timeout = interpolated['open_timeout'].to_i
          end

          request.params.update(params) if params
        }

        if boolify(interpolated['emit_events'])
          create_event payload: output_event.merge(
            body: response.body,
            status: response.status
          ).merge(
            event_headers_payload(response.headers)
          )
        end
      rescue => e
        handle_req_error(e, output_event, url)
      end
    end

    def event_headers_key
      super || 'headers'
    end

    def handle_req_error( error, output_payload, endpoint )

      error_status = defined?(error.response_status)  && !error.response_status.nil? ? error.response_status : 500

      #  NOTE:  `options['payload']`` below is intentionally _NOT_ interpolated.
      #  The primary reason for this is that it may contain sensitive values
      #  By passing the raw option, we will see liquid placeholders instead.
      #  This wiill assist with debugging while also not exposing secrets.

      log({
        error_message: error.message,
        status_code: error_status,
        endpoint: endpoint,
        payload_options: options['payload'],
      })

      if boolify(interpolated['emit_events'])
        create_event payload: output_payload.merge(
          status: error_status,
          error_message: error.message,
          endpoint: endpoint,
          payload_options: options['payload'],
        )
      end

    end

  end # <-- End of class
end
