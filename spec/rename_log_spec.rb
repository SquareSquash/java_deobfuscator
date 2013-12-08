# Copyright 2013 Square Inc.
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

require 'spec_helper'

describe Squash::Java::RenameLog do
  describe "parse" do
    it "should correctly parse a yGuard file" do
      @namespace = Squash::Java::RenameLog.new(File.join(File.dirname(__FILE__), 'fixtures', 'renamelog.xml')).parse

      expect(@namespace.obfuscated_package('com.hvilela.A').full_name).to eql('com.hvilela.drawer')
      expect(@namespace.obfuscated_class('com.hvilela.A.A').full_name).to eql('com.hvilela.drawer.Columns')
      expect(@namespace.obfuscated_class('com.hvilela.Wallpaperer$6').full_name).to eql('com.hvilela.Wallpaperer$6')
      expect(@namespace.obfuscated_class('com.hvilela.6')).to be_nil

      expect(@namespace.obfuscated_method(
          @namespace.klass('com.hvilela.Wallpaperer'),
          'void A(java.io.File)'
      ).full_name).to eql('void addDirectory(java.io.File)')
      expect(@namespace.obfuscated_method(
          @namespace.klass('com.hvilela.Wallpaperer'),
          'javax.swing.JSpinner B(com.hvilela.Wallpaperer)'
      ).full_name).to eql('javax.swing.JSpinner access$1(com.hvilela.Wallpaperer)')
    end

    it "should correctly parse a ProGuard file" do
      @namespace = Squash::Java::RenameLog.new(File.join(File.dirname(__FILE__), 'fixtures', 'mapping.txt')).parse

      expect(@namespace.obfuscated_class('com.example.account.manager.client.d').full_name).to eql('com.example.account.manager.client.AsyncPost')
      expect(@namespace.obfuscated_class('com.example.account.manager.client.k').full_name).to eql('com.example.account.manager.client.AddFoodLog$1')
      expect(@namespace.obfuscated_method(
          @namespace.klass('com.example.account.manager.client.AsyncPost'),
          'java.lang.Void a()'
      ).full_name).to eql('java.lang.Void doInBackground$10299ca()')
    end
  end
end
