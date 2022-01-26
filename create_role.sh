#!/bin/bash
#
# create_role.sh
# ============
#
# Create a new IAM role for task execution.
#
# Usage:
#     create_role.sh  [Options]
#     create_role.sh  -h|--help
#
# Options:
#   -a, --account ACCOUNT       Specify AWS account ID
#                               (default: get by AWS CLI)
#   -r, --region REGION         Specify a region
#                               (default: get from ~/.aws/config)

# Function help() shows help
help() {
  awk 'NR > 2 {
    if (/^#/) { sub("^# ?", ""); print }
    else { exit }
  }' $0
}

while getopts arntbpih-: opt; do
    optarg="${!OPTIND}"
    [[ "$opt" = - ]] && opt="-$OPTARG"

    case "-$opt" in
        -a | --account ) AWS_ACCOUNT_ID="$optarg" ;;
        -r | --region ) REGION="$optarg" ;;
        -h | --help ) help; exit 1 ;;
        --) break ;;
        -\?) exit 1 ;;
        --*) echo "$0: illegal option -- ${opt##-}" >&2
             exit 1 ;;
    esac
    shift $((OPTIND - 1))
done
shift $((OPTIND - 1))


if [ -z "$AWS_ACCOUNT_ID" ]; then
  AWS_ACCOUNT_ID=`aws sts get-caller-identity | jq .Account | sed 's/"//g'`
  if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "Error: -a option for AWS_ACCOUNT_ID is required." 1>&2
    exit 1
  fi
fi

if [ -z "$REGION" ]; then
  REGION=`aws configure get region`
  if [ -z "$REGION" ]; then
    echo "Error: -r option for REGION is required." 1>&2
    exit 1
  fi
fi

echo "AWS_ACCOUNT_ID: $AWS_ACCOUNT_ID"
echo "REGION: $REGION"

set -ex

# Create ECS task execution IAM role
unset tmpfile

atexit() {
  [[ -n ${tmpfile-} ]] && rm -f "$tmpfile"
}

trap atexit EXIT
trap 'rc=$?; trap - EXIT; atexit; exit $?' INT PIPE TERM

tmpfile=$(mktemp "/tmp/${0##*/}.tmp.XXXXXX")

IFS= read -r -p "Role Name > " ROLE_NAME ;
echo "Specify SSM Parameter Name for permission to access IAM secrets registered in SSM.";
IFS= read -p "AWS_ACCESS_KEY SSM Parameter Name > " SSM_AWS_ACCESS_KEY ;
IFS= read -p "AWS_SECRET_KEY SSM Parameter Name > " SSM_AWS_SECRET_KEY ;

cat ./policies/ssm-access-policy.json | \
    sed -e "s/\${REGION}/${REGION}/g" | \
    sed -e "s/\${AWS_ACCOUNT_ID}/${AWS_ACCOUNT_ID}/g" | \
    sed -e "s/\${SSM_AWS_ACCESS_KEY}/${SSM_AWS_ACCESS_KEY}/g" >> "$tmpfile"
    sed -e "s/\${SSM_AWS_SECRET_KEY}/${SSM_AWS_SECRET_KEY}/g" >> "$tmpfile"

aws iam create-role \
--role-name $ROLE_NAME \
--assume-role-policy-document "file://policies/ecs-tasks-trust-policy.json"
echo "Created ${ROLE_NAME} role."

aws iam put-role-policy \
--role-name $ROLE_NAME \
--policy-name ssm-parameter-access-inline-policy \
--policy-document "file://${tmpfile}"
echo "Put ssm-parameter-access-inline-policy to ${ROLE_NAME}."

aws iam attach-role-policy \
--role-name $ROLE_NAME \
--policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
echo "Attach AmazonECSTaskExecutionRolePolicy to ${ROLE_NAME}."
