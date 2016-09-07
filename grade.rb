require 'active_record'
require_relative 'log'

ActiveRecord::Base.logger = AutoGrader.logger

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: 'grades.db')

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.data_sources.include? 'grades'
    create_table :grades do |table|
      table.column :organization, :string
      table.column :assignment, :string
      table.column :repository, :string
      table.column :commit, :string
      table.column :success, :boolean
      table.column :output, :blob
    end
  end
end

module AutoGrader
  class Grade < ActiveRecord::Base
  end
end

# vim: set sw=2 sts=2 ts=8 expandtab:
