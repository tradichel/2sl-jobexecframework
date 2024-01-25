#!/bin/bash -e
#
# generic function to call the get_id function for an AWS type
# based on a parameter configuration value in this format:
# :get_id:resource_category:resource_type:name

#profile must be set to the correct account where the resource exists
#or assume the correct role...
source resources/ssm/parameter/parameter_functions.sh
source shared/validate.sh
source shared/functions.sh

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

deploy(){
	job_parameter="$1"
  
	echo "Parsing Job Parameter:  $job_parameter"

  role=$(echo $job_parameter | cut -d "/" -f4)
  resource=$(echo $job_parameter | cut -d "/" -f5)

  rcat=$(echo $resource | cut -d "-" -f1)
  rtype=$(echo $resource | cut -d "-" -f2)
  rname=$(echo $resource | cut -d "-" -f3)

  config=$(get_ssm_parameter_job_config $job_parameter)

  read -a lines <<<"$config"
  for i in "${lines[@]}"
  do
     pname=$(echo $i | cut -d "=" -f1)
     pvalue=$(echo $i | cut -d "=" -f2)

     if [ "$pname" == "env" ];
         then set env=$value;
         if [ "$rname" != "$env" ]; then set rname=$env'-'$rname; fi
     		 continue
		 fi

     if [ "$pname" == "region" ];
         then set region=$value;
         continue
     fi

     if [[ $pname == cf_param_* ]]; then
         if [[ $pvalue == :get_id:* ]]; then
            pvalue=$(get_config_resource_id $pvalue)
         fi
         p=$(add_parameter $pname $pvalue)
		 fi
     
   done

   deploy_stack $rname $rcat $rtype $p
}


