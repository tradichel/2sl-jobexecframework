#!/bin/bash

#validate argument passed to a bash function
validate_var(){
  local varfunc="$1"
  local varname="$2"
  local varvalue="$3"

  validate_set $varfunc $varname $varvalue

}

#validate that resource starts with valid environment name
validate_resource_name(){
	local resourcename="$1"

	local env=$(echo $resourcename | cut -d "-" -f1)
  validate_env $env
}


#validate that the value only has alphanumeric characters,
#dashes (-) or underscores (_).
validate_alphanumeric_underscore_dash_period(){
	local v=$(echo "$1" | sed 's/[^[:alnum:]_-.]//g')

	if [ "$1" != "$v" ]; then

		>&2 echo "Invalid value. Must contain only alphanumeric characters, strings, dashes or periods."
		exit 1
	fi
}

#validate the value is set (not null, not empty string)
#first parameter is the value, 2nd parameter is the name
validate_set(){
	local varcaller="$1"
	local varname="$2"
	local varvalue=$3

	#remove quotes in varname
	varname=$(echo $varname | sed 's/"//g')
	varname=$(echo $varname | sed "s/'//g")
	#remove spaces in var value
  varvalue=$(echo $varvalue | sed 's/ //g')
  varvalue=$(echo $varvalue | sed 's/"//g')
  varvalue=$(echo $varvalue | sed "s/'//g")
	#remove spaces in var caller
	varcaller=$(echo $varcaller | sed 's/ //g')
  varcaller=$(echo $varcaller | sed 's/"//g')
  varcaller=$(echo $varcaller | sed "s/'//g")

  if [[ ! -v varcaller ]]; then
    echo "Caller is not set in trying to check value $varname: $varvalue"
    exit 1
  fi

  if [ "$varcaller" == "" ]; then
      >&2 echo "Error: caller is empty string. $varname: $varvalue"
      exit 1
  fi

  if [ "$varcaller" == "null" ];  then
      >&2 echo "Error: caller is string null in $varname: $varvalue"
      exit 1
  fi

	#check varname
  if [[ ! -v varname ]]; then
    echo "Varname is not set in trying to check value in $varcaller varvalue: $varvalue"
    exit 1
  fi

	if [ "$varname" == "" ]; then
      >&2 echo "Error: varname is empty string in $varcaller. Value: $varvalue"
      exit 1
  fi

  if [ "$varname" == "null" ];  then
      >&2 echo "Error: $varname value is string null in $varcaller $varvalue"
      exit 1
  fi


  if [ "$varname" == "None" ];  then
      >&2 echo "Error: $varname value is string None in $varcaller $varvalue"
      exit 1
  fi

  if [ "$varname" == "none" ];  then
      >&2 echo "Error: $varname value is string none in $varcaller $varvalue"
      exit 1
  fi

	#check value
	if [[ ! -v varvalue ]]; then
		echo "$varname is not set in $varcaller: $varvalue"
		exit 1
	fi

	if [ "$varvalue" == "" ]; then
	    >&2 echo "Error: $varname value is empty string in $varcaller."
    	exit 1
	fi	

  if [ "$varvalue" == "null" ];  then
      >&2 echo "Error: $varname value is string null in $varcaller: $varvalue"
      exit 1
  fi

}

#replace periods with dashes
dots_to_dashes(){
	local s="$1"
	s=$(echo $s | sed 's/\./-/g')
	echo $s
}

toupper(){
	local value="$1"
  echo $value | tr '[:lower:]' '[:upper:]'
}

tolower(){
	local value="$1"
	echo $value | tr '[:upper:]' '[:lower:]'
}

truncate(){
	local value="$1"
	local length=$2

	value=$(echo "${value:0:$length}")
	echo "$value"
}

remove_period_at_end(){
	local s="$1"
	s=${s%.*}
	echo $s
}


validate_region(){
	local src="$1"
	local region="$2"

	validate_set "$src" "region" "$region"
 
	#TODO: need a way to update regions to allowed
	if [ "$region" != "xx-xxxx-x" ] && [ "$region" != "xx-xxxx-x" ]; then
		echo "Invalid region: $region caller: $src"; exit
	fi	
}

validate_environment(){
	local varcaller="$1"
	local env="$2"
	local resourcename="$3" #optional


	echo "Validating environment. Source: $varcaller Env: $env Resource: $resourcename"
	#TODO: This should pull from an environment list stored somewhere instead of hardcoding it."

  validate_set "$varcaller" "varcaller" "$varcaller"
	validate_set "$varcaller" "env" $env

  for check in "staging" "root" "prod" "dev" "test" "org" "nonprod"; do
        if [ $env == "$check" ]; then
            #environment is ok
            return 0
        fi
  done

  echo "Invalid environment $env."
	echo "If you are naming a resource make sure you prefix it with the env [env]-[resource name]"
	exit 1
 
}

validate_alphanumeric(){
  local v=$(echo "$1" | sed 's/[^[:alnum:]]//g')

  if [ "$1" != "$v" ]; then

    >&2 echo "Invalid value. Must contain only alphanumeric characters."
    exit 1
  fi
}

validate_numeric(){
  local v=$(echo "$1" | sed 's/[^[:digit:]]//g')

  if [ "$1" != "$v" ]; then

    >&2 echo "Invalid value. Must contain only numbers."
    exit 1
  fi
}

#validate that the string does not contain quotes
#note that this does not check for encoded characters
validate_no_quotes(){
  local v=$(echo "$1" | sed "s/'//g" | sed 's/"//g' )

  if [ "$1" != "$v" ]; then
    >&2 echo "Invalid value. No quotes allowed."
    exit 1
  fi
}

#remove unsafe characters and return the result
safe_string_alphanumeric(){
  local ss=$(echo "$1" | sed "s/[^[:alnum:]]//g")
  echo $ss
}

#remove unsafe characters and return the result
safe_string_alphanumeric_underscore_dash(){
	local ss=$(echo "$1" | sed "s/[^[:alnum:]_-]//g")
	echo $ss
}

safe_numeric(){
	local n=$(echo "$1" | sed "s/[^[:digit:]]//g")
	echo $n
}

valdiate_length(){
	local value="$1"
	local length="$2"

	local n=${#value}
	if [ "$n" !=  "$length" ]; then
     >&2 echo "Invalid length: $n. Should be $length"
    exit 1
	fi
}

#parameters list must start with [ and end with ]
#paramters list but be name=value,
validate_parameters(){
  
	if [[ "$1" != [* ]]; then
    >&2 echo "Invalid parameters list. Parameters must be in this format [name=value,name=value,...]."
    exit 1
  fi
  
}

validate_template(){
  local templatefile=$1
  aws cloudformation validate-template --template-body file://$templatefile --profile $PROFILE
}

validate_all_templates(){
  validate_template "resources/ec2/vpc/vpc.yaml"
  validate_template "resources/ec2/routetable/routetable.yaml"
  validate_template "resources/ec2/securitygroup/rules/noaccess.yaml"
}

validate_param(){
  echo "Validating $1 $2 $3"
  echo "validate_param was changed to validate_var and moved to validate.sh."
  echo "The order of arguments changed to: function name, arg name, arg value."
  exit
}

validate_starts_with(){
	local value="$1"
	local match=$2

	if [[ ! $value == $match* ]]; then
			echo "$value does not start with $match"
			exit
	fi

}

validate_job_param_name(){
	local value="$1"

	#job parameter name should have four slashes
	local slashes=$(echo -n $value | sed 's|[^/]||g' | wc -c)
	
	if [ ! $slashes -eq 4 ]; then
		echo "Incorrect number of characters in $value"
		exit 1
	fi
		
	#only charaters should be alphanumeric or a forward
	#slash or dash
	local v=$(echo "$value" | sed -r 's|[^[:alnum:]/-]||g')

	echo "$v"

  if [ "$1" != "$v" ]; then

    >&2 echo "Invalid value. Must contain only alphanumeric characters, forward slashes, or dashes."
    exit 1
  fi

	#validate that the value starts with /job
	validate_starts_with $value "/job"
}


