module Pvcglue
  class Ssl < Thor

    desc "csr", "create new csr"

    def csr
      name = Pvcglue.cloud.app_and_stage_name
      system("openssl req -new -newkey rsa:2048 -nodes -keyout #{name}.key -out #{name}.csr")
    end
  end
end
