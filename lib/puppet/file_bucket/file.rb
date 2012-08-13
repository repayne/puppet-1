require 'puppet/file_bucket'
require 'puppet/indirector'
require 'puppet/util/checksums'

class Puppet::FileBucket::File
  # This class handles the abstract notion of a file in a filebucket.
  # There are mechanisms to save and load this file locally and remotely in puppet/indirector/filebucketfile/*
  # There is a compatibility class that emulates pre-indirector filebuckets in Puppet::FileBucket::Dipper
  extend Puppet::Indirector
  indirects :file_bucket_file, :terminus_class => :selector

  attr :contents
  attr :bucket_path

  include Puppet::Util::Checksums

  def initialize( contents, options = {} )
    raise ArgumentError.new("contents must be a String, got a #{contents.class}") unless contents.is_a?(String)
    @contents = contents

    @bucket_path = options.delete(:bucket_path)
    Puppet.settings.use('main')
    @checksum_type = Puppet[:digest_algorithm] || 'md5'
    @checksum_type = @checksum_type.intern unless @checksum_type.is_a? Symbol
    raise ArgumentError.new("invalid checksum type #@checksum_type") unless known_checksum_types.include? @checksum_type
    raise ArgumentError.new("Unknown option(s): #{options.keys.join(', ')}") unless options.empty?
  end

  def checksum_type
    @checksum_type.to_s
  end

  def checksum
    "{#{checksum_type}}#{checksum_data}"
  end

  def checksum_data
    algorithm = method(@checksum_type)
    @checksum_data ||= algorithm.call(contents)
  end

  def to_s
    contents
  end

  def name
    "#{checksum_type}/#{checksum_data}"
  end

  def self.from_s(contents)
    self.new(contents)
  end

  def to_pson
    { "contents" => contents }.to_pson
  end

  def self.from_pson(pson)
    self.new(pson["contents"])
  end
end
