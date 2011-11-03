require 'puppet'
require 'puppet/indirector'
require 'puppet/file_serving'
require 'puppet/file_serving/base'
require 'puppet/util/checksums'

# A class that handles retrieving file metadata.
class Puppet::FileServing::Metadata < Puppet::FileServing::Base

  include Puppet::Util::Checksums

  extend Puppet::Indirector
  indirects :file_metadata, :terminus_class => :selector

  attr_reader :path, :owner, :group, :mode, :checksum_type, :checksum, :ftype, :destination

  PARAM_ORDER = [:mode, :ftype, :owner, :group]

  def attributes_with_tabs
    raise(ArgumentError, "Cannot manage files of type #{ftype}") unless ['file','directory','link'].include? ftype
    desc = []
    PARAM_ORDER.each { |check|
      check = :ftype if check == :type
      desc << send(check)
    }

    desc << checksum
    desc << @destination rescue nil if ftype == 'link'

    desc.join("\t")
  end

  def checksum_type=(type)
    raise(ArgumentError, "Unsupported checksum type #{type}") unless respond_to?("#{type}_file")

    @checksum_type = type
  end

  class MetaStat
    extend Forwardable

    def initialize(stat)
      @stat = stat
    end

    def_delegator :@stat, :uid, :owner
    def_delegator :@stat, :gid, :group
    def_delegators :@stat, :mode, :ftype
  end

  class WindowsStat < MetaStat
    if Puppet.features.microsoft_windows?
      require 'puppet/util/windows/security'
    end

    def initialize(stat, path)
      super(stat)
      @path = path
    end

    { :owner => 'S-1-5-32-544',
      :group => 'S-1-0-0',
      :mode => 0644
    }.each do |method, default_value|
      define_method method do
        Puppet::Util::Windows::Security.send("get_#{method}", @path) || default_value
      end
    end
  end

  def collect_stat(path)
    stat = stat()

    if Puppet.features.microsoft_windows?
      WindowsStat.new(stat, path)
    else
      MetaStat.new(stat)
    end
  end

  # Retrieve the attributes for this file, relative to a base directory.
  # Note that File.stat raises Errno::ENOENT if the file is absent and this
  # method does not catch that exception.
  def collect
    real_path = full_path

    stat = collect_stat(real_path)
    @owner = stat.owner
    @group = stat.group
    @ftype = stat.ftype

    # We have to mask the mode, yay.
    @mode = stat.mode & 007777

    case stat.ftype
    when "file"
      @checksum = ("{#{@checksum_type}}") + send("#{@checksum_type}_file", real_path).to_s
    when "directory" # Always just timestamp the directory.
      @checksum_type = "ctime"
      @checksum = ("{#{@checksum_type}}") + send("#{@checksum_type}_file", path).to_s
    when "link"
      @destination = File.readlink(real_path)
      @checksum = ("{#{@checksum_type}}") + send("#{@checksum_type}_file", real_path).to_s rescue nil
    else
      raise ArgumentError, "Cannot manage files of type #{stat.ftype}"
    end
  end

  def initialize(path,data={})
    @owner       = data.delete('owner')
    @group       = data.delete('group')
    @mode        = data.delete('mode')
    if checksum = data.delete('checksum')
      @checksum_type = checksum['type']
      @checksum      = checksum['value']
    end
    Puppet.settings.use :main
    @checksum_type ||= Puppet[:digest_algorithm]
    @checksum_type ||= "md5"
    @ftype       = data.delete('type')
    @destination = data.delete('destination')
    super(path,data)
  end

  PSON.register_document_type('FileMetadata',self)
  def to_pson_data_hash
    {
      'document_type' => 'FileMetadata',

        'data'       => super['data'].update(
          {
          'owner'        => owner,
          'group'        => group,
          'mode'         => mode,
          'checksum'     => {
            'type'   => checksum_type,
            'value'  => checksum
        },
        'type'         => ftype,
        'destination'  => destination,

        }),
      'metadata' => {
        'api_version' => 1
        }
    }
  end

  def to_pson(*args)
    to_pson_data_hash.to_pson(*args)
  end

  def self.from_pson(data)
    new(data.delete('path'), data)
  end

end
