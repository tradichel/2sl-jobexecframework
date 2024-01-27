
handle_array(){
	local arr=("$@")

	declare -p arr

}


config="Sequential:
  /job/awsenvinit/dev/organizations-organizationalunit-dev
  	- env=dev
  	- region=us-east-2
  	- cfparamParentid=:get_id:organizations:organizationalunit:root
Parallel:
  /job/awsenvinit/dev/organizations-organizationalunit-governance
   	- env=dev
   	- region=us-east-2
  	- cfparamParentid=:get_id:organizations:organizationalunit:dev
  /job/awsenvinit/dev/organizations-organizationalunit-apps
    - env=dev
    - region=us-east-2
    - cfparamParentid=:get_id:organizations:organizationalunit:dev"


#read -a a <<<$config

IFS=$' ' readarray -t a <<< "$config" 

handle_array "${a[@]}"


