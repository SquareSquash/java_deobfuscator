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

require 'spec_helper'

describe Squash::Java::RenameLog do
  describe "parse" do
    it "should correctly parse a yGuard file" do
      @namespace = Squash::Java::RenameLog.new(File.join(File.dirname(__FILE__), 'fixtures', 'renamelog.xml')).parse

      @namespace.obfuscated_package('com.hvilela.A').full_name.should eql('com.hvilela.drawer')
      @namespace.obfuscated_class('com.hvilela.A.A').full_name.should eql('com.hvilela.drawer.Columns')
      @namespace.obfuscated_class('com.hvilela.Wallpaperer$6').full_name.should eql('com.hvilela.Wallpaperer$6')
      @namespace.obfuscated_class('com.hvilela.6').should be_nil

      @namespace.obfuscated_method(
          @namespace.klass('com.hvilela.Wallpaperer'),
          'void A(java.io.File)'
      ).full_name.should eql('void addDirectory(java.io.File)')
      @namespace.obfuscated_method(
          @namespace.klass('com.hvilela.Wallpaperer'),
          'javax.swing.JSpinner B(com.hvilela.Wallpaperer)'
      ).full_name.should eql('javax.swing.JSpinner access$1(com.hvilela.Wallpaperer)')
    end

    it "should correctly parse a ProGuard file" do
      @namespace = Squash::Java::RenameLog.new(File.join(File.dirname(__FILE__), 'fixtures', 'mapping.txt')).parse

      @namespace.obfuscated_class('com.example.account.manager.client.d').full_name.should eql('com.example.account.manager.client.AsyncPost')
      @namespace.obfuscated_class('com.example.account.manager.client.k').full_name.should eql('com.example.account.manager.client.AddFoodLog$1')
      @namespace.obfuscated_method(
          @namespace.klass('com.example.account.manager.client.AsyncPost'),
          'java.lang.Void a()'
      ).full_name.should eql('java.lang.Void doInBackground$10299ca()')
    end
  end
end
