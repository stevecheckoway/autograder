require 'active_record'
require_relative 'log'

ActiveRecord::Base.logger = AutoGrader.logger

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: 'grades.db', pool: 16)

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.data_sources.include? 'grades'
    create_table :grades do |table|
      table.column :organization, :string
      table.column :assignment, :string
      table.column :repository, :string
      table.column :branch, :string
      table.column :commit, :string
      table.column :status, :string, limit: 1
      table.column :created_at, :datetime
      table.column :output, :binary
    end
  end
end

module AutoGrader
  class Grade < ActiveRecord::Base
  end
end

# vim: set sw=2 sts=2 ts=8 expandtab:
