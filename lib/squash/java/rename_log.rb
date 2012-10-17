# Copyright 2012 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

require 'rexml/document'

# Parses a rename log file (generated from yGuard or ProGuard) and generates a
# {Squash::Java::Namespace} object from it.

class Squash::Java::RenameLog
  # @private
  JAVA_PACKAGE_COMPONENT = '[a-z][a-z0-9_]*'
  # @private
  JAVA_PACKAGE_NAME = "#{JAVA_PACKAGE_COMPONENT}(?:\\.#{JAVA_PACKAGE_COMPONENT})*"
  # @private
  JAVA_CLASS_NAME = JAVA_VARIABLE_NAME = JAVA_OBFUSCATED_NAME = JAVA_METHOD_NAME = "[A-Za-z0-9_$]+"
  # @private
  JAVA_CLASS_PATH = "(?:#{JAVA_PACKAGE_NAME}\\.)?#{JAVA_CLASS_NAME}"
  # @private
  JAVA_PRIMITIVE = '(?:boolean|byte|char|short|int|long|float|double|void)'
  # @private
  JAVA_TYPE = "(?:#{JAVA_PRIMITIVE}|#{JAVA_CLASS_PATH})(?:\\[\\])*"
  # @private
  JAVA_TYPE_LIST = "#{JAVA_TYPE}(?:,\\s?#{JAVA_TYPE})*"
  # @private
  JAVA_METHOD_SIGNATURE = "#{JAVA_TYPE} #{JAVA_METHOD_NAME}\\((?:#{JAVA_TYPE_LIST})?\\)"

  # Creates a new parser for a given rename log file. The file is assumed to be
  # in the yGuard format if it ends in ".xml", and in the ProGuard format if it
  # ends in ".txt".
  #
  # @param [String] logfile The path to a rename log file.

  def initialize(logfile)
    @logfile = logfile
  end

  # @return [Squash::Java::Namespace] The name mapping in the file.

  def parse
    return parse_yguard if File.extname(@logfile) == '.xml'
    return parse_proguard if File.extname(@logfile) == '.txt'
  end

  private

  def parse_yguard
    namespace = Squash::Java::Namespace.new

    xml = REXML::Document.new(File.new(@logfile))
    xml.elements.each("//yguard/map/*") do |element|
      obfuscation = element.attributes['map']
      name        = element.attributes['name']
      case element.name
        when 'package'
          namespace.add_package_alias name, obfuscation
        when 'class'
          # "com.hvilela.Wallpaperer$6" gets an obfuscation of "6" when it should be "Wallpaperer$6"
          class_name = name.split('.').last
          if class_name.include?('$')
            base_class = namespace.klass(class_name.split('$').first)
            new_obfuscation = [base_class.obfuscation || base_class.name]
            new_obfuscation += class_name.split('$')[1..-2] << obfuscation
            obfuscation = new_obfuscation.join('$')
          end
          namespace.add_class_alias name, obfuscation
        when 'method'
          namespace.add_method_alias element.attributes['class'], name, obfuscation
      end
    end

    xml.elements.each("//yguard/expose/class") do |element|
      name = element.attributes['name']
      namespace.klass name
    end

    return namespace
  end

  def parse_proguard
    namespace = Squash::Java::Namespace.new

    File.open(@logfile) do |f|
      current_class = nil
      f.each_line do |line|
        if line =~ /^(#{JAVA_CLASS_PATH}) -> (#{JAVA_CLASS_PATH}):$/ # class
          current_class = namespace.add_class_alias($1, $2.split('.').last)
        elsif line =~ /^    #{JAVA_TYPE} #{JAVA_VARIABLE_NAME} -> #{JAVA_OBFUSCATED_NAME}$/ # field, skip
          raise "Unexpected field mapping outside of class" unless current_class
        elsif line =~ /^    (?:\d+:\d+:)?(#{JAVA_METHOD_SIGNATURE}) -> (#{JAVA_OBFUSCATED_NAME})$/ # method
          raise "Unexpected method mapping outside of class" unless current_class
          begin
            namespace.add_method_alias(current_class, $1, $2) if current_class.kind_of?(Squash::Java::Class)
          rescue ArgumentError
            # duplicate obfuscation -- this happens when the Java compiler
            # generates multiple methods with the same signature to support
            # generics. ignore the less specific variant (all later variants)
            raise unless $!.to_s =~ /Tried to assign obfuscation/
          end
        elsif line.empty? # blank, skip
        else
          raise "Invalid mapping line: #{line}"
        end
      end
    end

    return namespace
  end
end
