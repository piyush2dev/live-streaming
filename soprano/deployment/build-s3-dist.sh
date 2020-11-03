#!/bin/bash

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Please provide the base source bucket name, trademark approved solution name and version where the lambda code will eventually reside."
    echo "For example: ./build-s3-dist.sh solutions trademarked-solution-name v1.0.0"
    exit 1
fi

set -e

# Get reference for all important folders
template_dir="$PWD"
template_dist_dir="$template_dir/global-s3-assets"
build_dist_dir="$template_dir/regional-s3-assets"
source_dir="$template_dir/../source"

echo "------------------------------------------------------------------------------"
echo "Rebuild distribution"
echo "------------------------------------------------------------------------------"
rm -rf $template_dist_dir
mkdir -p $template_dist_dir
rm -rf $build_dist_dir
mkdir -p $build_dist_dir

[ -e $template_dist_dir ] && rm -r $template_dist_dir
[ -e $build_dist_dir ] && rm -r $build_dist_dir
mkdir -p $template_dist_dir $build_dist_dir

echo "------------------------------------------------------------------------------"
echo "Main CloudFormation Template"
echo "------------------------------------------------------------------------------"
cp $template_dir/live-streaming-on-aws.yaml $template_dist_dir/live-streaming-on-aws.template

replace="s/CODE_BUCKET/$1/g"
echo "sed -i -e $replace"
sed -i -e $replace $template_dist_dir/live-streaming-on-aws.template
replace="s/SOLUTION_NAME/$2/g"
echo "sed -i -e $replace"
sed -i -e $replace $template_dist_dir/live-streaming-on-aws.template
replace="s/CODE_VERSION/$3/g"
echo "sed -i -e $replace"
sed -i -e $replace $template_dist_dir/live-streaming-on-aws.template
# remove tmp file for MACs
[ -e $template_dist_dir/live-streaming-on-aws.template-e ] && rm -r $template_dist_dir/live-streaming-on-aws.template-e

echo "------------------------------------------------------------------------------"
echo "Creating NODE custom-resource deployment package"
echo "------------------------------------------------------------------------------"
cd $source_dir/custom-resource/
rm -rf node_modules/
npm ci --production
zip -q -r9 $build_dist_dir/custom-resource.zip *

echo "------------------------------------------------------------------------------"
echo "Buildinbg console"
echo "------------------------------------------------------------------------------"
cd $source_dir/console
[ -e build ] && rm -r build
[ -e node_modules ] && rm -rf node_modules
npm ci
touch public/assets/aws-exports.js
npm run build
mkdir $build_dist_dir/console
cp -r ./build/* $build_dist_dir/console/

echo "------------------------------------------------------------------------------"
echo "Generate console manifest file"
echo "------------------------------------------------------------------------------"
cd $source_dir/console/build
manifest=(`find * -type f ! -iname ".DS_Store"`) 
manifest_json=$(IFS=,;printf "%s" "${manifest[*]}")
echo "[\"$manifest_json\"]" | sed 's/,/","/g' > $build_dist_dir/console-manifest.json

echo "------------------------------------------------------------------------------"
echo "Build S3 Packaging Complete"
echo "------------------------------------------------------------------------------"
