source 2sl-jobexecframework/aws/shared/functions.sh

creds=$(curl -H "Authorization: $AWS_CONTAINER_AUTHORIZATION_TOKEN" $AWS_CONTAINER_CREDENTIALS_FULL_URI 2>/dev/null)
profile='root-admin'
region=$AWS_REGION

accesskeyid="$(echo $creds | jq -r ".AccessKeyId")"
secretaccesskey="$(echo $creds | jq -r ".SecretAccessKey")"
sessiontoken="$(echo $creds | jq -r ".Token")"

aws configure set aws_access_key_id $accesskeyid --profile $profile
aws configure set aws_secret_access_key $secretaccesskey --profile $profile
aws configure set region $region --profile $profile
aws configure set output "json" --profile $profile
