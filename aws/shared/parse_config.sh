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

deploy_resource_config(){
	r_job_parameter="$1"	
	r_config="$2"

	validate_job_param_name	$r_job_parameter

  resource=$(echo $r_job_parameter | cut -d "/" -f5)
  rcat=$(echo $resource | cut -d "-" -f1)
  rtype=$(echo $resource | cut -d "-" -f2)
  rname=$(echo $resource | cut -d "-" -f3)

  for i in "${r_config[@]}"
  do
     pname=$(echo $i | cut -d "=" -f1)
     pvalue=$(echo $i | cut -d "=" -f2)

		 echo $pname

     if [ "$pname" == "env" ]; then 
				 env=$pvalue;
         if [ "$rname" != "$env" ]; then rname=$env'-'$rname; fi
     		 echo "Env: $env"
				 echo "rname: $rname"
				 continue
		 fi

     if [ "$pname" == "region" ];
         then region=$pvalue;
				 echo "Region: $region"
         continue
     fi

     if [[ $pname == cfparam* ]]; then
         if [[ $pvalue == :get_id:* ]]; then
            pvalue=$(get_config_resource_id $pvalue)
         fi
         p=$(add_parameter $pname $pvalue $p)
		 fi
     
   done

   p=$(add_parameter "cfparamName" $rname $p)

   f=${FUNCNAME[0]}	 
	 validate_set $f "rname" $rname
	 validate_set $f "rcat" $rcat
	 validate_set $f "rtype" $rtype
	 validate_set $f "env" $env
	 validate_region $f $region

	 echo "deploy_stack $rname $rcat $rtype $env $region $p"
   deploy_stack $rname $rcat $rtype $env $region $p
}

deploy() {
	job_parameter="$1"

 	role=$(echo $job_parameter | cut -d "/" -f4)
  resource=$(echo $job_parameter | cut -d "/" -f5)
  rcat=$(echo $resource | cut -d "-" -f1)
 
  job_config=$(get_ssm_parameter_job_config $job_parameter)

	read -a config <<<"$job_config"

	if [ "$rcat" == "stack" ]; then
    deploy_stack_config $config
	else
		deploy_resource_config $job_parameter $config
	fi
}

deploy_stack_config(){
  stack_config="$1"

	job_parameter=""
	job_config=$@

  for i in "${stack_config[@]}"
  do
		
     pname=$(echo $i | cut -d "=" -f1 | tr -d ' ') 
     pvalue=$(echo $i | cut -d "=" -f2 | tr -d ' ')

     echo $pname

     if [[ $pname == /job/* ]]; then 
        job_parameter=$pname 
     fi

		 if [ "$job_parameter" != "" ]; then
				if [[ $pname ==  -* ]]; then 
					job_config+=($i)
				else
					deloy_resource_config $job_parameter $job_config
					job_parameter=""
					job_config=$@
				fi
		 fi
 
     if [ "$pname" == "Sequential:" ]; then parallel=0; continue; fi
 		 if [ "$pname" == "Parallel:" ]; then parallel=1; continue; fi

		 echo "Parallel: $parallel"

   done

}



