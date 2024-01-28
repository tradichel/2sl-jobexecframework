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
  
	#source $file
  #id=$(get_id $name)
  
  #trying the following when multiple files have get_id
  id=$(sh -c "source $file; get_id $name")
  echo $id
}

deploy_resource_config(){
	local job_parameter="$1"	
  local config=("$@")

	validate_job_param_name	$job_parameter

  local resource=$(echo $job_parameter | cut -d "/" -f5)
  local rcat=$(echo $resource | cut -d "-" -f1)
  local rtype=$(echo $resource | cut -d "-" -f2)
  local rname=$(echo $resource | cut -d "-" -f3)
	local pname=""
	local pvalue=""
	local env=""
	local region=""
	local p=""
	local parm=""

  for i in "${config[@]}"
  do
		 echo "Line: $i"
     pname=$(echo $i | cut -d "=" -f1 | tr -d ' ')
     pvalue=$(echo $i | cut -d "=" -f2 | tr -d ' ')

     if [ "$pname" == "env" ]; then 
				 env=$pvalue;
         if [ "$rname" != "$env" ]; then rname=$env'-'$rname; fi
		 fi

     if [ "$pname" == "region" ]; then region=$pvalue; fi

     if [[ $pname == cfparam* ]]; then
         if [[ $pvalue == :get_id:* ]]; then
            pvalue=$(get_config_resource_id $pvalue)
         fi
         if [[ $pvalue == :ssm:* ]]; then
						parm=$(echo $pvalue | cut -d ":" -f3)
            pvalue=$(get_ssm_parameter_value $parm)
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
	 validate_set $f "region" $region

	 echo "deploy_stack $rname $rcat $rtype $env $region $p"
   deploy_stack $rname $rcat $rtype $env $region $p
}

deploy() {
   local job_parameter="$1"

   echo "run job: $job_parameter"

   local role=$(echo $job_parameter | cut -d "/" -f4)
   local resource=$(echo $job_parameter | cut -d "/" -f5)
   local rcat=$(echo $resource | cut -d "-" -f1)
   local config=$(get_ssm_parameter_job_config $job_parameter)

   readarray -t -d ' ' a <<<$config
   #declare -p a 

   if [ "$rcat" == "stack" ]; then
      echo "deploy stack"
      deploy_stack_config "${a[@]}"
   else
     echo "deploy resource"
     deploy_resource_config $job_parameter "${a[@]}"
   fi
}

deploy_stack_config(){

   local stack_config=("$@")

   local job_parameter=""
	 local first="true"

   for i in "${stack_config[@]}"
   do

     local pname=$(echo $i | cut -d "=" -f1 | tr -d ' ') 
     local pvalue=$(echo $i | cut -d "=" -f2 | tr -d ' ')

     if [ "$pname" == "Sequential:" ]; then parallel=""; continue; fi
     if [ "$pname" == "Parallel:" ]; then 
			parallel="&"; 
			if [ "first" == "true" ]; then first="false"; else wait; fi
			continue; 
     fi
			
     if [[ $pname == /job/* ]]; then
        if [ "$job_parameter" != "" ]; then
             echo "~~~~"
             echo "Deploy job $job_parameter"
             echo "Parallel: $parallel"
             declare -p job_config
             c="deploy_resource_config $job_parameter \"${config[@]}\" $parallel"
             $($c)
             echo "~~~"
        fi
        job_parameter=$pname
        declare -a job_config
        continue
     fi

     if [[ $pname ==  cfparam* ]]; then job_config+=($i); fi

   done

}



