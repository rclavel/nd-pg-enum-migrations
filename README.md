# ND::PG::Enum::Migrations

This gem allows you to create, update and destroy PG enums in your Rails project.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add nd-pg-enum-migrations

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install nd-pg-enum-migrations

## Usage

All migrations can be reverted.

- [Create enum](#create-enum)
- [Delete enum](#delete-enum)
- [Add a value to enum](#add-a-value-to-enum)
- [Remove a value from enum](#remove-a-value-from-enum)
- [Change enum values](#change-enum-values)
- [Rename enum](#rename-enum)
- [List enum values](#list-enum-values)
- [Get all columns using enum](#get-all-columns-using-enum)

### Create enum

```ruby
class CreateUserRoleEnum < ActiveRecord::Migration[7.0]
  def change
    create_enum(:user_role, %w(admin owner user))
  end
end
```

### Delete enum

The second attribute is optional, but is required if the migration is reverted.
Otherwise, a `ActiveRecord::IrreversibleMigration` exception will be raised.

```ruby
class DropUserRoleEnum < ActiveRecord::Migration[7.0]
  def change
    drop_enum(:user_role, %w(admin owner user))
  end
end
```

### Add a value to enum

#### Add one value

```ruby
class AddValueToUserRoleEnum < ActiveRecord::Migration[7.0]
  def change
    add_enum_value(:user_role, 'banned')
  end
end
```

#### Add several values

```ruby
class AddValuesToUserRoleEnum < ActiveRecord::Migration[7.0]
  def change
    add_enum_values(:user_role, 'banned', 'expired')
  end
end
```

### Remove a value from enum

#### Add one value

```ruby
class RemoveValueFromUserRoleEnum < ActiveRecord::Migration[7.0]
  def change
    remove_enum_value(:user_role, 'banned')
  end
end
```

#### Add several values

```ruby
class RemoveValuesFromUserRoleEnum < ActiveRecord::Migration[7.0]
  def change
    remove_enum_values(:user_role, 'banned', 'expired')
  end
end
```

### Change enum values

```ruby
class ChangeValuesFromUserRoleEnum < ActiveRecord::Migration[7.0]
  def change
    change_enum_values(:user_role, add: %w(banned expired), remove: %w(admin))
  end
end
```

### Rename enum

```ruby
class RenameUserRoleEnum < ActiveRecord::Migration[7.0]
  def change
    rename_enum(:user_role, :user_kind)
  end
end
```

### List enum values

```ruby
class ListValuesFromUserRoleEnum < ActiveRecord::Migration[7.0]
  def change
    values = enum_values(:user_role)
    # => ["admin", "owner", "user"]

    # ...
  end
end
```

### Get all columns using enum

```ruby
class ListColumnsUsingEnum < ActiveRecord::Migration[7.0]
  def up
    values = columns_from_type(:user_role)
    # => [
    #   {:table_name=>"users", :column_name=>"role"},
    #   {:table_name=>"users", :column_name=>"kind"},
    #   {:table_name=>"profiles", :column_name=>"role"}
    # ]

    # ...
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

Guard is also installed: `bundle exec guard`.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, run `gem bump` (or manually update the version number in `version.rb`), and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rclavel/nd-pg-enum-migrations.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
