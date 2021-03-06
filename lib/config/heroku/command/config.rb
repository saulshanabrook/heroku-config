require "heroku/command/base"
require "heroku/command/config"

class Heroku::Command::Config < Heroku::Command::Base

  # config:pull [FILENAME]
  #
  # pull heroku config vars down to the local environment
  #
  # will not overwrite existing config vars by default
  #
  # -i, --interactive  # prompt whether to overwrite each config var
  # -o, --overwrite    # overwrite existing config vars
  #
  def pull
    filename = shift_argument || ".env"
    validate_arguments!
    interactive = options[:interactive]
    overwrite   = options[:overwrite]

    config = merge_config(remote_config, local_config, interactive, overwrite)
    write_local_config(config, filename)
    display "Config for #{app} written to #{filename}"
  end

  # config:push [FILENAME]
  #
  # push local config vars to heroku
  #
  # will not overwrite existing config vars by default
  #
  # -i, --interactive  # prompt whether to overwrite each config var
  # -o, --overwrite    # overwrite existing config vars
  #
  def push
    filename = shift_argument || ".env"
    validate_arguments!
    interactive = options[:interactive]
    overwrite   = options[:overwrite]

    config = merge_config(local_config(filename), remote_config, interactive, overwrite)
    write_remote_config(config)
    display "Config in #{filename} written to #{app}"
  end

private ######################################################################

  def local_config(filename)
    File.read(filename).split("\n").inject({}) do |hash, line|
      if line =~ /\A([A-Za-z_0-9]+)=(.*)\z/
        hash[$1] = $2
      end
      hash
    end
  rescue
    {}
  end

  def remote_config
    api.get_config_vars(app).body
  end

  def write_local_config(config, filename)
    temp_filename = "#{filename}.#{Time.now.utc.to_i}.tmp"

    File.open(temp_filename, "w") do |file|
      config.keys.sort.each do |key|
        file.puts "#{key}=#{config[key]}"
      end
    end

    File.delete(filename) if File.exists?(filename)

    File.rename(temp_filename, filename)

  end

  def write_remote_config(config)
    remote_config_vars = remote_config

    add_config_vars = config.inject({}) do |hash, (key,val)|
      hash[key] = val unless remote_config_vars[key] == val
      hash
    end

    api.put_config_vars(app, add_config_vars)
  end

  def merge_config(source, target, interactive=false, overwrite=false)
    if interactive
      source.keys.sort.inject(target) do |hash, key|
        value = source[key]
        display "%s: %s" % [key, value]
        hash[key] = value if confirm("Overwite? (y/N)")
        hash
      end
    else
      overwrite ? target.merge(source) : source.merge(target)
    end
  end

end
