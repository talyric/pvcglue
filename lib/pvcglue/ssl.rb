module Pvcglue
  class Ssl < Thor

    desc "csr", "create new csr"

    def csr
      name = Pvcglue.cloud.app_and_stage_name
      system("openssl req -new -newkey rsa:2048 -nodes -keyout #{name}.key -out #{name}.csr")
    end


    desc "import", "import .key or .crt or both if no extension given (.crt must be 'prepared' for nginx)"

    def import(file_name)
      cloud_data = Pvcglue.cloud.data

      ext = File.extname(file_name)

      case ext
      when ".crt", ".key"
        cloud_data[Pvcglue.cloud.app_name][:stages][Pvcglue.cloud.stage_name]["ssl_#{ext[1..-1]}"] = File.read(file_name)
      when ""
        cloud_data[Pvcglue.cloud.app_name][:stages][Pvcglue.cloud.stage_name]["ssl_key"] = File.read("#{file_name}.key")
        cloud_data[Pvcglue.cloud.app_name][:stages][Pvcglue.cloud.stage_name]["ssl_crt"] = File.read("#{file_name}.crt")
      else
        raise(Thor::Error, "Unknown file extension:  #{ext}.")
      end

      File.write(::Pvcglue.cloud.local_file_name, TOML.dump(cloud_data))

      Pvcglue::Manager.push_configuration
    end


  end
end
