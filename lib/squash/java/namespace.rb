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

require 'set'
require 'find'


# A Ruby representation of the packages, classes, methods, and fields of a
# Java project, with their full and obfuscated names. The {RenameLog} class
# loads a Namespace from a yGuard or ProGuard rename log file.
#
# **Note:** Some of the finder methods of this class and its enclosed classes
# are find-or-create-type methods. Read the method documentation for each
# method carefully.
#
# **Another note:** A distinction is made between _full_ and _partial_ names
# (e.g., "MyClass" vs. "com.mycompany.MyClass"), and _cleartext_ and
# _obfuscated_ names (e.g., "com.mycompany.MyClass" vs. "com.A.B"). Note that
# there are four possible combinations of these states. Method docs will state
# what naming format is expected for each parameter.

class Squash::Java::Namespace
  # @private
  METHOD_REGEX = /^([a-z0-9_.$\[\]]+) ([a-z0-9_$]+)\(([a-z$0-9_.\[\] ,]*)\)/i

  # Creates a new empty Namespace.

  def initialize
    @package_roots = Set.new
  end

  # @overload find_files(root)
  #   Attempts to locate the paths to the {Squash::Java::Class Classes} defined
  #   in this Namespace. Classes must be defined in files named after the class,
  #   organized into folders structured after the classes' packages. For
  #   example, the source of the `com.foo.bar.Baz` class should be defined in a
  #   file located at "com/foo/bar/Baz.java", somewhere inside your project
  #   root. This is a "best guess" attempt and will not work every time.
  #
  #   Once this method is complete, any Class objects under this namespace that
  #   were successfully matched will have their {Squash::Java::Class#path path}
  #   attributes set.
  #
  #   @param [String] root The project root. All source directories must be
  #     under this root.

  def find_files(root, package_or_class=nil)
    case package_or_class
      when nil
        root.sub! /\/$/, ''
        @package_roots.each { |pkg| find_files root, pkg }
      when Squash::Java::Package
        package_or_class.classes.each { |cl| find_files root, cl }
        package_or_class.children.each { |pkg| find_files root, pkg }
      when Squash::Java::Class
        class_subpath = package_or_class.subpath
        Find.find(root) do |project_path|
          if project_path[0, root.length + 2] == root + '/.'
            Find.prune
            next
          end
          if project_path[-class_subpath.length, class_subpath.length] == class_subpath
            package_or_class.path = project_path.sub(/^#{Regexp.escape root}\//, '')
          end
        end
    end
  end

  # Returns the path to a {Squash::Java::Class Class}'s source .java file,
  # relative to the project root, if a) the class exists in the namespace, and
  # b) the class has a known path.
  #
  # @param [String] klass The full class name (parts of which can be
  #   obfuscated), e.g., "com.foo.A.Baz".
  # @return [String, nil] The path to the class's source file, if known.
  # @see #find_files

  def path_for_class(klass)
    cl = obfuscated_class(klass)
    cl ? cl.path : nil
  end

  # Associates a full package name with an obfuscated name.
  #
  # @param [String] name The full package name (e.g., "com.foo.bar").
  # @param [String] obfuscation The obfuscated name for just the last segment of
  #   the full name (e.g., "A").
  # @return [Squash::Java::Package] The newly created package object.

  def add_package_alias(name, obfuscation)
    pkg             = package(name)
    pkg.obfuscation = obfuscation
    return pkg
  end

  # Associates a full class name with an obfuscated name.
  #
  # @param [String] name The full class name (e.g., "com.foo.bar.Baz").
  # @param [String] obfuscation The obfuscated name for just the last segment of
  #   the full name (e.g., "A").
  # @return [Squash::Java::Class] The newly created class object.

  def add_class_alias(name, obfuscation)
    cl             = klass(name)
    cl.obfuscation = obfuscation
    return cl
  end

  # Associates a method name with an obfuscated alias.
  #
  # @param [String, Squash::Java::Class] class_or_name A full class name (e.g.,
  #   "com.foo.bar.Baz"), or a class object.
  # @param [String] method_name A method name, with return value and argument
  #  types (e.g., "com.foo.Type1 methodName(com.foo.Type2, int[])").
  # @return [Squash::Java::Method] The newly created method object.

  def add_method_alias(class_or_name, method_name, obfuscation)
    cl               = (class_or_name.kind_of?(Squash::Java::Class) ? class_or_name : klass(class_or_name))
    meth             = java_method(cl, method_name)
    meth.obfuscation = obfuscation
    return meth
  end

  # **Finds or creates** a package by its full name.
  #
  # @param [String] identifier A full package name (e.g., "com.foo.bar").
  # @return [Squash::Java::Package] The package with that name.

  def package(identifier)
    parts     = identifier.split('.')
    root_name = parts.shift
    root      = @package_roots.detect { |pkg| pkg.name == root_name } || begin
      pkg = Squash::Java::Package.new(root_name)
      @package_roots << pkg
      pkg
    end
    if parts.empty?
      root
    else
      root.find_or_create(parts.join('.'))
    end
  end

  alias klass package

  # **Finds** a package by its obfuscated (or partially obfuscated) full name.
  # (Technically it also works as a **find-only** variant of {#package} since
  # all, some, or none of the name need be obfuscated.)
  #
  # @param [String] identifier An obfuscated full package name (e.g.,
  #   "com.foo.A").
  # @return [Squash::Java::Package, nil] The package with that obfuscated name.

  def obfuscated_package(identifier)
    parts     = identifier.split('.')
    root_name = parts.shift
    root      = @package_roots.detect { |pkg| pkg.name == root_name }
    if parts.empty?
      root
    else
      root ? root.find_obfuscated(parts.join('.')) : nil
    end
  end

  # **Finds** a class by its obfuscated (or partially obfuscated) full name.
  # (Technically it also works as a **find-only** variant of {#klass} since all
  # some, or none of the name need be obfuscated.)
  #
  # @param [String] identifier An obfuscated full class name (e.g.,
  #   "com.foo.A.B").
  # @return [Squash::Java::Class, nil] The class with that obfuscated name.

  def obfuscated_class(identifier)
    parts      = identifier.split('.')
    class_name = parts.pop
    pkg        = obfuscated_package(parts.join('.'))
    return nil unless pkg

    pkg.classes.detect { |cl| cl.obfuscation == class_name || cl.name == class_name }
  end

  # **Finds or creates** a primitive or class type by its name.
  #
  # @param [String] name The type name (e.g., "int" or "FooClass").
  # @return [Squash::Java::Type] The type object.

  def type(name)
    Squash::Java::PRIMITIVES.detect { |prim| prim.name == name } || klass(name)
  end

  # **Finds** a class or primitive type by its obfuscated name. Primitives are
  # never obfuscated.
  #
  # @param [String] name The obfuscated full class name (e.g.,
  #   "com.squareup.A.B") or full primitive name
  # @return [Squash::Java::Type, nil] The type of that name, if found.

  def obfuscated_type(name)
    Squash::Java::PRIMITIVES.detect { |prim| prim.name == name } || obfuscated_class(name)
  end

  # **Finds or creates** a method by its name and parent class. Polymorphism is
  # supported: Two methods can share the same name so long as their argument
  # count or types are different.
  #
  # @param [Squash::Java::Class] klass The class containing the method.
  # @param [String] name The method name, with return type and arguments as
  #   full, unobfuscated types (e.g., "com.foo.Bar myMethod(com.foo.Baz, int[])".
  # @return [Squash::Java::Method] The corresponding method.

  def java_method(klass, name)
    matches = name.match(METHOD_REGEX) or raise "Invalid method name #{name.inspect}"
    return_type = argument(matches[1])
    method_name = matches[2]
    args        = matches[3].split(/,\s*/).map { |arg| argument(arg) }
    args = [] if matches[3].empty?

    klass.java_methods.detect { |meth| meth.name == method_name && meth.arguments == args } ||
        Squash::Java::Method.new(klass, method_name, return_type, *args)
  end

  # **Finds** a method by its obfuscated name and parent class. Polymorphism is
  # supported: Two methods can share the same name so long as their argument
  # count or types are different.
  #
  # @param [Squash::Java::Class] klass The class containing the method.
  # @param [String] name The obfuscated method name, with return type and
  #   arguments as full, obfuscated types (e.g., "com.foo.A myMethod(com.foo.B, int[])".
  # @return [Squash::Java::Method, nil] The corresponding method.

  def obfuscated_method(klass, name)
    matches = name.match(METHOD_REGEX) or raise "Invalid method name #{name.inspect}"
    return_type = obfuscated_type(matches[1])
    method_name = matches[2]
    args        = matches[3].split(/,\s*/).map { |arg| obfuscated_argument(arg) }
    args = [] if matches[3].empty?
    klass.java_methods.detect { |m| m.obfuscation == method_name && m.arguments == args }
  end

  # Creates a new Argument for a given type descriptor. This can be a
  # primitive (e.g., "float") or a full class name (e.g., "com.foo.Bar"), and
  # can be a scalar or an array (e.g., "float[]" or "com.foo.Bar[]"). **Finds or
  # creates** the {Squash::Java::Type Type}, and **always creates** a new
  # Argument.
  #
  # @param [String] type_descriptor The type description.
  # @return [Squash::Java::Argument] The argument object, unbound to any
  #   {Squash::Java::Method Method}.

  def argument(type_descriptor)
    dimensionality = type_descriptor.scan(/\[\]/).size
    type_name      = type_descriptor.gsub(/\[\]/, '')
    Squash::Java::Argument.new type(type_name), dimensionality
  end

  # Creates a new Argument for a given type descriptor, which can be fully or
  # partially obfuscated. This can be an unobfuscated primitive (e.g., "float")
  # or a possibly-obfuscated full class name (e.g., "com.foo.A"), and can be a
  # scalar or an array (e.g., "float[]" or "com.foo.A[]"). **Finds** the
  # {Squash::Java::Type Type}, and **always creates** a new Argument. Returns
  # `nil` for unknown types.
  #
  # @param [String] type_descriptor The type description.
  # @return [Squash::Java::Argument, nil] The argument object, unbound to any
  #   {Squash::Java::Method Method}, or `nil` if the type is not recognized.

  def obfuscated_argument(type_descriptor)
    dimensionality = type_descriptor.scan(/\[\]/).size
    type_name      = type_descriptor.gsub(/\[\]/, '')
    type           = obfuscated_type(type_name)
    return nil unless type
    Squash::Java::Argument.new type, dimensionality
  end
end

# Represents a Java package.

class Squash::Java::Package

  # @return [String] The last part of the package name (e.g., "bar" for package
  #   "com.foo.bar").
  attr_reader :name

  # @return [String, nil] The obfuscated package name (e.g., "A" for
  #   "com.foo.A").
  attr_reader :obfuscation

  # Sets the method's obfuscation.
  # @raise [ArgumentError] If the obfuscation is taken by another class or in
  #   package the same namespace.

  def obfuscation=(name)
    if (package = parent.children.detect { |p| p.obfuscation == name })
      raise ArgumentError, "Tried to assign obfuscation #{name} to #{package.inspect} and #{inspect}"
    end
    @obfuscation = name
  end

  # @return [Squash::Java::Package] The parent package (e.g., package "com.foo"
  #   for "com.foo.bar").
  attr_reader :parent

  # @return [Array<Squash::Java::Package>] Packages nested underneath this
  #   package (see {#parent}).
  attr_reader :children

  # @return [Array<Squash::Java::Class>] Classes belonging to this package.
  attr_reader :classes

  # @private
  def initialize(name, parent=nil)
    @name   = name
    @parent = parent
    @parent.children << self if @parent
    @children = Set.new
    @classes  = Set.new
  end

  # **Finds** a package underneath this package.
  #
  # @param [String] identifier The package name relative to this package. If
  #   finding package "com.foo.bar", pass "foo.bar" to Package "com".
  # @return [Squash::Java::Package, nil] The matching package, if found.

  def find(identifier)
    parts = identifier.split('.')
    name  = parts.shift
    child = children.detect { |pkg| pkg.name == name }
    if parts.empty?
      child
    else
      child ? child.find(parts.join('.')) : nil
    end
  end

  # **Finds** a package by obfuscated (or non-obfuscated) name relative to this
  # package.
  #
  # @param [String] identifier The package name relative to this package (parts
  #   may be obfuscated). If finding package "com.A.B", pass "A.B" to package
  #   "com".
  # @return [Squash::Java::Package, nil] The matching package, if found.

  def find_obfuscated(identifier)
    parts = identifier.split('.')
    name  = parts.shift
    child = children.detect { |pkg| pkg.obfuscation == name || pkg.name == name }
    if parts.empty?
      child
    else
      child ? child.find_obfuscated(parts.join('.')) : nil
    end
  end

  # **Finds or creates** A package underneath this package.
  #
  # @param [String] identifier The package name relative to this package. If
  #   finding package "com.foo.bar", pass "foo.bar" to Package "com".
  # @return [Squash::Java::Package] The matching package, or the newly created
  #   package.

  def find_or_create(identifier)
    parts = identifier.split('.')
    name  = parts.shift

    if ('A'..'Z').include? name[0, 1] # class
      raise "Unexpected class midway through identifier" unless parts.empty?
      classes.detect { |cl| cl.name == name } || Squash::Java::Class.new(self, name)
    else # package
      child = children.detect { |pkg| pkg.name == name } || Squash::Java::Package.new(name, self)
      parts.empty? ? child : child.find_or_create(parts.join('.'))
    end
  end

  # @return [String] The full name of this package (e.g., "com.foo.bar").
  def full_name() parent ? "#{parent.full_name}.#{name}" : name end

  # @private
  def inspect() "#<#{self.class.to_s} #{full_name}>" end

  # @private
  def subpath() parent ? "#{parent.subpath}/#{name}" : name end
end

# Superclass describing both {Squash::Java::Primitive Primitive} types and
# {Squash::Java::Class Classes}.

class Squash::Java::Type
  # @return [String] The type name.
  attr_reader :name

  # @return [String] The full type name. By default this is equal to {#name},
  #   but can be overridden.
  def full_name() name end

  # @private
  def inspect() "#<#{self.class.to_s} #{full_name}>" end
end

# Represents a Java class or inner class.

class Squash::Java::Class < Squash::Java::Type
  # @return [Squash::Java::Class, Squash::Java::Package] The parent package (or
  #   parent class for inner classes).
  attr_reader :parent

  # @return [String, nil] The obfuscated name of this class.
  attr_accessor :obfuscation

  # @return [Array<Squash::Java::Method>] The instance methods of this class.
  attr_reader :java_methods

  # @return [Array<Squash::Java::Class>] The inner classes of this class.
  attr_reader :classes

  # @return [String] The path to the .java file defining this class, relative to
  #   the project root.
  # @see Squash::Java::Namespace#find_files
  attr_accessor :path

  # @private
  def initialize(parent, name)
    @parent       = parent
    @java_methods = Set.new
    @classes      = Array.new
    @name         = name

    @parent.classes << self
  end

  # @return [String] The name of this class (with package and parent class
  #   names).

  def full_name
    "#{parent.full_name}.#{name}"
  end

  # @private
  def subpath() parent.kind_of?(Squash::Java::Package) ? "#{parent.subpath}/#{name}.java" : parent.subpath end
end

# Represents a primitive Java type, like `int` or `float`.

class Squash::Java::Primitive < Squash::Java::Type

  # @private
  def initialize(name)
    @name = name
  end
end

# Represents a Java instance method. Polymorphism is handled by using separate
# Method instances with different {#arguments} values.

class Squash::Java::Method
  # @return [Squash::Java::Class] The class owning this method.
  attr_reader :klass

  # @return [Squash::Java::Argument] The type of object returned.
  attr_reader :return_type

  # @return [String] The method name.
  attr_reader :name

  # @return [Array<Squash::Java::Argument>] The method arguments.
  attr_reader :arguments

  # @return [String, nil] The obfuscated method name.
  attr_reader :obfuscation

  # Sets the method's obfuscation.
  # @raise [ArgumentError] If the obfuscation is taken by another method in
  #   the same class.

  def obfuscation=(name)
    if (meth = klass.java_methods.detect { |m| m.arguments == arguments && m.obfuscation == name })
      raise ArgumentError, "Tried to assign obfuscation #{name} to #{meth.inspect} and #{inspect}"
    end
    @obfuscation = name
  end

  # @private
  def initialize(klass, name, return_type, *arguments)
    @klass       = klass
    @name        = name
    @return_type = return_type
    @arguments   = arguments
    klass.java_methods << self
  end

  # @private
  def add_argument(type)
    @arguments << type
    @arguments.size - 1
  end

  # @return [String] The full method name, along with return value and arguments
  #   as full type names.

  def full_name
    args = arguments.map { |type| type.to_s }.join(', ')
    "#{return_type.to_s} #{name}(#{args})"
  end

  # @private
  def inspect() "#<#{self.class.to_s} #{full_name}>" end
end

# A {Squash::Java::Method Method} argument. Includes the argument
# {Squash::Java::Type} and whether it is a scalar or an array.

class Squash::Java::Argument
  # @return [Squash::Java::Type] The argument type.
  attr_reader :type

  # @return [Fixnum] The number of dimensions for vector values. A type of
  #   `int[][]` has a dimensionality of 2. Scalars have a dimensionality of 0.
  attr_reader :dimensionality

  # @private
  def initialize(type, dimensionality=0)
    @type           = type
    @dimensionality = dimensionality
  end

  # @private
  def ==(other)
    other.kind_of?(Squash::Java::Argument) &&
        type == other.type &&
        dimensionality == other.dimensionality
  end

  # @return [String] The type's full name, with "[]" appended for arrays.
  def to_s() "#{type.full_name}#{'[]'*dimensionality}" end

  # @private
  def inspect() "#<#{self.class} #{to_s}>" end
end

# All known Java primitives.
Squash::Java::PRIMITIVES = %w(boolean byte char short int long float double void).map { |name| Squash::Java::Primitive.new name }
