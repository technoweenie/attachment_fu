module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    module Backends
      class BackendDelegator < Delegator
        attr_accessor :attachment_options

        def initialize(obj, opts)
          @obj = obj
          @attachment_options = opts
        end
        
        def __getobj__
          @obj
        end
      end
    end
  end
end

