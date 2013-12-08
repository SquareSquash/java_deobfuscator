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

describe Squash::Java::Namespace do
  describe "#find_files" do
    before :all do
      @namespace = Squash::Java::Namespace.new
      @namespace.add_class_alias 'foo.Bar', 'A'
      @namespace.add_class_alias 'foo.Baz', 'B'
    end

    it "should set class paths correctly" do
      allow(Find).to receive(:find).
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
      allow(Find).to receive(:prune)
      @namespace.find_files('/path/to/project/')

      expect(@namespace.path_for_class('foo.Bar')).to eql('source1/foo/Bar.java')
      expect(@namespace.path_for_class('foo.Baz')).to eql('source2/foo/Baz.java')
    end
  end

  describe "#add_package_alias" do
    before(:each) { @namespace = Squash::Java::Namespace.new }

    it "should create a Package" do
      pkg = @namespace.add_package_alias('com.foo.bar', 'A')
      expect(pkg).to be_kind_of(Squash::Java::Package)
      expect(pkg.name).to eql('bar')
      expect(pkg.parent.full_name).to eql('com.foo')
      expect(pkg.obfuscation).to eql('A')
    end
  end

  describe "#add_class_alias" do
    before(:each) { @namespace = Squash::Java::Namespace.new }

    it "should create a Class" do
      cl = @namespace.add_class_alias('com.foo.Bar', 'A')
      expect(cl).to be_kind_of(Squash::Java::Class)
      expect(cl.name).to eql('Bar')
      expect(cl.parent).to be_kind_of(Squash::Java::Package)
      expect(cl.parent.full_name).to eql('com.foo')
      expect(cl.obfuscation).to eql('A')
    end
  end

  describe "#add_method_alias" do
    before(:each) { @namespace = Squash::Java::Namespace.new }

    it "should create a Method" do
      cl   = @namespace.add_class_alias('com.foo.Bar', 'A')
      meth = @namespace.add_method_alias(cl, 'com.foo.Bar finagle(com.foo.Bar, int[])', 'a')

      expect(meth).to be_kind_of(Squash::Java::Method)
      expect(meth.name).to eql('finagle')
      expect(meth.obfuscation).to eql('a')
      expect(meth.klass.full_name).to eql('com.foo.Bar')
      expect(meth.return_type.to_s).to eql('com.foo.Bar')

      expect(meth.arguments.size).to eql(2)
      expect(meth.arguments.first.type.full_name).to eql('com.foo.Bar')
      expect(meth.arguments.first.dimensionality).to eql(0)
      expect(meth.arguments.last.type.full_name).to eql('int')
      expect(meth.arguments.last.dimensionality).to eql(1)
    end
    
    it "should handle vector values appropriately" do
      cl   = @namespace.add_class_alias('com.foo.Bar', 'A')
      meth = @namespace.add_method_alias(cl, 'int[][] finagle(com.foo.Bar)', 'a')
      
      expect(meth).to be_kind_of(Squash::Java::Method)
      expect(meth.name).to eql('finagle')
      expect(meth.obfuscation).to eql('a')
      expect(meth.klass.full_name).to eql('com.foo.Bar')
      expect(meth.return_type.to_s).to eql('int[][]')

      expect(meth.arguments.size).to eql(1)
      expect(meth.arguments.first.type.full_name).to eql('com.foo.Bar')
      expect(meth.arguments.first.dimensionality).to eql(0)
    end
  end

  describe "#obfuscated_method" do
    before :each do
      @namespace = Squash::Java::Namespace.new
      @method = @namespace.add_method_alias('com.foo.Bar', 'int baz(int[])', 'a')
    end

    it "should locate a method by obfuscated name" do
      expect(@namespace.obfuscated_method(@namespace.klass('com.foo.Bar'), 'int a(int[])')).to eql(@method)
    end

    it "should return nil if nothing was found" do
      expect(@namespace.obfuscated_method(@namespace.klass('com.foo.Bar'), 'int a()')).to be_nil
      expect(@namespace.obfuscated_method(@namespace.klass('com.foo.Bar'), 'int a(int)')).to be_nil
      expect(@namespace.obfuscated_method(@namespace.klass('com.foo.Bar'), 'int b(int[])')).to be_nil
    end
  end
end
