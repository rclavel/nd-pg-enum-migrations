# frozen_string_literal: true

require 'active_record'
require_relative 'migrations/version'

module ND::PG::Enum::Migrations::Concern
  def create_enum(name, values)
    reversible do |direction|
      direction.up   { _create_enum(name, values) }
      direction.down { _drop_enum(name) }
    end
  end

  def drop_enum(name, values = nil)
    if values
      reversible do |direction|
        direction.up   { _drop_enum(name) }
        direction.down { _create_enum(name, values) }
      end
    else
      # If reverted, an ActiveRecord::IrreversibleMigration error will be raised.
      _drop_enum(name)
    end
  end

  def add_enum_value(name, *values)
    change_enum_values(name, add: values.flatten)
  end
  alias_method :add_enum_values, :add_enum_value

  def remove_enum_value(name, *values)
    change_enum_values(name, remove: values.flatten)
  end
  alias_method :remove_enum_values, :remove_enum_value

  def change_enum_values(name, add: [], remove: [])
    reversible do |direction|
      direction.up   { _change_enum_values(name, add: add, remove: remove) }
      direction.down { _change_enum_values(name, add: remove, remove: add) }
    end
  end

  def rename_enum(from, to)
    reversible do |direction|
      direction.up   { _rename_enum(from, to) }
      direction.down { _rename_enum(to, from) }
    end
  end

  def enum_values(name)
    values = ActiveRecord::Base.connection.execute(<<~SQL.squish)
      SELECT unnest(enum_range(null, null::#{name})) AS value;
    SQL

    values.map { |value| value['value'] }
  end

  def columns_from_type(type)
    values = ActiveRecord::Base.connection.execute(<<~SQL.squish)
      SELECT table_name, column_name FROM information_schema.columns WHERE table_schema = 'public' AND udt_name = '#{type}';
    SQL

    values.to_a.map(&:symbolize_keys)
  end

  private

  def _create_enum(name, values)
    logger.debug("Create enum `#{name}` with values #{values.inspect}")
    execute <<-SQL
      CREATE TYPE #{name} AS ENUM (#{values.map { |value| "'#{value}'" }.join(', ')});
    SQL
  end

  def _drop_enum(name)
    logger.debug("Drop enum `#{name}`")
    execute <<-SQL
      DROP TYPE #{name};
    SQL
  end

  def _change_enum_values(name, add: [], remove: [])
    logger.debug("Change enum `#{name}` values: Add #{add.inspect}, remove #{remove.inspect}")
    temporary_name = "new_#{name}".to_sym
    existing_values = enum_values(name)
    new_values = existing_values + add - remove

    _create_enum(temporary_name, existing_values)
    _change_enum_type(from: name, to: temporary_name)
    _drop_enum(name)

    _create_enum(name, new_values)
    _change_enum_type(from: temporary_name, to: name)
    _drop_enum(temporary_name)
  end

  def _rename_enum(old_name, new_name)
    logger.debug("Rename enum from `#{old_name}` to `#{new_name}`")
    values = enum_values(old_name)

    _create_enum(new_name, values)
    _change_enum_type(from: old_name, to: new_name)
    _drop_enum(old_name)
  end

  def _change_enum_type(from:, to:)
    logger.debug("Change enum type from `#{from}` to `#{to}`")
    source_type = from
    destination_type = to

    columns_from_type(source_type).each do |data|
      table, column = data.values_at(:table_name, :column_name)
      change_column(table, column, "#{destination_type} USING #{column}::varchar::#{destination_type}")
    end
  end

  def logger
    @_logger ||= Logger.new(STDOUT)
  end
end

class ActiveRecord::Migration
  include ND::PG::Enum::Migrations::Concern
end
