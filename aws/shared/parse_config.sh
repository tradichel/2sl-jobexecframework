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
	config="$1"
  rcat="$2"
	rtype="$3"
	rname="$4"

  for i in "${config[@]}"
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

	 echo "deploy_stack $rname $rcat $rtype $env $region $p"
   deploy_stack $rname $rcat $rtype $env $region $p
}

deploy() {
	job_parameter="$1"

  role=$(echo $job_parameter | cut -d "/" -f4)
  resource=$(echo $job_parameter | cut -d "/" -f5)

  rcat=$(echo $resource | cut -d "-" -f1)
  rtype=$(echo $resource | cut -d "-" -f2)
  rname=$(echo $resource | cut -d "-" -f3)

  config=$(get_ssm_parameter_job_config $job_parameter)

	read -a config <<<"$config"

	if [ "$rcat" == "stack" ]; then
    deploy_stack_config $config $rcat $rtype $rname
	else
		deploy_resource_config $config $rcat $rtype $rname
	fi

}

deploy_stack_config(){
  config="$1"
  rcat="$2"
  rtype="$3"
  rname="$4"

  for i in "${lines[@]}"
  do
     pname=$(echo $i | cut -d "=" -f1 | tr -d ' ') 
     pvalue=$(echo $i | cut -d "=" -f2 | tr -d ' ')

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

     if [ "$pname" == "Sequential:" ]; then parallel=0; continue; fi
 		 if [ "$pname" == "Parallel:" ]; then parallel=1; continue; fi

		 echo "Parallel: $parallel"

   done

}


