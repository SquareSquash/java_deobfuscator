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

describe Squash::Java::Namespace do
  describe "#find_files" do
    before :all do
      @namespace = Squash::Java::Namespace.new
      @namespace.add_class_alias 'foo.Bar', 'A'
      @namespace.add_class_alias 'foo.Baz', 'B'
    end

    it "should set class paths correctly" do
      Find.stub!(:find).
          and_yield('/path/to/project/.backup').
          and_yield('/path/to/project/.backup/foo').
          and_yield('/path/to/project/.backup/foo/Bar.java').
          and_yield('/path/to/project/lib').
          and_yield('/path/to/project/lib/foo').
          and_yield('/path/to/project/lib/foo/Bar.jar').
          and_yield('/path/to/project/lib/foo/Baz.jar').
          and_yield('/path/to/project/source1').
          and_yield('/path/to/project/source1/foo').
          and_yield('/path/to/project/source1/foo/Bar.java').
          and_yield('/path/to/project/source2').
          and_yield('/path/to/project/source2/foo').
          and_yield('/path/to/project/source2/foo/Baz.java')
      Find.stub!(:prune)
      @namespace.find_files('/path/to/project/')

      @namespace.path_for_class('foo.Bar').should eql('source1/foo/Bar.java')
      @namespace.path_for_class('foo.Baz').should eql('source2/foo/Baz.java')
    end
  end

  describe "#add_package_alias" do
    before(:each) { @namespace = Squash::Java::Namespace.new }

    it "should create a Package" do
      pkg = @namespace.add_package_alias('com.foo.bar', 'A')
      pkg.should be_kind_of(Squash::Java::Package)
      pkg.name.should eql('bar')
      pkg.parent.full_name.should eql('com.foo')
      pkg.obfuscation.should eql('A')
    end
  end

  describe "#add_class_alias" do
    before(:each) { @namespace = Squash::Java::Namespace.new }

    it "should create a Class" do
      cl = @namespace.add_class_alias('com.foo.Bar', 'A')
      cl.should be_kind_of(Squash::Java::Class)
      cl.name.should eql('Bar')
      cl.parent.should be_kind_of(Squash::Java::Package)
      cl.parent.full_name.should eql('com.foo')
      cl.obfuscation.should eql('A')
    end
  end

  describe "#add_method_alias" do
    before(:each) { @namespace = Squash::Java::Namespace.new }

    it "should create a Method" do
      cl   = @namespace.add_class_alias('com.foo.Bar', 'A')
      meth = @namespace.add_method_alias(cl, 'com.foo.Bar finagle(com.foo.Bar, int[])', 'a')

      meth.should be_kind_of(Squash::Java::Method)
      meth.name.should eql('finagle')
      meth.obfuscation.should eql('a')
      meth.klass.full_name.should eql('com.foo.Bar')
      meth.return_type.full_name.should eql('com.foo.Bar')

      meth.arguments.size.should eql(2)
      meth.arguments.first.type.full_name.should eql('com.foo.Bar')
      meth.arguments.first.should_not be_array
      meth.arguments.last.type.full_name.should eql('int')
      meth.arguments.last.should be_array
    end
  end

  describe "#obfuscated_method" do
    before :each do
      @namespace = Squash::Java::Namespace.new
      @method = @namespace.add_method_alias('com.foo.Bar', 'int baz(int[])', 'a')
    end

    it "should locate a method by obfuscated name" do
      @namespace.obfuscated_method(@namespace.klass('com.foo.Bar'), 'int a(int[])').should eql(@method)
    end

    it "should return nil if nothing was found" do
      @namespace.obfuscated_method(@namespace.klass('com.foo.Bar'), 'int a()').should be_nil
      @namespace.obfuscated_method(@namespace.klass('com.foo.Bar'), 'int a(int)').should be_nil
      @namespace.obfuscated_method(@namespace.klass('com.foo.Bar'), 'int b(int[])').should be_nil
    end
  end
end
