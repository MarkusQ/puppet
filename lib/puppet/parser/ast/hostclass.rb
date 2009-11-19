require 'puppet/parser/ast/definition'

# The code associated with a class.  This is different from definitions
# in that each class is a singleton -- only one will exist for a given
# node.
class Puppet::Parser::AST::HostClass < Puppet::Parser::AST::Definition

    associates_doc

    @name = :class

    # Are we a child of the passed class?  Do a recursive search up our
    # parentage tree to figure it out.
    def child_of?(klass)
        return false unless self.parentclass

        if klass == self.parentobj
            return true
        else
            return self.parentobj.child_of?(klass)
        end
    end

    # Make sure our parent class has been evaluated, if we have one.
    def evaluate(scope)
        if parentclass and ! scope.catalog.resource(self.class.name, parentclass)
            parent_resource = parentobj.evaluate(scope)
        end

        # Do nothing if the resource already exists; this makes sure we don't
        # get multiple copies of the class resource, which helps provide the
        # singleton nature of classes.
        if resource = scope.catalog.resource(self.class.name, self.classname)
            return resource
        end

        super
    end

    def self.adjust_context(resource)
        scope = resource.scope

        # Todo: sort this all out

        # Verify that we haven't already been evaluated.  This is
        # what provides the singleton aspect.
        if existing_scope = scope.compiler.class_scope(self)
            Puppet.debug "Class '%s' already evaluated; not evaluating again" % (classname == "" ? "main" : classname)
            return nil
        end

        pnames = nil

        puts "Skipping a bunch of stuff I don't feel like understanding yet."
        %q{
        if pklass = self.parentobj
            parent_resource = resource.scope.compiler.catalog.resource(self.class.name, pklass.classname)
            # This shouldn't evaluate if the class has already been evaluated.
            pklass.evaluate_code(parent_resource)

            scope = parent_scope(scope, pklass)
            pnames = scope.namespaces
        end
        }

        # Don't create a subscope for the top-level class, since it already
        # has its own scope.
        unless resource.title == :main
            scope = subscope(scope, resource)

            scope.setvar("title", resource.title)
            scope.setvar("name", resource.name)
        end

        # Add the parent scope namespaces to our own.
        if pnames
            pnames.each do |ns|
                scope.add_namespace(ns)
            end
        end

        # Set the class before we evaluate the code, so that it's set during
        # the evaluation and can be inspected.
#        scope.compiler.class_set(self.classname, scope)
        scope
    end

    def evaluate_code
        # Now evaluate our code, yo.
        code && code.safeevaluate(scope)
    end

    def parent_scope(scope, klass)
        if s = scope.compiler.class_scope(klass)
            return s
        else
            raise Puppet::DevError, "Could not find scope for %s" % klass.classname
        end
    end
end
