require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    return @columns if @columns

    all_columns = DBConnection.execute2(<<-SQL).first
      SELECT
        *
      FROM
        #{self.table_name}
      LIMIT
        1
      SQL

    @columns = all_columns.map(&:to_sym)
  end

  def self.finalize!
    self.columns.each do |col|

      define_method(col) do
        self.attributes[col]
      end

      define_method("#{col}=") do |value|
        self.attributes[col] = value
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    "#{self}s".downcase
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
      SELECT
        #{self.table_name}.*
      FROM
        #{self.table_name}
    SQL

    self.parse_all(results)
  end

  def self.parse_all(results)
    results.map { |result| self.new(result) }
  end

  def self.find(id)
    fetched = DBConnection.execute(<<-SQL, id)
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        #{self.table_name}.id = ?
      LIMIT
        1
      SQL

    parse_all(fetched).last
  end

  def initialize(params = {})
    params.each do |attr_name, value|
      unless self.class.columns.include?(attr_name.to_sym)
        raise "unknown attribute '#{attr_name}'"
      end

      self.send("#{attr_name}=", value)
    end
  end

  def attributes
    @attributes ||= Hash.new
  end

  def attribute_values
    @attributes.values
  end

  def insert
    my_table = self.class.table_name
    my_columns = self.class.columns.drop(1)

    column_labels = my_columns.map(&:to_s).join(', ')
    q_marks = (['?'] * my_columns.count).join(', ')

    DBConnection.execute(<<-SQL, *attribute_values.drop(1))
      INSERT INTO
        #{my_table} #{column_labels}
      VALUES
        #{q_marks}
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update
    # mapped ::columns to #{attr_name} = ?
    question_marks = self.class.columns.map { |attr_name| "#{attr_name} = ?" }.join(', ')

    DBConnection.execute(<<-SQL)
      UPDATE
        #{self.class.table_name}
      SET
        #{question_marks}
      WHERE
        id = #{self.id}
    SQL
  end

  def save
    id.nil? ? insert : update
  end


end
