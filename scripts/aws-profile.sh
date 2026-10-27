# shellcheck shell=bash
# Sourced by the other scripts. Selects the AWS CLI profile (default: "demo"),
# resolves the region, and asks you to confirm the account before changing anything.
#
# Override with:  AWS_PROFILE=other-profile AWS_REGION=ap-south-1 scripts/setup.sh
# Skip the prompt: YES=1 scripts/setup.sh

export AWS_PROFILE="${AWS_PROFILE:-demo}"

# Stray keys in the shell would silently override the profile, so drop them.
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

AWS_REGION="${AWS_REGION:-$(aws configure get region --profile "$AWS_PROFILE" 2>/dev/null || true)}"
export AWS_REGION="${AWS_REGION:-us-east-1}"

if [ "${AWS_PROFILE_CONFIRMED:-}" != "1" ]; then
  if ! IDENTITY="$(aws sts get-caller-identity --output text --query '[Account,Arn]' 2>&1)"; then
    echo "Could not use AWS profile '${AWS_PROFILE}':" >&2
    echo "$IDENTITY" >&2
    echo "Check it with: aws sts get-caller-identity --profile ${AWS_PROFILE}" >&2
    exit 1
  fi
  echo "AWS profile: ${AWS_PROFILE}"
  echo "Account/ARN: ${IDENTITY}"
  echo "Region:      ${AWS_REGION}"
  if [ "${YES:-}" != "1" ]; then
    read -r -p "Is this the demo account? [y/N] " answer
    [ "$answer" = "y" ] || { echo "Stopped. Nothing was changed."; exit 1; }
  fi
  export AWS_PROFILE_CONFIRMED=1
fi
