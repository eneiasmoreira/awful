module Awful

  class CloudFormation < Cli

    no_commands do
      def cf
        @cf ||= Aws::CloudFormation::Client.new
      end
    end

    desc 'ls [PATTERN]', 'list cloudformation stacks matching PATTERN'
    method_option :long, aliases: '-l', default: false, desc: 'Long listing'
    method_option :all,  aliases: '-a', default: false, desc: 'Show all, including stacks in DELETE_COMPLETE'
    def ls(name = /./)
      stacks = cf.list_stacks.stack_summaries.select do |stack|
        stack.stack_name.match(name)
      end

      ## skip deleted stacks unless -a given
      unless options[:all]
        stacks = stacks.select { |stack| stack.stack_status != 'DELETE_COMPLETE' }
      end

      stacks.tap do |stacks|
        if options[:long]
          print_table stacks.map { |s| [s.stack_name, s.creation_time, s.stack_status, s.template_description] }
        else
          puts stacks.map(&:stack_name)
        end
      end
    end

    desc 'dump NAME', 'describe stack named NAME'
    def dump(name)
      cf.describe_stacks(stack_name: name).stacks.tap do |stacks|
        stacks.each do |stack|
          puts YAML.dump(stringify_keys(stack.to_hash))
        end
      end
    end

    desc 'template NAME', 'get template for stack named NAME'
    def template(name)
      cf.get_template(stack_name: name).template_body.tap do |template|
        puts template
      end
    end

    desc 'validate FILE', 'validate given template in FILE or stdin'
    def validate(file = nil)
      begin
        cf.validate_template(template_body: file_or_stdin(file)).tap do |response|
          puts YAML.dump(stringify_keys(response.to_hash))
        end
      rescue Aws::CloudFormation::Errors::ValidationError => e
        e.tap { |err| puts err.message }
      end
    end

    desc 'update NAME', 'update stack with name NAME'
    def update(name, file = nil)
      begin
        cf.update_stack(stack_name: name, template_body: file_or_stdin(file)).tap do |response|
          p response.stack_id
        end
      rescue Aws::CloudFormation::Errors::ValidationError => e
        e.tap { |err| puts err.message }
      end
    end

    desc 'events NAME', 'show events for stack with name NAME'
    def events(name)
      cf.describe_stack_events(stack_name: name).stack_events.tap do |events|
        print_table events.map { |e| [e.timestamp, e.resource_status, e.resource_type, e.logical_resource_id, e.resource_status_reason] }
      end
    end

  end
end
