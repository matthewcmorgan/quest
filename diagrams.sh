#!/bin/bash
# installed dependencies - ruby, gem, gem install mkstack
# installed dependencies - node, npm, npm install aws-cdk@2.x @mhlabs/cfn-diagram @mhlabs/cfn-diagram-ci

TEMPLATE_PATH="${TEMPLATE_PATH:-.}"
PIPELINE_NAME="blackbird-repo-templates"
OUT="${TEMPLATE_PATH}/diagram"
echo "Set pipeline_name: ${PIPELINE_NAME}"
echo "Set template_path: ${TEMPLATE_PATH}"
echo "Set destination: ${OUT}"

mkdir -p "${OUT}" || exit 1

# Move around requirements for render templates
rsync blackbird_config.yml "${TEMPLATE_PATH}"
rsync -a shared/blackbird/tools "${TEMPLATE_PATH}/blackbird" --exclude=generate-tags-for-environment-from-pipeline-config.py

# If we have a render manifest, then render the templates. ami-bake does not
if [ -f "${TEMPLATE_PATH}/render_manifest.yml" ]; then
    cd "${TEMPLATE_PATH}" || exit 1
    pip3 install --upgrade -r blackbird/tools/requirements.txt -t /tmp
    python3 "blackbird/tools/pipeline_config.py" --pipeline-name "$PIPELINE_NAME" --pipeline-partition primary --branch master --pipeline-config-path "pipeline_config.json"
    python3 "blackbird/tools/render_templates.py" --pipeline-config-path "pipeline_config.json" --render-manifest-path "render_manifest.yml"
    cd - || exit 1
fi

# Generate the diagram for cdk projects from the cdk synth -o cdk.out
if [ -f "${TEMPLATE_PATH}/cdk/cdk.json" ]; then
    cd "${TEMPLATE_PATH}/cdk" || exit 1
    npm install -g aws-cdk@2.x
    pip3 install --upgrade -r requirements.txt
    rsync pr-cdk.context.json cdk.context.json
    CDK_DEPLOY_ACCOUNT=149646805241 CDK_DEPLOY_REGION=us-east-1 cfn-diagram-ci html -t "cdk.json"
    cd - || exit 1
elif [ "${OUT}" == "static/pipeline" ]; then
    # Generate pipeline diagram from any yml files we find
    find . -type f -name "*.yml" \! -path "*/templates/*" \! -path "*/experimental/*" \! -name "*.jinja.yml" \! -name "*combined.yml*" \! -name "*ver.yml*" -print0 | xargs -0 mkstack -f yaml --verbose -o "CloudFormation/combined.yml"
    cd CloudFormation || exit 1
    cfn-diagram-ci draw.io -t "combined.yml" -o "../diagram/diagram.drawio"
    cfn-diagram-ci html -t "combined.yml"
    mv cfn-diagram.png "../diagram/cfn-diagram.png"
    cd - || exit 1
else
    # not a cdk project, so combine template files and render diagram
    cd "${TEMPLATE_PATH}" || exit 1
    find . \! -name "*.jinja.yml" -name "*.yml" -print0 | xargs -0 mkstack -f yaml --verbose -o "CloudFormation/combined.yml"
    cd - || exit 1
    cd "${TEMPLATE_PATH}/CloudFormation" || exit 1
    cfn-diagram-ci draw.io -t "combined.yml" -o "../diagram/diagram.drawio"
    cfn-diagram-ci html -t "combined.yml"
    mv cfn-diagram.png "../diagram/cfn-diagram.png"
    cd ../../../ || exit 1
fi
