module BosonLib
  # @render_options :change_fields=>['arguments', 'commands'],
  #  :filters=>{:default=>{'commands'=>:inspect}}
  # @options :count=>:boolean, :transform=>true
  # Lists arguments from all known commands. Depends on option_command_filters plugin.
  def arguments(options={})
    Boson::Index.read
    hash = Boson::Index.commands.inject({}) {|t,com|
      (com.args || []).each {|arg|
        arg_name = options[:transform] ? Boson::OptionCommand.extract_argument(arg[0].to_s) : arg[0]
        (t[arg_name] ||= []) << com.name
      }
      t
    }
  end

  # @render_options :change_fields=>['name', 'commands'], :filters=>{:default=>{'commands'=>:inspect}}
  # @options :type=>:boolean, [:skip_booleans, :S]=>true, :toggle_global_options=>:boolean, :use_parser=>true
  # @desc Lists option stats from all known commands. Doesn't include boolean options
  # if listing option names.
  def opts(options={})
    Boson::Index.read
    hash = Boson::Index.commands.select {|e| e.option_command? }.inject({}) {|a,com|
      opt_parser = options[:toggle_global_options] ?
        Boson::Scientist.option_command(com).option_parser : com.option_parser
      names_or_types = options[:use_parser] ?
        (options[:type] ? opt_parser.types : opt_parser.names) :
        (options[:type]) ? [] :
        ( (options[:toggle_global_options] ? com.render_options : com.options) || {} ).
          keys.map {|e| Array(e)[0] }.flatten.map {|e| e.to_s}
      names_or_types.each {|e|
        # skip boolean options
        next if options[:skip_booleans] && !options[:type] &&
          (opt_parser.option_type(opt_parser.dasherize(e)) == :boolean)
        (a[e] ||= []) << com.name
      }
      a
    }
  end

  # Used as a pipe option to pipe to any command
  def post_command(arg, command)
    Boson.full_invoke(command, [arg])
  end

  # @options :all=>:boolean, :verbose=>true, :reset=>:boolean
  # Updates/resets index of libraries and commands
  def index(options={})
    Boson::Index.indexes {|index|
      File.unlink(index.marshal_file) if options[:reset] && File.exists?(index.marshal_file)
      index.update(options)
    }
  end

  # Downloads a url and saves to a local boson directory
  def download(url)
    filename = determine_download_name(url)
    File.open(filename, 'w') { |f| f.write get(url) }
    filename
  end

  # Tells you what methods in current binding aren't boson commands.
  def undetected_methods(priv=false)
    public_undetected = metaclass.instance_methods - (Kernel.instance_methods + Object.instance_methods(false) + MyCore::Object::InstanceMethods.instance_methods +
      Boson.commands.map {|e| [e.name, e.alias] }.flatten.compact)
    public_undetected -= IRB::ExtendCommandBundle.instance_eval("@ALIASES").map {|e| e[0].to_s} if Object.const_defined?(:IRB)
    priv ? (public_undetected + metaclass.private_instance_methods - (Kernel.private_instance_methods + Object.private_instance_methods)) : public_undetected
  end

  private  
  def determine_download_name(url)
    FileUtils.mkdir_p(File.join(Boson.repo.dir,'downloads'))
    basename = strip_name_from_url(url) || url.sub(/^[a-z]+:\/\//,'').tr('/','-')
    filename = File.join(Boson.repo.dir, 'downloads', basename)
    filename += "-#{Time.now.strftime("%m_%d_%y_%H_%M_%S")}" if File.exists?(filename)
    filename
  end
end