#!/bin/bash -e
#
# generic function to call the get_id function for an AWS type
# based on a parameter configuration value in this format:
# :get_id:resource_category:resource_type:name

#profile must be set to the correct account where the resource exists
#or assume the correct role...
source resources/ssm/parameter_functions.sh
source shared/validate.sh

get_config_resource_id(){
  value="$1"

  category=$(echo $value | cut -d ':' -f3)
  resource_type=$(echo $value | cut -d ':' -f4)
  name=$(echo $value | cut -d ':' -f5)

  file='resources/'$category'/'$resource_type'/'$resource_type'_functions.sh'
 	source $file

  id=$(get_id $name)
  echo $id

}

parse_config(){
	job_parameter="$1"

	role=$(echo $job_parameter | cut -d "/" -f4)
	resource=$(echo $job_parameter | cut -d "/" -f5)
	rcat=$(echo $resource | cut -d "/" -f1)
	rtype=$(echo $resource | cut -d "/" -f2)
	rname=$(echo $resource | cut -d "/" -f3)
	
	config=$(get_paramter_value $job_parameter)

	#loop through lines
	#if env set env and adjust resource name
	#if cf_param_ then get value
	#if value starts with :get_id: then call get id function above
	#set parameter name and value in array of parameters (p)

	deploy_stack $name $rcat $rtype $p

}


