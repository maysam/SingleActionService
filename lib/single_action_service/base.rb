# Parent class for services.
# A service is an object that implements part of the business logic.
# Create an inheritor to use it
# and call 'success' or 'error' methods to return a result object.
class SingleActionService::Base
  protected

  # Helper methods to setup the service
  class << self
    # Some usefull methods that exists in Rails
    # but does not exists in the pure ruby
    unless respond_to?(:module_parent)
      include SingleActionService::ModuleHelper
    end

    # Call this method to generate methods in the service to return
    # specific errors.
    #
    # @param errors_data is an array of hashes with information about errors.
    # Each hash can contain keys:
    # :name => A symbol representing a name of the error.
    # :code => A symbol representing an error code of the error.
    #
    # For each name, a method "#{name}_error" will be generated
    # to return a result with the corresponding error code.
    # The returned result will have "#{name}_error?" methods
    # for checking for a specific error.
    #
    # For example, if you pass an array:
    # [{ name: :already_exists, code: :'errors.already_exists' }],
    # the 'already_exists_error' method will be generated to return the
    # result with a :'errors.already_exists' code.
    # You can check for the error by calling 'already_exists_error?'
    # method on the result object.
    def errors(errors_data = nil)
      return @errors if errors_data.nil?

      parse_errors(errors_data)
      create_result_class
      define_methods_to_create_error_results
    end

    def parse_errors(errors_data)
      @errors = errors_data.map do |error_data|
        SingleActionService::ServiceError.new(**error_data)
      end
    end

    def create_result_class
      demodulized_name = name.split('::').last
      result_class_name = "#{demodulized_name}Result"
      return if module_parent.const_defined?(result_class_name)

      # Programmatically create the inheritor for the service result object
      # with autogenerated methods for checking for errors.
      errors = @errors
      @result_class = Class.new(SingleActionService::Result) do
        def self.define_error_checking_method(error)
          method_name = "#{error.name}_error?"

          define_method(method_name) do
            error_code == error.code
          end
        end

        errors.each do |error|
          define_error_checking_method(error)
        end
      end

      module_parent.const_set(result_class_name, @result_class)
    end

    def define_methods_to_create_error_results
      @errors.each do |error_object|
        result_method_name = "#{error_object.name}_error"
        define_method(result_method_name) do |data = nil|
          error(code: error_object.code, data: data)
        end
      end
    end

    def result_class
      @result_class ||= SingleActionService::Result
    end
  end

  # @return a result with a success indicator and passed data.
  # @param data is any data to return from service.
  def success(data = nil)
    SingleActionService::Result.new(true, data: data)
  end

  # @return a result with an error indicator, passed data and error code.
  # @param data is any data to return from the service.
  # @param code is an error code of the occurred error.
  def error(data: nil, code: nil)
    SingleActionService::Result.new(false, data: data, error_code: code)
  end
end
