#!/bin/bash -e
#
# generic function to call the get_id function for an AWS type
# based on a parameter configuration value in this format:
# :get_id:resource_category:resource_type:name

#PROFILE must be set to the correct account where the resource exists
#or assume the correct role...
source resources/ssm/parameter/parameter_functions.sh
source shared/validate.sh
source shared/functions.sh

get_config_resource_id(){
  value="$1"

  local category=$(echo $value | cut -d ':' -f3)
  local resource_type=$(echo $value | cut -d ':' -f4)
  local name=$(echo $value | cut -d ':' -f5)

  local file='resources/'$category'/'$resource_type'/'$resource_type'_functions.sh'

        source $file
  id=$(get_id $name)

  #trying the following when multiple files have get_id
        #c="PROFILE=$PROFILE; source $file; get_id $name"
  #id=$(sh -c $c)
  if [ "$id" == "" ]; then echo "Error getting ID for $value using command: $c"; exit 1; fi
  echo $id
}

deploy_resource_config(){
  local job_parameter="$1"      
  shift
  local config=("$@")

  echo "~~~~~ Resource Config ~~~~~"
  declare -p config
  echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~"

  echo "job parameter in deploy_resource_config: $job_parameter"
  validate_job_param_name       $job_parameter

  local resource=$(echo $job_parameter | cut -d "/" -f5)
  local rcat=$(echo $resource | cut -d "-" -f1)
  local rtype=$(echo $resource | cut -d "-" -f2)
  local rname=$(echo $resource | cut -d "-" -f3)

  f=${FUNCNAME[0]}
  validate_set $f "rname" $rname
  validate_set $f "rcat" $rcat
  validate_set $f "rtype" $rtype

        local pname=""
        local pvalue=""
        local env=""
        local region=""
        local p=""
        local parm=""
        local i=""


for i in "${config[@]}"
  do
     echo "Resource line: $i"

     local pname=$(echo $i | cut -d "=" -f1 | tr -d ' ')
     local pvalue=$(echo $i | cut -d "=" -f2 | tr -d ' ')

     echo 'Resource pname: "'$pname'"'
     echo 'Resource pvalue: "'$pvalue'"'

     if [ "$pname" == "env" ]; then env=$pvalue; echo "Environment: $env"; fi

     if [ "$pname" == "region" ]; then region=$pvalue; echo "Region: $region"; fi

     if [[ $pname == cfparam* ]]; then
         if [[ $pvalue == :get_id:* ]]; then
            pvalue=$(get_config_resource_id $pvalue)
            if [ "$?" == "1" ]; then echo $pvalue; exit 1; else echo "id: $pvalue"; fi
         fi
         if [[ $pvalue == :ssm:* ]]; then
            parm=$(echo $pvalue | cut -d ":" -f3)
            pvalue=$(get_ssm_parameter_value $parm)
            if [ "$?" == "1" ] || [ "$pvalue" == "" ]; then "Error getting ssm paramter value for $parm"; exit 1;
            else echo "SSM Param value: $pvalue"; fi
         fi


         echo "add_parameter $pname $pvalue $p"
         p=$(add_parameter $pname $pvalue $p)
         if [ "$?" == "1" ]; then echo "Error addming parameter $pname $pvalue"; exit 1; fi
      fi
     done

     validate_set $f "env" $env
     validate_set $f "region" $region

     if [ "$rname" != "$env" ]; then rname=$env'-'$rname; fi
     p=$(add_parameter "cfparamName" $rname $p)
     if [ "$?" == "1" ]; then echo "Error addming parameter $pname $pvalue"; exit 1; fi

    echo "deploy_stack $rname $rcat $rtype $env $region $p"
   deploy_stack $rname $rcat $rtype $env $region $p

}

deploy() {
   local job_parameter="$1"

   echo "run job: $job_parameter with profile: $PROFILE"

   local role=$(echo $job_parameter | cut -d "/" -f4)
   local resource=$(echo $job_parameter | cut -d "/" -f5)
   local rcat=$(echo $resource | cut -d "-" -f1)
   local config=$(get_ssm_parameter_job_config $job_parameter)

   readarray -t -d ' ' a <<<$config

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

     echo "Stack Config Line: $i"

     local pname=$(echo $i | cut -d "=" -f1 | tr -d ' ') 
     local pvalue=$(echo $i | cut -d "=" -f2 | tr -d ' ')


     echo "pname: $pname"
     echo "pvalue: $pvalue"

     if [ "$pname" == "Sequential:" ]; then echo "Sequential"; wait; continue; fi

     if [ "$pname" == "Parallel:" ]; then echo "Parallel"; wait; continue; fi

     if [[ $pname == /job/* ]]; then

        echo "Process job name"
        if [ "$job_parameter" != "" ] && [ "$pname" != "$job_parameter" ]; then
            if [ "$parallel" == "P" ]; then
                                                echo "Deploy job $job_parameter $parallel"
                                                        deploy_resource_config $job_parameter "${job_config[@]}"
                                                 else
                                                        echo "Deploy job $job_parameter sequential"
                                                        deploy_resource_config $job_parameter "${job_config[@]}"
                                                        wait
                                                 fi
        fi

        echo "Set job_parameter = $pname"
        job_parameter=$pname
        declare -a job_config
        continue

     fi

      echo "Add line to job config"; job_config+=($i);
    #if [[ $pname ==  cfparam* ]]; then echo "Add cfparm to job config"; job_config+=($i); fi
      #if [[ $pname ==  cfparam* ]]; then echo "Add region to job config"; job_config+=($i); fi
     #if [[ $pname ==  cfparam* ]]; then echo "Add cfparm to job config"; job_config+=($i); fi

   done

}


PROFILE="aws-root"
deploy /job/awsenvinit/root-admin/stack-environment-dev
