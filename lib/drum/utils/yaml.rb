require 'date'
require 'yaml'

module Drum
  module YAMLUtils
    # Deserializes YAML with a number of standard permitted classes.
    def from_yaml(yaml)
      YAML.load(yaml, permitted_classes: [Date, DateTime, Symbol, Time])
    end
  end
end
