module ZeroDowntimeMigrations
  class Validation
    class AddForeignKey < Validation
      def validate!
        return unless requires_validate_constraints?
        error!(message) unless foreign_key_not_validated?
      end

      private

      def message
        <<-MESSAGE.strip_heredoc
          Adding a foreign key causes an AccessExclusiveLock on both tables which blocks reads.
          It is possible to add a foreign key in one step and validate later (which only causes RowShareLocks)

            class Add#{foreign_table}ForeignKeyTo#{table} < ActiveRecord::Migration
              def change
                add_foreign_key :#{table}, #{foreign_table}, validate: false
              end
            end

            class Validate#{foreign_table}ForeignKeyOn#{table} < ActiveRecord::Migration
              def change
                validate_foreign_key :#{table}, :#{foreign_table}
              end
            end

          Note, both `add_foreign_key` and `validate_foreign_key` accept `name` and `column` options.
        MESSAGE
      end

      def foreign_key_not_validated?
        options[:validate] == false
      end

      def foreign_table
        args[1]
      end

      def table
        args[0]
      end

      def requires_validate_constraints?
        supports_validate_constraints? && old_postgresql_version?
      end

      def supports_validate_constraints?
        ActiveRecord::Base.connection.respond_to?(:supports_validate_constraints?) &&
          ActiveRecord::Base.connection.supports_validate_constraints?
      end

      # In Postgresql version 9.5+ adding a ForeignKey only takes an ShareRowExclusiveLock
      # and so is far safer.  In previous versions it would take an AccessExclusiveLock
      # https://git.postgresql.org/gitweb/?p=postgresql.git;a=commitdiff;h=0ef0396ae1687bf738d4703773d55467c36b2bcd
      def old_postgresql_version?
        ActiveRecord::Base.connection.respond_to?(:postgresql_version) &&
          ActiveRecord::Base.connection.postgresql_version < 90_500
      end
    end
  end
end
