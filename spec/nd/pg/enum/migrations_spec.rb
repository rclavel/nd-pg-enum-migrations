# frozen_string_literal: true

RSpec.describe ND::PG::Enum::Migrations do
  let(:root_path) { File.join(Dir.pwd, 'db', 'migrate') }

  let(:migrations_paths)   { ActiveRecord::Migrator.migrations_paths }
  let(:migrations_context) { ActiveRecord::MigrationContext.new(migrations_paths) }

  around { |example| DatabaseCleaner.cleaning { example.run } }

  before { set_initial_migration! }
  after  { FileUtils.rm_rf(root_path) }

  describe '#create_enum' do
    it 'creates then drops the enum' do
      create_migration(<<~RUBY)
        def change
          create_enum(:user_role, %i(foo bar foobar))
        end
      RUBY

      expect(pg_enums).to eq({})
      migrate!
      expect(pg_enums).to eq(user_role: %w(foo bar foobar))

      rollback!
      expect(pg_enums).to eq({})
    end

    describe 'when name is already used' do
      before { create_enum(:user_role, %i(abc def ghi)) }

      it 'raises an error' do
        create_migration(<<~RUBY)
          def change
            create_enum(:user_role, %i(foo bar foobar))
          end
        RUBY

        expect { migrate! }.to raise_error do |error|
          expect(error).to be_a(StandardError)
          expect(error.cause).to be_a(ActiveRecord::StatementInvalid)
          expect(error.cause.message).to eq("PG::DuplicateObject: ERROR:  type \"user_role\" already exists\n")
        end
      end
    end
  end

  describe '#drop_enum' do
    before { create_enum(:user_role, %i(foo bar foobar)) }

    describe 'when enum values are provided' do
      it 'drops then creates the enum' do
        create_migration(<<~RUBY)
          def change
            drop_enum(:user_role, %i(foo bar foobar))
          end
        RUBY

        expect(pg_enums).to eq(user_role: %w(foo bar foobar))
        migrate!
        expect(pg_enums).to eq({})

        rollback!
        expect(pg_enums).to eq(user_role: %w(foo bar foobar))
      end
    end

    describe 'when enum values are not provided' do
      it 'drops the enum then raises an error' do
        create_migration(<<~RUBY)
          def change
            drop_enum(:user_role)
          end
        RUBY

        expect(pg_enums).to eq(user_role: %w(foo bar foobar))
        migrate!
        expect(pg_enums).to eq({})

        expect { rollback! }.to raise_error do |error|
          expect(error).to be_a(StandardError)
          expect(error.cause).to be_a(ActiveRecord::IrreversibleMigration)
        end
      end
    end

    describe 'when a column uses enum' do
      before { add_column(:users, :role, :user_role) }

      it 'raises an error' do
        create_migration(<<~RUBY)
          def change
            drop_enum(:user_role)
          end
        RUBY

        expect { migrate! }.to raise_error do |error|
          expect(error).to be_a(StandardError)
          expect(error.cause).to be_a(ActiveRecord::StatementInvalid)
          expect(error.cause.message).to eq("PG::DependentObjectsStillExist: ERROR:  cannot drop type user_role because other objects depend on it\nDETAIL:  table users column role depends on type user_role\nHINT:  Use DROP ... CASCADE to drop the dependent objects too.\n")
        end
      end
    end
  end

  describe '#add_enum_value' do
    before { create_enum(:user_role, %i(foo bar foobar)) }

    it 'add value to enum' do
      create_migration(<<~RUBY)
        def change
          add_enum_value(:user_role, 'foobaz')
        end
      RUBY

      expect(pg_enums).to eq(user_role: %w(foo bar foobar))
      migrate!
      expect(pg_enums).to eq(user_role: %w(foo bar foobar foobaz))

      rollback!
      expect(pg_enums).to eq(user_role: %w(foo bar foobar))
    end
  end

  describe '#add_enum_values' do
    before { create_enum(:user_role, %i(foo bar foobar)) }

    it 'add values to enum' do
      create_migration(<<~RUBY)
        def change
          add_enum_values(:user_role, 'foobaz', 'foobax')
        end
      RUBY

      expect(pg_enums).to eq(user_role: %w(foo bar foobar))
      migrate!
      expect(pg_enums).to eq(user_role: %w(foo bar foobar foobaz foobax))

      rollback!
      expect(pg_enums).to eq(user_role: %w(foo bar foobar))
    end
  end

  describe '#remove_enum_value' do
    before { create_enum(:user_role, %i(foo bar foobar)) }

    it 'removes value from enum' do
      create_migration(<<~RUBY)
        def change
          remove_enum_value(:user_role, 'foobar')
        end
      RUBY

      expect(pg_enums).to eq(user_role: %w(foo bar foobar))
      migrate!
      expect(pg_enums).to eq(user_role: %w(foo bar))

      rollback!
      expect(pg_enums).to eq(user_role: %w(foo bar foobar))
    end

    describe 'when a column uses a deleted value' do
      before do
        add_column(:users, :role, :user_role)
        execute_sql_query(<<~SQL)
          INSERT INTO users ("email", "role") VALUES ('foo@bar.fr', 'foobar')
        SQL
      end

      it 'raises an error' do
        create_migration(<<~RUBY)
          def change
            remove_enum_value(:user_role, 'foobar')
          end
        RUBY

        expect { migrate! }.to raise_error do |error|
          expect(error).to be_a(StandardError)
          expect(error.cause).to be_a(ActiveRecord::StatementInvalid)
          expect(error.cause.message).to eq("PG::InvalidTextRepresentation: ERROR:  invalid input value for enum user_role: \"foobar\"\n")
        end
      end
    end
  end

  describe '#remove_enum_values' do
    before { create_enum(:user_role, %i(foo bar foobar)) }

    it 'removes value from enum' do
      create_migration(<<~RUBY)
        def change
          remove_enum_values(:user_role, 'foo', 'bar')
        end
      RUBY

      expect(pg_enums).to eq(user_role: %w(foo bar foobar))
      migrate!
      expect(pg_enums).to eq(user_role: %w(foobar))

      rollback!
      expect(pg_enums).to eq(user_role: %w(foobar foo bar))
    end

    describe 'when a column uses a deleted value' do
      before do
        add_column(:users, :role, :user_role)
        execute_sql_query(<<~SQL)
          INSERT INTO users ("email", "role") VALUES ('foo@bar.fr', 'foobar')
        SQL
      end

      it 'raises an error' do
        create_migration(<<~RUBY)
          def change
            remove_enum_values(:user_role, 'foo', 'foobar')
          end
        RUBY

        expect { migrate! }.to raise_error do |error|
          expect(error).to be_a(StandardError)
          expect(error.cause).to be_a(ActiveRecord::StatementInvalid)
          expect(error.cause.message).to eq("PG::InvalidTextRepresentation: ERROR:  invalid input value for enum user_role: \"foobar\"\n")
        end
      end
    end
  end

  describe '#change_enum_values' do
    before { create_enum(:user_role, %i(foo bar foobar)) }

    it 'adds and removes values from enum' do
      create_migration(<<~RUBY)
        def change
          change_enum_values(:user_role, add: %w(foobaz foobax), remove: %w(foo bar))
        end
      RUBY

      expect(pg_enums).to eq(user_role: %w(foo bar foobar))
      migrate!
      expect(pg_enums).to eq(user_role: %w(foobar foobaz foobax))

      rollback!
      expect(pg_enums).to eq(user_role: %w(foobar foo bar))
    end

    describe 'when a column uses a deleted value' do
      before do
        add_column(:users, :role, :user_role)
        execute_sql_query(<<~SQL)
          INSERT INTO users ("email", "role") VALUES ('foo@bar.fr', 'foobar')
        SQL
      end

      it 'raises an error' do
        create_migration(<<~RUBY)
          def change
            change_enum_values(:user_role, add: %w(foobaz), remove: %w(foobar))
          end
        RUBY

        expect { migrate! }.to raise_error do |error|
          expect(error).to be_a(StandardError)
          expect(error.cause).to be_a(ActiveRecord::StatementInvalid)
          expect(error.cause.message).to eq("PG::InvalidTextRepresentation: ERROR:  invalid input value for enum user_role: \"foobar\"\n")
        end
      end
    end
  end

  describe '#rename_enum' do
    before do
      create_enum(:user_role, %i(foo bar foobar))
      add_column(:users, :role, :user_role)
    end

    it 'renames enum' do
      create_migration(<<~RUBY)
        def change
          rename_enum(:user_role, :user_kind)
        end
      RUBY

      expect(pg_enums).to eq(user_role: %w(foo bar foobar))
      expect(pg_columns_type(:users)).to eq(id: 'int8', email: 'varchar', role: 'user_role')

      migrate!

      expect(pg_enums).to eq(user_kind: %w(foo bar foobar))
      expect(pg_columns_type(:users)).to eq(id: 'int8', email: 'varchar', role: 'user_kind')

      rollback!

      expect(pg_enums).to eq(user_role: %w(foo bar foobar))
      expect(pg_columns_type(:users)).to eq(id: 'int8', email: 'varchar', role: 'user_role')
    end

    describe 'when new name is already used' do
      before { create_enum(:user_kind, %i(abc def ghi)) }

      it 'raises an error' do
        create_migration(<<~RUBY)
          def change
            rename_enum(:user_role, :user_kind)
          end
        RUBY

        expect { migrate! }.to raise_error do |error|
          expect(error).to be_a(StandardError)
          expect(error.cause).to be_a(ActiveRecord::StatementInvalid)
          expect(error.cause.message).to eq("PG::DuplicateObject: ERROR:  type \"user_kind\" already exists\n")
        end
      end
    end
  end

  describe '#enum_values' do
    before { create_enum(:user_role, %i(foo bar foobar)) }

    it 'list enum values' do
      create_migration(<<~RUBY)
        def change
          values = enum_values(:user_role)

          # Workaround to get the result of `enum_values` in the test.
          raise values.inspect
        end
      RUBY

      expect(pg_enums).to eq(user_role: %w(foo bar foobar))
      expect { migrate! }.to raise_error do |error|
        expect(error.cause.message).to eq('["foo", "bar", "foobar"]')
      end
    end
  end

  describe '#columns_from_type' do
    before do
      create_enum(:user_role, %i(foo bar foobar))
      add_column(:users, :role, :user_role)
    end

    it 'list which columns are using enum' do
      create_migration(<<~RUBY)
        def change
          values = columns_from_type(:user_role)

          # Workaround to get the result of `enum_values` in the test.
          raise values.inspect
        end
      RUBY

      expect(pg_enums).to eq(user_role: %w(foo bar foobar))
      expect(pg_columns_type(:users)).to eq(id: 'int8', email: 'varchar', role: 'user_role')

      expect { migrate! }.to raise_error do |error|
        expect(error.cause.message).to eq('[{:table_name=>"users", :column_name=>"role"}]')
      end
    end
  end

  def set_initial_migration!
    FileUtils.mkdir_p(root_path)
    create_migration(<<~RUBY)
      def change
        create_table :users, force: true do |t|
          t.string :email
        end
      end
    RUBY
  end

  def create_migration(migration_content, migrate: false)
    @_counter ||= 0
    @_counter += 1
    file_name = "#{20190106184413 + @_counter}_test_migration_#{@_counter}.rb"
    file_path = File.join(root_path, file_name)

    File.write(file_path, <<~RUBY)
      class TestMigration#{@_counter} < ActiveRecord::Migration[7.0]
        #{migration_content}
      end
    RUBY

    migrate! if migrate
  end

  def create_enum(name, values)
    create_migration(<<~RUBY, migrate: true)
      def change
        create_enum(#{name.inspect}, #{values.inspect})
      end
    RUBY
  end

  def add_column(table_name, column_name, column_type)
    create_migration(<<~RUBY, migrate: true)
      def change
        add_column #{table_name.inspect}, #{column_name.inspect}, #{column_type.inspect}
      end
    RUBY
  end

  def migrate!
    migrations_context.forward
  end

  def rollback!
    migrations_context.rollback
  end

  def pg_columns_type(table_name)
    sql_query = <<~SQL
      SELECT *
        FROM information_schema.columns
       WHERE table_schema = 'public'
         AND table_name   = '#{table_name}';
    SQL

    execute_sql_query(sql_query)
      .map(&:symbolize_keys)
      .index_by { |column| column[:column_name].to_sym }
      .transform_values { |column| column[:udt_name] }
  end

  def pg_enums
    sql_query = <<~SQL
      select n.nspname as enum_schema,  
             t.typname as enum_name,  
             e.enumlabel as enum_value
      from pg_type t 
         join pg_enum e on t.oid = e.enumtypid  
         join pg_catalog.pg_namespace n ON n.oid = t.typnamespace;
    SQL

    execute_sql_query(sql_query)
      .map(&:symbolize_keys)
      .group_by { |data| data[:enum_name].to_sym }
      .transform_values { |data| data.map { |d| d[:enum_value] } }
  end

  def execute_sql_query(sql_query)
    ActiveRecord::Base.connection.execute(sql_query)
  end
end
